# Tasks: Skill-trigger evals and a description lint

**Change:** 037-skill-trigger-evals
**Created:** 2026-09-19
**Total Tasks:** 5

## Summary

One always-on lint with a baseline, one opt-in headless runner with a fixture, PR wiring, CI, and a
meta-suite that tests the lint against synthetic skills.

## Tasks

### Wave 1 — The cheap gate

- [x] `T1` — `tests/run-description-lint-tests.sh` + baseline
  - Files: plugins/specclaw/tests/run-description-lint-tests.sh, plugins/specclaw/tests/description-lint-baseline.txt
  - Estimate: medium
  - Kind: test
  - Notes: FR7–FR10. Closed trigger set; shellcheck-gate's baseline discipline verbatim.

### Wave 2 — The expensive gate

- [x] `T2` — `tests/fixtures/triggers.tsv`
  - Files: plugins/specclaw/tests/fixtures/triggers.tsv
  - Estimate: small
  - Kind: config
  - Notes: FR1, FR2, and the two state-dependent rows.

- [x] `T3` — `tests/run-trigger-tests.sh`
  - Files: plugins/specclaw/tests/run-trigger-tests.sh
  - Estimate: medium
  - Kind: test
  - Depends: T2
  - Notes: FR3–FR6. Opt-in; asserts on the Skill tool call; fails loudly on a missing CLI.

### Wave 3 — Wiring and proof

- [x] `T4` — PR attachment, contributor rule, CI
  - Files: plugins/specclaw/bin/specclaw-pr, plugins/specclaw/CLAUDE.md, .github/workflows/ci.yml, .github/workflows/trigger-evals.yml
  - Estimate: medium
  - Kind: impl
  - Depends: T1, T3
  - Notes: FR11–FR13.

- [x] `T5` — `tests/run-lint-meta-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-lint-meta-tests.sh, .github/workflows/ci.yml
  - Estimate: medium
  - Kind: test
  - Depends: T1, T2, T3
  - Notes: AC-1 … AC-14 against synthetic skills, so the lint's rules are pinned independently of
    what the real descriptions happen to say today.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
