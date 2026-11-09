import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { verifyOtpSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/verify-otp — verify the registration code. No session is returned (D-050 R1). */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, verifyOtpSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.verifyOtp(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
