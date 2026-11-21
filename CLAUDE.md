# Protect JnU'ins — Project Instructions for AI Agents

Student safety system for Jagannath University. Two apps, one Supabase backend.

| Dir | What | Stack |
|---|---|---|
| `app/` | Student Android app | Flutter, Riverpod, go_router, feature-first |
| `web/` | Admin dashboard **and** trusted server API (OTP, Brevo, auth) | Next.js App Router, TypeScript, Tailwind, shadcn/ui |
| `docs/` | All documentation | Markdown |

Source of truth for requirements: [docs/PRD.md](docs/PRD.md). Do not edit it unless the user asks.

## Read first, every session
1. [PROGRESS.md](PROGRESS.md) — current phase, blockers, pending decisions.
2. [docs/README.md](docs/README.md) — documentation index.
3. The current phase file in `docs/phases/`.
4. [docs/03-technical-decisions.md](docs/03-technical-decisions.md) — decisions made and still open.

## Non-negotiable rules
1. **No undocumented assumptions.** If something is not in the PRD, `docs/`, or an explicit user answer, it is NOT decided. Stop and ask the user (use AskUserQuestion). Never choose a library, schema column, endpoint shape, limit, or UX behavior on your own when it is unspecified. See skill `clarify-before-assuming`.
2. **No invented facts about external tools.** For Supabase, Flutter packages, Next.js, Brevo, Leaflet: verify against current official docs or the Supabase MCP before using an API. If you cannot verify, say so and ask. Do not guess package names, versions, or method signatures.
3. **One phase at a time, in order.** Do not start phase N+1 until phase N's completion criteria are met and the user confirmed. Do not implement features from later phases early.
4. **Record every decision.** New decision → add to `docs/03-technical-decisions.md` and `PROGRESS.md` Decisions log in the same change.
5. **Keep PROGRESS.md current** while working (skill `update-progress`). Never mark a task done without evidence (test output, MCP query result, manual check noted).
6. **Database changes only via Supabase MCP migrations**, and every migration is also saved as `web/schemas/NNNN_*.sql` (append-only). See `docs/05-supabase-mcp-workflow.md`.
7. **Secrets**: Brevo key, Supabase service-role key, JWT secret, MCP tokens exist only in server-side env / developer secret storage. Never in `app/`, client bundles, `NEXT_PUBLIC_*`, logs, or git.
8. **Never log or return** OTPs, reset tokens, password hashes, API keys, or raw provider responses.
9. **Do not use** Supabase SMTP / Supabase Auth email / Google Maps / cloud media storage / iOS / SMS (PRD non-goals). Push: only what D-081 allows (local notifications; FCM pending B-022).
10. Report faithfully: failing tests or skipped steps must be stated, not hidden.

## Locked decisions (user-confirmed, 2026-11-09)
- Auth (D-001 amended by D-027): Supabase Auth is the identity/password store (template pattern); OTP, Brevo email, verified-gating and password reset are our server code in `web/`. NO Supabase-sent emails. JWT/RLS mechanism (D-004) and email-gating (D-032) still open.
- RLS policies + client Realtime per PRD 7.6 (D-028).
- Trusted server code = **Next.js API routes in `web/`**; Flutter calls them over HTTPS.
- Web: TypeScript + Tailwind + shadcn/ui, App Router. `web/` is a one-time copy of template `nextjs-supabase` (D-031): follow `web/CLAUDE.md`, `web/AGENTS.md`, `web/.claude/rules/*` and read `web/docs/nextjs/16.4.3/` before Next.js code (Next 16: `proxy.ts` replaces `middleware.ts`). Layout per D-030; migrations in `web/schemas/NNNN_*.sql` applied via MCP (D-029). Where template rules conflict with this file or the PRD, stop and ask. The template rule 'server-only, no RLS policies' is overridden by D-028.
- Flutter: Riverpod + go_router, feature-first folders. `app/` is based on the template https://github.com/ahsanulhoqueabir/flutter (D-025): follow `app/CLAUDE.md` and `app/.claude/rules/` for Flutter code style; if they conflict with this file, this file wins. Template cleanup (rename, remove sample features/platforms) is pending user answers Q-015–Q-017 — do not do it unasked.

## Delegated decisions
On 2026-11-09 the user said "follow the recommended and best practices". Resulting choices are in `docs/03-technical-decisions.md` under *Decided by delegation*: treat them as decided but revisable. Anything NOT listed there or in the PRD still requires asking. Items marked (verify) must be checked against current docs; if the check contradicts the choice, stop and ask.

## Skills (in `.claude/skills/`)
`clarify-before-assuming`, `start-phase`, `update-progress`, `verify-phase`, `supabase-mcp-workflow`, `otp-brevo-auth`, `flutter-conventions`, `nextjs-conventions`.

## Workflow per phase
`start-phase` → resolve open questions → implement tasks in order → `verify-phase` → `update-progress` → ask user to confirm before next phase.
