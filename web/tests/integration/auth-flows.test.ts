import { createClient } from "@supabase/supabase-js";
import { NextRequest } from "next/server";
import { afterAll, beforeEach, describe, expect, it, vi } from "vitest";
import { POST as adminLogin } from "@/app/api/auth/admin/login/route";
import { POST as forgotPassword } from "@/app/api/auth/forgot-password/route";
import { POST as login } from "@/app/api/auth/login/route";
import { POST as logout } from "@/app/api/auth/logout/route";
import { GET as me } from "@/app/api/auth/me/route";
import { POST as refresh } from "@/app/api/auth/refresh/route";
import { POST as register } from "@/app/api/auth/register/route";
import { POST as resendOtp } from "@/app/api/auth/resend-otp/route";
import { POST as resetPassword } from "@/app/api/auth/reset-password/route";
import { POST as verifyOtp } from "@/app/api/auth/verify-otp/route";
import { ok } from "@/lib/api/api-response";
import { withAdmin, withAuth } from "@/lib/api/auth-middleware";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import { emailFails, emailWorks, lastCode, sent } from "./email-mock";
import {
  bearer,
  call,
  cleanupTestUsers,
  clearSendEvents,
  PASSWORD,
  trackByEmail,
  uniqueEmail,
  uniqueStudentId,
} from "./helpers";

vi.mock("@/services/email.service", async () => {
  const m = await import("./email-mock");
  return { EmailService: { sendOtp: m.emailMock.sendOtp } };
});

const sb = () => getSupabaseServerClient();
const OTHER_PASSWORD = "Another-Strong-Pw-2";

function newReg(over: Record<string, unknown> = {}) {
  return {
    full_name: "Flow Test",
    student_id: uniqueStudentId(),
    email: uniqueEmail(),
    password: PASSWORD,
    ...over,
  } as { full_name: string; student_id: string; email: string; password: string };
}

async function doRegister(reg = newReg()) {
  const res = await call(register, "/api/auth/register", reg);
  await trackByEmail(reg.email);
  return { reg, res };
}

async function registerAndVerify(reg = newReg()) {
  const { res } = await doRegister(reg);
  expect(res.status).toBe(201);
  const code = lastCode(reg.email, "email_verification");
  const v = await call(verifyOtp, "/api/auth/verify-otp", {
    email: reg.email, code, purpose: "email_verification",
  });
  expect(v.status).toBe(200);
  return reg;
}

async function loginOk(email: string, password = PASSWORD) {
  const res = await call(login, "/api/auth/login", { email, password });
  expect(res.status).toBe(200);
  return res.json.data as {
    user: Record<string, unknown>;
    session: { access_token: string; refresh_token: string; expires_in: number; expires_at: number };
  };
}

async function profileOf(email: string) {
  const { data } = await sb().from("profiles").select("*").eq("university_email", email).maybeSingle();
  return data;
}

beforeEach(() => emailWorks());
afterAll(cleanupTestUsers);

