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

**AC-1** — For a fixture project with 2 entities, `bf-baseline` design mode derives **exactly one** entity round-trip scenario per entity — not one per form, not one per field.

**AC-2** — Each round-trip scenario's Assert shape names the **whole output shape**, and its arrange values are distinguishable from one another (no two fields seeded with the same value).

**AC-3** — For a functional-spec carrying a named composite workflow, exactly one composite-flow scenario is derived, and its Assert shape names the sequence's observable end state — not the individual calls.

**AC-4** — A composite-flow scenario pins the `CAP-###` whose capability bullet cross-references that workflow.

**AC-5** — For an entity with defaultable fields, exactly one defaults-at-rest scenario is derived, and its recorded default is stated mechanically (no invented rationale).

**AC-6** — An **answered** T6 (`PQ` promoted to a resolved `CQ` in `decisions.md`) yields a scenario; an **unanswered** T6 yields none. Both asserted.

**AC-7 — The anti-explosion rule holds mechanically.** For a project with 2 entities × 6 fields × 2 forms, the derived non-rule scenario count is bounded by `2E + C`, **not** by fields or forms. Asserted as a count, because this is the constraint most likely to erode.

**AC-8** — Every capability covered by a new scenario reads `covered by GM-###` in the Capability Coverage Check; capabilities with no scenario still read `not covered` or a `NOT-REPLAYABLE` classification. `033`'s gate behaviour is unchanged by this change.

**AC-9 — No existing fixture flips to `SUPERSEDED`.** Given a recorded fixture set, a `record` run after this change reports every previously-`VERIFIABLE` fixture as still `VERIFIABLE`, **with a companion assertion proving the mechanism fires** on genuinely changed text — so a green result cannot mean the check is broken.

**AC-10** — The three pre-existing non-rule classes and all `DR-###` scenarios are still derived, with their ids unchanged across a regeneration.

**AC-11** — `manifest_schema` stays `4` and no new manifest field appears.

**AC-12** — The designer reports the added fixture count and names the candidate scenarios it declined under the divergence principle.

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
