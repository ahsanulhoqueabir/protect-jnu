import { createHmac, randomInt, timingSafeEqual } from "node:crypto";
import { otp as otpConfig } from "@/config/env.config";

/** Purposes an OTP can serve (matches the `otp_purpose` DB enum). */
export type OtpPurpose = "email_verification" | "password_reset";

/** 6-digit code from the OS CSPRNG (PRD 5.1). Leading zeros are kept. */
export function generateOtpCode(): string {
  return randomInt(0, 1_000_000).toString().padStart(6, "0");
}

/**
 * HMAC-SHA256 over `userId:purpose:code`, keyed by OTP_HASH_SECRET (D-047).
 * A 6-digit code has only 1,000,000 values, so a plain hash would be brute-forced
 * in seconds; the server-only key prevents that if the table ever leaks.
 */
export function hashOtp(
  userId: string,
  purpose: OtpPurpose,
  code: string,
): string {
  const secret = otpConfig.hashSecret;
  if (!secret || secret.length < 32) {
    throw new Error("OTP_HASH_SECRET must be set (at least 32 characters)");
  }
  return createHmac("sha256", secret)
    .update(`${userId}:${purpose}:${code}`)
    .digest("hex");
}

/** Constant-time comparison of two hex digests. */
export function hashesEqual(a: string, b: string): boolean {
  const left = Buffer.from(a, "hex");
  const right = Buffer.from(b, "hex");
  if (left.length === 0 || left.length !== right.length) return false;
  return timingSafeEqual(left, right);
}
