import Link from "next/link";
import { Pager, StatusBadge, formatTime } from "@/components/admin/alert-ui";
import { alertListQuerySchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

export const dynamic = "force-dynamic";

const FILTERS = ["all", "active", "acknowledged", "resolved", "cancelled"] as const;

export default async function HistoryPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const sp = await searchParams;
  const q = alertListQuerySchema.safeParse({ status: sp.status ?? "all", page: sp.page });
  const query = q.success ? q.data : { status: "all" as const, page: 1 };
  const result = await AlertService.list(query);

  return (
    <div>
      <h1 className="text-xl font-semibold text-zinc-900">Alert history</h1>
      <div className="mt-3 flex gap-2 text-sm">
        {FILTERS.map((f) => (
          <Link
            key={f}
            href={`/admin/history?status=${f}`}
            className={`rounded-full border px-3 py-1 capitalize ${
              query.status === f ? "bg-[#1F3A5F] text-white" : "hover:bg-zinc-100"
            }`}
          >
            {f}
          </Link>
        ))}
      </div>

      {!result.success ? (
        <p className="mt-4 text-sm text-red-600">Could not load alerts.</p>
      ) : (
        <>
          <table className="mt-4 w-full rounded border bg-white text-sm">
            <thead className="border-b text-left text-xs text-zinc-500">
              <tr>
                <th className="p-3">Student</th>
                <th className="p-3">Sent</th>
                <th className="p-3">Status</th>
              </tr>
            </thead>
            <tbody>
              {result.data.items.map((a) => (
                <tr key={a.id} className="border-b last:border-0 hover:bg-zinc-50">
                  <td className="p-3">
                    <Link href={`/admin/alerts/${a.id}`} className="font-medium hover:underline">
                      {a.student.full_name}
                    </Link>
                    <span className="block text-xs text-zinc-500">{a.student.student_id}</span>
                  </td>
                  <td className="p-3">{formatTime(a.started_at)}</td>
                  <td className="p-3"><StatusBadge status={a.status} /></td>
                </tr>
              ))}
              {result.data.items.length === 0 && (
                <tr><td className="p-4 text-zinc-500" colSpan={3}>No alerts.</td></tr>
              )}
            </tbody>
          </table>
          <Pager
            base={`/admin/history?status=${query.status}`}
            page={result.data.page}
            pageSize={result.data.page_size}
            total={result.data.total}
          />
        </>
      )}
    </div>
  );
}
