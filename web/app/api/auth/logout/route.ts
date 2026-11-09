import { ok, failFromService } from "@/lib/api/api-response";
import { withAuth } from "@/lib/api/auth-middleware";
import { AuthService } from "@/services/auth.service";

/** POST /api/auth/logout — revoke the session of the presented access token. */
export const POST = withAuth(async ({ accessToken }) => {
  const result = await AuthService.logout(accessToken);
  if (!result.success) return failFromService(result);

  return ok({ data: result.data });
});