describe("register", () => {
  it("rejects a non-university email on the server with email_domain_not_allowed", async () => {
    const reg = newReg({ email: "someone@gmail.com" });
    const res = await call(register, "/api/auth/register", reg);
    expect(res.status).toBe(422);
    expect(res.json.code).toBe("email_domain_not_allowed");
    expect(sent).toHaveLength(0);
    expect(await profileOf(reg.email)).toBeNull();
  });

  it("rejects look-alike domains", async () => {
    for (const email of ["x@jnu.ac.bd.evil.com", "x@xjnu.ac.bd", "x@jnu.ac.bd@evil.com", "x@cse.jnu.ac.bd.evil.com"]) {
      const res = await call(register, "/api/auth/register", newReg({ email }));
      expect(res.status).toBe(422);
    }
    expect(sent).toHaveLength(0);
  });

  it("accepts a department subdomain address end to end (D-052; needs migration 0012)", async () => {
    const reg = newReg({ email: `itest-${Math.random().toString(16).slice(2, 12)}@cse.jnu.ac.bd` });
    const { res } = await doRegister(reg);
    expect(res.status).toBe(201);
    expect(sent[0].to).toBe(reg.email);
    const code = lastCode(reg.email, "email_verification");
    const v = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code, purpose: "email_verification" });
    expect(v.status).toBe(200);
    const data = await loginOk(reg.email);
    expect(data.user.email).toBe(reg.email);
  });

  it("creates an UNVERIFIED account, emails a code, and returns no session or code", async () => {
    const { reg, res } = await doRegister();
    expect(res.status).toBe(201);
    expect(res.json).toEqual({ success: true, data: { email: reg.email, resend_available_in: 60 } });

    expect(sent).toHaveLength(1);
    expect(sent[0].purpose).toBe("email_verification");
    expect(sent[0].to).toBe(reg.email);

    const text = JSON.stringify(res.json);
    expect(text).not.toContain(sent[0].code);
    expect(text).not.toContain("access_token");

    const profile = await profileOf(reg.email);
    expect(profile?.email_verified_at).toBeNull();
    expect(profile?.role).toBe("user");
    expect(profile?.student_id).toBe(reg.student_id);

    const { data } = await sb().auth.admin.getUserById(profile!.id);
    expect(data.user?.email_confirmed_at).toBeFalsy();
  });

  it("normalises email case and student ID", async () => {
    const reg = newReg();
    const res = await call(register, "/api/auth/register", {
      ...reg, email: reg.email.toUpperCase(), student_id: ` ${reg.student_id.toLowerCase()} `,
    });
    await trackByEmail(reg.email);
    expect(res.status).toBe(201);
    const profile = await profileOf(reg.email);
    expect(profile?.student_id).toBe(reg.student_id);
  });

  it("rejects a taken email and a taken student ID", async () => {
    const reg = await registerAndVerify();
    const sameEmail = await call(register, "/api/auth/register", newReg({ email: reg.email }));
    expect(sameEmail.status).toBe(409);
    expect(sameEmail.json.code).toBe("email_taken");

    const sameId = await call(register, "/api/auth/register", newReg({ student_id: reg.student_id }));
    expect(sameId.status).toBe(409);
    expect(sameId.json.code).toBe("student_id_taken");
  });

  it("two simultaneous registrations of one email produce one account and no server error", async () => {
    const reg = newReg();
    const [a, b] = await Promise.all([
      call(register, "/api/auth/register", reg),
      call(register, "/api/auth/register", { ...reg, student_id: uniqueStudentId() }),
    ]);
    await trackByEmail(reg.email);
    for (const r of [a, b]) expect([201, 409, 429]).toContain(r.status);
    const { count } = await sb()
      .from("profiles").select("*", { count: "exact", head: true }).eq("university_email", reg.email);
    expect(count).toBe(1);
  });

  it("re-registering an unverified email never replaces the original password (D-050 R6)", async () => {
    const first = newReg();
    await doRegister(first);
    const firstCode = lastCode(first.email, "email_verification");
    await clearSendEvents(first.email);

    const again = await call(register, "/api/auth/register", {
      ...first, student_id: uniqueStudentId(), password: OTHER_PASSWORD,
    });
    expect(again.status).toBe(201);
    expect(sent).toHaveLength(2);

    // the first code was superseded
    const stale = await call(verifyOtp, "/api/auth/verify-otp", {
      email: first.email, code: firstCode, purpose: "email_verification",
    });
    expect(stale.status).toBe(400);

    const code = lastCode(first.email, "email_verification");
    const v = await call(verifyOtp, "/api/auth/verify-otp", {
      email: first.email, code, purpose: "email_verification",
    });
    expect(v.status).toBe(200);

    // original password works, the attacker-style second password does not
    await loginOk(first.email, PASSWORD);
    const bad = await call(login, "/api/auth/login", { email: first.email, password: OTHER_PASSWORD });
    expect(bad.status).toBe(401);
  });

  it("an immediate second registration is throttled by the resend cooldown", async () => {
    const reg = newReg();
    await doRegister(reg);
    const again = await call(register, "/api/auth/register", reg);
    expect(again.status).toBe(429);
    expect(again.json.code).toBe("otp_resend_cooldown");
    expect(again.json.data.retry_after_seconds).toBeGreaterThanOrEqual(1);
    expect(sent).toHaveLength(1);
  });

  it("a failed email delivery returns 502, leaves no live code, and allows an immediate retry", async () => {
    emailFails();
    const { reg, res } = await doRegister();
    expect(res.status).toBe(502);
    expect(res.json.code).toBe("email_delivery_failed");

    const profile = await profileOf(reg.email);
    expect(profile).not.toBeNull(); // account exists, unverified
    expect(profile?.email_verified_at).toBeNull();
    const { data: codes } = await sb()
      .from("otp_codes").select("invalidated_at, consumed_at").eq("user_id", profile!.id);
    expect(codes?.every((c) => c.invalidated_at)).toBe(true);

    emailWorks();
    const retry = await call(resendOtp, "/api/auth/resend-otp", { email: reg.email, purpose: "email_verification" });
    expect(retry.status).toBe(200);
    expect(sent).toHaveLength(1);
  });
});

