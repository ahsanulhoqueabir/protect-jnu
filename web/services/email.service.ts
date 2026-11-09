import { brevo } from "@/config/env.config";
import { renderOtpEmail } from "@/lib/email/otp-email";
import { failure, success } from "@/lib/service-result";
import type { OtpPurpose } from "@/lib/otp";
import type { ServiceResult } from "@/types/generic.types";

/**
 * Email delivery through the Brevo Transactional API (PRD 7.4, D-010).
 * Verified against developers.brevo.com on 2026-11-09: POST https://api.brevo.com/v3/smtp/email,
 * header `api-key`, body { sender, to, subject, htmlContent }, success is 201.
 * Never logs the code, the API key, or the provider's response body.
 */
const BREVO_SEND_URL = "https://api.brevo.com/v3/smtp/email";
const REQUEST_TIMEOUT_MS = 10_000;

export class EmailService {
  /** Send an OTP email. On any failure nothing is considered sent. */
  static async sendOtp(params: {
    to: string;
    name: string;
    purpose: OtpPurpose;
    code: string;
    ttlMinutes: number;
  }): Promise<ServiceResult<null>> {
    const { apiKey, senderEmail, senderName } = brevo;
    if (!apiKey || !senderEmail || !senderName) {
      console.error("Email send skipped: Brevo is not configured");
      return failure("Could not send the email. Try again later.", {
        code: "email_delivery_failed",
      });
    }

    try {
      const { subject, html } = renderOtpEmail({
        purpose: params.purpose,
        name: params.name,
        code: params.code,
        ttlMinutes: params.ttlMinutes,
      });

      const response = await fetch(BREVO_SEND_URL, {
        method: "POST",
        headers: {
          "api-key": apiKey,
          "content-type": "application/json",
          accept: "application/json",
        },
        body: JSON.stringify({
          sender: { name: senderName, email: senderEmail },
          to: [{ email: params.to }],
          subject,
          htmlContent: html,
        }),
        signal: AbortSignal.timeout(REQUEST_TIMEOUT_MS),
      });

      if (response.status !== 201) {
        // Status only. The body can contain provider internals, so it is never logged or returned.
        console.error("Brevo send failed", { status: response.status });
        return failure("Could not send the email. Try again later.", {
          code: "email_delivery_failed",
        });
      }
      return success(null);
    } catch {
      console.error("Brevo send failed", { status: "network_or_timeout" });
      return failure("Could not send the email. Try again later.", {
        code: "email_delivery_failed",
      });
    }
  }
}
