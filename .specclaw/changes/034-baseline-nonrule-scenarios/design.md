# Design: Non-rule baseline scenario classes

**Change:** 034-baseline-nonrule-scenarios
**Created:** 2026-09-10

## Technical Approach

This change is **agent instruction plus one template section, and nothing else**. `033` deliberately built every mechanism these scenarios need: the `CAP-###` family they pin, the union acceptance basis their fixtures are selected through, the Capability Coverage Check they populate, and the `record`-time validation that refuses a bad pin. What was missing was any instruction to *derive* them.

Three properties make this small:

1. **`Kind` is prose.** It is never validated against an enum and never extracted into the manifest, so four new scenario classes need no contract change, no schema move, and no `record` change.
2. **`seam_layer` already covers the seams these use.** `persistence` is documented as "the data/ORM boundary — cascade, delete-rule, and constraint behaviour", which a round-trip and a defaults-at-rest scenario fit without stretching. `service` covers a composite flow.
3. **The extension point already exists.** `bf-baseline-designer.md` has a "Scenarios are not limited to numbered business rules" list with three entries. This change adds four more and the principle that bounds them.

**If this change edits a `bin/` script, the design is wrong** (NFR-3). That is a deliberate tripwire: the temptation while touching the designer will be to add a counter, a validator, or a new manifest field, and every one of those would be `033`'s job done late.

## Architecture

Where each class attaches, and what already carries it:

```
functional-spec.md          CAP-### capabilities  ─┐   (033)
  + Composite-Flow Rule     named workflows        │
                                                   │
domain-model.md             entities, fields       │
  + Field Semantics Rule    capture widgets        │
                                                   ▼
bf-baseline-designer.md  ── Task 3 ──►  four new scenario classes
  (THIS CHANGE)                         bounded by the divergence principle
                                                   │
                                                   ▼
scenarios.md                GM-### + Capabilities pinned   (033)
                            + Capability Coverage Check    (033)
                                                   │
                                                   ▼
record ─► manifest capabilities_pinned ─► bf-replay union join   (033)
```

Everything below the designer is `033`'s and unchanged. This change writes only into the box marked THIS CHANGE, plus the matching guidance in `templates/scenarios.md` so the shape is documented where every other scenario convention is documented.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/agents/bf-baseline-designer.md` | modify | The four classes in Task 3; the divergence principle as the test for deriving one at all; the declined-candidates report; harness-mode coverage of the new ids |
| `plugins/specclaw/templates/scenarios.md` | modify | HTML-comment guidance for the four classes: each one's `Kind`, expected seam, and the constraint that bounds it |
| `plugins/specclaw/tests/run-nonrule-scenario-tests.sh` | create | Derivation shape, the anti-explosion count, no-`SUPERSEDED`, id stability |
| `.github/workflows/ci.yml` | modify | Register the suite (NFR-6) |

## Data Model Changes

**None.** No new manifest field, `manifest_schema` stays `4`, no new document section, no new id family. The scenarios these classes produce are ordinary `GM-###` scenarios that happen to pin a `CAP-###` — a shape `033` already records, validates and selects.

## API Changes

**None.** No CLI change, no new flag, no new subcommand. The visible difference is that `bf-baseline` design mode produces more scenarios and the Capability Coverage Check reports real coverage instead of a uniform `not covered`.

## Key Decisions

**D-1 — One scenario per entity, not per form or per field.** This is the whole cost model. A per-field assertion cannot diverge in a competent rebuild, so it buys nothing while multiplying human capture work by fields × forms. A round-trip diverges in exactly one way that matters — the field is gone — and a whole-shape assertion catches that once. Cost scales with entity count.

**D-2 — Whole-shape assertion, not an explicit field list.** A shape assertion catches a field that *appeared* as well as one that vanished, and an explicit list silently stops covering any field added after it was written. Exclusions go in `normalized_fields` as canonical paths, which is the mechanism `033`'s contract already validates.