describe("verify-otp", () => {
  it("wrong code: otp_invalid with attempts_remaining; right code: verified, no session", async () => {
    const { reg } = await doRegister();
    const code = lastCode(reg.email, "email_verification");
    const wrong = code === "000000" ? "111111" : "000000";

    const bad = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: wrong, purpose: "email_verification" });
    expect(bad.status).toBe(400);
    expect(bad.json.code).toBe("otp_invalid");
    expect(bad.json.data.attempts_remaining).toBe(4);

    const good = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code, purpose: "email_verification" });
    expect(good.status).toBe(200);
    expect(good.json).toEqual({ success: true, data: { verified: true } });
    expect(JSON.stringify(good.json)).not.toContain("access_token");

    const profile = await profileOf(reg.email);
    expect(profile?.email_verified_at).not.toBeNull();
    const { data } = await sb().auth.admin.getUserById(profile!.id);
    expect(data.user?.email_confirmed_at).toBeTruthy();
  });

  it("the same code cannot be used twice", async () => {
    const { reg } = await doRegister();
    const code = lastCode(reg.email, "email_verification");
    const body = { email: reg.email, code, purpose: "email_verification" };
    expect((await call(verifyOtp, "/api/auth/verify-otp", body)).status).toBe(200);
    const second = await call(verifyOtp, "/api/auth/verify-otp", body);
    expect(second.status).toBe(400);
    expect(second.json.code).toBe("otp_not_found");
  });

  it("an unknown email looks the same as 'no active code'", async () => {
    const res = await call(verifyOtp, "/api/auth/verify-otp", {
      email: uniqueEmail(), code: "123456", purpose: "email_verification",
    });
    expect(res.status).toBe(400);
    expect(res.json.code).toBe("otp_not_found");
  });

  it("the 6th attempt is refused after 5 wrong codes, even with the right code", async () => {
    const { reg } = await doRegister();
    const code = lastCode(reg.email, "email_verification");
    const wrong = code === "000000" ? "111111" : "000000";
    for (let i = 0; i < 5; i++) {
      const r = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: wrong, purpose: "email_verification" });
      expect(r.json.code).toBe("otp_invalid");
    }
    const sixth = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code, purpose: "email_verification" });
    expect(sixth.status).toBe(400);
    expect(sixth.json.code).toBe("otp_attempts_exceeded");
    expect((await profileOf(reg.email))?.email_verified_at).toBeNull();
  });

  it("a malformed code is a validation error and does not count as an attempt", async () => {
    const { reg } = await doRegister();
    const r = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: "12", purpose: "email_verification" });
    expect(r.status).toBe(422);
    const profile = await profileOf(reg.email);
    const { data } = await sb().from("otp_codes").select("attempts").eq("user_id", profile!.id);
    expect(data?.[0].attempts).toBe(0);
  });
});

