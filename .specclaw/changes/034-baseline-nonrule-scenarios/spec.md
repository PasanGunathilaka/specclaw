# Spec: Non-rule baseline scenario classes

**Change:** 034-baseline-nonrule-scenarios
**Created:** 2026-09-10
**Status:** 🟡 Draft
**Depends on:** `033-capability-acceptance-basis` (merged — provides `CAP-###`, the union basis, and the Capability Coverage Check)

## Overview

`033` built the plumbing and the ledger. It generates no fixtures: every capability in a fresh run reads `not covered`, for the same reason each time — no scenario class exists that would cover it.

This change adds four scenario classes so `bf-baseline` actually derives the behaviour a rebuild silently drops: a form's field set, a composite flow's missing step, a drifted default, an answered ordering question.

The whole change is governed by one principle, and the acceptance criteria enforce it as strictly as they enforce the classes themselves:

> **A fixture earns its place when replaying it could plausibly diverge.**

That is why this is not "cover every form". A per-field, per-form CRUD assertion cannot diverge in a competent rebuild — it tests the ORM, not a legacy decision — and it would multiply as forms × fields, each one costing a human capture against a running legacy app and a human review of every divergence. **Blanket coverage is how a harness becomes unaffordable and stops being run.** A round-trip *does* diverge in exactly one way that matters — the field is gone — so it is captured **once per entity as a shape assertion**, never per field as a value assertion. Cost then scales with entity count, not form or field count.

## Requirements

### Functional Requirements

**FR-1 — Entity round-trip, one scenario per entity.** Create with every documented field populated at a **distinguishable** value, read back, assert the whole output shape. Seam: `persistence` or `service`. Catches dropped fields, silent truncation, unapplied defaults, and a file-upload field degraded to text — the regression the Field Semantics & Capture-Widget Rule exists to flag but cannot verify. Pins the create/edit `CAP-###` that writes the entity.

**FR-2 — Composite flow, one scenario per named composite workflow.** Assert the sequence's **observable end state**, not each call in isolation. The Composite-Flow Rule already produces the evidence: each backend call in order, every parameter of business significance, and what is functionally lost if a step is omitted — that last field is the assertion. Pins the `CAP-###` whose bullet cross-references the workflow.

**FR-3 — Defaults-at-rest, one scenario per entity with defaultable fields.** Create with those fields omitted; assert what the legacy app actually wrote. Recorded **mechanically** per the Mechanical Recording Rule — what the default *is*, never an invented rationale for why.

**FR-4 — Promoted T6, one scenario per answered ordering/formatting question.** When a T6 `PQ-NNN` has been promoted to a `CQ-###` and resolved in `decisions.md`, the resolved behaviour becomes a scenario. An **unanswered** T6 stays a pending question and generates nothing.

**FR-5 — The divergence principle is stated as the test for designing a scenario at all**, not as background. The designer applies it before adding any scenario in these classes, and says in its final response which candidate scenarios it declined and why.

**FR-6 — Distinguishable values are required for a round-trip.** A field asserted with a value indistinguishable from another field's cannot detect a field swap — a real rebuild regression — so the class is specified with that constraint, not merely encouraged.

**FR-7 — The classes feed the Capability Coverage Check `033` built.** A capability covered by one of these scenarios reads `covered by GM-###` rather than `not covered`, which is the visible outcome of this change.

**FR-8 — Existing scenario derivation is unchanged.** The three existing non-rule classes (cascade deletes, computed read-model boundaries, coexisting mechanisms) and all `DR-###`-derived scenarios keep their current behaviour and their `GM-###` ids.

### Non-Functional Requirements

**NFR-1 — No contract change.** `Kind` in `templates/scenarios.md` is prose — never validated against an enum, never extracted into the manifest — so the four classes need no schema change. `seam_layer` stays the closed enum it is; `persistence` already covers constraint behaviour and `manifest_schema` stays at 4.

**NFR-2 — No existing fixture flips to `SUPERSEDED`.** New scenarios take new `GM-###` ids; existing scenario text is untouched.

**NFR-3 — Additive to agent instruction and one template.** No `bin/` logic changes. If this change finds itself editing a `bin/` script, that is a signal the design is wrong.

**NFR-4 — Bounded cost, stated up front.** The added fixture count is `2E + C` (E entities, C composite flows) and must be reported to the human at design time so the capture cost is known before anyone captures anything.

**NFR-5 — shellcheck gate**: `shellcheck-baseline.txt` unmodified; no new findings in any touched file.

**NFR-6 — CI registration**: any new test suite registered in `.github/workflows/ci.yml`.

## Acceptance Criteria

> **What is and is not mechanically testable here.** Scenario derivation is done by
> the `bf-baseline-designer` **agent**, not by bash — `bf-baseline` design mode
> spawns it and the agent writes `scenarios.md`. So "the designer derives exactly
> one round-trip per entity" cannot be asserted by a deterministic suite; it would
> need a live, non-deterministic model run. This was a planning error in the first
> draft of this spec, corrected mid-build rather than papered over with a test that
> greps its own fixture and calls it coverage.
>
> The criteria below therefore split honestly in two: **instruction criteria**
> (AC-1..AC-7), asserted by a doc-lint that fails when a bound is removed or
> weakened, and **mechanical criteria** (AC-8..AC-14), asserted by running code.
> A doc-lint is a weaker guarantee than an execution test and is labelled as such
> — but it is not nothing: it is what stops the cost model being silently deleted
> in a later edit, which is R-1, the highest risk in this change.

### Instruction criteria — asserted by doc-lint

**AC-1** — `bf-baseline-designer.md` states the entity round-trip class **bounded per entity**, with the words that forbid the explosion ("never per form", "never per field") present verbatim. Fails if the bound is removed or softened.

