# Phase 1 — RLS Test Matrix

Run: 2026-11-09, dev project `bthjjlpylvauiolwrdfn`, after migrations 0006–0010.
Script: [`web/scripts/phase1-rls-matrix.sql`](../../web/scripts/phase1-rls-matrix.sql) (re-runnable).
Result: **70 cases, 70 passed, 0 failed.**

## Method and limits
- Three throwaway users (student A, student B, admin) are inserted directly into `auth.users` inside one transaction, so no Auth API call and no email can occur. The `on_auth_user_created` trigger creates their profiles; the admin is promoted by SQL.
- Each case runs under `set local role authenticated` (or `anon`) with `request.jwt.claims` set to the user's `sub`, so `auth.uid()`, grants, column privileges, RLS policies and triggers all apply as they do through PostgREST.
- The script ends with a deliberate `RAISE EXCEPTION`, rolling the whole transaction back. Verified afterwards: no leftover test users; profiles 3, auth users 3.
- NOT covered: real JWTs through PostgREST, and Realtime websocket delivery (that a student's subscription receives only their own rows). Realtime policy behavior rests on the same RLS policies tested here; the websocket test belongs with the first real client in Phase 4.

## Cases (all passed)
| Area | Cases | What is proven |
|---|---|---|
| profiles | P1–P12 | A reads only own row; admin reads all; anon denied; A may edit own `full_name` and valid `phone`; A cannot edit `student_id`, `role`, `email_verified_at`, cannot touch B, cannot delete; invalid phone rejected |
| emergency_contacts | C1–C10 | 3 contacts allowed, 4th rejected; cannot add for B; B cannot read or delete A's; admin reads A's; own delete works; bad phone rejected |
| alerts | A1–A13 (+A7b, A10b) | A raises only own `active` alerts (no status column insert, none for B); A cannot read or change B's alerts; A can cancel own alert but forged `acknowledged_at`/`resolved_at` are pinned and `cancelled_at` is set by trigger; A cannot acknowledge or edit coordinates without cancelling; admin acknowledges (`acknowledged_at` set by trigger); nobody can delete from a client; anon denied |
| locations | L1–L8 | A adds points only to own open alert (not B's, not a cancelled one, not as B); B cannot read A's; admin can; no client update or delete |
| messages | M1–M14 | A posts only as self on own open alert (not on cancelled, no forged `read_at`, not as B); B cannot post or read on A's thread; admin posts as self only (spoofing A rejected); `body` cannot be edited; only `read_at` updatable; no deletes |
| OTP tables | O1–O5 | `otp_codes` and `otp_send_events` denied to anon, students and admins (service role only) |
| functions | F1–F3 | anon cannot call `is_admin()`; signed-in users can; `handle_new_user()` is not callable through the API |
| constraints | D1–D3 | non-`@jnu.ac.bd` email rejected; bad student ID rejected; duplicate student ID rejected |

## Known limits found while testing
- The 3 test profiles created before 2026-11-09 still have non-conforming student IDs (`profiles_student_id_format` is `NOT VALID`), so those rows cannot be updated until fixed. The matrix uses fresh users.
- `handle_new_user()` does not trim or uppercase the student ID (user declined that change); Phase 2 server code must normalise it before calling Auth.
