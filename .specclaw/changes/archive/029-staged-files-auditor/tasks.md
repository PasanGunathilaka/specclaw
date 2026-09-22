# Tasks: Staged-files auditor

**Change:** 029-staged-files-auditor
**Created:** 2026-08-01
**Total Tasks:** 5

## Summary

One classifier, one judgement seat, the callers that enforce it, the loop's scoped add, one suite.

## Tasks

### Wave 1 — The classifier

- [x] `T1` — `bin/specclaw-check-staged`
  - Files: plugins/specclaw/bin/specclaw-check-staged
  - Estimate: large
  - Kind: impl
  - Notes: FR1–FR5. Four buckets, `--json`, `--strict`, exit 1 on BLOCK and 2 on usage.

### Wave 2 — The seat and the config

- [x] `T2` — `agents/staged-files-auditor.md` + config keys
  - Files: plugins/specclaw/agents/staged-files-auditor.md, plugins/specclaw/templates/config.yaml
  - Estimate: medium
  - Kind: docs
  - Depends: T1
  - Notes: FR6–FR8. Ships `staged_files_block: false`.

### Wave 3 — Enforcement

- [x] `T3` — PR scripts run the gate
  - Files: plugins/specclaw/bin/specclaw-pr, plugins/specclaw/bin/specclaw-azdo-pr, plugins/specclaw/skills/pr/SKILL.md
  - Estimate: medium
  - Kind: impl
  - Depends: T1, T2
  - Notes: FR9, FR13. Pre-staging check, post-commit re-check, report link.

- [x] `T4` — the loop's scoped add, and build's prohibition
  - Files: plugins/specclaw/bin/specclaw-loop, plugins/specclaw/skills/loop/SKILL.md, plugins/specclaw/skills/build/SKILL.md
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR10–FR12.

- [x] `T5` — `tests/run-staged-files-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-staged-files-tests.sh, .github/workflows/ci.yml
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