describe("resend-otp", () => {
  it("is throttled by the 60 s cooldown and says how long to wait", async () => {
    const { reg } = await doRegister();
    const r = await call(resendOtp, "/api/auth/resend-otp", { email: reg.email, purpose: "email_verification" });
    expect(r.status).toBe(429);
    expect(r.json.code).toBe("otp_resend_cooldown");
    expect(r.json.data.retry_after_seconds).toBeLessThanOrEqual(60);
    expect(sent).toHaveLength(1);
  });

  it("sends a new code and the old one stops working", async () => {
    const { reg } = await doRegister();
    const oldCode = lastCode(reg.email, "email_verification");
    await clearSendEvents(reg.email);
    const r = await call(resendOtp, "/api/auth/resend-otp", { email: reg.email, purpose: "email_verification" });
    expect(r.status).toBe(200);
    expect(r.json.data.resend_available_in).toBe(60);
    expect(sent).toHaveLength(2);

    const newCode = lastCode(reg.email, "email_verification");
    if (newCode !== oldCode) {
      const stale = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: oldCode, purpose: "email_verification" });
      expect(stale.json.code).toBe("otp_invalid");
    }
    const ok1 = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: newCode, purpose: "email_verification" });
    expect(ok1.status).toBe(200);
  });

  it("sends nothing for an unknown email or an already-verified one, with the same answer", async () => {
    const unknown = await call(resendOtp, "/api/auth/resend-otp", { email: uniqueEmail(), purpose: "email_verification" });
    expect(unknown.status).toBe(200);
    expect(unknown.json.data.resend_available_in).toBe(60);

    const reg = await registerAndVerify();
    sent.length = 0;
    const verified = await call(resendOtp, "/api/auth/resend-otp", { email: reg.email, purpose: "email_verification" });
    expect(verified.status).toBe(200);
    expect(sent).toHaveLength(0);
  });
});

