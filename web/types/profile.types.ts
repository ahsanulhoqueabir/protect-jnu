import type { Database } from "@/types/database.types";

type Tables = Database["public"]["Tables"];

/** Full `profiles` row (server-side only). */
export type Profile = Tables["profiles"]["Row"];
export type ProfileInsert = Tables["profiles"]["Insert"];

/**
 * Columns a client may change on its own profile (migration 0008 column grant).
 * Server code uses the service role and is not limited by this.
 */
export type ProfileUpdate = Pick<
  Tables["profiles"]["Update"],
  "full_name" | "phone"
>;

/** Client-safe projection returned by the auth API (docs/api-contract.md). `email` = `university_email`. */
export type PublicProfile = Pick<
  Profile,
  "id" | "full_name" | "student_id" | "phone" | "role"
> & { email: Profile["university_email"] };
