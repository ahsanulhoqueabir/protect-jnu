---
name: start-phase
description: Begin work on a numbered implementation phase (0-9). Use when the user says "start phase N" or asks to continue the plan. Loads context, checks prerequisites and open questions before any code.
---

# Start Phase N

1. Read `PROGRESS.md`, `docs/04-implementation-roadmap.md`, `docs/phases/phase-N-*.md`, `docs/03-technical-decisions.md`, `docs/07-open-questions.md`.
2. Verify the previous phase is marked done in PROGRESS **and** user-confirmed. If not, stop and tell the user.
3. List the phase's "Open questions" and any Q-/D- items gating it. Ask the user (skill `clarify-before-assuming`) before step-by-step work.
4. Copy the phase's tasks as checkboxes into PROGRESS.md (set phase status "In progress", date).
5. Work tasks in order. Use `supabase-mcp-workflow` for DB, `otp-brevo-auth` for auth/email, `flutter-conventions` / `nextjs-conventions` for code.
6. Update PROGRESS.md after each task (`update-progress`).
7. When all tasks are done, run `verify-phase`.
8. Do not begin phase N+1 without explicit user go-ahead.
