import { afterAll, describe, expect, it } from "vitest";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { createSupabaseAuthClient, getSupabaseServerClient } from "@/lib/api/supabase";
import { sb as sbEnv } from "@/config/env.config";
import { ChatService } from "@/services/chat.service";
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

describe("chat rules (Phase 6, migration 0016)", () => {
  it("isolation, length, read-only after close, mark-read and unread counts", async () => {
    const admin = await verifiedUser("admin");
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const asA = asUser(a.token);
    const asB = asUser(b.token);

    const { data: alert, error: alertError } = await asA
      .from("alerts")
      .insert({ user_id: a.id })
      .select("id")
      .single();
    expect(alertError).toBeNull();
    const alertId = alert!.id;

    // Student sends; B cannot send on A's alert or read it.
    expect((await asA.from("messages").insert({ alert_id: alertId, sender_id: a.id, body: "help" })).error).toBeNull();
    expect((await asB.from("messages").insert({ alert_id: alertId, sender_id: b.id, body: "x" })).error?.code).toBe("42501");
    expect((await asB.from("messages").select("id").eq("alert_id", alertId)).data).toEqual([]);

    // Length: empty / whitespace / 1001 refused, 1000 accepted.
    const bad = (body: string) =>
      asA.from("messages").insert({ alert_id: alertId, sender_id: a.id, body });
    expect((await bad("")).error?.code).toBe("23514");
    expect((await bad("   ")).error?.code).toBe("23514");
    expect((await bad("x".repeat(1001))).error?.code).toBe("23514");
    expect((await bad("x".repeat(1000))).error).toBeNull();

    // Spoofed sender refused.
    expect((await asA.from("messages").insert({ alert_id: alertId, sender_id: b.id, body: "spoof" })).error?.code).toBe("42501");

    // Admin unread = 2 student messages ("help" + 1000 x), student unread = 0.
    const adminList = await ChatService.conversations(admin.token);
    expect(adminList.success && adminList.data.find((c) => c.alert_id === alertId)?.unread_count).toBe(2);
    expect((await asA.rpc("chat_conversations")).data?.[0]?.unread_count).toBe(0);

    // Admin replies through the service (user-JWT client); student unread becomes 1.
    const sent = await ChatService.send(admin.token, admin.id, alertId, "on our way");
    expect(sent.success).toBe(true);
    expect((await asA.rpc("chat_conversations")).data?.[0]?.unread_count).toBe(1);

    // Admin opens the thread: student's messages become read; own message stays unread for the student.
    const marked = await ChatService.markRead(admin.token, admin.id, alertId);
    expect(marked.success && marked.data.updated).toBe(2);
    const after = await ChatService.conversations(admin.token);
    expect(after.success && after.data.find((c) => c.alert_id === alertId)?.unread_count).toBe(0);

    // A user cannot mark their OWN messages read, nor change body/sender.
    const own = await asA.from("messages").update({ read_at: new Date().toISOString() })
      .eq("alert_id", alertId).eq("sender_id", a.id).is("read_at", null).select("id");
    expect(own.data ?? []).toEqual([]);
    expect((await asA.from("messages").update({ body: "edited" } as never).eq("alert_id", alertId)).error).not.toBeNull();

    // Student marks the admin reply read -> student unread 0.
    await asA.from("messages").update({ read_at: new Date().toISOString() })
      .eq("alert_id", alertId).neq("sender_id", a.id).is("read_at", null);
    expect((await asA.rpc("chat_conversations")).data?.[0]?.unread_count).toBe(0);

    // History through the service: oldest first, sender names, from_student flag.
    const history = await ChatService.history(admin.token, alertId);
    expect(history.success).toBe(true);
    if (history.success) {
      expect(history.data.map((m) => m.from_student)).toEqual([true, true, false]);
      const since = await ChatService.history(admin.token, alertId, history.data[1].sent_at);
      expect(since.success && since.data.map((m) => m.body)).toEqual(["on our way"]);
    }

    // Resolve: thread becomes read-only for BOTH sides, history still readable.
    await db().from("alerts").update({ status: "acknowledged", acknowledged_by: admin.id }).eq("id", alertId);
    await db().from("alerts").update({ status: "resolved", resolved_by: admin.id }).eq("id", alertId);
    await sleep(300);
    const late = await ChatService.send(admin.token, admin.id, alertId, "too late");
    expect(!late.success && late.code).toBe("chat_closed");
    expect((await asA.from("messages").insert({ alert_id: alertId, sender_id: a.id, body: "late" })).error?.code).toBe("42501");
    expect((await asA.from("messages").select("id").eq("alert_id", alertId)).data).toHaveLength(3);
  }, 60_000);

  it("Realtime: admin and owner receive a message insert quickly; another student does not", async () => {
    const admin = await verifiedUser("admin");
    const a = await verifiedUser("user");
    const b = await verifiedUser("user");
    const asA = asUser(a.token);
    const { data: alert } = await asA.from("alerts").insert({ user_id: a.id }).select("id").single();
    const alertId = alert!.id;

    const listen = (token: string) => {
      const c = createClient<Database>(sbEnv.url, sbEnv.publish!, {
        auth: { persistSession: false, autoRefreshToken: false },
      });
      clients.push(c);
      c.realtime.setAuth(token);
      const seen: number[] = [];
      const ready = new Promise<void>((resolve) => {
        c.channel(`t-${Math.random()}`)
          .on(
            "postgres_changes",
            { event: "INSERT", schema: "public", table: "messages", filter: `alert_id=eq.${alertId}` },
            () => seen.push(Date.now()),
          )
          .subscribe((s) => s === "SUBSCRIBED" && resolve());
      });
      return { seen, ready };
    };
    const adminL = listen(admin.token);
    const ownerL = listen(a.token);
    const otherL = listen(b.token);
    await Promise.all([adminL.ready, ownerL.ready, otherL.ready]);
    await sleep(2000); // subscribe race seen in Phases 4 and 5

    const t0 = Date.now();
    await asA.from("messages").insert({ alert_id: alertId, sender_id: a.id, body: "hello" });
    await sleep(4000);
    expect(adminL.seen.length).toBe(1);
    expect(ownerL.seen.length).toBe(1);
    expect(otherL.seen.length).toBe(0);
    expect(adminL.seen[0] - t0).toBeLessThan(2500);
  }, 60_000);
});
