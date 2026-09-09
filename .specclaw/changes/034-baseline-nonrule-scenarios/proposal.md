# Proposal: Non-rule baseline scenario classes — round-trip, composite flow, defaults, promoted T6

**Created:** 2026-09-09
**Status:** 🟡 Draft
**Depends on:** `033-capability-acceptance-basis` (must be built and merged first)

## Problem

With `033` merged, `functional-spec.md` capabilities carry `CAP-###`, `scenarios.md` closes with a Capability Coverage Check, and `bf-replay` selects a DR-less fixture at all four scopes. What `033` deliberately does **not** do is generate any such fixture. Its output is an honest ledger of what is not covered — every capability reads `not covered: <reason>`, and the reason is the same reason for nearly all of them: no scenario class exists that would cover it.

`bf-baseline-designer.md:74` opens the door and then names a closed list of three non-rule classes — cascade/`SetNull` deletes, boundary values of computed read-model properties, and two-mechanisms-for-one-concern. None of them is the case that actually breaks rebuilds. The uncovered behaviour is:

- **A field that stopped existing.** Twelve fields in the legacy form, ten in the rebuild. No `DR-###` mentions the ten that survived, so no fixture pins them, so nothing notices. This is the single most common rebuild regression there is.
- **A composite flow that lost a step.** `bf-domain-analyst.md:82` documents these with full evidence and states plainly that no backend fixture can verify them. A rebuild can pass every `DR-###` fixture and still create a product with no opening stock.
- **A default that drifted.** Create with a field omitted; legacy wrote one value, the rebuild writes another. Invisible, and it silently corrupts data rather than failing.
- **An answered ordering or formatting question.** Trigger T6 correctly routes "observable but not pinned by any code path" to a `PQ-NNN` for a human. Routing the *decision* to a human is right; leaving the *answer* as prose is not. Once answered it should be a fixture, and today it never becomes one.

## Proposed Solution

Add four scenario classes to `bf-baseline-designer.md`'s Task 3, governed by one principle:

> **A fixture earns its place when replaying it could plausibly diverge.**

That principle is why this change is not "cover every form". A per-field, per-form CRUD assertion cannot diverge in a competent rebuild — "I saved X, I read back X" tests the ORM, not a legacy decision — and it would multiply as forms × fields, each one costing a human capture against a running legacy app and a human review of every divergence. Blanket coverage is how a harness becomes unaffordable and stops being run.

But a round-trip *does* diverge in exactly one way that matters: the field is gone. So it is captured **once per entity as a shape assertion**, not per field as a value assertion. Cost then scales with entity count, not form or field count, which is what makes it affordable.

### The four classes

1. **Entity round-trip — one fixture per entity.** Create with every documented field populated at a distinguishable value, read back, assert the whole output shape. Seam: `persistence` or `service`, both already in the enum. Catches dropped fields, silent truncation, unapplied defaults, and the file-upload-degraded-to-text regression that the Field Semantics & Capture-Widget Rule exists to flag but currently cannot verify. Pins the create/edit `CAP-###` that writes the entity.

2. **Composite flow — one fixture per named composite workflow.** Assert the full sequence's observable end state, not each call in isolation. The Composite-Flow Rule already produces the evidence: each backend call in order, every parameter of business significance, and what is functionally lost if a step is omitted. That last field is the assertion. Pins the `CAP-###` whose bullet cross-references the workflow.

3. **Defaults-at-rest — one fixture per entity with defaultable fields.** Create with those fields omitted; assert what the legacy app actually wrote. Recorded mechanically per the Mechanical Recording Rule — what the default *is*, never an invented rationale for why.

4. **Promoted T6 — one fixture per answered ordering/formatting question.** When a T6 `PQ-NNN` has been promoted to a `CQ-###` and resolved in `decisions.md`, the resolved behaviour becomes a scenario. An unanswered T6 stays a pending question and generates nothing, exactly as today.

### What stays excluded

