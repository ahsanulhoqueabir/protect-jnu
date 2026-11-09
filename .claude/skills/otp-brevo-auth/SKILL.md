---
name: otp-brevo-auth
description: Use when implementing or modifying registration, OTP, login, sessions, password reset, or any email sending (Brevo) in web/ or the Flutter auth screens.
---

# OTP + Brevo + Custom Auth Rules

Fixed by PRD 5.1/7.4 and decisions D-001 (amended)/D-027: Supabase Auth is only the identity/password store; OTP, Brevo, gating and reset are our code. Never let Supabase send an email; verify behavior first (D-032).
- Domain `@jnu.ac.bd` enforced on the **server** (plus UI + DB constraint). Normalize email (trim, lowercase) first.
- OTP: 6 digits, CSPRNG, TTL 10 min, single use, max 5 attempts, 60 s resend cooldown, default max 3 sends/15 min/email (configurable), new OTP supersedes old (same email + purpose), server-time expiry, store only a hash, constant-time compare.
- Never log or return OTP, reset tokens, hashes, API keys, raw Brevo responses. Error messages are generic where needed.
- Emails only via Brevo Transactional API from server code; Flutter never calls Brevo; no Supabase SMTP/Auth email.
- If Brevo fails: return an error, do NOT mark sent, do not relax OTP rules.
- Unverified accounts get no session and no protected data access.
- Admin APIs: authenticate + check `role=admin` on every request.

Delegated decisions apply (docs/03): Supabase-issued JWTs for RLS (D-004), secure token storage (D-005/D-033), reset via emailed OTP (D-016), password policy (D-015), Postgres rate-limit table (D-019). Still to verify before coding: that Supabase Auth user creation/sign-in sends no Supabase email and sign-in can be blocked until our OTP verifies (D-032); if it cannot, STOP and ask.

Verify Brevo API details against current official docs before coding; document endpoints in `docs/api-contract.md` before implementing.
