import type { NextResponse } from "next/server";
import type { SessionTokens } from "@/types/auth.types";

/**
 * Admin dashboard session cookies (D-005/D-033, api-contract R4): httpOnly, SameSite=Strict,
 * Secure in production. Tokens never reach browser JavaScript. Values are never logged.
 */
export const ACCESS_COOKIE = "pj_access";
export const REFRESH_COOKIE = "pj_refresh";

/** Refresh-cookie lifetime. Not specified by the PRD: proposed D-057, revisable. */
const REFRESH_MAX_AGE_SECONDS = 7 * 24 * 60 * 60;

const base = {
  httpOnly: true,
  sameSite: "strict" as const,
  secure: process.env.NODE_ENV === "production",
  path: "/",
};

export function setSessionCookies(res: NextResponse, session: SessionTokens) {
  res.cookies.set(ACCESS_COOKIE, session.access_token, {
    ...base,
    maxAge: Math.max(1, session.expires_in),
  });
  res.cookies.set(REFRESH_COOKIE, session.refresh_token, {
    ...base,
    maxAge: REFRESH_MAX_AGE_SECONDS,
  });
}

export function clearSessionCookies(res: NextResponse) {
  res.cookies.set(ACCESS_COOKIE, "", { ...base, maxAge: 0 });
  res.cookies.set(REFRESH_COOKIE, "", { ...base, maxAge: 0 });
}
