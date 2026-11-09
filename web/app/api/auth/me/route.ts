import { withAuth } from "@/lib/api/auth-middleware";
import { ProfileService } from "@/services/profile.service";
import { fail, ok } from "@/lib/api/api-response";

/**
 * GET /api/auth/me
 * Protected — returns `{ user }` for the JWT's profile (client-safe projection).
 */
export const GET = withAuth(async ({ user }) => {
  const result = await ProfileService.getPublicById(user.profile);

  if (!result.success) {
    return fail({ error: result.error, statusCode: 404 });
  }

  return ok({ data: { user: result.data } });
});
