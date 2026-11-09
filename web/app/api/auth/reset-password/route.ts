import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { resetPasswordSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/reset-password — verify the reset code, set a new password, revoke sessions. */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, resetPasswordSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.resetPassword(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
