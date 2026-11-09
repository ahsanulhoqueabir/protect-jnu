import { createClient } from "@supabase/supabase-js";
import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import { generateOtpCode, hashOtp } from "@/lib/otp";
import { emailFails, emailMock, emailWorks, lastCode, sent } from "./email-mock";
import { cleanupTestUsers, clearSendEvents, createTestUser, sleep } from "./helpers";

vi.mock("@/services/email.service", async () => {
  const m = await import("./email-mock");
  return { EmailService: { sendOtp: m.emailMock.sendOtp } };
});

import { OtpService } from "@/services/otp.service";

const sb = () => getSupabaseServerClient();
const PURPOSE = "email_verification" as const;

/** Issue directly through the DB function with custom limits (the service uses env defaults). */
async function rpcIssue(
  user: { id: string; email: string },
  over: Partial<{ ttl: number; cooldown: number; window: number; max: number; purpose: typeof PURPOSE | "password_reset" }> = {},
) {
  const purpose = over.purpose ?? PURPOSE;
  const code = generateOtpCode();
  const { data, error } = await sb().rpc("otp_issue", {
    p_user_id: user.id,
    p_email: user.email,
    p_purpose: purpose,
    p_code_hash: hashOtp(user.id, purpose, code),
    p_ttl_seconds: over.ttl ?? 600,
    p_cooldown_seconds: over.cooldown ?? 0,
    p_window_seconds: over.window ?? 900,
    p_max_sends: over.max ?? 3,
  });
  expect(error).toBeNull();
  return { code, row: data![0] };
}

async function otpRows(userId: string) {
  const { data } = await sb()
    .from("otp_codes")
    .select("*")
    .eq("user_id", userId)
    .order("created_at", { ascending: true });
  return data ?? [];
}

async function sendEventCount(email: string) {
  const { count } = await sb()
    .from("otp_send_events")
    .select("*", { count: "exact", head: true })
    .eq("email", email);
  return count ?? 0;
}

beforeEach(() => emailWorks());
afterAll(cleanupTestUsers);

describe("issue", () => {
  it("stores only an HMAC hash, with a 10-minute expiry and zero attempts", async () => {
    const user = await createTestUser();
    const issued = await OtpService.issue({
      userId: user.id, email: user.email, name: "Test", purpose: PURPOSE,
    });
    expect(issued.success).toBe(true);

    const code = lastCode(user.email, PURPOSE);
    expect(code).toMatch(/^[0-9]{6}$/);

    const [row] = await otpRows(user.id);
    expect(row.code_hash).toMatch(/^[0-9a-f]{64}$/);
    expect(JSON.stringify(row)).not.toContain(code);
    expect(row.code_hash).toBe(hashOtp(user.id, PURPOSE, code));
    expect(row.attempts).toBe(0);
    expect(row.consumed_at).toBeNull();
    const ttl = (Date.parse(row.expires_at) - Date.parse(row.created_at)) / 1000;
    expect(ttl).toBe(600);
  });

  it("emails the code once and tells the client the cooldown", async () => {
    const user = await createTestUser();
    const issued = await OtpService.issue({
      userId: user.id, email: user.email, name: "Test", purpose: PURPOSE,
    });
    expect(emailMock.sendOtp).toHaveBeenCalledTimes(1);
    expect(sent[0].to).toBe(user.email);
    expect(sent[0].ttlMinutes).toBe(10);
    expect(issued.success && issued.data.resend_available_in).toBe(60);
  });
});

describe("resend cooldown (60 s)", () => {
  it("rejects a second send right away, sends no email, and keeps the first code valid", async () => {
    const user = await createTestUser();
    const first = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    expect(first.success).toBe(true);
    const code = lastCode(user.email, PURPOSE);

    const second = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    expect(second.success).toBe(false);
    if (!second.success) {
      expect(second.code).toBe("otp_resend_cooldown");
      const retry = second.data?.retry_after_seconds as number;
      expect(retry).toBeGreaterThanOrEqual(1);
      expect(retry).toBeLessThanOrEqual(60);
    }
    expect(emailMock.sendOtp).toHaveBeenCalledTimes(1);

    const verified = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(verified.success).toBe(true);
  });

  it("cooldown and limits are per email and per purpose", async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    expect((await OtpService.issue({ userId: a.id, email: a.email, name: "T", purpose: PURPOSE })).success).toBe(true);
    // another email is unaffected
    expect((await OtpService.issue({ userId: b.id, email: b.email, name: "T", purpose: PURPOSE })).success).toBe(true);
    // another purpose for the same email is unaffected
    expect((await OtpService.issue({ userId: a.id, email: a.email, name: "T", purpose: "password_reset" })).success).toBe(true);
  });
});

