import type { Database } from "@/types/database.types";

type Tables = Database["public"]["Tables"];
type Views = Database["public"]["Views"];

/** Full `profiles` row (server-side only). */
export type Profile = Tables["profiles"]["Row"];
export type ProfileInsert = Tables["profiles"]["Insert"];
export type ProfileUpdate = Omit<
  Tables["profiles"]["Update"],
  "id" | "user" | "created_at" | "updated_at"
>;

/** Client-safe projection — row of the `profiles_public` view. */
export type PublicProfile = Views["profiles_public"]["Row"];
