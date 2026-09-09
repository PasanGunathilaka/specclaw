# Baseline Scenarios: {{title}}

**Date generated:** {{date}}
**Grounded in:** .specclaw/analysis/domain-model.md's numbered Business Rules and .specclaw/analysis/functional-spec.md's CAP-### capabilities{{supplementary_docs_note}}

<!--
  Every scenario carries:

  ### GM-NNN — <short title>

  - **Seam:** <from seams.md>
  - **Seam layer:** pure-function | service | http | persistence
  - **Modules:** <every MOD-### from module-map.md that OWNS one of the rules
    OR ONE OF THE CAPABILITIES this scenario pins, comma-separated — or
    omitted entirely when module-map.md does not exist yet, exactly as
    "Verifies backlog item" reads "not yet backlog-linked" before
    rebuild-backlog.md exists. A scenario pinning no DR-### derives this
    field from capability ownership alone; without that derivation a
    DR-less fixture would carry no module tag and be invisible to every
    --module run.>
  - **Business rules pinned:** <rule number(s) from domain-model.md, e.g. "rule 7">
  - **Capabilities pinned:** <CAP-### id(s) from functional-spec.md this
    scenario pins, e.g. "CAP-014" — omitted entirely when the scenario pins
    no capability. A scenario may pin rules, capabilities, or BOTH; the
    acceptance basis is the union of the two families, so a scenario
    pinning only capabilities is still selected at every replay scope.>
  - **Arrange:** <state to set up>
  - **Act:** <call/action under test>
  - **Assert (shape):** <what the fixture must capture to prove the rule held>
  - **Kind:** boundary | edge case
  - **Verifies backlog item:** <rebuild-backlog.md item, or "not yet backlog-linked —
    rebuild-backlog.md does not exist yet">

  GM-NNN IDs are permanent, never renumbered — a captured fixture, a
  manifest entry and a module tag all hang off one, so a re-design that
  reassigned them would silently re-point every one of those without
  changing a single hash. specclaw-bf-baseline collect hands the design
  agent the PRIOR scenario roster (id, title, rules, modules, seam layer)
  for exactly this reason: surviving ids are carried forward by rule+title
  match, and only a genuinely new scenario takes the next free id. A
  scenario that is no longer designed becomes a tombstone

  ### GM-NNN — WITHDRAWN <date>, <reason>

  rather than disappearing, so its id stays claimed forever. Tombstones are
  skipped by `record` (they declare no seam layer and can never be captured)
  and by `harness-collect`, but they still count toward the next free id.

  Scenarios are derived directly from domain-model.md's documented rules and
  functional-spec.md's CAP-### capabilities; never invent a rule, a
  capability, or a rationale the source document doesn't state.

  MODULES is the migration/acceptance dimension (MOD-### -> BL-0## ->
  {DR-###, CAP-###} -> GM-###). It is DERIVED, once, from module-map.md's
  own ownership — which module owns each DR-### and each CAP-### this
  scenario pins — and copied verbatim thereafter, exactly like Seam layer:
  `record` extracts it into manifest.json and /specclaw:bf-replay --module
  joins on it there, never on this prose. Never re-derive it at record or
  replay time.

  A SCENARIO WHOSE RULES SPAN MODULES IS TAGGED WITH ALL OF THEM. That is
  required, not an edge case to round down: a multi-module scenario is the
  record of a flow that crosses a module boundary, it is selected by a
  --module run for EVERY module it names, and /specclaw:bf-replay's
  per-module rollup counts it toward each of them and states how many of a
  module's fixtures are shared. Tagging such a scenario with one module
  would make the other module's PASS a false verdict, and a module-scoped
  redesign would be able to retire another module's coverage without
  anyone noticing.

  `record` HARD-FAILS on a declared MOD-### that has no matching heading in
  module-map.md, on the same grounds as an unmapped error code: a module tag
  naming no module selects nothing, silently. It WARNS (never blocks) when a
  scenario's module disagrees with the module its own BL item is filed under
  in rebuild-backlog.md — one of the two documents is wrong, and bash does
  not decide which.

  `record` HARD-FAILS on a pinned CAP-### with no matching capability in
  functional-spec.md, for exactly the same reason and with the same shape of
  message. A tombstoned (WITHDRAWN) capability counts as unmatched: an id
  kept claimed is not an id anything can verify.

  SEAM LAYER is a closed enum (templates/CONTRACT.md (i)), copied from the
  seam's own declaration in seams.md — never re-derived from this scenario's
  prose. `specclaw-bf-baseline record` extracts it verbatim into
  manifest.json and HARD-FAILS on a missing or non-enum value; there is no
  default. It exists so /specclaw:bf-replay can enforce that the replay test
  exercises the rebuild at the same layer the fixture was captured at — a
  service-layer fixture replayed through HTTP measures transport and
  middleware, not the business rule this scenario pins.

  IDENTITY AND IDEMPOTENCY SCENARIOS (CONTRACT.md (k)): when the rule is
  about identity or idempotency, the Assert (shape) must name boolean
  ASSERTIONS the seam itself can answer — first_call_created,
  second_call_same_entity, second_call_created_duplicate — never a raw
  generated id. Two independently seeded databases never produce the same
  key, so comparing one is guaranteed noise and the rule goes unverified. A
  raw id recorded as evidence belongs in the fixture's normalized_fields, as
  a canonical path (CONTRACT.md (g)).

  A scenario the legacy app can never actually reach (no code path sets
  that state) does not belong here — list it under "No Legacy Behaviour
  Exists" instead, since there is no legacy behaviour to pin as a golden
  master.

  PROVISIONAL marker: when a scenario's pinned business rule is itself
  provisional (domain-model.md already marks it, or a clarifications.md CQ
  promoted from a PQ touches it), append
  `⚠ PROVISIONAL — pending PQ-NNN/CQ-NNN (proposed default: <x>)` to that
  scenario's own "Business rules pinned" line. This is soft-block — the
  scenario is still fully designed, just like any other; the Rule Coverage
  Check below groups these under their own "Provisional pending decision"
  heading. `specclaw-bf-baseline record` detects this literal marker text
  mechanically to set the matching manifest.json fixture entry's `status`
  to `PROVISIONAL` (see templates/CONTRACT.md) — never rename or reformat
  the marker string, or that detection silently stops working.
-->

## Scenarios

{{scenarios}}

## No Legacy Behaviour Exists

{{unreachable_states}}

## Rule Coverage Check

{{rule_coverage}}

## Capability Coverage Check

<!--
  Accounts for every CAP-### in functional-spec.md, exactly as the Rule
  Coverage Check accounts for every DR-###. One entry per capability, in
  one of exactly two forms:

    CAP-014 — covered by GM-031, GM-032
    CAP-015 — NOT-REPLAYABLE: verified by human UI sign-off; the field set
              is asserted by SCR-004's screenshot checklist, not by any
              non-UI seam.

  THE `NOT-REPLAYABLE:` LITERAL IS LOAD-BEARING — NEVER REFORMAT IT.
  `specclaw-bf-replay` greps for this exact token, with the same discipline
  the `⚠ PROVISIONAL` marker above and error-map.md's `### CODE` headings
  are matched by. Rename it, change its punctuation, or drop the colon and
  the detection silently stops working — and because the detection is what
  distinguishes an accepted decision from an unnoticed omission, a silent
  failure here turns a gate green over unverified behaviour.

  THE SECTION HEADING IS EQUALLY LOAD-BEARING. It must read exactly
  `## Capability Coverage Check` with nothing after it. A decorated heading
  (`## Capability Coverage Check (12 capabilities)`) yields ZERO
  classifications — which fails closed, so it gates rather than passes, but
  it does so silently and the entries below look fine.

  THE ID MUST OPEN ITS LINE, and the entry must not sit inside a ``` fenced
  block. Fenced regions are skipped deliberately: this contract is often
  illustrated with a visible example, and an example that armed the gate for
  whatever id it named would be worse than no documentation at all.

  NEVER WRITE `-->` INSIDE ONE OF THESE HTML COMMENTS. The comment stripper
  is line-oriented and does not nest, so an arrow spelled that way ends the
  strip early and turns the rest of the comment — including any example
  classification in it — into live content. Spell arrows `->`.

  AN ID RECORDED IN BOTH FORMS IS REFUSED. `CAP-014 — covered by GM-031`
  alongside `CAP-014 — NOT-REPLAYABLE: ...` is contradictory, and a stale
  exclusion line left behind after a fixture was finally captured must never
  outrank the coverage entry beside it.

  A CLASSIFIED ID MUST EXIST. Every `CAP-###` classified here is checked
  against functional-spec.md's active roster; a typo or a withdrawn id is
  refused rather than trusted, because one mistyped line should not be able
  to turn a red gate green.

  THE REASON IS REQUIRED AND MUST BE NON-EMPTY. A reason is what makes an
  exclusion a decision someone made rather than a blank nobody filled in.
  An empty or whitespace-only reason is treated as UNCLASSIFIED, not as an
  accepted exclusion.

  WHAT THIS SECTION GATES. /specclaw:bf-replay reports
  `NO BEHAVIOUR TO VERIFY` and exits 0 for a backlog item that resolves to
  zero fixtures ONLY IF EVERY CAP-### in that item's own acceptance basis
  is classified NOT-REPLAYABLE here with a non-empty reason — all of them,
  not any of them. Anything else — no classification, a partial one, or an
  empty reason — keeps `NO BASELINE DATA` / INCOMPLETE / exit 2.

  ZERO FIXTURES FOUND IS NEVER, BY ITSELF, SUCCESS. The absence of a
  fixture is the symptom both verdicts share; this section is the only
  thing that separates a decision from an omission. A partially classified
  basis is not partially accepted — it is incomplete, because any-of would
  let one classified capability green-light an item whose other
  capabilities nobody examined.

  A capability listed here that belongs to no backlog item's basis is
  ignored for any verdict: exit 0 quantifies over the ITEM's basis, never
  over this whole document.
-->

{{capability_coverage}}
