# Tasks: Non-rule baseline scenario classes

**Change:** 034-baseline-nonrule-scenarios
**Created:** 2026-09-10
**Total Tasks:** 5

## Summary

Three waves, five tasks. Small by design: `033` built every mechanism, so this is agent instruction plus one template section plus the tests that stop the cost model eroding.

The ordering constraint: **T3's counting assertion is the point of the change, not a formality.** The four classes are prose instructions to an agent, and prose bounds erode on the first regeneration unless something counts. T3 therefore asserts the derived scenario count against a project deliberately shaped to explode (2 entities × 6 fields × 2 forms) — if the per-entity bound is ever read as per-form or per-field, that count changes and the suite fails.

`bin/` is untouched throughout. If a task finds itself editing a `bin/` script, stop — that is either scope creep or a gap in `033`, and neither belongs here (design D-7).

## Tasks

### Wave 1 — The classes

- [x] `T1` — Add the four scenario classes and the principle that bounds them
  - Files: `plugins/specclaw/agents/bf-baseline-designer.md`
  - Estimate: medium
  - Kind: docs
  - Notes: Extend Task 3's existing "Scenarios are not limited to numbered business rules" list — do not replace it; the three existing entries keep their behaviour (AC-10). Add: entity round-trip (one per entity, whole-shape assert, distinguishable arrange values, `normalized_fields` for anything that cannot survive a rebuild), composite flow (one per named workflow, asserts the observable end state, pins the cross-referenced `CAP-###`), defaults-at-rest (one per entity with defaultable fields, recorded mechanically per the Mechanical Recording Rule), and promoted-T6 (resolved `CQ` only — an open question yields nothing). State the divergence principle as **the test for deriving a scenario at all**, and require the final response to name declined candidates plus the added fixture count (AC-12). Each class names its `Kind` and expected seam; no `seam_layer` enum change.

- [x] `T2` — Document the four classes where scenario conventions live
  - Files: `plugins/specclaw/templates/scenarios.md`
  - Estimate: small
  - Kind: docs
  - Depends: T1
  - Notes: HTML-comment guidance only, in the existing per-scenario comment block. Per class: what it pins, its `Kind`, its seam, and the constraint that bounds it. State plainly that the per-entity bound is a **cost model, not a style preference** — one scenario per entity, never per form or per field — and that `normalized_fields` is where a raw id, path or blob belongs. **Do not add a new template section and do not touch `{{capability_coverage}}`** — that is `033`'s and already correct.

### Wave 2 — The tests that keep it honest

- [x] `T3` — Write the non-rule scenario suite, counting assertion first
  - Files: `plugins/specclaw/tests/run-nonrule-scenario-tests.sh`
  - Estimate: large
  - Kind: test
  - Depends: T1, T2
  - Notes: Covers AC-1 through AC-11. **Write AC-7 first**: a fixture project of 2 entities × 6 fields × 2 forms, asserting the derived non-rule count is bounded by `2E + C` and not by fields or forms — that assertion is the change's real deliverable. Then AC-1/2 (one round-trip per entity, whole-shape, distinguishable values), AC-3/4 (one composite flow, end-state assert, pins the cross-referenced capability), AC-5 (defaults-at-rest, mechanical), AC-6 (**both** the answered and unanswered T6 case), AC-8 (coverage check reports real coverage; `033`'s gate unchanged), AC-9 (no `SUPERSEDED` flip **plus a companion assertion proving the mechanism fires** — a green result must not be able to mean the check is broken), AC-10 (existing classes and `DR-###` ids survive a regeneration), AC-11 (`manifest_schema` still 4, no new field). **Drive `bf-baseline` itself** — do not assert against hand-built scenario text; per L11, a test that re-implements the thing under test verifies the duplicate. Suite stays jq-free except against JSON artefacts, per the existing convention.

- [x] `T4` — Register the suite and clear the gate
  - Files: `.github/workflows/ci.yml`, `plugins/specclaw/tests/run-nonrule-scenario-tests.sh`
  - Estimate: small
  - Kind: config
  - Depends: T3
  - Notes: Separate task deliberately — an unregistered suite silently never runs, which `context.md` records as having happened twice here. Assert registration by grepping `ci.yml`, and set the exec bit with `git update-index --chmod=+x` (chmod alone does not reach the index on Windows). Then shellcheck clean with `shellcheck-baseline.txt` **unmodified** — fix findings, never baseline them (AC-13, AC-14).

### Wave 3 — Regression proof

- [ ] `T5` — Prove nothing else moved
  - Files: *(no source changes — verification only)*
  - Estimate: medium
  - Kind: test
  - Depends: T4
  - Notes: Run the five suites `033` established as the affected set — `run-capability-selection-tests`, `run-replay-classification-tests`, `run-bf-status-tests`, `run-stub-registry-tests`, `run-item-split-tests` — plus the new one. All must stay at their known-good counts (78 / 204 / 133 / 50 / 89). Where a count moves, use the archive-both-sides method against pristine `main` before attributing it to this change; raw counts on this checkout are unreadable because several suites fail environmentally. Record the results in `verify-report.md` with the vacuous-`tests_passed` caveat stated, since `config.yaml` still carries empty test/lint/build commands.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:**
```
- [ ] `T<n>` — <title>
  - Files: <files to create/modify>
  - Estimate: small | medium | large
  - Kind: docs | test | config | refactor | impl | migration   (optional; hints the build subagent's role, tools, and model)
  - Depends: <task ids> (if any)
  - Notes: <additional context>
```

The optional `Kind` hint is consumed by `build.dynamic_agents` (when enabled) to
synthesize a specialized subagent per task. Omit it and build classifies
heuristically, defaulting to `impl`.