**D-3 — Distinguishable arrange values are specified, not encouraged.** Two fields seeded with the same value cannot detect a field swap, which is a real rebuild regression. Stated as a constraint of the class so it is reviewable.

**D-4 — Defaults-at-rest stays separate from the round-trip.** One creates with everything populated, the other with fields omitted; merging them would make a single fixture assert two different arrange states. This is the one place the class count could be halved if capture cost proves too high, and it is called out here so that trade is made deliberately rather than by drift.

**D-5 — Composite flow asserts the end state, not the call sequence.** The Composite-Flow Rule's own "what is functionally lost if any step is omitted" field is the assertion. Asserting each call individually would test the rebuild's internal structure rather than its behaviour, and a rebuild is allowed to restructure.

**D-6 — Only a resolved T6 produces a scenario.** An open question yields a `PQ`, which is `bf-clarify`'s business. Deriving a scenario from an unanswered question would pin behaviour nobody has decided.

**D-7 — No `bin/` changes, enforced as a tripwire.** Every mechanism exists. A `bin/` edit here means either scope creep or a gap in `033` that should be fixed as `033`'s follow-up, not absorbed silently.

## Risks & Mitigations

**R-1 — The anti-explosion rule erodes.** *Highest risk in the change.* An agent reading "derive a round-trip scenario" will reasonably produce one per form, or one per field, and the result is a fixture set nobody can afford to capture — which kills the harness rather than the feature. **Mitigation:** the per-entity bound is written into the class itself, the divergence principle is stated as the test for deriving anything, and **AC-7 asserts the count mechanically** against a project with 2 entities × 6 fields × 2 forms. A prose rule with no counting test is a rule that erodes on the first regeneration.

**R-2 — A round-trip asserts something that cannot survive a rebuild.** Raw ids, file paths and blobs differ between two independently seeded systems, so a shape assertion that includes them is guaranteed noise. **Mitigation:** the class specifies `normalized_fields` for exactly these, reusing `033`'s existing canonical-path validation, which hard-fails a path matching nothing.

**R-3 — Capture cost lands as a surprise.** `2E + C` is bounded but real: ~88 fixtures on a 40-entity app. Discovered at capture time it reads as the tool being unreasonable. **Mitigation:** AC-12 requires the designer to state the added count at *design* time, before anyone captures anything.

**R-4 — A green test that never ran.** `033` shipped three acceptance criteria with no assertion and a "verified" claim resting on a helper's return code. **Mitigation:** AC-7 is a count (fails if derivation is absent), AC-9 carries a companion assertion proving the `SUPERSEDED` mechanism fires at all, and AC-6 asserts both the positive and negative T6 case. No criterion in this change is satisfied by a check that would pass on an empty result.

**R-5 — Scope creep into `035`.** The join-key finding is adjacent and tempting. **Mitigation:** stated out of scope in the spec's Dependencies, and this change touches no `bin/` file, which is where that fix lives.

## Grounding sources

- `.specclaw/context.md` — *"Every test suite must be registered in `.github/workflows/ci.yml`. An unregistered suite silently never runs — this has happened twice in this repo."* → NFR-6, AC-14.
- `.specclaw/context.md` — *"`tests/shellcheck-gate.sh` must pass with `shellcheck-baseline.txt` unmodified."* → NFR-5, AC-13.
- `.specclaw/knowledge/agent-hints.md` (L11, promoted from `033`) — a test that re-implements the logic under test verifies the duplicate → the new suite drives `bf-baseline` itself rather than asserting on hand-built scenario text.
- `.specclaw/knowledge/agent-hints.md` (L14) — a gate that can return a passing result must fail closed on every ambiguity → why AC-6 asserts the *unanswered* T6 case, not only the answered one.
- `plugins/specclaw/templates/CONTRACT.md` (i) — `persistence` is "the data/ORM boundary — cascade, delete-rule, and constraint behaviour" → D-1's seam choice needs no enum change.
- `plugins/specclaw/agents/bf-domain-analyst.md:82` — the Composite-Flow Rule's "what is functionally lost if any step is omitted" → D-5's assertion shape.
