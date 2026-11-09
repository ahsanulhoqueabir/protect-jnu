import { NextRequest, NextResponse } from "next/server";
import { fail, failFromService } from "@/lib/api/api-response";
import { AuthService } from "@/services/auth.service";
import type { AuthenticatedUser } from "@/types/auth.types";

export type AuthenticatedHandlerContext = {
  req: NextRequest;
  user: AuthenticatedUser;
  /** The validated Supabase access token (needed by logout). Never log it. */
  accessToken: string;
};

export type AuthenticatedHandler = (
  ctx: AuthenticatedHandlerContext,
) => Promise<NextResponse>;

/**
 * Protects a route with a Supabase access token (D-004).
 * Reads `Authorization: Bearer <token>`, validates it with the Supabase Auth server on every
 * request (no custom JWT), loads the caller's role, and refuses unverified profiles.
 *
 * @example export const GET = withAuth(async ({ user }) => { … });
 */
export function withAuth(handler: AuthenticatedHandler) {
  return async (req: NextRequest): Promise<NextResponse> => {
    const header = req.headers.get("Authorization");
    if (!header || !header.startsWith("Bearer ")) {
      return fail({
        error: "Missing or invalid Authorization header",
        code: "invalid_token",
        statusCode: 401,
      });
    }

    const accessToken = header.slice(7).trim();
    if (!accessToken) {
      return fail({
        error: "Missing or invalid Authorization header",
        code: "invalid_token",
        statusCode: 401,
      });
    }

    const auth = await AuthService.authenticate(accessToken);
    if (!auth.success) return failFromService(auth);

    try {
      return await handler({ req, user: auth.data, accessToken });
    } catch {
      return fail({
        error: "An unexpected error occurred",
        code: "internal_error",
        statusCode: 500,
      });
    }
  };
}

/**
 * Admin-only guard (FR-AUTH-11): authenticates, then requires `role = 'admin'` on EVERY request.
 * Use for every admin API.
 *
 * @example export const GET = withAdmin(async ({ user }) => { … });
 */
export function withAdmin(handler: AuthenticatedHandler) {
  return withAuth(async (ctx) => {
    if (ctx.user.role !== "admin") {
      return fail({
        error: "Administrator access required",
        code: "not_admin",
        statusCode: 403,
      });
    }
    return handler(ctx);
  });
}
