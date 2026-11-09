---
name: flutter-conventions
description: Use when writing or modifying code in app/ (Flutter Android student app).
---

# Flutter Conventions (app/)

- `app/` comes from a template (D-025): read `app/CLAUDE.md`, `app/.claude/rules/*`, `app/docs/` first. Follow its data flow (Widget → provider → Repository → ApiClient/Dio), manual Riverpod providers (no codegen), `AppLogger` not `print`, `Env` for dart-defines, validators in `core/forms`. `features/posts` is the reference feature; copy its shape.
- Android only; min Android 8.0 (API 26). No iOS work.
- Riverpod for state, go_router for navigation with guards (unauthenticated → login; unverified → OTP; no emergency contacts → setup). Feature-first: `lib/features/<name>/{data,domain,presentation}`; shared code in `lib/core`.
- API client implements `docs/api-contract.md` exactly; no undocumented endpoints.
- No secrets in code/assets. Config via build-time values; only public Supabase URL/anon key if D-004 approves them.
- Tokens in secure storage, not plain preferences.
- Location only after SOS; foreground service only while the alert is active; stop on resolve/cancel.
- Media stays on device; never upload.
- Handle permission denied/permanently denied states explicitly.
- Add a dependency only after confirming with the user (D-023) and verifying the current package version/compat via pub.dev docs. Record it in the phase doc and PROGRESS.
- Run `flutter analyze` and tests before marking tasks done.
