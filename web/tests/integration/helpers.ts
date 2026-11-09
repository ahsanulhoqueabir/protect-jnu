import { randomBytes, randomInt } from "node:crypto";
import { NextRequest } from "next/server";
import { getSupabaseServerClient } from "@/lib/api/supabase";

export const PASSWORD = "Integration-Test-Pw-1";

type TestUser = { id: string; email: string; studentId: string };
const created: TestUser[] = [];
const emails = new Set<string>();

export function uniqueEmail() {
  return `itest-${randomBytes(5).toString("hex")}@jnu.ac.bd`;
}

export function uniqueStudentId() {
  return `B9${randomInt(0, 100_000_000).toString().padStart(8, "0")}`;
}

/**
 * Create an UNCONFIRMED user directly through the Auth admin API (sends no email, verified in
 * Phase 1). The DB trigger creates the profile. Cleaned up by `cleanupTestUsers`.
 */
export async function createTestUser(
  opts: { email?: string; password?: string; fullName?: string } = {},
): Promise<TestUser> {
  const email = opts.email ?? uniqueEmail();
  const studentId = uniqueStudentId();
  const { data, error } = await getSupabaseServerClient().auth.admin.createUser({
    email,
    password: opts.password ?? PASSWORD,
    user_metadata: { full_name: opts.fullName ?? "Integration Test", student_id: studentId },
  });
  if (error || !data.user) throw new Error(`createTestUser failed: ${error?.code}`);
  const user = { id: data.user.id, email, studentId };
  track(user);
  return user;
}

/** Remember a user created through the API under test so it is deleted afterwards. */
export function track(user: { id: string; email: string; studentId?: string }) {
  created.push({ studentId: "", ...user });
  emails.add(user.email);
}

/** Track by email once the user exists (for accounts created through /register). */
export async function trackByEmail(email: string) {
  emails.add(email);
  const { data } = await getSupabaseServerClient()
    .from("profiles")
    .select("id")
    .eq("university_email", email)
    .maybeSingle();
  if (data) created.push({ id: data.id, email, studentId: "" });
}

export async function cleanupTestUsers() {
  const sb = getSupabaseServerClient();

  async function remove(id: string) {
    for (let attempt = 0; attempt < 3; attempt++) {
      const { error } = await sb.auth.admin.deleteUser(id);
      if (!error || error.status === 404) return;
      await sleep(500 * (attempt + 1));
    }
    throw new Error(`cleanup could not delete test user ${id}`);
  }

  for (const u of created) await remove(u.id);

  // Safety net: anything an unlucky test created and did not track (all test accounts use this prefix).
  const { data: strays } = await sb
    .from("profiles")
    .select("id, university_email")
    .like("university_email", "itest-%jnu.ac.bd");
  for (const s of strays ?? []) {
    emails.add(s.university_email);
    await remove(s.id);
  }

  if (emails.size > 0) {
    await sb.from("otp_send_events").delete().in("email", [...emails]);
  }
  created.length = 0;
  emails.clear();
}

/** Clear throttle state for an email so a test can issue again without waiting 60 s. */
export async function clearSendEvents(email: string) {
  await getSupabaseServerClient().from("otp_send_events").delete().eq("email", email);
}

export function jsonRequest(
  path: string,
  body?: unknown,
  headers: Record<string, string> = {},
  method = "POST",
) {
  return new NextRequest(`http://localhost${path}`, {
    method,
    headers: { "content-type": "application/json", ...headers },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

/** Call a route handler and return its status and parsed JSON body. */
export async function call(
  handler: (req: NextRequest) => Promise<Response>,
  path: string,
  body?: unknown,
  headers: Record<string, string> = {},
  method = "POST",
) {
  const res = await handler(jsonRequest(path, body, headers, method));
  // Parsed JSON, typed loosely on purpose: tests assert on shape at runtime.
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return { status: res.status, json: (await res.json()) as Record<string, any> };
}

export const bearer = (token: string) => ({ authorization: `Bearer ${token}` });

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));
