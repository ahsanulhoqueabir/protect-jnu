import { NextRequest, NextResponse } from "next/server";
import {
  REFRESH_COOKIE,
  clearSessionCookies,
  setSessionCookies,
} from "@/lib/api/admin-session";
import { AuthService } from "@/services/auth.service";

/** Only same-site relative paths under /admin are accepted as the return target. */
function safeNext(value: string | null): string {
  return value && /^\/admin(\/[\w\-./]*)?$/.test(value) ? value : "/admin";
}

/**
 * GET /api/admin/session/refresh?next=/admin/... — used by proxy.ts when the access cookie has
 * expired. Rotates the refresh token, sets new cookies, redirects back. On failure the cookies
 * are cleared and the user goes to /login.
 */
export async function GET(request: NextRequest) {
  const next = safeNext(request.nextUrl.searchParams.get("next"));
  const refresh = request.cookies.get(REFRESH_COOKIE)?.value;

  if (refresh) {
    const result = await AuthService.refresh({ refresh_token: refresh });
    if (result.success) {
      const res = NextResponse.redirect(new URL(next, request.url));
      setSessionCookies(res, result.data.session);
      return res;
    }
  }

  const res = NextResponse.redirect(new URL("/login", request.url));
  clearSessionCookies(res);
  return res;
}
