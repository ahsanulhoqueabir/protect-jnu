---
name: verify-phase
description: Run a phase's validation and completion checklist before declaring it done. Use at the end of every phase.
---

# Verify Phase N

1. Open `docs/phases/phase-N-*.md`; execute every item under "Testing & validation" — actually run commands/tests/MCP queries; do not infer.
2. Check each "Completion criteria" box only with evidence; record evidence in PROGRESS.md.
3. Cross-check requirement IDs in `docs/01-requirements-summary.md` for the phase; confirm each is covered.
4. Security sweep: grep `app/` and `web/src` client code for secrets/keys; confirm no OTP/token in logs; `.env*` not committed.
5. Confirm docs updated: decisions, `docs/api-contract.md`, schema docs, `.env.example`.
6. Summarize to the user: passed / failed / skipped (with reasons). Ask for confirmation to close the phase.
