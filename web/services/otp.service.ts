import { otp as otpConfig } from "@/config/env.config";
import { getSupabaseServerClient } from "@/lib/api/supabase";
import {
  generateOtpCode,
  hashesEqual,
  hashOtp,
  type OtpPurpose,
} from "@/lib/otp";
import { failure, success, toMessage } from "@/lib/service-result";
import { EmailService } from "@/services/email.service";
import type { ServiceResult } from "@/types/generic.types";

const GENERIC = "Something went wrong. Try again later.";

/**
 * OTP lifecycle (PRD 5.1, D-012, D-047). All state changes that must be atomic live in Postgres
 * functions (schemas/0011): issue + throttle + supersede, attempt counting, single-use consume.
 * This service generates the code, hashes it, sends the email, and compares hashes in constant time.
 * It never logs or returns a code or a hash.
 */
export class OtpService {
  /** Issue a code for `userId` and email it. Counts toward the send limits only if delivery succeeds. */
  static async issue(params: {
    userId: string;
    email: string;
    name: string;
    purpose: OtpPurpose;
  }): Promise<ServiceResult<{ resend_available_in: number }>> {
    try {
      const supabase = getSupabaseServerClient();
      const code = generateOtpCode();
      const codeHash = hashOtp(params.userId, params.purpose, code);

      const { data, error } = await supabase.rpc("otp_issue", {
        p_user_id: params.userId,
        p_email: params.email,
        p_purpose: params.purpose,
        p_code_hash: codeHash,
        p_ttl_seconds: otpConfig.ttlSeconds,
        p_cooldown_seconds: otpConfig.cooldownSeconds,
        p_window_seconds: otpConfig.windowSeconds,
        p_max_sends: otpConfig.maxSends,
      });
      const row = data?.[0];
      if (error || !row) {
        console.error("otp_issue failed", { dbCode: error?.code });
        return failure(GENERIC, { code: "internal_error" });
      }

      if (row.status === "cooldown") {
        return failure("Please wait before requesting another code.", {
          code: "otp_resend_cooldown",
          data: { retry_after_seconds: row.retry_after_seconds },
        });
      }
      if (row.status === "send_limit") {
        return failure("Too many codes requested. Try again later.", {
          code: "otp_send_limit",
          data: { retry_after_seconds: row.retry_after_seconds },
        });
      }

      const sent = await EmailService.sendOtp({
        to: params.email,
        name: params.name,
        purpose: params.purpose,
        code,
        ttlMinutes: otpConfig.ttlSeconds / 60,
      });
      if (!sent.success) {
        // Delivery failed: the code is dead and the send does not count toward the limit.
        await supabase.rpc("otp_revoke_issue", {
          p_otp_id: row.otp_id,
          p_email: params.email,
        });
        return sent;
      }

      return success({ resend_available_in: otpConfig.cooldownSeconds });
    } catch (err) {
      console.error("OTP issue error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /**
   * Check a submitted code. The attempt is counted in the database BEFORE the comparison.
   * On success the code is NOT consumed yet: the caller does its side effects, then calls `consume`.
   */
  static async verify(params: {
    userId: string;
    purpose: OtpPurpose;
    code: string;
  }): Promise<ServiceResult<{ otpId: string }>> {
    try {
      const { data, error } = await getSupabaseServerClient().rpc(
        "otp_begin_attempt",
        {
          p_user_id: params.userId,
          p_purpose: params.purpose,
          p_max_attempts: otpConfig.maxAttempts,
        },
      );
      const row = data?.[0];
      if (error || !row) {
        console.error("otp_begin_attempt failed", { dbCode: error?.code });
        return failure(GENERIC, { code: "internal_error" });
      }

      if (row.status === "not_found") {
        return failure("No active code. Request a new one.", {
          code: "otp_not_found",
        });
      }
      if (row.status === "expired") {
        return failure("This code has expired. Request a new one.", {
          code: "otp_expired",
        });
      }
      if (row.status === "attempts_exceeded") {
        return failure("Too many wrong attempts. Request a new code.", {
          code: "otp_attempts_exceeded",
        });
      }

      const submitted = hashOtp(params.userId, params.purpose, params.code);
      if (!row.stored_hash || !hashesEqual(submitted, row.stored_hash)) {
        return failure("Incorrect code.", {
          code: "otp_invalid",
          data: {
            attempts_remaining: Math.max(
              0,
              otpConfig.maxAttempts - row.attempts_after,
            ),
          },
        });
      }

      return success({ otpId: row.otp_id });
    } catch (err) {
      console.error("OTP verify error", toMessage(err));
      return failure(GENERIC, { code: "internal_error" });
    }
  }

  /** Mark a verified code used. False if it was already used, superseded or expired. */
  static async consume(otpId: string): Promise<boolean> {
    const { data, error } = await getSupabaseServerClient().rpc("otp_consume", {
      p_otp_id: otpId,
    });
    return !error && data === true;
  }
}
