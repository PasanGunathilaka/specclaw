# Module Map: {{title}}

**Path analyzed:** {{path}}
**Date analyzed:** {{date}}
**Status:** {{map_status}}

<!--
  The migration/acceptance hierarchy for a brownfield rebuild is:

      MOD-### (module)  →  BL-0## (backlog item)  →  {DR-### (rule),
                                                     CAP-### (capability)}
                                                 →  GM-### (scenario)

  The acceptance basis is the UNION of two id families. A backlog item is
  resolved to its fixtures through both, so behaviour no numbered rule
  states — a form's field set, a composite flow, a default — is still
  citable, countable, and selectable at every replay scope.

  A MODULE is a migration and acceptance unit — the "one flow at a time"
  slice a large legacy system is rebuilt and behaviourally accepted in.
  BL items remain the BUILD units; a module groups existing-granularity
  items and never replaces them. Nothing here splits .specclaw/ — there is
  one manifest, one decisions.md, one backlog, one fixtures directory, and
  modules are a SELECTION DIMENSION over that single shared corpus.

  THIS DOCUMENT IS AGENT-PROPOSED AND HUMAN-CONFIRMED. The Status field
  above reads exactly one of:

    PROPOSED — awaiting human confirmation
    CONFIRMED by <name>, <YYYY-MM-DD>

  A human edits that line to confirm the map. Downstream commands read the
  field mechanically and say plainly, in their own output, when the map they
  grouped by is still PROPOSED — a proposed grouping is a starting point for
  a conversation, not a fact to sequence a migration on. Confirmation is a
  soft block, exactly like an open pending question: it never stops a
  command from running, it just travels with the result.

  ── Per-module structure ─────────────────────────────────────────────────

  ### MOD-### — <Module Name>

  - **Purpose:** <what this module is for, in the project's own language>
  - **Owns (entities):** <entity names this module is the single owner of>
  - **References (not owned):** <entity name (MOD-###), ... — an entity this
    module reads or writes but another module OWNS. THIS DISTINCTION IS
    REQUIRED, not optional: it is the only record of where a flow crosses a
    module boundary, and cross-module flow detection downstream reads
    nothing else. "None" is a valid value; omitting the field is not.>
  - **Services/routes:** <service classes, entry points, routes, commands>
  - **Screens:** <screen/form/view names; SCR-### ids once
    /specclaw:bf-ui has run, otherwise the names as functional-spec.md
    states them>
  - **Business rules:** <DR-### ids this module owns, e.g. "DR-007, DR-011">
  - **Owns (capabilities):** <CAP-### ids from functional-spec.md this module
    is the single owner of, e.g. "CAP-014, CAP-015", or "None". SUBJECT TO
    THE SAME SINGLE-OWNER INVARIANT as entities: a capability is owned by
    exactly one module, never two. This field is what lets a scenario
    pinning only capabilities still carry a Modules tag — without it, a
    DR-less fixture is invisible to every --module run. A capability two
    modules could each plausibly own is trigger T3: a pending question and
    a PROVISIONAL placement under one of them, never a split across both.>
  - **Depends on:** <other MOD-### ids, or "None">
  - **Backlog items:** <BL-0## ids, or "not yet backlog-linked —
    rebuild-backlog.md does not exist yet". THIS FIELD IS A BACK-FILLED
    CONVENIENCE, never authoritative: an item's module is declared by
    rebuild-backlog.md's own "**Module:**" field, because this document is
    produced before any backlog exists. One direction per fact — the map
    owns entity/rule/service/screen ownership, the backlog owns item
    membership.>
  - **Evidence:**
    - <one entry per grouping claim: a file:line, or a quoted passage from
      domain-model.md / functional-spec.md / architecture.md. A module
      boundary asserted without evidence is not a finding.>

  ── Grouping is evidenced, never named after a directory ─────────────────

  A module boundary is derived from what the code actually does: which
  entities are written together, which services call which, which screens
  operate on which entities, which rules cluster around one entity family,
  and which way the dependency edges point. A directory name is a hint, at
  most — plenty of legacy trees group by technical layer (forms/, services/,
  dal/) with no business boundary anywhere in the layout, and grouping by
  those names produces a map that describes the folder structure rather than
  the system. Never let a directory name be the whole justification for a
  boundary.

  ── MOD-### IDs ARE PERMANENT — and reconciled, not regenerated ──────────

  Unlike scenarios.md (a fresh design each run), this document is
  RECONCILED against its own prior version on every regeneration. The
  producing collector reads the live map BEFORE the archive step and hands
  the agent a roster of every prior module's id, name, owned entities, and
  rules. The agent then matches each proposed module against that roster,
  in this order, first match wins:

    1. Exact module name match (case-insensitive, whitespace-normalized).
    2. Otherwise, the strongest owned-entity overlap at or above 50% of the
       prior module's owned entities — and the overlap is stated in the new
       module's own Evidence field.
    3. No match → a genuinely new module, taking the next free id.

  A surviving module KEEPS ITS ID, always. A rename keeps the id and carries
  a "⟲ renamed from <old name>" line right after the heading. A merge of two
  prior modules keeps the LOWER id and leaves the other as a tombstone. A
  split keeps the id on whichever module retains the larger owned-entity
  share and mints a new id for the other. Nothing is ever renumbered,
  reused, or deleted — a module that no longer exists becomes

  ### MOD-### — WITHDRAWN <date>, superseded by MOD-###

  so that any backlog item, scenario, or manifest entry still citing it
  fails loudly instead of silently re-pointing at whatever module now
  occupies that position. MOD-### joins GM/DR/CQ/SQ/UQ/BL/SCR/TK under the
  ID-permanence rule in templates/CONTRACT.md (c).

  When two prior modules match a proposed one at comparable overlap, the id
  is NOT chosen silently: the agent raises a pending question (trigger T3),
  places the module under the higher-overlap candidate's id PROVISIONALLY,
  and marks it — see the PROVISIONAL rule below.

  ── AMBIGUOUS PLACEMENT: ASK, DON'T GUESS ───────────────────────────────

  An entity, rule, service, or screen that two modules could each plausibly
  own is never assigned silently. The agent appends a typed pending question
  to .specclaw/analysis/pending-questions.md (trigger T3, Blocks naming the
  MOD-### ids and the contested item), places the item PROVISIONALLY under
  one module, and appends

    ⚠ PROVISIONAL — pending PQ-NNN (proposed default: <x>)

  to that line. /specclaw:bf-clarify ingests the question, types it
  DECISION (an ownership fork) or SCOPE (whether the module belongs in the
  rebuild at all), and assigns it a permanent CQ-###. Soft block: the map
  is complete and fully usable, the uncertainty is just mechanically
  traceable instead of buried in prose. It clears automatically once the
  question is answered under decisions.md's ## Decisions and this document
  is regenerated.

  ── Coverage ────────────────────────────────────────────────────────────

  Every entity, DR-### rule, CAP-### capability, and screen in
  domain-model.md / functional-spec.md is either owned by exactly one
  module, or listed under "Unassigned" with a stated reason. Silence is a
  defect and is reported as one — the same discipline rebuild-backlog.md's
  Coverage Check applies to capability bullets.

  An UNASSIGNED CAP-### is a real coverage hole, not a tidy-up: a
  capability no module owns can carry no Modules tag, so its fixture is
  selectable only by --all and no module run will ever exercise it. Report
  it with its reason rather than letting it fall out of the map silently.

  Archive-then-replace applies: a re-run archives the prior version into
  .specclaw/analysis/archive/ before writing a new one, exactly like
  domain-model.md and functional-spec.md.
-->

## Modules

{{modules}}

## Cross-Module References

<!--
  Derived from every module's own "References (not owned)" field: one line
  per entity that more than one module touches, naming its owner and every
  referencing module. This is the table that makes a cross-module flow
  visible before anyone tries to accept a module in isolation — a flow whose
  rules span two modules cannot be signed off by exercising either one
  alone, and /specclaw:bf-replay's module rollup reports exactly this
  sharing per module for the same reason.
-->

{{cross_module_references}}

## Module Dependencies

```mermaid
flowchart TD
{{module_dependency_diagram}}
```

{{module_dependency_narrative}}

## Unassigned

<!--
  Entities, DR-### rules, services, or screens no module owns — each with
  the reason it is unassigned (genuinely cross-cutting infrastructure, dead
  code the analysis flagged, or an open pending question about where it
  belongs). "None." is the expected value on a healthy map.
-->

{{unassigned}}

## Coverage Check

{{coverage_check}}
