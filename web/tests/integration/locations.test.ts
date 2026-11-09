import { afterAll, describe, expect, it } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createSupabaseAuthClient, getSupabaseServerClient } from "@/lib/api/supabase";
import { sb as sbEnv } from "@/config/env.config";
import { AlertService } from "@/services/alert.service";
import type { Database } from "@/types/database.types";
import { cleanupTestUsers, createTestUser, PASSWORD, sleep } from "./helpers";

const db = () => getSupabaseServerClient();

async function verifiedUser(role: "user" | "admin") {
  const u = await createTestUser();
  await db().auth.admin.updateUserById(u.id, { email_confirm: true });
  await db()
    .from("profiles")
    .update({ email_verified_at: new Date().toISOString(), role })
    .eq("id", u.id);
  const { data } = await createSupabaseAuthClient().auth.signInWithPassword({
    email: u.email,
    password: PASSWORD,
  });
  return { ...u, token: data.session!.access_token };
}

const clients: SupabaseClient<Database>[] = [];
function asUser(token: string) {
  const c = createClient<Database>(sbEnv.url, sbEnv.publish!, {
    global: { headers: { Authorization: `Bearer ${token}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  clients.push(c);
  return c;
}

afterAll(async () => {
  for (const c of clients) await c.removeAllChannels();
  await cleanupTestUsers();
});

const at = (sec: number) => new Date(Date.UTC(2026, 10, 9, 12, 0, sec)).toISOString();

/** The same upsert the phone sends (app/lib/features/location/data/location_uploader.dart). */
function phoneUpload(
  c: SupabaseClient<Database>,
  alertId: string,
  userId: string,
  secs: number[],
) {
  return c.from("locations").upsert(
    secs.map((s) => ({
      alert_id: alertId,
      user_id: userId,
      latitude: 23.7 + s / 10000,
      longitude: 90.4,
      accuracy: 5,
      recorded_at: at(s),
    })),
    { onConflict: "alert_id,recorded_at", ignoreDuplicates: true },
  );
}

describe("live location rows (Phase 5)", () => {
  it("dedupe, ordering, RLS and refusal after the alert closes", async () => {
    const admin = await verifiedUser("admin");
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const asA = asUser(a.token);
    const asB = asUser(b.token);
    const asAdmin = asUser(admin.token);

    const { data: alert, error } = await asA
      .from("alerts")
      .insert({ user_id: a.id, first_latitude: 23.7, first_longitude: 90.4 })
      .select("id")
      .single();
    expect(error).toBeNull();
    const id = alert!.id;

    // owner uploads out of order, then the same batch again (lost response re-send)
    expect((await phoneUpload(asA, id, a.id, [30, 10, 20])).error).toBeNull();
    expect((await phoneUpload(asA, id, a.id, [30, 10, 20])).error).toBeNull();
    expect((await phoneUpload(asA, id, a.id, [20, 40])).error).toBeNull(); // overlap + one new
    const { data: rows } = await db().from("locations").select("recorded_at").eq("alert_id", id);
    expect(rows).toHaveLength(4); // 10, 20, 30, 40: no duplicates

    // newest 20 are returned oldest first
    const recent = await AlertService.recentLocations(id);
    expect(recent.success && recent.data.map((p) => Date.parse(p.recorded_at))).toEqual(
      [10, 20, 30, 40].map((s) => Date.parse(at(s))),
    );

    // student B cannot insert onto A's alert nor read A's points
    const forged = await phoneUpload(asB, id, b.id, [50]);
    expect(forged.error).not.toBeNull();
    const asOther = await asB.from("locations").select("id").eq("alert_id", id);
    expect(asOther.data).toEqual([]);
    // ... and cannot attribute a point to A either
    const spoof = await phoneUpload(asB, id, a.id, [51]);
    expect(spoof.error).not.toBeNull();

    // owner and admin can read them
    expect((await asA.from("locations").select("id").eq("alert_id", id)).data).toHaveLength(4);
    expect((await asAdmin.from("locations").select("id").eq("alert_id", id)).data).toHaveLength(4);

    // once the alert is closed the server refuses new points (code the phone treats as final)
    await asA.from("alerts").update({ status: "cancelled" }).eq("id", id);
    const late = await phoneUpload(asA, id, a.id, [60]);
    expect(late.error?.code).toBe("42501");
    const { count } = await db()
      .from("locations")
      .select("id", { count: "exact", head: true })
      .eq("alert_id", id);
    expect(count).toBe(4);
  }, 60000);

  it("admin websocket receives a location insert for the alert, other students do not", async () => {
    const admin = await verifiedUser("admin");
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const asA = asUser(a.token);
    const { data: alert } = await asA
      .from("alerts")
      .insert({ user_id: a.id })
      .select("id")
      .single();
    const id = alert!.id;

    async function listen(token: string) {
      const c = createClient<Database>(sbEnv.url, sbEnv.publish!, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      clients.push(c);
      c.realtime.setAuth(token);
      const seen: number[] = [];
      await new Promise<void>((resolve, reject) => {
        const t = setTimeout(() => reject(new Error("subscribe timeout")), 15000);
        c.channel(`loc-${Math.random().toString(36).slice(2)}`)
          .on(
            "postgres_changes",
            { event: "INSERT", schema: "public", table: "locations", filter: `alert_id=eq.${id}` },
            () => seen.push(Date.now()),
          )
          .subscribe((s) => {
            if (s === "SUBSCRIBED") {
              clearTimeout(t);
              resolve();
            }
            if (s === "CHANNEL_ERROR" || s === "TIMED_OUT") reject(new Error(s));
          });
      });
      return seen;
    }

    const adminSeen = await listen(admin.token);
    const bSeen = await listen(b.token);
    const sent = Date.now();
    expect((await phoneUpload(asA, id, a.id, [1])).error).toBeNull();
    for (let i = 0; i < 40 && adminSeen.length === 0; i++) await sleep(250);
    expect(adminSeen.length).toBe(1);
    console.log(`location insert -> admin websocket: ${adminSeen[0] - sent} ms`);
    await sleep(1500);
    expect(bSeen).toEqual([]);
  }, 60000);
});