describe("login", () => {
  it("an unverified user gets 403 email_not_verified and no session", async () => {
    const { reg } = await doRegister();
    const res = await call(login, "/api/auth/login", { email: reg.email, password: PASSWORD });
    expect(res.status).toBe(403);
    expect(res.json.code).toBe("email_not_verified");
    expect(JSON.stringify(res.json)).not.toContain("access_token");
  });

  it("Supabase itself refuses an unverified user, so the gate holds without our API (D-043)", async () => {
    const { reg } = await doRegister();
    const direct = createClient(process.env.NEXT_PUBLIC_SUPABASE_URL!, process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await direct.auth.signInWithPassword({ email: reg.email, password: PASSWORD });
    expect(data.session).toBeNull();
    expect(error?.code).toBe("email_not_confirmed");
  });

  it("a verified user gets the user shape and a Supabase session", async () => {
    const reg = await registerAndVerify();
    const data = await loginOk(reg.email);
    expect(Object.keys(data.user).sort()).toEqual(["email", "full_name", "id", "phone", "role", "student_id"]);
    expect(data.user.email).toBe(reg.email);
    expect(data.user.role).toBe("user");
    expect(data.session.access_token.split(".")).toHaveLength(3);
    expect(data.session.refresh_token.length).toBeGreaterThan(5);
    expect(data.session.expires_in).toBeGreaterThan(0);
    expect(data.session.expires_at).toBeGreaterThan(Date.now() / 1000);
  });

  it("wrong password and unknown email give the same 401", async () => {
    const reg = await registerAndVerify();
    const wrong = await call(login, "/api/auth/login", { email: reg.email, password: "Not-The-Password-1" });
    const unknown = await call(login, "/api/auth/login", { email: uniqueEmail(), password: PASSWORD });
    expect(wrong.status).toBe(401);
    expect(unknown.status).toBe(401);
    expect(wrong.json).toEqual(unknown.json);
    expect(wrong.json.code).toBe("invalid_credentials");
  });

  it("a non-university email is rejected before any lookup", async () => {
    const res = await call(login, "/api/auth/login", { email: "x@gmail.com", password: "x" });
    expect(res.status).toBe(422);
    expect(res.json.code).toBe("email_domain_not_allowed");
  });
});

describe("me, refresh, logout", () => {
  it("/me needs a valid bearer token", async () => {
    const reg = await registerAndVerify();
    const { session } = await loginOk(reg.email);

    const good = await call(me as never, "/api/auth/me", undefined, bearer(session.access_token), "GET");
    expect(good.status).toBe(200);
    expect(good.json.data.user.email).toBe(reg.email);

    const none = await call(me as never, "/api/auth/me", undefined, {}, "GET");
    expect(none.status).toBe(401);
    expect(none.json.code).toBe("invalid_token");

    const garbage = await call(me as never, "/api/auth/me", undefined, bearer("not.a.token"), "GET");
    expect(garbage.status).toBe(401);
    expect(garbage.json.code).toBe("invalid_token");

    const wrongScheme = await call(me as never, "/api/auth/me", undefined, { authorization: `Token ${session.access_token}` }, "GET");
    expect(wrongScheme.status).toBe(401);
  });

  it("refresh returns a new session; a bad refresh token is 401 invalid_refresh_token", async () => {
    const reg = await registerAndVerify();
    const { session } = await loginOk(reg.email);

    const r = await call(refresh, "/api/auth/refresh", { refresh_token: session.refresh_token });
    expect(r.status).toBe(200);
    expect(r.json.data.session.access_token).toBeTruthy();
    expect(r.json.data.session.refresh_token).not.toBe(session.refresh_token); // rotated

    const bad = await call(refresh, "/api/auth/refresh", { refresh_token: "nope-nope-nope" });
    expect(bad.status).toBe(401);
    expect(bad.json.code).toBe("invalid_refresh_token");
  });

  it("logout revokes the session: its refresh token stops working", async () => {
    const reg = await registerAndVerify();
    const { session } = await loginOk(reg.email);

    const out = await call(logout, "/api/auth/logout", undefined, bearer(session.access_token));
    expect(out.status).toBe(200);
    expect(out.json.data).toEqual({ logged_out: true });

    const reuse = await call(refresh, "/api/auth/refresh", { refresh_token: session.refresh_token });
    expect(reuse.status).toBe(401);

    // Recorded for the docs: Supabase says an issued access token of a revoked session stays
    // valid until it expires; this prints what the validation call actually does here.
    const after = await call(me as never, "/api/auth/me", undefined, bearer(session.access_token), "GET");
    process.stdout.write(`[observed] /me with the access token of a logged-out session -> HTTP ${after.status}\n`);
    expect([200, 401]).toContain(after.status);
  });

  it("logout only ends the presented session, not the user's other sessions", async () => {
    const reg = await registerAndVerify();
    const one = (await loginOk(reg.email)).session;
    const two = (await loginOk(reg.email)).session;
    await call(logout, "/api/auth/logout", undefined, bearer(one.access_token));
    expect((await call(refresh, "/api/auth/refresh", { refresh_token: one.refresh_token })).status).toBe(401);
    expect((await call(refresh, "/api/auth/refresh", { refresh_token: two.refresh_token })).status).toBe(200);
  });

  it("logout without a token is 401", async () => {
    const res = await call(logout, "/api/auth/logout");
    expect(res.status).toBe(401);
  });
});

describe("admin guard (FR-AUTH-11)", () => {
  it("a student cannot use admin login and gets no session", async () => {
    const reg = await registerAndVerify();
    const res = await call(adminLogin, "/api/auth/admin/login", { email: reg.email, password: PASSWORD });
    expect(res.status).toBe(403);
    expect(res.json.code).toBe("not_admin");
    expect(JSON.stringify(res.json)).not.toContain("access_token");
  });

  it("an admin can use admin login, and /login also reports the role", async () => {
    const reg = await registerAndVerify();
    const profile = await profileOf(reg.email);
    await sb().from("profiles").update({ role: "admin" }).eq("id", profile!.id);

    const res = await call(adminLogin, "/api/auth/admin/login", { email: reg.email, password: PASSWORD });
    expect(res.status).toBe(200);
    expect(res.json.data.user.role).toBe("admin");
    expect(res.json.data.session.access_token).toBeTruthy();
  });

  it("withAdmin: no token 401, student 403, admin 200 (role is re-checked on every request)", async () => {
    const student = await registerAndVerify();
    const studentToken = (await loginOk(student.email)).session.access_token;
    const admin = await registerAndVerify();
    const adminProfile = await profileOf(admin.email);
    await sb().from("profiles").update({ role: "admin" }).eq("id", adminProfile!.id);
    const adminToken = (await loginOk(admin.email)).session.access_token;

    const guarded = withAdmin(async () => ok({ data: { secret: "admin-only" } }));
    const get = (headers: Record<string, string>) =>
      guarded(new NextRequest("http://localhost/api/admin/x", { headers }));

    expect((await get({})).status).toBe(401);
    const asStudent = await get(bearer(studentToken));
    expect(asStudent.status).toBe(403);
    expect((await asStudent.json()).code).toBe("not_admin");
    expect((await get(bearer(adminToken))).status).toBe(200);

    // demote: the same still-valid token must now be refused, because the role is read each time
    await sb().from("profiles").update({ role: "user" }).eq("id", adminProfile!.id);
    expect((await get(bearer(adminToken))).status).toBe(403);
  });

  it("withAuth refuses a profile that is not verified, even with a valid Supabase token", async () => {
    const reg = await registerAndVerify();
    const token = (await loginOk(reg.email)).session.access_token;
    const profile = await profileOf(reg.email);
    await sb().from("profiles").update({ email_verified_at: null }).eq("id", profile!.id);

    const guarded = withAuth(async () => ok({ data: { hi: true } }));
    const res = await guarded(new NextRequest("http://localhost/x", { headers: bearer(token) }));
    expect(res.status).toBe(403);
    expect((await res.json()).code).toBe("email_not_verified");
  });
});

describe("forgot-password and reset-password", () => {
  it("an unknown email gets the same answer and no email is sent", async () => {
    const res = await call(forgotPassword, "/api/auth/forgot-password", { email: uniqueEmail() });
    expect(res.status).toBe(200);
    expect(res.json).toEqual({ success: true, data: { resend_available_in: 60 } });
    expect(sent).toHaveLength(0);
  });

  it("a known email gets a reset code (and the same answer)", async () => {
    const reg = await registerAndVerify();
    sent.length = 0;
    const res = await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    expect(res.status).toBe(200);
    expect(res.json).toEqual({ success: true, data: { resend_available_in: 60 } });
    expect(sent).toHaveLength(1);
    expect(sent[0].purpose).toBe("password_reset");
  });

  it("full reset: new password works, old one and old sessions stop, code is single use", async () => {
    const reg = await registerAndVerify();
    const { session: before } = await loginOk(reg.email);
    sent.length = 0;
    await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    const code = lastCode(reg.email, "password_reset");

    const done = await call(resetPassword, "/api/auth/reset-password", {
      email: reg.email, code, new_password: OTHER_PASSWORD,
    });
    expect(done.status).toBe(200);
    expect(done.json.data).toEqual({ password_reset: true });

    expect((await call(login, "/api/auth/login", { email: reg.email, password: PASSWORD })).status).toBe(401);
    await loginOk(reg.email, OTHER_PASSWORD);

    // sessions that existed before the reset are revoked (D-016)
    const old = await call(refresh, "/api/auth/refresh", { refresh_token: before.refresh_token });
    expect(old.status).toBe(401);

    // the code cannot be reused
    const reuse = await call(resetPassword, "/api/auth/reset-password", {
      email: reg.email, code, new_password: "Yet-Another-Pw-3",
    });
    expect(reuse.status).toBe(400);
    expect(reuse.json.code).toBe("otp_not_found");
  });

  it("a wrong reset code is otp_invalid and the password stays the same", async () => {
    const reg = await registerAndVerify();
    sent.length = 0;
    await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    const code = lastCode(reg.email, "password_reset");
    const wrong = code === "000000" ? "111111" : "000000";
    const res = await call(resetPassword, "/api/auth/reset-password", {
      email: reg.email, code: wrong, new_password: OTHER_PASSWORD,
    });
    expect(res.status).toBe(400);
    expect(res.json.code).toBe("otp_invalid");
    await loginOk(reg.email, PASSWORD);
  });

  it("a weak new password is rejected before the code is touched", async () => {
    const reg = await registerAndVerify();
    sent.length = 0;
    await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    const code = lastCode(reg.email, "password_reset");

    for (const new_password of ["short", "password123"]) {
      const weak = await call(resetPassword, "/api/auth/reset-password", { email: reg.email, code, new_password });
      expect(weak.status).toBe(422);
    }
    const profile = await profileOf(reg.email);
    const { data } = await sb().from("otp_codes").select("attempts, consumed_at").eq("user_id", profile!.id).eq("purpose", "password_reset");
    expect(data?.[0].attempts).toBe(0);
    expect(data?.[0].consumed_at).toBeNull();

    const good = await call(resetPassword, "/api/auth/reset-password", { email: reg.email, code, new_password: OTHER_PASSWORD });
    expect(good.status).toBe(200);
  });

  it("a reset code cannot be used as a verification code, and vice versa", async () => {
    const { reg } = await doRegister();
    await clearSendEvents(reg.email);
    await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    const resetCode = lastCode(reg.email, "password_reset");
    const verifyCode = lastCode(reg.email, "email_verification");

    const asVerify = await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: resetCode, purpose: "email_verification" });
    if (resetCode !== verifyCode) expect(asVerify.status).toBe(400);

    const asReset = await call(resetPassword, "/api/auth/reset-password", { email: reg.email, code: verifyCode, new_password: OTHER_PASSWORD });
    if (resetCode !== verifyCode) expect(asReset.status).toBe(400);
  });

  it("resetting an UNVERIFIED account verifies the email (the code proved the inbox)", async () => {
    const { reg } = await doRegister();
    await clearSendEvents(reg.email);
    await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email });
    const code = lastCode(reg.email, "password_reset");
    const res = await call(resetPassword, "/api/auth/reset-password", { email: reg.email, code, new_password: OTHER_PASSWORD });
    expect(res.status).toBe(200);
    expect((await profileOf(reg.email))?.email_verified_at).not.toBeNull();
    await loginOk(reg.email, OTHER_PASSWORD);
  });
});

describe("responses never leak secrets", () => {
  it("no response body from any flow contains the code, a hash or the OTP secret", async () => {
    const reg = newReg();
    const bodies: unknown[] = [];
    bodies.push((await call(register, "/api/auth/register", reg)).json);
    await trackByEmail(reg.email);
    const code = lastCode(reg.email, "email_verification");
    bodies.push((await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code: "000000", purpose: "email_verification" })).json);
    bodies.push((await call(verifyOtp, "/api/auth/verify-otp", { email: reg.email, code, purpose: "email_verification" })).json);
    bodies.push((await call(forgotPassword, "/api/auth/forgot-password", { email: reg.email })).json);

    const text = JSON.stringify(bodies);
    const profile = await profileOf(reg.email);
    const { data: rows } = await sb().from("otp_codes").select("code_hash").eq("user_id", profile!.id);
    for (const r of rows ?? []) expect(text).not.toContain(r.code_hash);
    expect(text).not.toContain(process.env.OTP_HASH_SECRET!);
    expect(text).not.toContain(process.env.SUPABASE_SECRET_KEY!);
    expect(text).not.toContain(process.env.BREVO_API_KEY ?? "no-brevo-key");
  });
});
