import Link from "next/link";
import { cookies } from "next/headers";
import { MonthlyChart } from "@/components/reports/monthly-chart";
import { ACCESS_COOKIE } from "@/lib/api/admin-session";
import { reportQuerySchema } from "@/schema/report.schema";
import { ReportService, currentReportYear } from "@/services/report.service";

export const dynamic = "force-dynamic";

const MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

export default async function ReportsPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const sp = await searchParams;
  const nowYear = currentReportYear();
  const q = reportQuerySchema.safeParse({ year: sp.year });
  const year = q.success && q.data.year ? q.data.year : nowYear;
  const token = (await cookies()).get(ACCESS_COOKIE)?.value ?? "";
  const result = await ReportService.monthly(token, year);
  const years = [nowYear, nowYear - 1, nowYear - 2];
  if (!years.includes(year)) years.push(year);

  const months = result.success ? result.data : [];
  const totalAlerts = months.reduce((n, m) => n + Number(m.alerts_handled), 0);

  return (
    <div>
      <div className="flex flex-wrap items-center justify-between gap-3">
        <h1 className="text-xl font-semibold text-zinc-900">Support reports</h1>
        <a
          href={`/api/admin/reports/export?year=${year}`}
          className="rounded-md border px-3 py-1.5 text-sm hover:bg-zinc-100"
        >
          Export CSV
        </a>
      </div>
      <div className="mt-3 flex gap-2 text-sm">
        {years.map((y) => (
          <Link
            key={y}
            href={`/admin/reports?year=${y}`}
            className={`rounded-full border px-3 py-1 ${y === year ? "bg-[#1F3A5F] text-white" : "hover:bg-zinc-100"}`}
          >
            {y}
          </Link>
        ))}
      </div>

      {!result.success ? (
        <p className="mt-4 text-sm text-red-600">Could not load the report.</p>
      ) : (
        <>
          <p className="mt-4 text-sm text-zinc-600">
            {totalAlerts} alerts handled in {year}. A student is counted once per month; months are in Asia/Dhaka time.
          </p>
          <div className="mt-4 rounded-lg border bg-white p-4">
            <MonthlyChart months={months} />
          </div>
          <table className="mt-4 w-full max-w-xl text-sm">
            <thead>
              <tr className="border-b text-left text-zinc-500">
                <th className="py-1">Month</th>
                <th className="py-1">Alerts handled</th>
                <th className="py-1">Students supported</th>
              </tr>
            </thead>
            <tbody>
              {months.map((m) => (
                <tr key={m.month} className="border-b">
                  <td className="py-1">{MONTH_NAMES[m.month - 1]}</td>
                  <td className="py-1">{m.alerts_handled}</td>
                  <td className="py-1">{m.students_supported}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </>
      )}
    </div>
  );
}
