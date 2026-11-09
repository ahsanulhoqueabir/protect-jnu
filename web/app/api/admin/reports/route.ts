import { fail, failFromService, ok } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { reportQuerySchema } from "@/schema/report.schema";
import { ReportService, currentReportYear } from "@/services/report.service";

/** GET /api/admin/reports?year=YYYY — monthly alerts handled and students supported. */
export const GET = withAdmin(async ({ req, accessToken }) => {
  const q = reportQuerySchema.safeParse(Object.fromEntries(new URL(req.url).searchParams));
  if (!q.success) return fail({ error: "Invalid year", statusCode: 422, code: "validation_failed" });
  const year = q.data.year ?? currentReportYear();
  const result = await ReportService.monthly(accessToken, year);
  if (!result.success) return failFromService(result);
  return ok({ data: { year, months: result.data } });
});
