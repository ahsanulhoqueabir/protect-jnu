import type { z } from "zod";
import type {
  forgotPasswordSchema,
  loginSchema,
  refreshSchema,
  registerSchema,
  resendOtpSchema,
  resetPasswordSchema,
  signUpSchema,
  verifyOtpSchema,
} from "@/schema/auth.schema";
import type { Profile, PublicProfile } from "@/types/profile.types";

/** Request payloads — inferred from the shared Zod schemas. */
export type RegisterParams = z.infer<typeof registerSchema>;
export type VerifyOtpParams = z.infer<typeof verifyOtpSchema>;
export type ResendOtpParams = z.infer<typeof resendOtpSchema>;
export type LoginParams = z.infer<typeof loginSchema>;
export type RefreshParams = z.infer<typeof refreshSchema>;
export type ForgotPasswordParams = z.infer<typeof forgotPasswordSchema>;
export type ResetPasswordParams = z.infer<typeof resetPasswordSchema>;

/** @deprecated Template signup form type; replaced in Phase 3 (see `signUpSchema`). */
export type SignUpParams = z.infer<typeof signUpSchema>;

/** The caller of a protected route, resolved from a Supabase access token. */
export type AuthenticatedUser = {
  id: Profile["id"];
  email: Profile["university_email"];
  role: Profile["role"];
};

/** User shape exposed to clients. */
export type AuthUser = PublicProfile;

/** Supabase session handed to the client (seconds). Never logged. */
export type SessionTokens = {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  expires_at: number;
};

/** Response `data` of login. */
export type AuthSession = { user: AuthUser; session: SessionTokens };
