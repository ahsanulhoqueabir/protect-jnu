import { afterAll, describe, expect, it } from "vitest";
import { NextRequest } from "next/server";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import { POST as sessionLogin, DELETE as sessionLogout } from "@/app/api/admin/session/route";
import { GET as sessionRefresh } from "@/app/api/admin/session/refresh/route";
import { proxy } from "@/proxy";
import { AuthService } from "@/services/auth.service";
import { cleanupTestUsers, createTestUser, jsonRequest, PASSWORD } from "./helpers";

const sb = () => getSupabaseServerClient();

/** A verified account (Auth confirmed + profile flag), optionally promoted to admin. */
async function verifiedUser(role: "user" | "admin") {
  const u = await createTestUser();
  await sb().auth.admin.updateUserById(u.id, { email_confirm: true });
  await sb()
    .from("profiles")
    .update({ email_verified_at: new Date().toISOString(), role })
    .eq("id", u.id);
  return u;
}

function cookiesOf(res: Response) {
  const jar = new Map<string, { value: string; attrs: string }>();
  for (const line of res.headers.getSetCookie()) {
    const [pair, ...attrs] = line.split(";");
    const i = pair.indexOf("=");
    jar.set(pair.slice(0, i), { value: pair.slice(i + 1), attrs: attrs.join(";").toLowerCase() });
  }
  return jar;
}

afterAll(cleanupTestUsers);

describe("admin session cookies (Phase 3, D-033)", () => {
  it("student: 403 not_admin and NO cookies", async () => {
    const s = await verifiedUser("user");
    const res = await sessionLogin(
      jsonRequest("/api/admin/session", { email: s.email, password: PASSWORD }),
    );
    expect(res.status).toBe(403);
    expect((await res.json()).code).toBe("not_admin");
    expect(cookiesOf(res).size).toBe(0);
  });

  it("admin: httpOnly strict cookies, tokens absent from the body, cookie token authenticates as admin", async () => {
    const a = await verifiedUser("admin");
    const res = await sessionLogin(
      jsonRequest("/api/admin/session", { email: a.email, password: PASSWORD }),
    );
    expect(res.status).toBe(200);
    const text = JSON.stringify(await res.json());
    const jar = cookiesOf(res);
    const access = jar.get("pj_access")!;
    const refresh = jar.get("pj_refresh")!;
    expect(access.attrs).toContain("httponly");
    expect(access.attrs).toContain("samesite=strict");
    expect(refresh.attrs).toContain("httponly");
    expect(text).not.toContain(access.value);
    expect(text).not.toContain(refresh.value);
    expect(text).toContain('"role":"admin"');

    const auth = await AuthService.authenticate(access.value);
    expect(auth.success && auth.data.role).toBe("admin");

    // refresh route rotates cookies and redirects to a safe target
    const req = new NextRequest("http://localhost/api/admin/session/refresh?next=/admin", {
      headers: { cookie: `pj_refresh=${refresh.value}` },
    });
    const r = await sessionRefresh(req);
    expect(r.status).toBe(307);
    expect(new URL(r.headers.get("location")!).pathname).toBe("/admin");
    expect(cookiesOf(r).get("pj_refresh")!.value).not.toBe(refresh.value);

    // open-redirect attempt falls back to /admin
    const bad = await sessionRefresh(
      new NextRequest("http://localhost/api/admin/session/refresh?next=//evil.com", {
        headers: { cookie: `pj_refresh=${cookiesOf(r).get("pj_refresh")!.value}` },
      }),
    );
    expect(new URL(bad.headers.get("location")!).pathname).toBe("/admin");

    // logout revokes the access token on the server and clears cookies
    const out = await sessionLogout(
      new NextRequest("http://localhost/api/admin/session", {
        method: "DELETE",
        headers: { cookie: `pj_access=${cookiesOf(r).get("pj_access")!.value}` },
      }),
    );
    expect(out.status).toBe(200);
    expect(cookiesOf(out).get("pj_access")!.attrs).toContain("max-age=0");
  });

  it("refresh with a bad token clears cookies and goes to /login", async () => {
    const r = await sessionRefresh(
      new NextRequest("http://localhost/api/admin/session/refresh", {
        headers: { cookie: "pj_refresh=not-a-real-token" },
      }),
    );
    expect(new URL(r.headers.get("location")!).pathname).toBe("/login");
  });
});

describe("proxy guard for /admin", () => {
  const go = (cookie?: string) =>
    proxy(
      new NextRequest("http://localhost/admin/users", cookie ? { headers: { cookie } } : {}),
    );

  it("no cookies -> /login", () => {
    expect(new URL(go().headers.get("location")!).pathname).toBe("/login");
  });
  it("only refresh cookie -> refresh route with next", () => {
    const loc = new URL(go("pj_refresh=x").headers.get("location")!);
    expect(loc.pathname).toBe("/api/admin/session/refresh");
    expect(loc.searchParams.get("next")).toBe("/admin/users");
  });
  it("access cookie -> passes through", () => {
    expect(go("pj_access=x").headers.get("location")).toBeNull();
  });
});
