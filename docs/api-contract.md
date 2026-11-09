# API Contract — Auth (Phase 2)

Status: **APPROVED by the user 2026-11-09, all proposals R1-R7 as written** (shapes and error codes). Base path `/api/auth`. HTTPS only. JSON in, JSON out. Implemented as Next.js route handlers in `web/app/api/auth/*`; Flutter and the admin dashboard are the clients. Basis: PRD 5.1, 7.4; decisions D-004, D-005, D-012, D-015, D-016, D-043, D-047–D-049.

## 1. Conventions
**Envelope** (template `ok()`/`fail()`): success `{ "success": true, "data": {...}, "message"?: "..." }`; failure `{ "success": false, "error": "<human message>", "code": "<machine_code>", "data"?: {...} }`. `code` is a **proposed addition** to the template envelope so clients can branch without parsing text.

**Auth for protected routes:** `Authorization: Bearer <access_token>` where the token is the Supabase-issued access token (D-004). The server validates it with Supabase Auth on every request; there is no custom JWT.

**Session object** returned by login/refresh: `{ "access_token": string, "refresh_token": string, "expires_in": number, "expires_at": number }` (seconds; Supabase default access-token lifetime about 1 hour, D-005). Flutter stores both in encrypted secure storage; never in shared preferences or logs.

**Normalisation (server, before anything else):** `email` trimmed + lowercased; `student_id` trimmed + uppercased (the DB trigger does not normalise, see 0006 note).

**Validation (shared Zod schemas in `web/schema/auth.schema.ts`, same rules as Flutter):**
| Field | Rule |
|---|---|
| email | valid email AND `@jnu.ac.bd` or a subdomain such as `@cse.jnu.ac.bd` after normalisation (D-052; checked on the server for every route that takes an email) |
| student_id | `^B[0-9]{9}$` (D-020) |
| full_name | trimmed, 1–100 chars |
| password / new_password | 8–64 chars, no composition rules (D-015); rejected if on a small built-in list of very common passwords |
| code | exactly 6 digits |
| purpose | `email_verification` or `password_reset` |

**Statuses:** 200 ok · 201 created · 400 bad request · 401 unauthenticated · 403 forbidden · 409 conflict · 422 validation · 429 throttled · 502 email provider failure · 500 unexpected.

**Never returned or logged:** OTP codes, code hashes, reset tokens, passwords, API keys, raw Brevo responses, Supabase error bodies.

## 2. Endpoints

### POST `/register` (public)
Body `{ full_name, student_id, email, password }`.
Creates the Supabase Auth user **unconfirmed** (`email_confirm` not set, D-043; profile created by the DB trigger), then issues and emails a verification OTP. No session is returned.
- 201 `data: { email, resend_available_in: 60 }`
- 409 `email_taken` (verified account exists) · 409 `student_id_taken`
- Existing **unverified** account with the same email: the stored password is **never replaced** (a second registration must not be able to set the password of an account whose owner then verifies it). A fresh OTP is issued (subject to throttling) and 201 is returned. The user who forgot the original password uses `/forgot-password`.
- 422 `validation_failed` (incl. a non-university address → `code: "email_domain_not_allowed"`) · 429 (see 3) · 502 `email_delivery_failed`

### POST `/verify-otp` (public)
Body `{ email, code, purpose: "email_verification" }`.
On success: marks the OTP used, calls Supabase `email_confirm: true`, sets `profiles.email_verified_at`. **No session is returned** (proposal R1): the client then calls `/login` with the password it still holds.
- 200 `data: { verified: true }`
- 400 `otp_invalid` (`data: { attempts_remaining }`) · 400 `otp_expired` · 400 `otp_attempts_exceeded` (a new code must be requested) · 400 `otp_not_found` (none issued, already used or superseded)

### POST `/resend-otp` (public)
Body `{ email, purpose }`. Invalidates the previous live code for the same user and purpose, issues a new one.
- 200 `data: { resend_available_in: 60 }` (same response whether or not the email is registered, for `password_reset`; for `email_verification` only for existing unverified accounts)
- 429 `otp_resend_cooldown` (`data: { retry_after_seconds }`) · 429 `otp_send_limit` (`data: { retry_after_seconds }`) · 502 `email_delivery_failed`

