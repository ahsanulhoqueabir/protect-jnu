import {
  createSupabaseAuthClient,
  getSupabaseServerClient,
} from "@/lib/api/supabase";
import { otp as otpConfig } from "@/config/env.config";
import { success, failure, toMessage } from "@/lib/service-result";
import { OtpService } from "@/services/otp.service";
import { ProfileService } from "@/services/profile.service";
import type {
  AuthenticatedUser,
  AuthSession,
  ForgotPasswordParams,
  LoginParams,
  RefreshParams,
  RegisterParams,
  ResendOtpParams,
  ResetPasswordParams,
  SessionTokens,
  VerifyOtpParams,
} from "@/types/auth.types";
import type { ServiceResult } from "@/types/generic.types";
import type { Profile, PublicProfile } from "@/types/profile.types";

const GENERIC = "Something went wrong. Try again later.";
const NOT_VERIFIED = "Verify your university email before signing in.";

/** Supabase session -> the shape the API returns. Tokens are never logged. */
function toTokens(session: {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at?: number;
}): SessionTokens {
  return {
    access_token: session.access_token,
    refresh_token: session.refresh_token,
    expires_in: session.expires_in,
    expires_at:
      session.expires_at ?? Math.floor(Date.now() / 1000) + session.expires_in,
  };
}

/**
 * Registration, OTP verification, login, sessions and password reset (docs/api-contract.md).
 * Supabase Auth is only the identity and password store (D-027): it is never asked to send an email.
 * Users are created UNCONFIRMED; Supabase's `email_not_confirmed` is the enforced gate and
 * `profiles.email_verified_at` is the second check (D-043).
 */
export class AuthService {
  /**
   * Registration for an email that already has an account. Verified: `email_taken`.
   * Unverified: keep the original password (a second registration must never replace it) and
   * send a fresh code. Recovery for a forgotten password is /forgot-password.
   */
  private static async registerExisting(
    profile: Profile,
    email: string,
  ): Promise<ServiceResult<{ email: string; resend_available_in: number }>> {
    if (profile.email_verified_at) {
      return failure("An account with this email already exists.", {
        code: "email_taken",
      });
    }
    const issued = await OtpService.issue({
      userId: profile.id,
      email: profile.university_email,
      name: profile.full_name,
      purpose: "email_verification",
    });
    if (!issued.success) return issued;
    return success({ email, ...issued.data });
  }

