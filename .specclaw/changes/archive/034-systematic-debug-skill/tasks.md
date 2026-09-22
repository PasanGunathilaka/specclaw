# Tasks: `/specclaw:debug` — root-cause-first debugging protocol

**Change:** 034-systematic-debug-skill
**Created:** 2026-09-19
**Total Tasks:** 6

## Summary

One new skill, one new `log-error` mode, one new loop halt reason, two prompt/prose updates, one
pattern-clustering change, one test suite.

## Tasks

### Wave 1 — The record and the protocol

- [x] `T1` — `specclaw-log-error --investigation`
  - Files: plugins/specclaw/bin/specclaw-log-error, plugins/specclaw/templates/errors.md
  - Estimate: medium
  - Kind: impl
  - Notes: jq-free `json_pick`/`json_pick_array` readers; FR2–FR5; refusals exit 2.

- [x] `T2` — `skills/debug/SKILL.md`
  - Files: plugins/specclaw/skills/debug/SKILL.md
  - Estimate: medium
  - Kind: docs
  - Notes: four phases, three strikes, red flags, record format, routing. Trigger-only description.

### Wave 2 — Wiring

- [x] `T3` — `specclaw-loop`: `architecture-question` halt reason
  - Files: plugins/specclaw/bin/specclaw-loop
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: FR6–FR8; `loop.architecture_question_limit` default 2; slug on every halt.

- [x] `T4` — Fix-agent protocol in the remediation payload
  - Files: plugins/specclaw/bin/specclaw-build-context, plugins/specclaw/references/agent-prompts.md
  - Estimate: small
  - Kind: impl
  - Notes: FR9 — Root-Cause Protocol block prepended to the failure-record section.

- [x] `T5` — `specclaw-detect-patterns` clusters on cause
  - Files: plugins/specclaw/bin/specclaw-detect-patterns
  - Estimate: small
  - Kind: impl
  - Depends: T1
  - Notes: FR10 — upheld hypothesis + fix become the clustering text for investigation blocks.

### Wave 3 — Proof

- [x] `T6` — `tests/run-debug-protocol-tests.sh` + CI registration
  - Files: plugins/specclaw/tests/run-debug-protocol-tests.sh, .github/workflows/ci.yml
  - Estimate: medium
  - Kind: test
  - Depends: T1, T3, T4, T5
  - Notes: AC-1 … AC-13.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
