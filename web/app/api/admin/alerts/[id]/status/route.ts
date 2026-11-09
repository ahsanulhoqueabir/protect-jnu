import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { parseBody } from "@/lib/api/validate";
import { alertActionSchema, uuidSchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

/** PATCH /api/admin/alerts/:id/status  body { action: "acknowledge" | "resolve" } */
export const PATCH = withAdmin(async ({ req, user, params }) => {
  const id = uuidSchema.safeParse(params.id);
  if (!id.success) {
    return fail({ error: "Alert not found.", code: "alert_not_found", statusCode: 404 });
  }
  const parsed = await parseBody(req, alertActionSchema);
  if (!parsed.ok) return parsed.response;

  const result = await AlertService.transition(user.id, id.data, parsed.data.action);
  if (!result.success) return failFromService(result);
  return ok({ data: result.data });
});
