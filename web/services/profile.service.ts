import { getSupabaseServerClient } from "@/lib/api/supabase";
import { success, failure, toMessage } from "@/lib/service-result";
import type { ServiceResult } from "@/types/generic.types";
import type { Profile, PublicProfile } from "@/types/profile.types";

/** Profile data access. The only place that touches `profiles` / `profiles_public`. */
export class ProfileService {
  /** Full row by auth user id (server-side use, e.g. building the JWT). */
  static async getByUserId(
    userId: Profile["user"],
  ): Promise<ServiceResult<Profile>> {
    try {
      const { data, error } = await getSupabaseServerClient()
        .from("profiles")
        .select("*")
        .eq("user", userId)
        .maybeSingle();

      if (error) return failure(error.message);
      if (!data) return failure("User profile not found");
      return success(data);
    } catch (err) {
      return failure(toMessage(err));
    }
  }

  /** Client-safe projection by profile id (via the `profiles_public` view). */
  static async getPublicById(
    id: Profile["id"],
  ): Promise<ServiceResult<PublicProfile>> {
    try {
      const { data, error } = await getSupabaseServerClient()
        .from("profiles_public")
        .select("*")
        .eq("id", id)
        .maybeSingle();

      if (error) return failure(error.message);
      if (!data) return failure("Profile not found");
      return success(data);
    } catch (err) {
      return failure(toMessage(err));
    }
  }
}
