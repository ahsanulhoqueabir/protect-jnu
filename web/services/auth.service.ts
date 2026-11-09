import {
  createSupabaseAuthClient,
  getSupabaseServerClient,
} from "@/lib/api/supabase";
import { signJwt } from "@/lib/jwt.helper";
import { success, failure, toMessage } from "@/lib/service-result";
import { ProfileService } from "@/services/profile.service";
import type {
  AuthSession,
  JwtPayload,
  LoginParams,
  SignUpParams,
} from "@/types/auth.types";
import type { ServiceResult } from "@/types/generic.types";
import type { Profile } from "@/types/profile.types";

async function issueSession(profile: Profile): Promise<AuthSession> {
  const payload: JwtPayload = {
    profile: profile.id,
    email: profile.email,
    role: profile.role,
  };
  const { id, email, name, username, role } = profile;
  return {
    user: { id, email, name, username, role },
    token: await signJwt(payload),
  };
}

export class AuthService {
  /**
   * Create the auth user. The `on_auth_user_created` trigger (schemas/0003)
   * creates the profile in the same transaction, so signup is atomic:
   * either both rows exist or neither does.
   */
  static async signUp(
    params: SignUpParams,
  ): Promise<ServiceResult<AuthSession>> {
    try {
      const { data, error } =
        await getSupabaseServerClient().auth.admin.createUser({
          email: params.email,
          password: params.password,
          email_confirm: true,
          user_metadata: { name: params.name, username: params.username ?? "" },
        });

      if (error) return failure(error.message);
      if (!data.user) return failure("Failed to create user");

      const profile = await ProfileService.getByUserId(data.user.id);
      if (!profile.success) return profile;

      return success(await issueSession(profile.data));
    } catch (err) {
      return failure(toMessage(err));
    }
  }

  /** Verify credentials, then return the profile-backed session + JWT. */
  static async login(params: LoginParams): Promise<ServiceResult<AuthSession>> {
    try {
      const { data, error } =
        await createSupabaseAuthClient().auth.signInWithPassword(params);

      if (error) return failure(error.message);
      if (!data.user) return failure("Invalid email or password");

      const profile = await ProfileService.getByUserId(data.user.id);
      if (!profile.success) return profile;

      return success(await issueSession(profile.data));
    } catch (err) {
      return failure(toMessage(err));
    }
  }
}
