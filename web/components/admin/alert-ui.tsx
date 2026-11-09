import type { AlertStatus } from "@/types/alert.types";

const STYLES: Record<AlertStatus, string> = {
  active: "bg-red-100 text-red-800",
  acknowledged: "bg-amber-100 text-amber-800",
  resolved: "bg-green-100 text-green-800",
  cancelled: "bg-zinc-200 text-zinc-700",
};

export function StatusBadge({ status }: { status: AlertStatus }) {
  return (
    <span
      className={`inline-block rounded-full px-2.5 py-0.5 text-xs font-medium capitalize ${STYLES[status]}`}
    >
      {status}
    </span>
  );
}

/** Fixed locale and zone so server and client render the same text. */
export function formatTime(iso: string | null): string {
  if (!iso) return "—";
  return new Date(iso).toLocaleString("en-GB", {
    timeZone: "Asia/Dhaka",
    dateStyle: "medium",
    timeStyle: "medium",
  });
}

export function Pager({
  base,
  page,
  pageSize,
  total,
}: {
  base: string;
  page: number;
  pageSize: number;
  total: number;
}) {
  const pages = Math.max(1, Math.ceil(total / pageSize));
  const join = base.includes("?") ? "&" : "?";
  const link = "rounded border px-3 py-1 text-sm hover:bg-zinc-100";
  return (
    <div className="mt-4 flex items-center justify-between text-sm text-zinc-600">
      <span>
        {total} total · page {page} of {pages}
      </span>
      <span className="flex gap-2">
        {page > 1 && (
          <a className={link} href={`${base}${join}page=${page - 1}`}>
            Previous
          </a>
        )}
        {page < pages && (
          <a className={link} href={`${base}${join}page=${page + 1}`}>
            Next
          </a>
        )}
      </span>
    </div>
  );
}