### POST `/login` (public)
Body `{ email, password }`. Student login; also usable by admins (role is in the response).
- 200 `data: { user: { id, full_name, student_id, email, phone, role }, session }`
- 401 `invalid_credentials` (same message for unknown email and wrong password)
- 403 `email_not_verified` (no session; the client sends the user to the OTP screen and may call `/resend-otp`)

### POST `/admin/login` (public)
Same body and response as `/login`, but returns 403 `not_admin` (and no session) unless `profiles.role = 'admin'` (proposal R3: separate route so the dashboard can never obtain a student session).

### POST `/refresh` (public, needs the refresh token)
Body `{ refresh_token }`. Supabase rotates the refresh token.
- 200 `data: { session }` · 401 `invalid_refresh_token`

### POST `/logout` (Bearer)
Revokes the current session on the server.
- 200 `data: { logged_out: true }` · 401

### GET `/me` (Bearer)
- 200 `data: { user: { id, full_name, student_id, email, phone, role } }` · 401 `invalid_token` · 403 `email_not_verified`

### POST `/forgot-password` (public)
Body `{ email }`. Always answers the same, so it cannot be used to discover accounts. If an account exists (verified or not), a `password_reset` OTP is issued and emailed (D-016). Proving control of the inbox is what both flows need, so this is also the recovery path for an unverified account.
- 200 `data: { resend_available_in: 60 }` · 429 throttling · 502 `email_delivery_failed`

### POST `/reset-password` (public)
Body `{ email, code, new_password }`. Verifies the `password_reset` OTP with the same rules as `/verify-otp`, sets the new password, marks the email verified if it was not (the OTP proved ownership), and **revokes all existing sessions** of the user (D-016).
- 200 `data: { password_reset: true }` · 400 OTP errors as in `/verify-otp` · 422 weak password

## 3. OTP and throttling rules (D-012, configurable via `OTP_*` env, D-048)
6 digits from a CSPRNG (`crypto.randomInt`); stored as HMAC-SHA256 with `OTP_HASH_SECRET` over `userId + purpose + code` (D-047); expires 10 min after server time; single use; at most 5 wrong attempts then the code is dead; a new code supersedes the old one for the same user and purpose; comparison is constant-time. Sends: at least 60 s between sends and at most 3 sends per 15 min per email and purpose (table `otp_send_events`). If Brevo fails, the response is 502, the code is invalidated, and the failed send does **not** count toward the limit.

## 4. Email (Brevo) — verified against official docs 2026-11-09
`POST https://api.brevo.com/v3/smtp/email`, header `api-key: <BREVO_API_KEY>`, `content-type: application/json`, `accept: application/json`. Body `{ sender: { name, email }, to: [{ email, name }], subject, htmlContent }`; success is 201 with a `messageId`. The sender must be registered and verified in Brevo. HTML only (D-049). 429 means Brevo rate limiting (headers `x-sib-ratelimit-*`) and maps to our 502. Sources: developers.brevo.com/reference/sendtransacemail, /docs/send-a-transactional-email, /docs/api-limits, /docs/limit-headers. Not stated in the docs and therefore handled generically: the error body for an unverified sender, and any size limit on `htmlContent`.

