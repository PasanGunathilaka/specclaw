# Tasks: Right-sized change paths

**Change:** 036-right-sized-change-paths
**Created:** 2026-09-19
**Total Tasks:** 6

## Summary

One new field, one new script, one gate taught to read it, three templates/skills, one suite.

## Tasks

### Wave 1 — The field and the gate

- [x] `T1` — `--size` on `specclaw-set-phase`
  - Files: plugins/specclaw/bin/specclaw-set-phase
  - Estimate: small
  - Kind: impl
  - Notes: FR2 — validate the closed set, carry over like `branch`.

- [x] `T2` — size-aware `specclaw-validate-change`
  - Files: plugins/specclaw/bin/specclaw-validate-change
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR3–FR5. Fail-open read; spike refusals name the follow-up.

### Wave 2 — The ratchet and the artifacts

- [x] `T3` — `bin/specclaw-set-size` (upgrade-only)
  - Files: plugins/specclaw/bin/specclaw-set-size
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR6–FR8. Delegates the write to set-phase; refuses downgrade and no-op by name.

- [x] `T4` — templates and skills
  - Files: plugins/specclaw/templates/proposal.md, plugins/specclaw/templates/findings.md, plugins/specclaw/skills/propose/SKILL.md, plugins/specclaw/skills/plan/SKILL.md, plugins/specclaw/skills/build/SKILL.md, plugins/specclaw/skills/archive/SKILL.md
  - Estimate: medium
  - Kind: docs
  - Notes: FR9–FR11, FR13.

- [x] `T5` — size glyph on the dashboard
  - Files: plugins/specclaw/bin/specclaw-update-status
  - Estimate: small
  - Kind: impl
  - Depends: T1
  - Notes: FR12 — inside the existing phase cell, not a new column.

### Wave 3 — Proof

- [x] `T6` — `tests/run-change-size-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-change-size-tests.sh, .github/workflows/ci.yml
  - Estimate: medium
  - Kind: test
  - Depends: T1, T2, T3, T5
  - Notes: AC-1 … AC-15.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
