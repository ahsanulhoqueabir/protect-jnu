import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { forgotPasswordSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/forgot-password — email a reset code. The answer never reveals if the account exists. */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, forgotPasswordSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.forgotPassword(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
