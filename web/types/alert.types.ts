import type { Database } from "@/types/database.types";
import type { Profile } from "@/types/profile.types";

export type AlertRow = Database["public"]["Tables"]["alerts"]["Row"];
export type AlertStatus = AlertRow["status"];

/** Student fields shown on the alert card (D-062). */
export type AlertStudent = Pick<Profile, "full_name" | "student_id">;

export type AlertListItem = Pick<
  AlertRow,
  "id" | "status" | "started_at" | "acknowledged_at" | "resolved_at" | "cancelled_at"
> & { student: AlertStudent };

/** Full detail for the admin page: student contact info and emergency contacts. */
export type AlertDetail = Pick<
  AlertRow,
  | "id"
  | "status"
  | "started_at"
  | "acknowledged_at"
  | "resolved_at"
  | "cancelled_at"
  | "first_latitude"
  | "first_longitude"
> & {
  student: Pick<Profile, "full_name" | "student_id" | "phone"> & { email: string };
  contacts: { id: string; name: string; phone: string }[];
  acknowledged_by_email: string | null;
  resolved_by_email: string | null;
};

export type AlertPage = {
  items: AlertListItem[];
  page: number;
  page_size: number;
  total: number;
};

export type AdminUserItem = Pick<
  Profile,
  "id" | "full_name" | "student_id" | "phone" | "role" | "created_at"
> & { email: string; verified: boolean };

export type AdminUserPage = {
  items: AdminUserItem[];
  page: number;
  page_size: number;
  total: number;
};

export type AlertAction = "acknowledge" | "resolve";
