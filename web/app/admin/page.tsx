import { cookies } from "next/headers";
import { ACCESS_COOKIE } from "@/lib/api/admin-session";
import { AlertService } from "@/services/alert.service";
import { LiveAlerts } from "./live-alerts";

export const dynamic = "force-dynamic";

export default async function AdminHome() {
  // The layout has already verified this token belongs to an admin.
  const token = (await cookies()).get(ACCESS_COOKIE)?.value ?? "";
  const list = await AlertService.list({ status: "open", page: 1 });

  return (
    <LiveAlerts
      initial={list.success ? list.data.items : []}
      accessToken={token}
      supabaseUrl={process.env.NEXT_PUBLIC_SUPABASE_URL!}
      publishableKey={process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY!}
    />
  );
}
