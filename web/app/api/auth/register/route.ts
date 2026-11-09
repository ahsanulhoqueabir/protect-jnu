import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { registerSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/register — create an unverified account and email a code. No session. */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, registerSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.register(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data, statusCode: 201 });
  } catch {
    return unexpected();
  }
}
