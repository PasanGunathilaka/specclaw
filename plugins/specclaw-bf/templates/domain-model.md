# Domain Model: {{title}}

**Path analyzed:** {{path}}
**Date analyzed:** {{date}}

## Entities

{{entities}}

## Relationships

```mermaid
erDiagram
{{relationships_diagram}}
```

{{relationships_narrative}}

## Business Rules

<!--
  Every business rule carries a permanent DR-NNN ID, assigned in the order
  rules are found, e.g.:

  1. **DR-007 — Promised-vs-delivered verdict computation** — <rule prose>

  (or the closest fit to this document's existing heading/list style — the
  ID is the stable part, not the surrounding markdown shape). DR-NNN IDs
  are permanent identifiers, not position — a later re-run may find rules
  in a different order, but an already-assigned ID is never reused or
  renumbered. A new rule takes the next free ID. A rule that no longer
  applies leaves a tombstone in place rather than disappearing, e.g.:

  4. **DR-004 — withdrawn 2026-08-01, superseded by DR-015**

  so that any other document citing DR-004 (clarifications.md, a rebuild
  backlog item, a golden-master scenario) fails loudly instead of silently
  pointing at whatever rule happens to occupy that position now.

  PROVISIONAL marker: whenever an entity field, business rule, or
  enumeration meaning can't be evidenced (see the analyst agent's own
  "Ask, Don't Guess" triggers T1-T6), the affected line carries
  `⚠ PROVISIONAL — pending PQ-NNN (proposed default: <x>)` appended after
  its text — e.g. a field's capture widget renders as
  `PROVISIONAL(PQ-004, default: text)` rather than a bare `text`. This is
  soft-block, not an omission: the finding is still fully documented
  (a Named Gap, an Inference: line, or the Mechanical Recording Rule still
  apply exactly as before), the marker just makes the uncertainty
  mechanically traceable into rebuild-backlog.md/scenarios.md/manifest.json
  downstream instead of relying on someone noticing the prose. It clears
  automatically the next time this document is regenerated after the
  underlying PQ-NNN/CQ-NNN is answered under decisions.md's ## Decisions.
-->

{{business_rules}}

## Enumerations

{{enumerations}}
