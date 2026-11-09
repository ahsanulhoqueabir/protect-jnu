import Link from "next/link";
import { notFound } from "next/navigation";
import { StatusBadge, formatTime } from "@/components/admin/alert-ui";
import { uuidSchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";
import { AlertActions } from "./alert-actions";

export const dynamic = "force-dynamic";

export default async function AlertDetailPage({
  params,
}: {
  params: Promise<{ id: string }>;
}) {
  const id = uuidSchema.safeParse((await params).id);
  if (!id.success) notFound();
  const result = await AlertService.detail(id.data);
  if (!result.success) notFound();
  const a = result.data;

  const row = "flex justify-between border-b py-2 text-sm last:border-0";
  return (
    <div>
      <Link href="/admin" className="text-sm text-zinc-500 hover:underline">
        ← Live alerts
      </Link>
      <div className="mt-2 flex items-center justify-between">
        <h1 className="text-xl font-semibold text-zinc-900">{a.student.full_name}</h1>
        <StatusBadge status={a.status} />
      </div>

      <AlertActions id={a.id} status={a.status} />

      <section className="mt-6 rounded border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-zinc-700">Student</h2>
        <div className={row}><span>Student ID</span><span>{a.student.student_id}</span></div>
        <div className={row}><span>Email</span><span>{a.student.email}</span></div>
        <div className={row}><span>Phone</span><span>{a.student.phone ?? "—"}</span></div>
      </section>

      <section className="mt-4 rounded border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-zinc-700">Emergency contacts</h2>
        {a.contacts.length === 0 ? (
          <p className="text-sm text-zinc-500">None saved.</p>
        ) : (
          a.contacts.map((c) => (
            <div key={c.id} className={row}><span>{c.name}</span><span>{c.phone}</span></div>
          ))
        )}
      </section>

      <section className="mt-4 rounded border bg-white p-4">
        <h2 className="mb-2 text-sm font-semibold text-zinc-700">Timeline</h2>
        <div className={row}><span>Sent</span><span>{formatTime(a.started_at)}</span></div>
        <div className={row}>
          <span>Acknowledged{a.acknowledged_by_email ? ` by ${a.acknowledged_by_email}` : ""}</span>
          <span>{formatTime(a.acknowledged_at)}</span>
        </div>
        <div className={row}>
          <span>Resolved{a.resolved_by_email ? ` by ${a.resolved_by_email}` : ""}</span>
          <span>{formatTime(a.resolved_at)}</span>
        </div>
        <div className={row}><span>Cancelled by student</span><span>{formatTime(a.cancelled_at)}</span></div>
        <div className={row}>
          <span>First location</span>
          <span>
            {a.first_latitude != null && a.first_longitude != null
              ? `${a.first_latitude.toFixed(5)}, ${a.first_longitude.toFixed(5)}`
              : "Not shared"}
          </span>
        </div>
      </section>
    </div>
  );
}
