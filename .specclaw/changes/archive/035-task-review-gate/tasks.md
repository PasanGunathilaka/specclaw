# Tasks: Per-task review gate and evidence-before-done

**Change:** 035-task-review-gate
**Created:** 2026-09-19
**Total Tasks:** 5

## Summary

One unconditional footer gate, one optional review gate, the prompts that feed them, the places the
verdicts surface, and a suite.

## Tasks

### Wave 1 — Evidence before done

- [x] `T1` — `specclaw-build check-report`
  - Files: plugins/specclaw/bin/specclaw-build
  - Estimate: medium
  - Kind: impl
  - Notes: FR2–FR4. Last footer wins; one file in, one verdict out.

- [x] `T2` — the footer requirement in every coding-agent prompt
  - Files: plugins/specclaw/references/agent-prompts.md, plugins/specclaw/bin/specclaw-build-context, plugins/specclaw/skills/build/SKILL.md
  - Estimate: small
  - Kind: docs
  - Depends: T1
  - Notes: FR1, FR5, FR15.

### Wave 2 — The optional gate

- [x] `T3` — `specclaw-build review-package` + `build.task_review`
  - Files: plugins/specclaw/bin/specclaw-build, plugins/specclaw/templates/config.yaml
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR6–FR8. Read-only w.r.t. git; visible truncation.

- [x] `T4` — reviewer prompt, verdict wiring, and where the verdicts show
  - Files: plugins/specclaw/agents/code-reviewer.md, plugins/specclaw/skills/build/SKILL.md, plugins/specclaw/skills/verify/SKILL.md, plugins/specclaw/templates/status.md
  - Estimate: medium
  - Kind: docs
  - Depends: T3
  - Notes: FR9–FR13.

### Wave 3 — Proof

- [x] `T5` — `tests/run-task-review-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-task-review-tests.sh, .github/workflows/ci.yml
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
