---
name: update-progress
description: Update PROGRESS.md (tasks, blockers, decisions, change log). Use after completing or starting any task, hitting a blocker, or recording a decision.
---

# Update PROGRESS.md

- Set the "Last updated" date (use today's actual date).
- Task states: `[ ]` pending, `[~]` in progress, `[x]` done, `[!]` blocked. Mark `[x]` only with evidence appended inline (command + result, MCP query result, or manual test note).
- Blockers: add row with ID (B-NNN), what, who must act, phases affected. Remove (move to change log) when resolved.
- Decisions: add row (date, D-ID, decision, who decided). Mirror in `docs/03-technical-decisions.md`.
- Phase overview table: update status only when completion criteria are all checked and the user confirmed.
- Append a one-line Change log entry per session of work.
- Never delete history; do not mark unverified work as done; report failing tests honestly.
