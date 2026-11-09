import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { pageQuerySchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

/** GET /api/admin/users?page=1 — basic users list. */
export const GET = withAdmin(async ({ req }) => {
  const parsed = pageQuerySchema.safeParse(
    Object.fromEntries(req.nextUrl.searchParams),
  );
  if (!parsed.success) {
    return fail({ error: "Invalid query", code: "validation_failed", statusCode: 422 });
  }
  const result = await AlertService.listUsers(parsed.data.page);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
