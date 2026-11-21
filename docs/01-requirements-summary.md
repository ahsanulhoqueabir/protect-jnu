# Requirements Summary (traceable to PRD)

IDs are used in phase docs and PROGRESS. "PRD §" = section in [PRD.md](PRD.md).

## Functional
| ID | Requirement | PRD § | Priority | Phase |
|---|---|---|---|---|
| FR-AUTH-1 | Register with name, student ID, university email, password | 5.1 | P0 | 3 |
| FR-AUTH-2 | Only `@jnu.ac.bd` emails or a subdomain of it (`@cse.jnu.ac.bd`, D-052); validated in UI and on server | 5.1 | P0 | 1,2,3 |
| FR-AUTH-3 | Email ownership verified by 6-digit OTP via Brevo (no link) | 5.1 | P0 | 2,3 |
| FR-AUTH-4 | OTP: CSPRNG, 10-min TTL, single use, 5 attempts, hashed storage, never logged/returned | 5.1 | P0 | 2 |
| FR-AUTH-5 | Resend: 60s cooldown; default max 3 sends / 15 min / email (configurable); new OTP invalidates older | 5.1 | P0 | 2 |
| FR-AUTH-6 | UI states: sent, invalid, expired, verified, rate-limited; resend action | 5.1 | P0 | 3 |
| FR-AUTH-7 | Unverified user has no protected access/session | 5.1 | P0 | 1,2,3 |
| FR-AUTH-8 | Login, logout, session persistence | 5.1 | P0 | 3 |
| FR-AUTH-9 | Forgot/reset password via Brevo; server-side single-use expiring tokens | 5.1 | P0 | 2,3 |
| FR-AUTH-10 | Student adds 2–3 emergency contacts after first login; admins can view | 5.1 | P0 | 3 |
| FR-AUTH-11 | Admins provisioned by team; dashboard rejects non-admin; no public admin signup | 4, 5.1 | P0 | 1,3 |
| FR-SOS-1 | Home SOS button: hold 2s, then 5s cancel window | 5.2 | P0 | 4 |
| FR-SOS-2 | Alert created with student details + initial location, status `active` | 5.2 | P0 | 4 |
| FR-SOS-3 | Dashboard shows new alerts immediately with audible/visual notification | 5.2 | P0 | 4 |
| FR-SOS-4 | Admin sets `acknowledged` then `resolved`; student sees status | 5.2 | P0 | 4 |
| FR-LOC-1 | After SOS, send GPS every 5–10s via Android foreground service until resolved/cancelled | 5.3 | P0 | 5 |
| FR-LOC-2 | Dashboard map: moving marker, short trail, last-update time | 5.3, 7.3 | P0 | 5 |
| FR-LOC-3 | Offline queue on phone, flush on reconnect | 5.3 | P0 | 5 |
| FR-LOC-4 | Stop collection when alert ends | 5.3, 8 | P0 | 5 |
| FR-CHAT-1 | One chat thread per alert (student + admin team), Supabase Realtime, timestamps | 5.4 | P0 | 6 |
| FR-CHAT-2 | Dashboard conversation list with unread counts | 5.4 | P0 | 6 |
| FR-MEDIA-1 | In-app photo/video capture incl. during SOS | 5.5 | P1 | 7 |
| FR-MEDIA-2 | Save to local storage; in-app gallery; no cloud upload | 5.5 | P1 | 7 |
| FR-REP-1 | Reports: students supported + alerts handled by month/year | 5.6 | P1 | 8 |
| FR-REP-2 | Supported = admin acknowledged/resolved; count student once per period; alerts counted separately | 5.6 | P1 | 8 |
| FR-REP-3 | Month/year filters, monthly bar chart, CSV export; derived from alerts table | 5.6 | P1 | 8 |

### Added 2026-11-21 (Phase 10, D-078..D-082)
| ID | Requirement | Source | Priority | Phase |
|---|---|---|---|---|
| FR-ADM-1 | Role-based access in the app: `role = 'admin'` gets an Admin tab and admin screens; normal users unchanged; server re-checks the role on every admin call | D-078 | P0 | 10 |
| FR-ADM-2 | Live alerts list with Realtime refresh | D-078 / 5.2 | P0 | 10 |
| FR-ADM-3 | Alert detail: student, emergency contacts, timeline, acknowledge/resolve | D-078 / 5.2 | P0 | 10 |
| FR-ADM-4 | Live map in the app (flutter_map + OSM, trail, attribution) | D-079 / 5.3 | P0 | 10 |
| FR-ADM-5 | Admin chat and conversations with unread counts | D-078 / 5.4 | P0 | 10 |
| FR-ADM-6 | History (filter, paging), users list, reports with chart and CSV share | D-080 / 5.6 | P1 | 10 |
| FR-ADM-7 | Notifications with sound and vibration: new SOS and messages (admins), status changes and admin messages (students); tap opens the screen | D-081 | P1 | 10 |

## Non-functional
| ID | Requirement | PRD § |
|---|---|---|
| NFR-1 | SOS visible on dashboard ≈ ≤3 s on normal mobile network | 8 |
| NFR-2 | HTTPS only; RLS on all relevant tables; authorize every admin request | 8 |
| NFR-3 | Location collected only after SOS; visible only to authorized admins; media stays on phone | 8 |
| NFR-4 | Android 8.0+ incl. low-end devices | 8 |
| NFR-5 | Foreground service for location; stop when alert ends | 8 |
| NFR-6 | Handle Brevo errors/rate limits without bypassing OTP rules; never mark unsent mail as sent | 7.4, 8 |
| NFR-7 | OSM attribution shown; graceful tile outage; no Google Maps | 7.3 |

## Screens
- Flutter: Splash, Sign Up, Verify Email (OTP), Login, Forgot Password, Emergency Contacts Setup, Home (SOS), Active Alert, Chat, Media Gallery & Camera, Profile.
- Web: Admin Login, Forgot Password, Live Alerts, Alert Details (map, student info, contacts, chat), Conversations, Users, Alert History, Reports.

## Non-goals (do NOT build)
iOS; non-university users; guardian SMS; remote push to a closed app (pending B-022; local notifications allowed by D-081); safe-spots map; cloud media upload; separate volunteer/university-admin roles; auto-dispatch of police/ambulance; Google Maps; Supabase SMTP/Auth emails.
