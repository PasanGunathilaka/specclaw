# Tasks: Phase time accounting

**Change:** 028-phase-time-accounting
**Created:** 2026-08-01
**Total Tasks:** 5

## Summary

One timing primitive, one progress formatter, instrumentation at four call sites, the places the
numbers surface, one suite.

## Tasks

### Wave 1 — The primitive

- [x] `T1` — `bin/specclaw-timer`
  - Files: plugins/specclaw/bin/specclaw-timer
  - Estimate: large
  - Kind: impl
  - Notes: FR1–FR6, FR8. Append-only; fail-open; jq optional.

- [x] `T2` — `bin/specclaw-progress`
  - Files: plugins/specclaw/bin/specclaw-progress
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR7.

### Wave 2 — Instrumentation

- [x] `T3` — call sites
  - Files: plugins/specclaw/bin/specclaw-run-long, plugins/specclaw/bin/specclaw-loop, plugins/specclaw/skills/build/SKILL.md, plugins/specclaw/skills/verify/SKILL.md, plugins/specclaw/skills/plan/SKILL.md, plugins/specclaw/skills/propose/SKILL.md
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR9–FR11. Every call `|| true`.

### Wave 3 — Where the numbers surface

- [x] `T4` — PR body, dashboard, config, gitignore
  - Files: plugins/specclaw/bin/specclaw-pr, plugins/specclaw/bin/specclaw-azdo-pr, plugins/specclaw/bin/specclaw-update-status, plugins/specclaw/bin/specclaw-init, plugins/specclaw/templates/config.yaml
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR12–FR15.

- [x] `T5` — `tests/run-timing-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-timing-tests.sh, .github/workflows/ci.yml
  - Estimate: medium
  - Kind: test
  - Depends: T1, T2, T3, T4
  - Notes: AC-1 … AC-15.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
