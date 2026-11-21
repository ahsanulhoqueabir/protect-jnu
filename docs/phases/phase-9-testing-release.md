# Phase 9 — Full Testing, Bug Fixing, Demo & Report Prep

**Status: COMPLETED** (marked by the project owner, 2026-11-21, D-083). The checklist below was not re-run by the agent.

## Objectives
Validate the whole system on real Android phones, fix defects, prepare the demo and report.

## Requirements covered
All; PRD §9 step 9, §10 risk table.

## Prerequisites
Phases 1–8 complete. Q-004 answered (deadline, report/demo). Q-013 devices.

## Steps
1. Build test plan `docs/test-plan.md` from the PRD risk table and every FR/NFR; each test: ID, steps, expected, result, evidence.
2. Auth tests: domain bypass attempts (direct API with `gmail.com`), OTP expiry/reuse/attempt limit/cooldown/rate limit, real email delivery, reset flow, unverified access attempts.
3. RLS audit via MCP: 2 students + admin + anon on every table/operation; run advisors.
4. SOS: accidental press, cancel window, latency, duplicate alerts.
5. Location: background, battery/foreground notification, offline queue, stop-on-end — on ≥2 phone brands/Android versions incl. 8.0 or low-end if available.
6. Chat: realtime, unread, isolation.
7. Media: capture, persistence, no upload.
8. Reports: numbers verification, CSV.
9. Security checks: grep repo/bundles for secrets, confirm no secrets in logs, HTTPS only, admin routes authorized.
10. Fix defects; log in PROGRESS; retest.
11. Release prep: release APK build (signing approach — ask), production env configuration, final deployment (D-018).
12. Demo script and written report outline if required (ask format).

## Testing & validation
Test plan fully executed; failures either fixed or listed as known issues with user acceptance.

## Completion criteria
- [ ] Test plan 100% executed with evidence
- [ ] No open critical/security defects
- [ ] Release build installed on real phone and verified
- [ ] Demo/report artifacts delivered as agreed
- [ ] PROGRESS finalized; user confirmed
