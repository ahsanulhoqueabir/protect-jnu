import { vi } from "vitest";

/**
 * Replaces the Brevo client in integration tests so NO email is ever sent. Tests read the OTP
 * code from here the way a user would read it from their inbox.
 * Use in a test file:
 *   vi.mock("@/services/email.service", async () => {
 *     const m = await import("./email-mock");
 *     return { EmailService: { sendOtp: m.emailMock.sendOtp } };
 *   });
 */
export type SentOtp = {
  to: string;
  name: string;
  purpose: string;
  code: string;
  ttlMinutes: number;
};

export const sent: SentOtp[] = [];
export const emailMock = { sendOtp: vi.fn() };

/** Delivery succeeds and the message is recorded in `sent`. */
export function emailWorks() {
  sent.length = 0;
  emailMock.sendOtp.mockReset();
  emailMock.sendOtp.mockImplementation(async (p: SentOtp) => {
    sent.push(p);
    return { success: true as const, data: null };
  });
}

/** Delivery fails the way a Brevo outage would. */
export function emailFails() {
  emailMock.sendOtp.mockReset();
  emailMock.sendOtp.mockImplementation(async () => ({
    success: false as const,
    error: "Could not send the email. Try again later.",
    code: "email_delivery_failed",
  }));
}

/** The most recent code "delivered" to this address for this purpose. */
export function lastCode(to: string, purpose: string): string {
  const hit = [...sent].reverse().find((m) => m.to === to && m.purpose === purpose);
  if (!hit) throw new Error(`no ${purpose} email was sent to ${to}`);
  return hit.code;
}
