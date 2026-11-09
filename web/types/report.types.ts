import type { Database } from "@/types/database.types";

/** One month of the support report (D-076): Asia/Dhaka months, first admin action decides the period. */
export type ReportMonth = Database["public"]["Functions"]["support_report"]["Returns"][number];