Widget type, layout, labels, navigation, client-side-only validation. Not observable at any non-UI seam, and the UI seam is `Excluded` by construction (`bf-baseline-designer.md:34`). Attempting these would either violate the seam-layer contract or produce assertions that prove nothing. They remain with `bf-ui` (`SCR-###` plus human sign-off) and `bf-e2e`. `033` states this boundary in bf-baseline's "What this command does not do"; this change does not move it.

### Contract impact: none

`Kind` in `templates/scenarios.md` is prose — never validated against an enum, never extracted into the manifest. The four classes need no new field and no schema change. `seam_layer` stays the closed enum it is, and `persistence` is already documented as "cascade, delete-rule, and constraint behaviour" (`templates/CONTRACT.md:473`), which a round-trip fits without stretching. Everything here is additive agent instruction landing on plumbing `033` already built and tested.

## Scope

### In Scope
- `bf-baseline-designer.md` Task 3 — the four classes, with the divergence principle stated as the test for whether a scenario is worth designing, and each class's `Kind` value and expected seam.
- `templates/scenarios.md` — HTML-comment guidance for the four classes, so the shape is documented where every other scenario convention is documented.
- The Capability Coverage Check (built in `033`) begins reporting real coverage rather than a uniform `not covered`.
- `bf-baseline-designer.md` harness mode — one test case per new scenario id, unchanged one-for-one discipline against the `harness-collect` checklist.
- Guidance on the round-trip's distinguishable-value requirement: a field asserted with a value indistinguishable from another field's cannot detect a field swap, which is a real rebuild regression and a plausible divergence.
- Tests: the four classes appear for a fixture project; per-entity (not per-field) fixture count holds; a composite flow with a dropped step produces `DIVERGES`; an unanswered T6 generates nothing.

### Out of Scope
- Everything `033` covers — `CAP-###`, the coverage check, the union join, the verdict split. This change depends on all of it and changes none of it.
- Per-field or per-form CRUD fixtures (see the divergence principle).
- Widget, layout, navigation, client-side-only validation.
- Any change to the fixture contract, manifest schema, or `seam_layer` enum.
- Re-capture of existing fixtures. New scenarios take new `GM-###` ids; existing scenario text is untouched, so no existing fixture flips to `SUPERSEDED`.

## Impact

- **Files affected:** ~4 (estimated) — 1 agent, 1 template, plus tests
- **Complexity:** small (additive instruction, no schema or CLI change)
- **Risk:** low on the tooling, **medium on human capture cost** — this is the change that actually adds fixtures a person must capture. Estimated addition: `2E + C` (E entities, C composite flows). For 40 entities and 8 composite flows against ~150 rule fixtures, roughly 88 more. Bounded by entity count by design, but it is real work and worth stating before approval rather than discovering at capture time.

## Open Questions

1. **Should the entity round-trip be one fixture per entity, or one per create/edit capability?** Proposed default: per entity. Two capabilities writing one entity share a shape, and per-capability would duplicate the assertion. Flagged because an entity written by two capabilities with genuinely different field subsets is a real case, and the answer there is probably a second scenario pinning the second `CAP-###`.
2. **Does a round-trip fixture assert the full output shape, or an explicit field list?** Proposed default: full shape, with `normalized_fields` carrying the exclusions. A shape assertion catches a field that appeared as well as one that vanished, and an explicit list silently stops covering any field added after it was written.
3. **Should defaults-at-rest merge into the round-trip fixture?** Proposed default: no, keep them separate — one creates with everything populated, the other with fields omitted, and merging them would make a single fixture assert two different arrange states. Called out because it is the one place these classes could be halved if capture cost proves too high.
4. **For an entity with no `CAP-###` writing it — a service-only entity with no user-facing create path — does a round-trip scenario still get designed?** Proposed default: yes, pinning the `DR-###` rules that govern it if any, otherwise reported under the Capability Coverage Check's unassigned section. Flagged because `033`'s selection chain joins on `{DR-###, CAP-###}`, and an entity with neither is a fixture that no scope except `--all` can select.

---

**To proceed:** Review this proposal and approve to begin planning. Build `033-capability-acceptance-basis` first.