describe("send limit (3 per 15 min)", () => {
  it("allows 3 sends and rejects the 4th with a retry time", async () => {
    const user = await createTestUser();
    for (let i = 0; i < 3; i++) {
      const { row } = await rpcIssue(user, { cooldown: 0, max: 3 });
      expect(row.status).toBe("ok");
    }
    const fourth = await rpcIssue(user, { cooldown: 0, max: 3 });
    expect(fourth.row.status).toBe("send_limit");
    expect(fourth.row.otp_id).toBeNull();
    expect(fourth.row.retry_after_seconds).toBeGreaterThanOrEqual(1);
    expect(fourth.row.retry_after_seconds).toBeLessThanOrEqual(900);
    // the rejected request created no code
    expect((await otpRows(user.id)).length).toBe(3);
  });

  it("the limit is enforced by the service with the env defaults too", async () => {
    const user = await createTestUser();
    // cooldown (60 s) hides the limit through the service, so fill the window directly...
    for (let i = 0; i < 3; i++) await rpcIssue(user, { cooldown: 0, max: 3 });
    // ...then the service (cooldown 60, max 3) must refuse and send nothing.
    const refused = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    expect(refused.success).toBe(false);
    expect(emailMock.sendOtp).not.toHaveBeenCalled();
  });

  it("sends older than the window no longer count", async () => {
    const user = await createTestUser();
    for (let i = 0; i < 3; i++) await rpcIssue(user, { cooldown: 0, max: 3, window: 2 });
    expect((await rpcIssue(user, { cooldown: 0, max: 3, window: 2 })).row.status).toBe("send_limit");
    await sleep(2500);
    expect((await rpcIssue(user, { cooldown: 0, max: 3, window: 2 })).row.status).toBe("ok");
  });
});

describe("new code supersedes the old one", () => {
  it("the old code stops working and its row is invalidated", async () => {
    const user = await createTestUser();
    const first = await rpcIssue(user);
    const second = await rpcIssue(user);

    const old = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code: first.code });
    expect(old.success).toBe(false);
    if (!old.success) expect(old.code).toBe("otp_invalid");

    const current = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code: second.code });
    expect(current.success).toBe(true);

    const rows = await otpRows(user.id);
    expect(rows[0].invalidated_at).not.toBeNull();
    expect(rows[1].invalidated_at).toBeNull();
  });

  it("at most one live code exists per user and purpose", async () => {
    const user = await createTestUser();
    for (let i = 0; i < 3; i++) await rpcIssue(user);
    const live = (await otpRows(user.id)).filter((r) => !r.consumed_at && !r.invalidated_at);
    expect(live.length).toBe(1);
  });
});

describe("expiry (10 min, server time)", () => {
  it("rejects a code after it expires, even the correct one", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user, { ttl: 1 });
    await sleep(1600);
    const r = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(r.success).toBe(false);
    if (!r.success) expect(r.code).toBe("otp_expired");
  });

  it("an expired code cannot be consumed", async () => {
    const user = await createTestUser();
    const { row } = await rpcIssue(user, { ttl: 1 });
    await sleep(1600);
    expect(await OtpService.consume(row.otp_id)).toBe(false);
  });
});

describe("attempts (max 5)", () => {
  it("counts down attempts_remaining, then rejects even the correct code", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user);
    const wrong = code === "000000" ? "111111" : "000000";

    for (let i = 1; i <= 5; i++) {
      const r = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code: wrong });
      expect(r.success).toBe(false);
      if (!r.success) {
        expect(r.code).toBe("otp_invalid");
        expect(r.data?.attempts_remaining).toBe(5 - i);
      }
    }

    const sixth = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(sixth.success).toBe(false);
    if (!sixth.success) expect(sixth.code).toBe("otp_attempts_exceeded");
  });

  it("the correct code on attempt 5 still works (limit is 5 attempts, not 4)", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user);
    const wrong = code === "000000" ? "111111" : "000000";
    for (let i = 0; i < 4; i++) await OtpService.verify({ userId: user.id, purpose: PURPOSE, code: wrong });
    const fifth = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(fifth.success).toBe(true);
  });

  it("parallel guesses cannot exceed the limit", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user);
    const wrong = code === "000000" ? "111111" : "000000";

    const results = await Promise.all(
      Array.from({ length: 12 }, () => OtpService.verify({ userId: user.id, purpose: PURPOSE, code: wrong })),
    );
    const codes = results.map((r) => (r.success ? "ok" : r.code));
    expect(codes.filter((c) => c === "otp_invalid").length).toBe(5);
    expect(codes.filter((c) => c === "otp_attempts_exceeded").length).toBe(7);

    const [row] = await otpRows(user.id);
    expect(row.attempts).toBe(5);
  });

  it("a code for one user never verifies for another", async () => {
    const a = await createTestUser();
    const b = await createTestUser();
    const issued = await rpcIssue(a);
    await rpcIssue(b);
    const r = await OtpService.verify({ userId: b.id, purpose: PURPOSE, code: issued.code });
    expect(r.success).toBe(false);
    if (!r.success) expect(r.code).toBe("otp_invalid");
  });

  it("a verification code does not work for password reset", async () => {
    const user = await createTestUser();
    const issued = await rpcIssue(user, { purpose: PURPOSE });
    await rpcIssue(user, { purpose: "password_reset" });
    const r = await OtpService.verify({ userId: user.id, purpose: "password_reset", code: issued.code });
    expect(r.success).toBe(false);
  });
});

