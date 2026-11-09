import { Pager, formatTime } from "@/components/admin/alert-ui";
import { pageQuerySchema } from "@/schema/alert.schema";
import { AlertService } from "@/services/alert.service";

export const dynamic = "force-dynamic";

export default async function UsersPage({
  searchParams,
}: {
  searchParams: Promise<Record<string, string | undefined>>;
}) {
  const q = pageQuerySchema.safeParse({ page: (await searchParams).page });
  const result = await AlertService.listUsers(q.success ? q.data.page : 1);

  return (
    <div>
      <h1 className="text-xl font-semibold text-zinc-900">Users</h1>
      {!result.success ? (
        <p className="mt-4 text-sm text-red-600">Could not load users.</p>
      ) : (
        <>
          <table className="mt-4 w-full rounded border bg-white text-sm">
            <thead className="border-b text-left text-xs text-zinc-500">
              <tr>
                <th className="p-3">Name</th>
                <th className="p-3">Student ID</th>
                <th className="p-3">Email</th>
                <th className="p-3">Phone</th>
                <th className="p-3">Role</th>
                <th className="p-3">Joined</th>
              </tr>
            </thead>
            <tbody>
              {result.data.items.map((u) => (
                <tr key={u.id} className="border-b last:border-0">
                  <td className="p-3 font-medium">{u.full_name}</td>
                  <td className="p-3">{u.student_id}</td>
                  <td className="p-3">
                    {u.email}
                    {!u.verified && <span className="ml-1 text-xs text-amber-700">(unverified)</span>}
                  </td>
                  <td className="p-3">{u.phone ?? "—"}</td>
                  <td className="p-3 capitalize">{u.role}</td>
                  <td className="p-3">{formatTime(u.created_at)}</td>
                </tr>
              ))}
            </tbody>
          </table>
          <Pager
            base="/admin/users"
            page={result.data.page}
            pageSize={result.data.page_size}
            total={result.data.total}
          />
        </>
      )}
    </div>
  );
}