**AC-2** — The round-trip class states both load-bearing constraints: **distinguishable** arrange values, and assert the **whole shape** rather than a field list.

**AC-3** — The composite-flow class is bounded **per named workflow** and states that it asserts the **observable end state**, not the individual calls.

**AC-4** — The composite-flow class states that it pins the cross-referenced `CAP-###`.

**AC-5** — The defaults-at-rest class is bounded **per entity with defaultable fields** and requires the default be recorded **mechanically**.

**AC-6** — The promoted-T6 class requires a **resolved** `CQ-###` and states explicitly that an **unanswered** question yields no scenario.

**AC-7 — The anti-explosion rule is stated, not implied.** The divergence test appears as the test for deriving a scenario at all; no class is phrased per-form or per-field; and `templates/scenarios.md` carries the same bounds so the constraint survives in the document authors actually read. **This is the criterion most likely to erode, so the lint asserts the specific bounding words rather than merely that the class exists.**

### Mechanical criteria — asserted by running code

**AC-8** — A `scenarios.md` containing scenarios of these shapes (capability-pinning, no `DR-###`) records, selects and reports through `033`'s chain unchanged: `record` writes `capabilities_pinned`, and the Capability Coverage Check reports `covered by GM-###` rather than `not covered`.

**AC-9 — No existing fixture flips to `SUPERSEDED`.** Given a recorded fixture set, a `record` run after this change reports every previously-`VERIFIABLE` fixture as still `VERIFIABLE`, **with a companion assertion proving the mechanism fires** on genuinely changed text — so a green result cannot mean the check is broken.

**AC-10** — The three pre-existing non-rule classes and the `DR-###` derivation instructions are still present and unmodified in the designer.

**AC-11** — `manifest_schema` stays `4`, no new manifest field appears, and `templates/scenarios.md` gains no new section (`{{capability_coverage}}` untouched).

**AC-11b — NFR-3 tripwire:** this change modifies no file under `plugins/specclaw/bin/`.

**AC-8** — Every capability covered by a new scenario reads `covered by GM-###` in the Capability Coverage Check; capabilities with no scenario still read `not covered` or a `NOT-REPLAYABLE` classification. `033`'s gate behaviour is unchanged by this change.

**AC-9 — No existing fixture flips to `SUPERSEDED`.** Given a recorded fixture set, a `record` run after this change reports every previously-`VERIFIABLE` fixture as still `VERIFIABLE`, **with a companion assertion proving the mechanism fires** on genuinely changed text — so a green result cannot mean the check is broken.

**AC-10** — The three pre-existing non-rule classes and all `DR-###` scenarios are still derived, with their ids unchanged across a regeneration.

**AC-11** — `manifest_schema` stays `4` and no new manifest field appears.

**AC-12** — The designer is *instructed* to report the added fixture count and name the candidates it declined under the divergence principle. Doc-lint criterion — whether a given run actually does so is agent behaviour, observable in that run's output and not assertable here.

**AC-13** — shellcheck gate: baseline unmodified, no new findings in touched files.

**AC-14** — Any new suite is registered in `ci.yml` and carries the exec bit `100755` in the git index.

## Edge Cases

- **An entity with one field.** Distinguishability (FR-6) is vacuous; the round-trip still asserts the shape, and the scenario is still worth one fixture because a dropped single field is still a dropped field.
- **An entity written by two capabilities with different field subsets.** Two scenarios, each pinning its own `CAP-###` — the per-entity rule bounds the common case without forcing a wrong answer here.
- **A service-only entity with no user-facing create path.** No `CAP-###` writes it. The round-trip pins the `DR-###` rules governing it if any; otherwise it is reported under the Capability Coverage Check's unassigned section, because a scenario pinning neither family is selectable only by `--all`.
- **A composite flow whose sequence could not be fully traced.** The Composite-Flow Rule already makes that a Named Gap. It stays a gap and yields no scenario — a partially-traced sequence asserted as complete is worse than no scenario.
- **An entity with no defaultable fields.** No defaults-at-rest scenario. The class is per-entity-with-defaults, not per-entity.
- **A T6 promoted to a `CQ` that is still open.** No scenario. Only a *resolved* decision produces one.
- **A capability whose behaviour is entirely widget/layout.** No scenario in any class; it belongs to the `NOT-REPLAYABLE` classification `033` built, with a reason.
- **A round-trip on an entity holding a file/image field.** The distinguishable-value rule applies to the *recorded* representation; the scenario must not assert a raw path or blob that cannot survive a rebuild — those go in `normalized_fields` as canonical paths.

## Dependencies

- **`033-capability-acceptance-basis`** — merged. Provides `CAP-###`, the union acceptance basis, the Capability Coverage Check, and the selection chain these scenarios' fixtures travel.
- **Blocks nothing.**
- **Explicitly not depended on:** `035-verification-join-key-parity`. That change alters matching semantics for existing projects; this one is additive and must not wait on it, nor inherit its risk.

## Notes

- **No `bin/` changes expected** (NFR-3). This is agent instruction plus one template section. `033` deliberately built all the mechanism.
- **Cost is the reviewable part.** `2E + C` added fixtures — for 40 entities and 8 composite flows, ~88 against ~150 rule fixtures. Bounded by entity count by design, but it is real human capture work and AC-12 requires it be stated at design time rather than discovered at capture time.
- **Lesson carried from `033`:** assertions must fail when the behaviour is absent. AC-7 and AC-9 are written specifically so a green result cannot mean "the check never ran" — AC-7 counts, AC-9 carries a companion proving the mechanism fires.
- No version bump, per the operator's standing instruction.
