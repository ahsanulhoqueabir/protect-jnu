import { NextRequest } from "next/server";
import { ok, fail } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { signUpSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, signUpSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.signUp(parsed.data);
    if (!result.success) {
      return fail({ error: result.error });
    }

    return ok({
      data: result.data,
      message: "User created successfully",
      statusCode: 201,
    });
  } catch (err) {
    return fail({
      error: (err as Error).message || "An unknown error occurred",
      statusCode: 500,
    });
  }
}