describe("single use", () => {
  it("consumes once; a second use and a parallel use both lose", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user);
    const verified = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(verified.success).toBe(true);
    if (!verified.success) return;

    const [a, b] = await Promise.all([
      OtpService.consume(verified.data.otpId),
      OtpService.consume(verified.data.otpId),
    ]);
    expect([a, b].filter(Boolean).length).toBe(1);

    const again = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code });
    expect(again.success).toBe(false);
    if (!again.success) expect(again.code).toBe("otp_not_found");
  });

  it("verification alone does not consume the code (the caller consumes after its side effects)", async () => {
    const user = await createTestUser();
    const { code } = await rpcIssue(user);
    expect((await OtpService.verify({ userId: user.id, purpose: PURPOSE, code })).success).toBe(true);
    const [row] = await otpRows(user.id);
    expect(row.consumed_at).toBeNull();
  });
});

describe("delivery failure", () => {
  it("kills the code, does not count toward the limit, and allows an immediate retry", async () => {
    const user = await createTestUser();
    emailFails();
    const failed = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    expect(failed.success).toBe(false);
    if (!failed.success) expect(failed.code).toBe("email_delivery_failed");

    const [row] = await otpRows(user.id);
    expect(row.invalidated_at).not.toBeNull();
    expect(await sendEventCount(user.email)).toBe(0);

    emailWorks();
    const retry = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    expect(retry.success).toBe(true); // no 60 s cooldown after a failed send
    expect(emailMock.sendOtp).toHaveBeenCalledTimes(1);
  });

  it("repeated failures never exhaust the 3-per-15-minutes limit", async () => {
    const user = await createTestUser();
    emailFails();
    for (let i = 0; i < 5; i++) {
      const r = await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
      expect(r.success).toBe(false);
      if (!r.success) expect(r.code).toBe("email_delivery_failed");
    }
    expect(await sendEventCount(user.email)).toBe(0);
    emailWorks();
    expect((await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE })).success).toBe(true);
  });

  it("the failed code can never be used", async () => {
    const user = await createTestUser();
    emailFails();
    await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    const r = await OtpService.verify({ userId: user.id, purpose: PURPOSE, code: "123456" });
    expect(r.success).toBe(false);
    if (!r.success) expect(r.code).toBe("otp_not_found");
  });
});

describe("database access (PRD 7.6)", () => {
  const anon = () =>
    createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

  it("a public client cannot call the OTP functions", async () => {
    const user = await createTestUser();
    const { error } = await anon().rpc("otp_issue", {
      p_user_id: user.id,
      p_email: user.email,
      p_purpose: PURPOSE,
      p_code_hash: "x",
      p_ttl_seconds: 600,
      p_cooldown_seconds: 0,
      p_window_seconds: 900,
      p_max_sends: 3,
    });
    expect(error).not.toBeNull();
    expect(await otpRows(user.id)).toHaveLength(0);

    const consume = await anon().rpc("otp_consume", { p_otp_id: user.id });
    expect(consume.error).not.toBeNull();
    const revoke = await anon().rpc("revoke_user_sessions", { p_user_id: user.id });
    expect(revoke.error).not.toBeNull();
  });

  it("a public client cannot read the OTP tables", async () => {
    const user = await createTestUser();
    await rpcIssue(user);
    const codes = await anon().from("otp_codes").select("*");
    expect(codes.error).not.toBeNull();
    expect(codes.data).toBeNull();
    const events = await anon().from("otp_send_events").select("*");
    expect(events.error).not.toBeNull();
  });
});

describe("housekeeping", () => {
  it("clearSendEvents lets a test re-issue without waiting", async () => {
    const user = await createTestUser();
    await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE });
    await clearSendEvents(user.email);
    expect((await OtpService.issue({ userId: user.id, email: user.email, name: "T", purpose: PURPOSE })).success).toBe(true);
  });
});
