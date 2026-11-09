import { NextRequest, NextResponse } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import {
  ACCESS_COOKIE,
  clearSessionCookies,
  setSessionCookies,
} from "@/lib/api/admin-session";
import { loginSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/**
 * POST /api/admin/session — dashboard sign-in. Same checks as /api/auth/admin/login, but the
 * tokens go into httpOnly cookies and only the user is returned in the body (R4, D-033).
 */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, loginSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.login(parsed.data, { adminOnly: true });
    if (!result.success) return failFromService(result);

    const res = ok({ data: { user: result.data.user } });
    setSessionCookies(res, result.data.session);
    return res;
  } catch {
    return unexpected();
  }
}

/** DELETE /api/admin/session — revoke the session on the server and clear the cookies. */
export async function DELETE(request: NextRequest) {
  try {
    const token = request.cookies.get(ACCESS_COOKIE)?.value;
    if (token) await AuthService.logout(token);
    const res = ok({ data: { logged_out: true } });
    clearSessionCookies(res);
    return res;
  } catch {
    const res: NextResponse = unexpected();
    clearSessionCookies(res);
    return res;
  }
}
