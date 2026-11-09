import { NextRequest } from "next/server";
import { ok, fail } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { loginSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, loginSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.login(parsed.data);
    if (!result.success) {
      return fail({ error: result.error, statusCode: 401 });
    }

    return ok({ data: result.data, message: "Login successful" });
  } catch (err) {
    return fail({
      error: (err as Error).message || "An unknown error occurred",
      statusCode: 500,
    });
  }
}
