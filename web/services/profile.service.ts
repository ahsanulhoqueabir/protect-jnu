import { getSupabaseServerClient } from "@/lib/api/supabase";
import { success, failure, toMessage } from "@/lib/service-result";
import type { ServiceResult } from "@/types/generic.types";
import type { Profile, PublicProfile } from "@/types/profile.types";

/** Profile data access. The only place that touches the `profiles` table. Server-side only. */
export class ProfileService {
  /** Client-safe projection of a full row (`email` = `university_email`). */
  static toPublic(profile: Profile): PublicProfile {
    return {
      id: profile.id,
      full_name: profile.full_name,
      student_id: profile.student_id,
      email: profile.university_email,
      phone: profile.phone,
      role: profile.role,
    };
  }

  static async getById(id: Profile["id"]): Promise<ServiceResult<Profile>> {
    try {
      const { data, error } = await getSupabaseServerClient()
        .from("profiles")
        .select("*")
        .eq("id", id)
        .maybeSingle();

      if (error) return failure("Could not load the profile");
      if (!data) return failure("Profile not found");
      return success(data);
    } catch (err) {
      return failure(toMessage(err));
    }
  }

  /** `null` data means no profile has this email (not an error). Email must already be normalised. */
  static async getByEmail(
    email: Profile["university_email"],
  ): Promise<ServiceResult<Profile | null>> {
    try {
      const { data, error } = await getSupabaseServerClient()
        .from("profiles")
        .select("*")
        .eq("university_email", email)
        .maybeSingle();

      if (error) return failure("Could not load the profile");
      return success(data);
    } catch (err) {
      return failure(toMessage(err));
    }
  }

  /** `null` data means no profile has this student ID. ID must already be normalised. */
  static async getByStudentId(
    studentId: Profile["student_id"],
  ): Promise<ServiceResult<Profile | null>> {
    try {
      const { data, error } = await getSupabaseServerClient()
        .from("profiles")
        .select("*")
        .eq("student_id", studentId)
        .maybeSingle();

      if (error) return failure("Could not load the profile");
      return success(data);
    } catch (err) {
      return failure(toMessage(err));
    }
  }

  /** Record that the email was proven by OTP. Idempotent: never overwrites an earlier time. */
  static async markVerified(id: Profile["id"]): Promise<ServiceResult<null>> {
    try {
      const { error } = await getSupabaseServerClient()
        .from("profiles")
        .update({ email_verified_at: new Date().toISOString() })
        .eq("id", id)
        .is("email_verified_at", null);

      if (error) return failure("Could not update the profile");
      return success(null);
    } catch (err) {
      return failure(toMessage(err));
    }
  }
}
