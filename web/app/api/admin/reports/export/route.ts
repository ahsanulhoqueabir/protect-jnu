import { NextResponse } from "next/server";
import { fail, failFromService } from "@/lib/api/api-response";
import { withAdmin } from "@/lib/api/auth-middleware";
import { toCsv } from "@/lib/csv";
import { reportQuerySchema } from "@/schema/report.schema";
import { ReportService, currentReportYear } from "@/services/report.service";

/** GET /api/admin/reports/export?year=YYYY — monthly summary CSV (admin only). */
export const GET = withAdmin(async ({ req, accessToken }) => {
  const q = reportQuerySchema.safeParse(Object.fromEntries(new URL(req.url).searchParams));
  if (!q.success) return fail({ error: "Invalid year", statusCode: 422, code: "validation_failed" });
  const year = q.data.year ?? currentReportYear();
  const result = await ReportService.monthly(accessToken, year);
  if (!result.success) return failFromService(result);
  const csv = toCsv(
    ["year", "month", "alerts_handled", "students_supported"],
    result.data.map((m) => [m.year, m.month, m.alerts_handled, m.students_supported]),
  );
  return new NextResponse(csv, {
    status: 200,
    headers: {
      "Content-Type": "text/csv; charset=utf-8",
      "Content-Disposition": `attachment; filename="support-report-${year}.csv"`,
      "Cache-Control": "no-store",
    },
  });
});
