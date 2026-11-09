import { afterAll, describe, expect, it } from "vitest";
import { NextRequest } from "next/server";
import { createClient } from "@supabase/supabase-js";
import { getSupabaseServerClient, createSupabaseAuthClient } from "@/lib/api/supabase";
import { GET as listAlerts } from "@/app/api/admin/alerts/route";
import { GET as alertDetail } from "@/app/api/admin/alerts/[id]/route";
import { PATCH as alertStatus } from "@/app/api/admin/alerts/[id]/status/route";
import { GET as listUsers } from "@/app/api/admin/users/route";
import { sb as sbEnv } from "@/config/env.config";
import type { Database } from "@/types/database.types";
import { bearer, cleanupTestUsers, createTestUser, PASSWORD } from "./helpers";

const db = () => getSupabaseServerClient();

async function verifiedUser(role: "user" | "admin") {
  const u = await createTestUser({ fullName: `Test ${role}` });
  await db().auth.admin.updateUserById(u.id, { email_confirm: true });
  await db()
    .from("profiles")
    .update({ email_verified_at: new Date().toISOString(), role })
    .eq("id", u.id);
  const { data, error } = await createSupabaseAuthClient().auth.signInWithPassword({
    email: u.email,
    password: PASSWORD,
  });
  if (error || !data.session) throw new Error("test sign-in failed");
  return { ...u, token: data.session.access_token };
}

const ctx = (id: string) => ({ params: Promise.resolve({ id }) });
const req = (path: string, init?: RequestInit) =>
  new NextRequest(`http://localhost${path}`, init as ConstructorParameters<typeof NextRequest>[1]);

async function openAlert(userId: string) {
  const { data, error } = await db()
    .from("alerts")
    .insert({ user_id: userId, first_latitude: 23.7, first_longitude: 90.4 })
    .select("id")
    .single();
  if (error) throw new Error(`insert alert failed: ${error.code}`);
  return data.id;
}

async function patch(token: string, id: string, action: string) {
  const res = await alertStatus(
    req(`/api/admin/alerts/${id}/status`, {
      method: "PATCH",
      headers: { ...bearer(token), "content-type": "application/json" },
      body: JSON.stringify({ action }),
    }),
    ctx(id),
  );
  return { status: res.status, json: (await res.json()) as Record<string, any> }; // eslint-disable-line @typescript-eslint/no-explicit-any
}

afterAll(cleanupTestUsers);