## 5. Proposals (all approved 2026-11-09)
| # | Proposal | Alternative |
|---|---|---|
| R1 | `/verify-otp` returns `verified: true` and **no session**; the app then calls `/login` | Server mints a session after verify (needs the password or a magic-link trick; more moving parts) |
| R2 | Add top-level `code` to the error envelope | Keep the template envelope and put codes in `data` |
| R3 | Separate `/admin/login` that checks `role = 'admin'` | One `/login` and the dashboard checks `role` itself (weaker) |
| R4 | Phase 2 returns tokens in JSON only. Web httpOnly cookies (D-033) are added with the admin dashboard in Phase 3 | Build cookie support now |
| R5 | Registering with an already-verified email returns 409 `email_taken` (reveals that the email is registered; university emails are not secret) | Generic success and silent no-op (hides it, confuses real users) |
| R6 | Registering again with an unverified email keeps the original password, resends an OTP, and never replaces the password (replacing it would let an attacker set the password of someone else's pending account). Recovery via `/forgot-password`, which also verifies the email | Reject with 409 `email_taken` |
| R7 | OTP wrong-code errors distinguish invalid / expired / attempts exceeded | One generic `otp_invalid` for all |

## 6. Admin alerts API (Phase 4, D-059..D-063)
Auth: `withAdmin`. Accepts `Authorization: Bearer <access_token>` or, when no header is sent, the dashboard's httpOnly `pj_access` cookie (SameSite=Strict). Role `admin` is re-read on every request. Lists are 20 per page, newest first (D-024). Students create their alert directly through Supabase RLS (D-061); there is no student alert endpoint.

| Route | Purpose | Success | Errors |
|---|---|---|---|
| GET `/api/admin/alerts?status=open\|all\|active\|acknowledged\|resolved\|cancelled&page=1` | list (`open` = active + acknowledged, default) | 200 `data: { items: [{ id, status, started_at, acknowledged_at, resolved_at, cancelled_at, student: { full_name, student_id } }], page, page_size, total }` | 401, 403 `not_admin`, 422 `validation_failed` |
| GET `/api/admin/alerts/:id` | detail | 200 `data: { ..., student: { full_name, student_id, phone, email }, contacts: [{ id, name, phone }], acknowledged_by_email, resolved_by_email, first_latitude, first_longitude }` | 404 `alert_not_found` |
| GET `/api/admin/alerts/:id/locations` | newest 20 location points, oldest first | 200 `data: [{ id, latitude, longitude, accuracy, recorded_at }]` | 404 `alert_not_found` |
| PATCH `/api/admin/alerts/:id/status` body `{ action: "acknowledge" \| "resolve" }` | transition | 200 `data: { id, status }` | 404 `alert_not_found`, 409 `invalid_transition` (`data.current_status`), 422 |
| GET `/api/admin/users?page=1` | basic users list | 200 `data: { items: [{ id, full_name, student_id, phone, role, created_at, email, verified }], page, page_size, total }` | 401, 403 |

### 6b. Admin chat API (Phase 6, D-072)
Same auth as above. The service calls Supabase AS the admin (their access token), so RLS and `chat_conversations()` apply (migration 0016). Students use RLS directly from the phone (no student chat endpoint).

| Route | Purpose | Success | Errors |
|---|---|---|---|
| GET `/api/admin/conversations` | last message + unread count per alert, newest first | 200 `data: [{ alert_id, last_body, last_sent_at, last_sender_id, unread_count, student: { full_name, student_id }, status }]` | 401, 403 |
| GET `/api/admin/alerts/:id/messages[?since=ISO]` | thread, oldest first, newest 200 max; `since` = only newer (reconnect) | 200 `data: [{ id, sender_id, body, sent_at, read_at, sender_name, from_student }]` | 404 `alert_not_found`, 422 |
| POST `/api/admin/alerts/:id/messages` body `{ body }` (1-1000 chars after trim) | send | 201 `data: { id, sent_at }` | 409 `chat_closed` (alert resolved/cancelled or missing), 422 |
| PATCH `/api/admin/alerts/:id/messages` | mark the student's messages read (any admin clears it, D-021) | 200 `data: { updated }` | 404 |

Rules: a thread accepts messages only while the alert is active or acknowledged; history stays readable. A user can mark only the other party's messages read, and only `read_at`.

Rules: only `active -> acknowledged` and `acknowledged -> resolved`. The update matches only while the row is in the expected state, so concurrent admins cannot both win and a resolved alert cannot be reopened. The acting admin id is stored in `acknowledged_by` / `resolved_by` (0013); timestamps come from the DB trigger.
