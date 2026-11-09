# Phase 2 — OTP Lifecycle, Brevo & Auth Server API

## Objectives
Trusted server (Next.js routes) implements registration, OTP issue/verify, resend throttling, login, session refresh/logout, and password reset — delivering all emails via Brevo.

## Requirements covered
FR-AUTH-1…5, 7, 9, 11; NFR-6; PRD §5.1, 7.4.

## Prerequisites
Phase 1 complete. Brevo account + verified sender (Q-002). OTP template approved (Q-003). Q-006 (reset mechanism), D-015 (password policy), D-019 (rate-limit storage) answered.

## Components
- Template layering (D-030): `web/schema/*.schema.ts` (Zod), `web/services/{otp,email,auth,rate-limit}.service.ts`, `web/lib/` helpers, routes under `web/app/api/auth/*`
- Existing template `auth.service.ts` and `jwt.helper.ts` are adapted per D-027/D-004/D-032 after user approval
- `docs/api-contract.md`

## Steps
0. Design the OTP (and reset) email per D-037: responsive HTML + plain-text fallback; render a preview to the user for approval; ask for the verified Brevo sender address if not yet given (Q-002).
1. Verify Brevo transactional API request format and auth header against current official docs; record link in api-contract.
2. Env vars (names PROPOSED; confirm): Brevo API key, sender email/name, Supabase URL, service-role key, JWT secret/signing key, OTP config (TTL, attempts, cooldown, window, max sends). Add names to `.env.example`.
3. Draft `docs/api-contract.md` for: register, verify-otp, resend-otp, login, refresh, logout, forgot-password, reset-password. Get user approval of shapes and error codes.
4. Implement OTP: 6-digit via CSPRNG (e.g. Node `crypto.randomInt`), store hash with per-record salt/HMAC (confirm approach), purpose, expiry from server time, attempts=0, used/invalidated flags. New OTP invalidates prior for same email+purpose.
5. Verify: reject expired/used/superseded/attempt-exhausted; increment attempts; constant-time compare; invalidate at 5 attempts; single use.
6. Throttling: 60s cooldown; ≤3 sends/15 min/email, values from config.
7. Brevo client: on non-2xx or network error → return error, do not mark sent, no OTP in logs; map provider rate-limit to controlled response.
8. Register route: server-side `@jnu.ac.bd` check (normalize), create unverified account, send OTP. Unverified accounts get no session.
9. Verify route: on success mark verified, then issue session.
10. Login/refresh/logout per D-005; admin login requires `role=admin`.
11. Password reset request/confirm: single-use, expiring, hashed token; revoke sessions after reset (confirm).
12. Admin-route guard helper used by all admin APIs.
13. Unit + integration tests; manual real-email test to a real `@jnu.ac.bd` inbox (ask user for test inbox).

## Dependencies / integrations
Brevo Transactional API, Supabase (service role, server-only), hashing library (D-003), validation library (PROPOSED zod; confirm).

## Database / API
Tables from Phase 1 (credentials, otp, reset, sessions, rate limits). Endpoints per api-contract.

## Testing & validation
Automated: OTP expiry (10 min), reuse, 6th attempt rejected after 5, resend <60s rejected, 4th send in 15 min rejected, new OTP supersedes old, non-`@jnu.ac.bd` rejected server-side, unverified login denied, Brevo failure → not marked sent, logs contain no secrets (grep test output).
Manual: real email delivered; reset flow end to end.
MCP: confirm DB rows hold hashes only.

## Completion criteria
- [ ] api-contract approved and implemented
- [ ] All OTP rules tested & passing
- [ ] Real Brevo email delivered
- [ ] No Supabase email used (verify Supabase Auth email/SMTP unused)
- [ ] Secrets only server-side (grep client bundles/`app/`)
- [ ] PROGRESS updated; user confirmed

## Out of scope
Any UI.
