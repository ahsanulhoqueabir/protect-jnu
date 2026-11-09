import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

/**
 * Optimistic guard only (Next 16 `proxy.ts`): it checks that a session cookie EXISTS.
 * The real check (token validity + role = admin) happens in app/admin/layout.tsx on every
 * request, and again in every admin API (`withAdmin`).
 */
export function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;
  const hasAccess = request.cookies.has("pj_access");
  const hasRefresh = request.cookies.has("pj_refresh");

  if (!hasAccess) {
    if (hasRefresh) {
      const url = new URL("/api/admin/session/refresh", request.url);
      url.searchParams.set("next", pathname);
      return NextResponse.redirect(url);
    }
    return NextResponse.redirect(new URL("/login", request.url));
  }
  return NextResponse.next();
}

export const config = {
  matcher: ["/admin", "/admin/:path*"],
};
