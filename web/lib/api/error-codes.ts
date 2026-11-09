/**
 * Machine-readable error codes and their HTTP status (docs/api-contract.md, approved D-050).
 * One table: routes map a service failure's `code` to a status through `statusForCode`.
 */
export const ERROR_STATUS = {
  validation_failed: 422,
  email_domain_not_allowed: 422,
  weak_password: 422,
  email_taken: 409,
  student_id_taken: 409,
  otp_invalid: 400,
  otp_expired: 400,
  otp_attempts_exceeded: 400,
  otp_not_found: 400,
  otp_resend_cooldown: 429,
  otp_send_limit: 429,
  email_delivery_failed: 502,
  invalid_credentials: 401,
  invalid_refresh_token: 401,
  invalid_token: 401,
  email_not_verified: 403,
  not_admin: 403,
  alert_not_found: 404,
  invalid_transition: 409,
  internal_error: 500,
} as const;

export type ErrorCode = keyof typeof ERROR_STATUS;

export function statusForCode(code: string | undefined): number {
  if (code && code in ERROR_STATUS) {
    return ERROR_STATUS[code as ErrorCode];
  }
  return ERROR_STATUS.internal_error;
}