  /** Create an unverified account and email a verification code. No session is returned. */
  static async register(
    params: RegisterParams,
  ): Promise<ServiceResult<{ email: string; resend_available_in: number }>> {
    try {
      const existing = await ProfileService.getByEmail(params.email);
      if (!existing.success) return failure(GENERIC, { code: "internal_error" });

      if (existing.data) {
        return await AuthService.registerExisting(existing.data, params.email);
      }

      const sameId = await ProfileService.getByStudentId(params.student_id);
      if (!sameId.success) return failure(GENERIC, { code: "internal_error" });
      if (sameId.data) {
        return failure("An account with this student ID already exists.", {
          code: "student_id_taken",
        });
      }

      // No `email_confirm`: the account stays unconfirmed until our OTP verifies (D-043).
      const { data, error } = await getSupabaseServerClient().auth.admin.createUser(
        {
          email: params.email,
          password: params.password,
          user_metadata: {
            full_name: params.full_name,
            student_id: params.student_id,
          },
        },
      );

      if (error || !data.user) {
        if (error?.code === "email_exists") {
          return failure("An account with this email already exists.", {
            code: "email_taken",
          });
        }
        if (error?.code === "weak_password") {
          return failure("Choose a stronger password.", {
            code: "weak_password",
          });
        }
        // A concurrent registration fails inside Auth or the DB trigger with a generic error.
        // Re-read both keys: the winner's account now exists.
        const racedEmail = await ProfileService.getByEmail(params.email);
        if (racedEmail.success && racedEmail.data) {
          return await AuthService.registerExisting(racedEmail.data, params.email);
        }
        const raced = await ProfileService.getByStudentId(params.student_id);
        if (raced.success && raced.data) {
          return failure("An account with this student ID already exists.", {
            code: "student_id_taken",
          });
        }
        console.error("createUser failed", { authCode: error?.code });
        return failure(GENERIC, { code: "internal_error" });
      }

      const issued = await OtpService.issue({
        userId: data.user.id,
        email: params.email,
        name: params.full_name,
        purpose: "email_verification",
      });
      if (!issued.success) return issued;
      return success({ email: params.email, ...issued.data });
    } catch (err) {
      console.error("register error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Verify the registration code. No session is issued (R1): the client logs in next. */
  static async verifyOtp(
    params: VerifyOtpParams,
  ): Promise<ServiceResult<{ verified: true }>> {
    try {
      const profile = await ProfileService.getByEmail(params.email);
      if (!profile.success) return failure(GENERIC, { code: "internal_error" });
      // Unknown email and already-verified email look the same as "no active code".
      if (!profile.data || profile.data.email_verified_at) {
        return failure("No active code. Request a new one.", {
          code: "otp_not_found",
        });
      }

      const checked = await OtpService.verify({
        userId: profile.data.id,
        purpose: "email_verification",
        code: params.code,
      });
      if (!checked.success) return checked;

      // Single use first: a racing second request loses here and does nothing else.
      if (!(await OtpService.consume(checked.data.otpId))) {
        return failure("No active code. Request a new one.", {
          code: "otp_not_found",
        });
      }

      const confirmed = await getSupabaseServerClient().auth.admin.updateUserById(
        profile.data.id,
        { email_confirm: true },
      );
      if (confirmed.error) {
        console.error("email_confirm failed", { authCode: confirmed.error.code });
        return failure(GENERIC, { code: "internal_error" });
      }
      const marked = await ProfileService.markVerified(profile.data.id);
      if (!marked.success) return failure(GENERIC, { code: "internal_error" });

      return success({ verified: true });
    } catch (err) {
      console.error("verifyOtp error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /**
   * Send a new code. For email_verification only an existing unverified account is emailed; for
   * password_reset any existing account is. Otherwise nothing is sent and the answer is the same.
   */
  static async resendOtp(
    params: ResendOtpParams,
  ): Promise<ServiceResult<{ resend_available_in: number }>> {
    try {
      const profile = await ProfileService.getByEmail(params.email);
      if (!profile.success) return failure(GENERIC, { code: "internal_error" });

      const eligible =
        profile.data &&
        (params.purpose === "password_reset" || !profile.data.email_verified_at);
      if (!profile.data || !eligible) {
        return success({ resend_available_in: otpConfig.cooldownSeconds });
      }

      return await OtpService.issue({
        userId: profile.data.id,
        email: profile.data.university_email,
        name: profile.data.full_name,
        purpose: params.purpose,
      });
    } catch (err) {
      console.error("resendOtp error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Password sign-in. `adminOnly` makes a non-admin fail with `not_admin` and no session. */
  static async login(
    params: LoginParams,
    options: { adminOnly?: boolean } = {},
  ): Promise<ServiceResult<AuthSession>> {
    try {
      const { data, error } =
        await createSupabaseAuthClient().auth.signInWithPassword({
          email: params.email,
          password: params.password,
        });

      if (error || !data.session || !data.user) {
        if (error?.code === "email_not_confirmed") {
          return failure(NOT_VERIFIED, { code: "email_not_verified" });
        }
        return failure("Incorrect email or password.", {
          code: "invalid_credentials",
        });
      }

      const revoke = () =>
        getSupabaseServerClient().auth.admin.signOut(
          data.session.access_token,
          "local",
        );

      const profile = await ProfileService.getById(data.user.id);
      if (!profile.success) {
        await revoke();
        return failure(GENERIC, { code: "internal_error" });
      }

      // Second check (D-043): never hand out a session to an unverified profile.
      if (!profile.data.email_verified_at) {
        await revoke();
        return failure(NOT_VERIFIED, { code: "email_not_verified" });
      }
      if (options.adminOnly && profile.data.role !== "admin") {
        await revoke();
        return failure("This account is not an administrator.", {
          code: "not_admin",
        });
      }

      return success({
        user: ProfileService.toPublic(profile.data),
        session: toTokens(data.session),
      });
    } catch (err) {
      console.error("login error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Exchange a refresh token for a new session (Supabase rotates the refresh token). */
  static async refresh(
    params: RefreshParams,
  ): Promise<ServiceResult<{ session: SessionTokens }>> {
    try {
      const { data, error } = await createSupabaseAuthClient().auth.refreshSession(
        { refresh_token: params.refresh_token },
      );
      if (error || !data.session) {
        return failure("Your session has expired. Sign in again.", {
          code: "invalid_refresh_token",
        });
      }
      return success({ session: toTokens(data.session) });
    } catch (err) {
      console.error("refresh error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Revoke the session belonging to this access token only (scope `local`). */
  static async logout(
    accessToken: string,
  ): Promise<ServiceResult<{ logged_out: true }>> {
    try {
      const { error } = await getSupabaseServerClient().auth.admin.signOut(
        accessToken,
        "local",
      );
      if (error) return failure(GENERIC, { code: "internal_error" });
      return success({ logged_out: true });
    } catch (err) {
      console.error("logout error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** The signed-in user's client-safe profile. */
  static async me(userId: string): Promise<ServiceResult<{ user: PublicProfile }>> {
    const profile = await ProfileService.getById(userId);
    if (!profile.success) return failure(GENERIC, { code: "internal_error" });
    return success({ user: ProfileService.toPublic(profile.data) });
  }

  /**
   * Validate a Supabase access token with the Auth server and load the caller's role.
   * Used by every protected route. Unverified profiles are refused.
   */
  static async authenticate(
    accessToken: string,
  ): Promise<ServiceResult<AuthenticatedUser>> {
    try {
      const { data, error } =
        await createSupabaseAuthClient().auth.getUser(accessToken);
      if (error || !data.user) {
        return failure("Invalid or expired token.", { code: "invalid_token" });
      }

      const profile = await ProfileService.getById(data.user.id);
      if (!profile.success) {
        return failure("Invalid or expired token.", { code: "invalid_token" });
      }
      if (!profile.data.email_verified_at) {
        return failure(NOT_VERIFIED, { code: "email_not_verified" });
      }

      return success({
        id: profile.data.id,
        email: profile.data.university_email,
        role: profile.data.role,
      });
    } catch (err) {
      console.error("authenticate error", toMessage(err));
      return failure("Invalid or expired token.", { code: "invalid_token" });
    }
  }

  /** Always succeeds from the caller's view; an email is sent only if the account exists. */
  static async forgotPassword(
    params: ForgotPasswordParams,
  ): Promise<ServiceResult<{ resend_available_in: number }>> {
    return AuthService.resendOtp({
      email: params.email,
      purpose: "password_reset",
    });
  }

  /** Verify the reset code, set the new password, verify the email, revoke every session. */
  static async resetPassword(
    params: ResetPasswordParams,
  ): Promise<ServiceResult<{ password_reset: true }>> {
    try {
      const profile = await ProfileService.getByEmail(params.email);
      if (!profile.success) return failure(GENERIC, { code: "internal_error" });
      if (!profile.data) {
        return failure("No active code. Request a new one.", {
          code: "otp_not_found",
        });
      }

      const checked = await OtpService.verify({
        userId: profile.data.id,
        purpose: "password_reset",
        code: params.code,
      });
      if (!checked.success) return checked;

      if (!(await OtpService.consume(checked.data.otpId))) {
        return failure("No active code. Request a new one.", {
          code: "otp_not_found",
        });
      }

      const supabase = getSupabaseServerClient();
      // The code proved control of the inbox, so the email counts as verified too.
      const updated = await supabase.auth.admin.updateUserById(profile.data.id, {
        password: params.new_password,
        email_confirm: true,
      });
      if (updated.error) {
        if (updated.error.code === "weak_password") {
          return failure("Choose a stronger password.", {
            code: "weak_password",
          });
        }
        console.error("password update failed", { authCode: updated.error.code });
        return failure(GENERIC, { code: "internal_error" });
      }

      const marked = await ProfileService.markVerified(profile.data.id);
      if (!marked.success) return failure(GENERIC, { code: "internal_error" });

      // Existing sessions end with the old password (D-016). Issued access tokens stay valid
      // until they expire (Supabase docs).
      const revoked = await supabase.rpc("revoke_user_sessions", {
        p_user_id: profile.data.id,
      });
      if (revoked.error) {
        console.error("revoke_user_sessions failed", { dbCode: revoked.error.code });
        return failure(GENERIC, { code: "internal_error" });
      }

      return success({ password_reset: true });
    } catch (err) {
      console.error("resetPassword error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }
}
