import { NextRequest } from "next/server";
import { ok, failFromService, unexpected } from "@/lib/api/api-response";
import { parseBody } from "@/lib/api/validate";
import { refreshSchema } from "@/schema/auth.schema";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/refresh — exchange a refresh token for a new session. */
export async function POST(request: NextRequest) {
  try {
    const parsed = await parseBody(request, refreshSchema);
    if (!parsed.ok) return parsed.response;

    const result = await AuthService.refresh(parsed.data);
    if (!result.success) return failFromService(result);

    return ok({ data: result.data });
  } catch {
    return unexpected();
  }
}
