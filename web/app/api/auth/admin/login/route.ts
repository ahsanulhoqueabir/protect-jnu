import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { loginSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/**
 * POST /api/auth/admin/login — dashboard sign-in. Same as /login, but a non-admin gets 403
 * `not_admin` and no session (FR-AUTH-11, D-050 R3).
 */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, loginSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.login(parsed.data, { adminOnly: true });
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
