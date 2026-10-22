# UI Inventory: {{title}}

**Path analyzed:** {{path}}
**Date analyzed:** {{date}}
**View technology identified:** {{view_technology}}
**Cross-referenced against:** {{cross_refs}}

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder
  token inside this comment's own prose (not even to describe it) — filling
  this template is a dumb global string replace, and a token mentioned here
  would get overwritten along with the real placeholder below, corrupting
  this comment. Refer to placeholders by section name instead.

  WHAT THIS DOCUMENT IS. The per-screen structural and visual record of the
  legacy application's user interface, extracted from its source by
  /specclaw-bf:bf-ui (Mode A) — one section per screen, each with a permanent
  SCR-### id. It is the design half of the UI fidelity workstream; the
  evidence half is the human-captured screens/ folder recorded in
  ui-manifest.json.

  NOT THE SAME DOCUMENT as functional-spec.md's own "## UI Inventory"
  section. That one is /specclaw-bf:bf-domain's detection-level roster (one
  line per form/view file: name, class, parsed or detection-only, control
  counts). This one is the deep per-screen structure: layout regions,
  widget-by-widget composition, navigation edges, and evidenced states.
  Every SCR entry below must cross-reference its functional-spec.md UI
  Inventory line (where one exists) and the domain-model.md fields its
  widgets bind to, so the two documents can never silently diverge.

  UI IS NEVER A GOLDEN-MASTER SEAM. templates/seams.md's "## Excluded: UI
  Automation" class stands unchanged — nothing in this document is
  replayable, and nothing here is ever compared by /specclaw-bf:bf-replay.
  Visual fidelity is verified by a human checklist with recorded evidence
  (ui-review.md), never by fixture diffing. This document must never be
  written or read as a promise of pixel-identity.

  SCR-### IDS ARE PERMANENT, exactly like DR-NNN/BL-NNN/GM-NNN/CQ-NNN/
  PQ-NNN — assigned once, never renumbered, never reused, across every
  regeneration and archive cycle. A re-run carries every prior id forward
  by matching screen content (not position); a screen that no longer
  exists becomes a one-line tombstone ("### SCR-NNN — REMOVED — <reason>,
  <date>") rather than being deleted or its id recycled.

  Per-screen block format — one entry per screen, in navigation order
  where the code evidences one (entry screen first), otherwise in
  definition-file order:

  ### SCR-NNN — <Screen Name>

  <optional, only when a pending question is open on this screen:>
  ⚠ PROVISIONAL — pending PQ-NNN (proposed default: <x>)

  **Purpose:** Inference: <what a user does on this screen>
  **Defined in:** <path:line of the view/markup definition>
  **Functional-spec UI Inventory line:** <the quoted line, or "no matching
    line — see Widget Cross-Reference Findings">
  **Navigation in:** <how a user reaches this screen> — `path:line`
  **Navigation out:** <where it leads, one per edge> — `path:line`

  **Layout structure:**
  - <one bullet per region/container, described NEUTRALLY — its role, its
    position relative to its siblings, its ordering, and what it contains.
    Never a view-framework type name (write "a full-width band at the top
    holding the title and a right-aligned action group", not the framework's
    class name for it). Nested regions are nested bullets. Every bullet
    carries its own `path:line` citation.>

  **Widgets:**

  | Field / control | Widget type | Domain-model ref | Citation |
  |---|---|---|---|
  | <label as the user sees it> | <widget type, per the vocabulary below> | <domain-model.md entity.field, enum, or "—"> | `path:line` |

  Widget-type vocabulary — the same one domain-model.md/functional-spec.md
  already use (bf-domain-analyst's Field Semantics & Capture-Widget Rule):
  text input | memo/textarea | numeric input | date picker | select/combo
  (naming where its options come from) | checkbox/toggle | FILE/IMAGE
  UPLOAD | button | grid/list | label/static text. A widget type that
  cannot be cited from the view definition renders as
  PROVISIONAL(PQ-NNN, default: text) — never a bare guessed type, and
  never inferred from the field's storage type.

  **States evidenced in code:** <one per evidenced state, each cited —
    e.g. "empty (`path:line`), validation-error (`path:line`)". Reads
    "none beyond the default view" when the code evidences no other state.
    A state the code does not evidence is never invented here, because
    every state listed becomes a screenshot a human has to capture.>
  **Token groups referenced:** <TK- group ids from design-tokens.json that
    apply to this screen, or "none">

  EVERY CLAIM IS CITED. A layout region, widget, navigation edge, or state
  with no `path:line` citation is not a finding — it is either dropped, or
  (when it meets a T1-T6 trigger) raised as a pending question and the
  affected line marked PROVISIONAL. Purpose lines are inherently inferred
  and carry the `Inference:` prefix, exactly as in domain-model.md.
-->

## Screens

{{screens}}

## Widget Cross-Reference Findings

<!--
  Two-way mismatches between this document and domain-model.md, reported
  and never silently reconciled: a widget on a screen with no
  corresponding domain-model field, and a domain-model field with no
  widget on any screen. Each line names both sides and cites the evidence
  for the side that exists. Reads "None — every widget maps to a
  documented field and every documented field appears on a screen." when
  there genuinely are none.
-->

{{crossref_findings}}

## Named Gaps

<!--
  Anything the extraction could not complete with confidence: a screen
  whose definition could not be parsed, a navigation edge that could not
  be traced, a theme/resource file whose active-ness could not be
  established, a widget whose type is unevidenced (also a pending
  question), a state suspected but not cited. Each gap names what is
  missing and why.
-->

{{named_gaps}}