describe("admin alerts API (Phase 4)", () => {
  it("auth: no token 401, student 403 not_admin, admin (Bearer or cookie) 200", async () => {
    const student = await verifiedUser("user");
    const admin = await verifiedUser("admin");

    expect((await listAlerts(req("/api/admin/alerts"), ctx(""))).status).toBe(401);
    const s = await listAlerts(req("/api/admin/alerts", { headers: bearer(student.token) }), ctx(""));
    expect(s.status).toBe(403);
    expect((await s.json()).code).toBe("not_admin");

    expect(
      (await listAlerts(req("/api/admin/alerts", { headers: bearer(admin.token) }), ctx(""))).status,
    ).toBe(200);
    const viaCookie = await listAlerts(
      req("/api/admin/alerts", { headers: { cookie: `pj_access=${admin.token}` } }),
      ctx(""),
    );
    expect(viaCookie.status).toBe(200);
    // a student's cookie is no better than a student's header
    const studentCookie = await listAlerts(
      req("/api/admin/alerts", { headers: { cookie: `pj_access=${student.token}` } }),
      ctx(""),
    );
    expect(studentCookie.status).toBe(403);
  });

  it("transitions: active -> acknowledged -> resolved only, admin id and timestamps recorded", async () => {
    const student = await verifiedUser("user");
    const admin = await verifiedUser("admin");
    const id = await openAlert(student.id);

    // resolve straight from active is refused
    const skip = await patch(admin.token, id, "resolve");
    expect(skip.status).toBe(409);
    expect(skip.json.code).toBe("invalid_transition");

    const ack = await patch(admin.token, id, "acknowledge");
    expect(ack.status).toBe(200);
    expect(ack.json.data.status).toBe("acknowledged");

    // acknowledging twice is refused (no silent overwrite of the first admin)
    expect((await patch(admin.token, id, "acknowledge")).status).toBe(409);

    const res = await patch(admin.token, id, "resolve");
    expect(res.status).toBe(200);
    expect(res.json.data.status).toBe("resolved");

    // cannot be reopened
    expect((await patch(admin.token, id, "acknowledge")).status).toBe(409);

    const { data: row } = await db().from("alerts").select("*").eq("id", id).single();
    expect(row?.status).toBe("resolved");
    expect(row?.acknowledged_by).toBe(admin.id);
    expect(row?.resolved_by).toBe(admin.id);
    expect(row?.acknowledged_at).not.toBeNull();
    expect(row?.resolved_at).not.toBeNull();
  });

  it("two admins racing: exactly one acknowledge wins", async () => {
    const student = await verifiedUser("user");
    const admin = await verifiedUser("admin");
    const id = await openAlert(student.id);
    const results = await Promise.all(
      Array.from({ length: 6 }, () => patch(admin.token, id, "acknowledge")),
    );
    expect(results.filter((r) => r.status === 200)).toHaveLength(1);
    expect(results.filter((r) => r.status === 409)).toHaveLength(5);
  });

  it("unknown or malformed id: 404; bad action: 422; student cannot change status", async () => {
    const student = await verifiedUser("user");
    const admin = await verifiedUser("admin");
    expect((await patch(admin.token, crypto.randomUUID(), "acknowledge")).status).toBe(404);
    expect((await patch(admin.token, "not-a-uuid", "acknowledge")).status).toBe(404);
    const id = await openAlert(student.id);
    expect((await patch(admin.token, id, "reopen")).status).toBe(422);
    expect((await patch(student.token, id, "acknowledge")).status).toBe(403);
    const { data } = await db().from("alerts").select("status").eq("id", id).single();
    expect(data?.status).toBe("active");
  });

  it("detail returns student info and emergency contacts; list is paginated and filtered", async () => {
    const student = await verifiedUser("user");
    const admin = await verifiedUser("admin");
    await db().from("emergency_contacts").insert([
      { user_id: student.id, name: "Mother", phone: "01711111111" },
      { user_id: student.id, name: "Friend", phone: "01822222222" },
    ]);
    const id = await openAlert(student.id);

    const d = await alertDetail(req(`/api/admin/alerts/${id}`, { headers: bearer(admin.token) }), ctx(id));
    expect(d.status).toBe(200);
    const detail = (await d.json()).data;
    expect(detail.student.email).toBe(student.email);
    expect(detail.contacts.map((c: { name: string }) => c.name)).toEqual(["Mother", "Friend"]);

    const l = await listAlerts(
      req("/api/admin/alerts?status=open&page=1", { headers: bearer(admin.token) }),
      ctx(""),
    );
    const list = (await l.json()).data;
    expect(list.page_size).toBe(20);
    expect(list.items.length).toBeLessThanOrEqual(20);
    expect(list.items.some((a: { id: string }) => a.id === id)).toBe(true);
    // card carries name + student ID only (D-062), no phone or email
    const card = list.items.find((a: { id: string }) => a.id === id);
    expect(Object.keys(card.student).sort()).toEqual(["full_name", "student_id"]);

    const bad = await listAlerts(
      req("/api/admin/alerts?status=bogus", { headers: bearer(admin.token) }),
      ctx(""),
    );
    expect(bad.status).toBe(422);

    const u = await listUsers(req("/api/admin/users?page=1", { headers: bearer(admin.token) }), ctx(""));
    expect(u.status).toBe(200);
    expect((await u.json()).data.items.length).toBeLessThanOrEqual(20);
  });
});

describe("alerts table rules (D-060, RLS, 0013/0014)", () => {
  const asUser = (token: string) =>
    createClient<Database>(sbEnv.url, sbEnv.publish!, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

  it("one open alert per student in the database; allowed again once resolved/cancelled", async () => {
    const student = await verifiedUser("user");
    const first = await openAlert(student.id);
    await expect(openAlert(student.id)).rejects.toThrow(/23505/);
    await db().from("alerts").update({ status: "cancelled" }).eq("id", first);
    await expect(openAlert(student.id)).resolves.toBeTruthy();
  });

  it("a student sees only own alerts; cannot forge admin ids when cancelling", async () => {
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const admin = await verifiedUser("admin");
    const idA = await openAlert(a.id);
    await openAlert(b.id);

    const own = await asUser(a.token).from("alerts").select("id,user_id");
    expect(own.data?.every((r) => r.user_id === a.id)).toBe(true);
    expect(own.data?.map((r) => r.id)).toContain(idA);

    const forged = await asUser(a.token)
      .from("alerts")
      .update({ status: "cancelled", acknowledged_by: admin.id, resolved_by: admin.id })
      .eq("id", idA)
      .select("status,acknowledged_by,resolved_by")
      .single();
    expect(forged.data?.status).toBe("cancelled");
    // needs migration 0014 (trigger pins the admin id columns for students)
    expect(forged.data?.acknowledged_by).toBeNull();
    expect(forged.data?.resolved_by).toBeNull();
  });
});
