import { afterAll, describe, expect, it } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createSupabaseAuthClient, getSupabaseServerClient } from "@/lib/api/supabase";
import { sb as sbEnv } from "@/config/env.config";
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

type Seen = { at: number; id: string; user_id: string; type: string };

/** Open a real Realtime websocket for `alerts` as this user and record every event. */
async function listen(token: string, clients: SupabaseClient<Database>[]) {
  const client = createClient<Database>(sbEnv.url, sbEnv.publish!, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  clients.push(client);
  client.realtime.setAuth(token);
  const seen: Seen[] = [];
  await new Promise<void>((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error("realtime subscribe timeout")), 15000);
    client
      .channel(`t-${Math.random().toString(36).slice(2)}`)
      .on("postgres_changes", { event: "*", schema: "public", table: "alerts" }, (p) => {
        const row = (p.new && "id" in p.new ? p.new : p.old) as { id: string; user_id: string };
        seen.push({ at: Date.now(), id: row.id, user_id: row.user_id, type: p.eventType });
      })
      .subscribe((s) => {
        if (s === "SUBSCRIBED") {
          clearTimeout(timer);
          resolve();
        }
        if (s === "CHANNEL_ERROR" || s === "TIMED_OUT") reject(new Error(`realtime ${s}`));
      });
  });
  return seen;
}

const clients: SupabaseClient<Database>[] = [];
afterAll(async () => {
  for (const c of clients) await c.removeAllChannels();
  await cleanupTestUsers();
});

describe("Realtime delivery of alerts (Phase 4)", () => {
  it("admin socket receives a new alert quickly; each student only their own; status change reaches the owner", async () => {
    const admin = await verifiedUser("admin");
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const adminSeen = await listen(admin.token, clients);
    const aSeen = await listen(a.token, clients);
    const bSeen = await listen(b.token, clients);

    // student A sends SOS through RLS as the real app does
    const asA = createClient<Database>(sbEnv.url, sbEnv.publish!, {
      global: { headers: { Authorization: `Bearer ${a.token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const sentAt = Date.now();
    const { data, error } = await asA
      .from("alerts")
      .insert({ user_id: a.id, first_latitude: 23.7, first_longitude: 90.4 })
      .select("id")
      .single();
    expect(error).toBeNull();
    const id = data!.id;

    for (let i = 0; i < 100 && !adminSeen.some((e) => e.id === id); i++) await sleep(100);
    const got = adminSeen.find((e) => e.id === id && e.type === "INSERT");
    expect(got).toBeDefined();
    const latency = got!.at - sentAt;
    console.log(`SOS insert -> admin websocket event: ${latency} ms`);
    expect(latency).toBeLessThan(3000);

    for (let i = 0; i < 50 && !aSeen.some((e) => e.id === id); i++) await sleep(100);
    expect(aSeen.some((e) => e.id === id)).toBe(true);

    // admin acknowledges; the owner sees the update, the other student never sees A's alert
    await db().from("alerts").update({ status: "acknowledged", acknowledged_by: admin.id }).eq("id", id);
    for (let i = 0; i < 50 && !aSeen.some((e) => e.id === id && e.type === "UPDATE"); i++) await sleep(100);
    expect(aSeen.some((e) => e.id === id && e.type === "UPDATE")).toBe(true);
    await sleep(1500);
    expect(bSeen.filter((e) => e.user_id === a.id)).toHaveLength(0);
  });
});
