---
name: clarify-before-assuming
description: Use whenever a requirement, library, schema field, endpoint, limit, UX behavior, or architecture choice is not explicitly specified in docs/PRD.md, docs/, or a user answer. Forces asking the user instead of guessing.
---

# Clarify Before Assuming

1. Search order for the answer: `docs/PRD.md` → `docs/03-technical-decisions.md` → `docs/07-open-questions.md` → current phase file → `PROGRESS.md` Decisions log.
2. 'Decided by delegation' items in docs/03 count as decided (user delegated best-practice choices on 2026-11-09) but are revisable on request. If found as **DECIDED**: follow it. If **OPEN/PROPOSED** or absent: do not implement.
3. Ask with AskUserQuestion: 1–4 questions, each self-contained, with 2–4 concrete options and a recommendation when you have one. Batch related questions.
4. After the answer: record it in `docs/03-technical-decisions.md` (move to Decided) and `PROGRESS.md` Decisions log; remove from `07-open-questions.md` or mark Answered.
5. Triggers that ALWAYS require a check: new dependency, new table/column/enum value, new endpoint, numeric limit, error wording, status transitions, anything touching security or PRD non-goals.
6. If external API behavior is uncertain, verify in official docs; if still uncertain, ask. Say plainly what you could not verify.
7. Never fill a gap with "reasonable defaults" silently. A default may be proposed only as an explicit option the user approves.
