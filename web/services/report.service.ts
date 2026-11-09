import { failure, success, toMessage } from "@/lib/service-result";
import { createSupabaseUserClient } from "@/lib/api/supabase";
import type { ServiceResult } from "@/types/generic.types";
import type { ReportMonth } from "@/types/report.types";

const GENERIC = "Something went wrong. Please try again.";

/** Current year in Asia/Dhaka (the report's timezone, D-076). */
export function currentReportYear(now = new Date()): number {
  return Number(new Intl.DateTimeFormat("en-CA", { timeZone: "Asia/Dhaka", year: "numeric" }).format(now));
}

export class ReportService {
  /** 12 rows for the year. Runs as the admin; the SQL function itself refuses non-admins (42501). */
  static async monthly(accessToken: string, year: number): Promise<ServiceResult<ReportMonth[]>> {
    try {
      const db = createSupabaseUserClient(accessToken);
      const { data, error } = await db.rpc("support_report", { p_year: year });
      if (error) {
        if (error.code === "42501") return failure("Admin access required.", { code: "not_admin" });
        throw new Error(error.message);
      }
      return success(data ?? []);
    } catch (err) {
      console.error("support report error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }
}
