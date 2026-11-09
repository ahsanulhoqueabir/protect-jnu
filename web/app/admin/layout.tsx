import { cookies } from "next/headers";
import { redirect } from "next/navigation";
import { ACCESS_COOKIE } from "@/lib/api/admin-session";
import { AuthService } from "@/services/auth.service";
import { LogoutButton } from "./logout-button";

/**
 * Authoritative admin check (the proxy only looks for a cookie): validates the token with
 * Supabase and requires role = admin on every request. Never cached.
 */
export default async function AdminLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const token = (await cookies()).get(ACCESS_COOKIE)?.value;
  if (!token) redirect("/login");

  const auth = await AuthService.authenticate(token);
  if (!auth.success || auth.data.role !== "admin") redirect("/login");

  return (
    <div className="min-h-screen bg-zinc-50 dark:bg-black">
      <header className="flex items-center justify-between bg-[#1F3A5F] px-6 py-3 text-white">
        <span className="text-sm font-semibold tracking-wide">
          Protect JnU&apos;ins · Admin
        </span>
        <nav className="flex gap-4 text-sm">
          <a href="/admin" className="hover:underline">Live</a>
          <a href="/admin/history" className="hover:underline">History</a>
          <a href="/admin/users" className="hover:underline">Users</a>
        </nav>
        <div className="flex items-center gap-4 text-sm">
          <span className="opacity-80">{auth.data.email}</span>
          <LogoutButton />
        </div>
      </header>
      <main className="mx-auto max-w-5xl px-6 py-8">{children}</main>
    </div>
  );
}
