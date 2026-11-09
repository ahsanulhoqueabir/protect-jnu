import { describe, expect, it } from "vitest";
import { POST as forgotPassword } from "@/app/api/auth/forgot-password/route";
import { POST as login } from "@/app/api/auth/login/route";
import { GET as me } from "@/app/api/auth/me/route";
import { POST as register } from "@/app/api/auth/register/route";
import { POST as resetPassword } from "@/app/api/auth/reset-password/route";
import { POST as verifyOtp } from "@/app/api/auth/verify-otp/route";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import { bearer, call } from "../integration/helpers";

/**
 * MANUAL real-email test (Phase 2 task 13). Uses the REAL Brevo client, so real emails are sent
 * to MANUAL_EMAIL. Not part of `npm test` or `npm run test:integration`.
 *
 * Run one stage at a time (the codes come from the inbox, read by a person):
 *   MANUAL_STAGE=register   MANUAL_EMAIL=... MANUAL_PASSWORD=...                    npx vitest run tests/manual
 *   MANUAL_STAGE=verify     MANUAL_EMAIL=... MANUAL_PASSWORD=... MANUAL_CODE=123456  npx vitest run tests/manual
 *   MANUAL_STAGE=forgot     MANUAL_EMAIL=...                                          npx vitest run tests/manual
 *   MANUAL_STAGE=reset      MANUAL_EMAIL=... MANUAL_PASSWORD=... MANUAL_NEW_PASSWORD=... MANUAL_CODE=123456 npx vitest run tests/manual
 *   MANUAL_STAGE=cleanup    MANUAL_EMAIL=...                                          npx vitest run tests/manual
 * Nothing here prints a code, password or token.
 */
const stage = process.env.MANUAL_STAGE;
const email = (process.env.MANUAL_EMAIL ?? "").toLowerCase();
const password = process.env.MANUAL_PASSWORD ?? "";
const newPassword = process.env.MANUAL_NEW_PASSWORD ?? "";
const code = process.env.MANUAL_CODE ?? "";
const studentId = process.env.MANUAL_STUDENT_ID ?? "B999999999";

const sb = () => getSupabaseServerClient();
const say = (line: string) => process.stdout.write(`[manual:${stage}] ${line}\n`);

describe("real email (manual)", () => {
  it.runIf(stage === "register")("registers and sends the verification email", async () => {
    expect(email).toMatch(/@(?:[a-z0-9-]+\.)*jnu\.ac\.bd$/);
    const res = await call(register, "/api/auth/register", {
      full_name: "Manual Test",
      student_id: studentId,
      email,
      password,
    });
    say(`HTTP ${res.status} code=${res.json.code ?? "none"}`);
    expect(res.status).toBe(201);
    expect(JSON.stringify(res.json)).not.toContain("access_token");
  });

  it.runIf(stage === "verify")("verifies the emailed code, then logs in", async () => {
    const v = await call(verifyOtp, "/api/auth/verify-otp", { email, code, purpose: "email_verification" });
    say(`verify HTTP ${v.status} code=${v.json.code ?? "none"} attempts_remaining=${v.json.data?.attempts_remaining ?? "-"}`);
    expect(v.status).toBe(200);

    const l = await call(login, "/api/auth/login", { email, password });
    say(`login HTTP ${l.status}`);
    expect(l.status).toBe(200);

    const profile = await call(me as never, "/api/auth/me", undefined, bearer(l.json.data.session.access_token), "GET");
    say(`me HTTP ${profile.status} role=${profile.json.data?.user?.role}`);
    expect(profile.status).toBe(200);
  });

  it.runIf(stage === "forgot")("requests a password-reset email", async () => {
    const res = await call(forgotPassword, "/api/auth/forgot-password", { email });
    say(`HTTP ${res.status} code=${res.json.code ?? "none"}`);
    expect(res.status).toBe(200);
  });

  it.runIf(stage === "reset")("resets the password with the emailed code", async () => {
    const r = await call(resetPassword, "/api/auth/reset-password", { email, code, new_password: newPassword });
    say(`reset HTTP ${r.status} code=${r.json.code ?? "none"}`);
    expect(r.status).toBe(200);

    const oldLogin = await call(login, "/api/auth/login", { email, password });
    say(`login with OLD password HTTP ${oldLogin.status}`);
    expect(oldLogin.status).toBe(401);

    const newLogin = await call(login, "/api/auth/login", { email, password: newPassword });
    say(`login with NEW password HTTP ${newLogin.status}`);
    expect(newLogin.status).toBe(200);
  });

  it.runIf(stage === "cleanup")("deletes the throwaway account", async () => {
    const { data } = await sb().from("profiles").select("id, student_id").eq("university_email", email).maybeSingle();
    if (data) {
      expect(data.student_id).toBe(studentId); // never delete a real student's account by mistake
      const { error } = await sb().auth.admin.deleteUser(data.id);
      expect(error).toBeNull();
      say("account deleted");
    } else {
      say("no account found");
    }
    await sb().from("otp_send_events").delete().eq("email", email);
    const { count } = await sb()
      .from("profiles").select("*", { count: "exact", head: true }).eq("university_email", email);
    expect(count).toBe(0);
  });

  it.runIf(!stage)("is skipped unless MANUAL_STAGE is set", () => {
    expect(true).toBe(true);
  });
});
