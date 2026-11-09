import type { OtpPurpose } from "@/lib/otp";

/**
 * OTP / reset email, rendered from the design approved in
 * docs/email-previews/otp-email.html (D-049). HTML only: Brevo accepts one body type per request.
 * Inline CSS and table layout so it renders in Gmail, Outlook and phones.
 */

const APP_NAME = "Protect JnU'ins";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

type Copy = {
  subject: string;
  heading: string;
  intro: (name: string) => string;
  footer: string;
};

const COPY: Record<OtpPurpose, Copy> = {
  email_verification: {
    subject: `Your ${APP_NAME} verification code`,
    heading: "Verify your university email",
    intro: (name) =>
      `Hi ${name}, use this code to finish creating your ${APP_NAME} account.`,
    footer:
      "Didn't request this? You can safely ignore this email. No account is activated without the code.",
  },
  password_reset: {
    subject: `Reset your ${APP_NAME} password`,
    heading: "Reset your password",
    intro: (name) =>
      `Hi ${name}, we received a request to reset the password for your ${APP_NAME} account. Enter this code to choose a new one.`,
    footer:
      "Didn't request a password reset? Ignore this email and your password stays the same. If this keeps happening, contact the project team.",
  },
};

export type RenderedEmail = { subject: string; html: string };

/** `code` must be exactly 6 digits; `name` is escaped before it is placed in the markup. */
export function renderOtpEmail(params: {
  purpose: OtpPurpose;
  name: string;
  code: string;
  ttlMinutes: number;
}): RenderedEmail {
  const copy = COPY[params.purpose];
  if (!/^[0-9]{6}$/.test(params.code)) {
    throw new Error("OTP code must be 6 digits");
  }
  const name = escapeHtml(params.name.trim() || "there");
  const minutes = String(Math.max(1, Math.round(params.ttlMinutes)));

  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(copy.subject)}</title>
</head>
<body style="margin:0;padding:24px 12px;background:#e9edf2;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#e9edf2;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:600px;background:#ffffff;border-radius:8px;overflow:hidden;border:1px solid #d5dce5;">
<tr><td style="background:#1f3a5f;padding:24px 32px;">
<div style="font-family:Arial,Helvetica,sans-serif;font-size:20px;font-weight:bold;color:#ffffff;letter-spacing:.2px;">${escapeHtml(APP_NAME)}</div>
<div style="font-family:Arial,Helvetica,sans-serif;font-size:13px;color:#b9c8dc;padding-top:4px;">Student safety for Jagannath University</div>
</td></tr>
<tr><td style="padding:32px 32px 8px;font-family:Arial,Helvetica,sans-serif;color:#1a2330;">
<h1 style="margin:0 0 12px;font-size:22px;line-height:1.3;color:#1a2330;">${escapeHtml(copy.heading)}</h1>
<p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#33415a;">${copy.intro(name)}</p>
</td></tr>
<tr><td align="center" style="padding:0 32px;">
<div style="display:inline-block;background:#f1f5fa;border:1px solid #d5dce5;border-radius:8px;padding:16px 28px;font-family:'Courier New',Courier,monospace;font-size:34px;font-weight:bold;letter-spacing:10px;color:#1f3a5f;">${params.code}</div>
</td></tr>
<tr><td style="padding:20px 32px 8px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.6;color:#33415a;">
<p style="margin:0 0 12px;">This code expires in <strong>${minutes} minutes</strong> and can be used once.</p>
<p style="margin:0;">Never share this code with anyone. The ${escapeHtml(APP_NAME)} team will never ask you for it.</p>
</td></tr>
<tr><td style="padding:20px 32px 32px;">
<div style="border-top:1px solid #e3e8ef;padding-top:16px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.6;color:#6b7a8f;">
${escapeHtml(copy.footer)}<br>
This is an automated message, please do not reply.
</div>
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;

  return { subject: copy.subject, html };
}
