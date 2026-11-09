import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { uuidSchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

/** GET /api/admin/alerts/:id — student details, emergency contacts, timestamps. */
export const GET = withAdmin(async ({ params }) => {
  const id = uuidSchema.safeParse(params.id);
  if (!id.success) {
    return fail({ error: "Alert not found.", code: "alert_not_found", statusCode: 404 });
  }
  const result = await AlertService.detail(id.data);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
