# Architecture

## Components
```
 Flutter app (app/)  ──HTTPS──►  Next.js (web/)  ──service role──►  Supabase Postgres
   │   │                          │  ├ Admin UI (pages)                 ▲   ▲
   │   │                          │  └ /api/* trusted server routes     │   │
   │   │                          │      ├ OTP / reset / login / refresh│   │
   │   │                          │      └ Brevo Transactional API      │   │
   │   └── supabase SDK (RLS, Realtime) using app-issued JWT ───────────┘   │
   └── Admin browser: supabase-js (RLS, Realtime) using app-issued JWT ─────┘
 Dev only: Claude agent ──Supabase MCP──► Supabase project (schema/migrations/verification)
```

## Responsibilities
| Concern | Where | Notes |
|---|---|---|
| Registration, OTP issue/verify, login, refresh, password reset | `web/` API routes + `services/` | Supabase Auth identity + our OTP/Brevo (D-027). Server-only secrets |
| Email sending | `web/` server → Brevo | Flutter never calls Brevo |
| Domain enforcement `@jnu.ac.bd` | UI + server (+ DB constraint, see Phase 1) | Server is authoritative |
| Data access from clients | Supabase SDK with RLS | Requires client JWT that Postgres RLS can read — **mechanism OPEN (D-004)** |
| Realtime (alerts, locations, messages) | Supabase Realtime | Subject to RLS |
| Map | `web/` Leaflet + OSM tiles | Attribution required |
| Location service, camera, local media | `app/` | Android foreground service; local files only |
| Reports | `web/` queries derived from `alerts` | No duplicate tracking tables |

## Repo layout (target)
```
protect-jnu/
├─ CLAUDE.md  PROGRESS.md
├─ .claude/skills/...
├─ docs/                      (this folder)
├─ app/                       Flutter
│   └─ lib/
│       ├─ core/              config, http client, theme, errors, router
│       ├─ features/<feature>/{data,domain,presentation}
│       └─ main.dart
│   features: auth, emergency_contacts, sos, alert, location, chat, media, profile
│   (base = template, D-025: lib/{app,core,shared,features}; sample features to be removed)
└─ web/                       Next.js (template nextjs-supabase, D-031)
    ├─ app/                   pages + app/api/**/route.ts (thin routes)
    ├─ services/              ALL Supabase access, return ServiceResult
    ├─ schema/                Zod schemas (singular)
    ├─ schemas/               SQL migrations NNNN_*.sql (plural)
    ├─ types/  lib/  store/  config/  components/
    └─ docs/nextjs/16.4.3/    committed Next docs (read first)
```
`app/` and `web/` layouts come from the templates (D-025, D-030). Supabase access lives only in `services/` and `lib/api/supabase.ts`.

## Key flows
**Registration:** Flutter → `POST /api/auth/register` (server validates domain, creates unverified credentials) → server generates OTP, stores hash, sends via Brevo → `POST /api/auth/verify-otp` → server marks verified → session issued only now.
**Password reset:** request → server issues single-use expiring token/OTP (mechanism OPEN, Q-006) → Brevo → confirm → new password.
**SOS:** hold 2s → 5s cancel window → insert `alerts(status=active)` + first location → Realtime → dashboard alert list + sound.
**Location:** foreground service posts points every 5–10s (queue offline) → `locations` → dashboard map via Realtime.
**Chat:** `messages` rows per alert; Realtime both ways; `read_at` drives unread counts.
**Reports:** aggregate over `alerts` by status timestamps.

## Security boundaries
- Service-role key, JWT signing secret, Brevo key: server env only.
- OTP/reset tables: RLS enabled with no client policies; server-only.
- Admin API routes verify admin role on every request.
