import { ok, failFromService } from "@/lib/api/api-response";
import { withAuth } from "@/lib/api/auth-middleware";
import { AuthService } from "@/services/auth.service";

/** GET /api/auth/me — the signed-in user's client-safe profile. */
export const GET = withAuth(async ({ user }) => {
  const result = await AuthService.me(user.id);
  if (!result.success) return failFromService(result);

  return ok({ data: result.data });
});
