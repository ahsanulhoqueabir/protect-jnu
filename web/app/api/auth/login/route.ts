import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { loginSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/login — student sign-in. Returns the Supabase session in JSON (D-050 R4). */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, loginSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.login(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
