/** Positive integer from an env var, or the documented default. */
function positiveInt(value: string | undefined, fallback: number): number {
  const n = Number.parseInt(value ?? "", 10);
  return Number.isFinite(n) && n > 0 ? n : fallback;
}

export const sb = {
  url: process.env.NEXT_PUBLIC_SUPABASE_URL!,
  secret: process.env.SUPABASE_SECRET_KEY!,
  publish: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
};

/** Brevo transactional email (server-side only). */
export const brevo = {
  apiKey: process.env.BREVO_API_KEY,
  senderEmail: process.env.BREVO_SENDER_EMAIL,
  senderName: process.env.BREVO_SENDER_NAME,
};

/** OTP rules (PRD 5.1, D-012). Defaults are the PRD values; names per D-048. */
export const otp = {
  /** HMAC key for code hashes (D-047). Never log or return. */
  hashSecret: process.env.OTP_HASH_SECRET,
  ttlSeconds: positiveInt(process.env.OTP_TTL_MINUTES, 10) * 60,
  maxAttempts: positiveInt(process.env.OTP_MAX_ATTEMPTS, 5),
  cooldownSeconds: positiveInt(process.env.OTP_RESEND_COOLDOWN_SECONDS, 60),
  windowSeconds: positiveInt(process.env.OTP_SEND_WINDOW_MINUTES, 15) * 60,
  maxSends: positiveInt(process.env.OTP_MAX_SENDS_PER_WINDOW, 3),
};
