# Tasks: Session-start bootstrap and intent router

**Change:** 033-session-bootstrap-router
**Created:** 2026-09-19
**Total Tasks:** 5

## Summary

One hook, one snapshot script, one router skill, config + docs, one suite.

## Tasks

### Wave 1 — State first

- [x] `T1` — `bin/specclaw-bootstrap-snapshot`
  - Files: plugins/specclaw/bin/specclaw-bootstrap-snapshot
  - Estimate: medium
  - Kind: impl
  - Notes: FR8, FR9, FR10. Disk only, no model, no writes, honours max_lines.

- [x] `T2` — `skills/using-specclaw/SKILL.md`
  - Files: plugins/specclaw/skills/using-specclaw/SKILL.md
  - Estimate: medium
  - Kind: docs
  - Notes: FR6, FR7, FR14. Under the byte cap — every sentence is paid for each session.

### Wave 2 — The emitter

- [x] `T3` — `hooks/hooks.json` + `hooks/session-start`
  - Files: plugins/specclaw/hooks/hooks.json, plugins/specclaw/hooks/session-start
  - Estimate: medium
  - Kind: impl
  - Depends: T1, T2
  - Notes: FR1–FR5, FR12. Block-scoped config read; printf, never a heredoc; always exit 0.

- [x] `T4` — config seed and documentation
  - Files: plugins/specclaw/templates/config.yaml, plugins/specclaw/CLAUDE.md, plugins/specclaw/bin/specclaw-check-update
  - Estimate: small
  - Kind: docs
  - Notes: FR11 plus the plugin-cache-lag note — hooks load from the installed plugin.

### Wave 3 — Proof

- [x] `T5` — `tests/run-bootstrap-hook-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-bootstrap-hook-tests.sh, .github/workflows/ci.yml
  - Estimate: medium
  - Kind: test
  - Depends: T1, T2, T3, T4
  - Notes: AC-1 … AC-14, including the decoy-`enabled:` fixture and the byte cap.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
