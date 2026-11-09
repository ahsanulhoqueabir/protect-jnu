import { failure, success, toMessage } from "@/lib/service-result";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import type { ServiceResult } from "@/types/generic.types";
import type {
  AdminUserPage,
  AlertAction,
  AlertDetail,
  AlertListItem,
  AlertPage,
  AlertStatus,
} from "@/types/alert.types";

export const PAGE_SIZE = 20;

const GENERIC = "Something went wrong. Please try again.";

/** Allowed admin transitions (PRD): active -> acknowledged -> resolved. Nothing else. */
const TRANSITIONS: Record<AlertAction, { from: AlertStatus; to: AlertStatus }> = {
  acknowledge: { from: "active", to: "acknowledged" },
  resolve: { from: "acknowledged", to: "resolved" },
};

const LIST_COLUMNS =
  "id,status,started_at,acknowledged_at,resolved_at,cancelled_at,student:profiles!alerts_user_id_fkey(full_name,student_id)";

function range(page: number) {
  const from = (page - 1) * PAGE_SIZE;
  return { from, to: from + PAGE_SIZE - 1 };
}

export class AlertService {
  /** Alerts for the dashboard (admin only, enforced by the route). Newest first. */
  static async list(params: {
    status: "open" | "all" | AlertStatus;
    page: number;
  }): Promise<ServiceResult<AlertPage>> {
    try {
      let q = getSupabaseServerClient()
        .from("alerts")
        .select(LIST_COLUMNS, { count: "exact" })
        .order("started_at", { ascending: false });
      if (params.status === "open") q = q.in("status", ["active", "acknowledged"]);
      else if (params.status !== "all") q = q.eq("status", params.status);

      const { from, to } = range(params.page);
      const { data, count, error } = await q.range(from, to);
      if (error) throw new Error(error.message);

      return success({
        items: (data ?? []) as unknown as AlertListItem[],
        page: params.page,
        page_size: PAGE_SIZE,
        total: count ?? 0,
      });
    } catch (err) {
      console.error("alert list error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  static async detail(id: string): Promise<ServiceResult<AlertDetail>> {
    try {
      const db = getSupabaseServerClient();
      const { data: alert, error } = await db
        .from("alerts")
        .select("*")
        .eq("id", id)
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (!alert) return failure("Alert not found.", { code: "alert_not_found" });

      const adminIds = [alert.acknowledged_by, alert.resolved_by].filter(
        (v): v is string => !!v,
      );
      const [student, contacts, admins] = await Promise.all([
        db
          .from("profiles")
          .select("full_name,student_id,phone,university_email")
          .eq("id", alert.user_id)
          .single(),
        db
          .from("emergency_contacts")
          .select("id,name,phone")
          .eq("user_id", alert.user_id)
          .order("created_at"),
        adminIds.length
          ? db.from("profiles").select("id,university_email").in("id", adminIds)
          : Promise.resolve({ data: [], error: null }),
      ]);
      if (student.error) throw new Error(student.error.message);
      if (contacts.error) throw new Error(contacts.error.message);
      if (admins.error) throw new Error(admins.error.message);

      const emailOf = (adminId: string | null) =>
        admins.data?.find((a) => a.id === adminId)?.university_email ?? null;

      return success({
        id: alert.id,
        status: alert.status,
        started_at: alert.started_at,
        acknowledged_at: alert.acknowledged_at,
        resolved_at: alert.resolved_at,
        cancelled_at: alert.cancelled_at,
        first_latitude: alert.first_latitude,
        first_longitude: alert.first_longitude,
        student: {
          full_name: student.data.full_name,
          student_id: student.data.student_id,
          phone: student.data.phone,
          email: student.data.university_email,
        },
        contacts: contacts.data ?? [],
        acknowledged_by_email: emailOf(alert.acknowledged_by),
        resolved_by_email: emailOf(alert.resolved_by),
      });
    } catch (err) {
      console.error("alert detail error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /**
   * Admin transition, validated on the server and race-safe: the UPDATE only matches while the row is
   * still in the expected state, so two admins cannot both win and a resolved alert cannot be reopened.
   * Timestamps are set by the DB trigger; the acting admin id is recorded here (D-061, 0013).
   */
  static async transition(
    adminId: string,
    alertId: string,
    action: AlertAction,
  ): Promise<ServiceResult<{ id: string; status: AlertStatus }>> {
    try {
      const { from, to } = TRANSITIONS[action];
      const patch =
        action === "acknowledge"
          ? { status: to, acknowledged_by: adminId }
          : { status: to, resolved_by: adminId };

      const db = getSupabaseServerClient();
      const { data, error } = await db
        .from("alerts")
        .update(patch)
        .eq("id", alertId)
        .eq("status", from)
        .select("id,status")
        .maybeSingle();
      if (error) throw new Error(error.message);
      if (data) return success(data);

      const { data: current, error: readError } = await db
        .from("alerts")
        .select("status")
        .eq("id", alertId)
        .maybeSingle();
      if (readError) throw new Error(readError.message);
      if (!current) return failure("Alert not found.", { code: "alert_not_found" });
      return failure(`This alert is ${current.status} and cannot be changed that way.`, {
        code: "invalid_transition",
        data: { current_status: current.status },
      });
    } catch (err) {
      console.error("alert transition error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Basic users list (admin only): contact details of students, newest first. */
  static async listUsers(page: number): Promise<ServiceResult<AdminUserPage>> {
    try {
      const { from, to } = range(page);
      const { data, count, error } = await getSupabaseServerClient()
        .from("profiles")
        .select(
          "id,full_name,student_id,phone,role,created_at,university_email,email_verified_at",
          { count: "exact" },
        )
        .order("created_at", { ascending: false })
        .range(from, to);
      if (error) throw new Error(error.message);

      return success({
        items: (data ?? []).map((p) => ({
          id: p.id,
          full_name: p.full_name,
          student_id: p.student_id,
          phone: p.phone,
          role: p.role,
          created_at: p.created_at,
          email: p.university_email,
          verified: !!p.email_verified_at,
        })),
        page,
        page_size: PAGE_SIZE,
        total: count ?? 0,
      });
    } catch (err) {
      console.error("users list error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }
}
