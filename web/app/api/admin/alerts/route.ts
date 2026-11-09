import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { alertListQuerySchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

/** GET /api/admin/alerts?status=open|all|active|acknowledged|resolved|cancelled&page=1 */
export const GET = withAdmin(async ({ req }) => {
  const parsed = alertListQuerySchema.safeParse(
    Object.fromEntries(req.nextUrl.searchParams),
  );
  if (!parsed.success) {
    return fail({ error: "Invalid query", code: "validation_failed", statusCode: 422 });
  }
  const result = await AlertService.list(parsed.data);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
