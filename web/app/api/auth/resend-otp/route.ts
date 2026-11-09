import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { resendOtpSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/resend-otp — send a new code, subject to cooldown and send limits. */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, resendOtpSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.resendOtp(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
