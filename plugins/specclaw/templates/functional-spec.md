# Functional Spec: {{title}}

**Path analyzed:** {{path}}
**Date analyzed:** {{date}}

## Capabilities

<!--
  Every capability carries a permanent CAP-NNN ID, assigned in the order
  capabilities are found, e.g.:

  1. **CAP-014 — Create a purchase order** — <what the user can do, the
     control/menu path that exposes it, and each field with its capture
     widget per the Field Semantics & Capture-Widget Rule>

  (or the closest fit to this document's existing heading/list style — the
  ID is the stable part, not the surrounding markdown shape.)

  CAP-NNN IDS ARE PERMANENT, exactly like DR-NNN and MOD-NNN
  (templates/CONTRACT.md (c)). They are the SECOND HALF OF THE ACCEPTANCE
  BASIS: the migration hierarchy is

      MOD-### → BL-0## → {DR-###, CAP-###} → GM-###

  and /specclaw:bf-replay resolves a backlog item to its fixtures through
  the union of both families. A renumbered CAP-### silently re-points a
  scenario's pin, a manifest entry's capabilities_pinned, and a module's
  ownership claim without changing a single hash — which is why the
  producing collector hands the agent the PRIOR capability roster
  (prior_capabilities[] plus next_cap_id) before the archive step, exactly
  as it does for MOD-###.

  RECONCILED BY CONTENT, NEVER BY POSITION. A regeneration that finds the
  same capability in a different order keeps its id. Only a genuinely new
  capability takes next_cap_id. A capability that no longer exists leaves a
  tombstone

  1. **CAP-NNN — WITHDRAWN <date>, <reason>**

  rather than disappearing, so its id stays claimed forever and anything
  still citing it fails loudly instead of re-pointing. Tombstones still
  count toward the next free id.

  WHY CAPABILITIES ARE IDENTIFIED AT ALL. A capability is behaviour a
  rebuild can silently drop: a form with twelve fields reimplemented with
  ten, a composite flow that loses a step, a default that drifts. None of
  that is stated by any DR-### rule, so before these ids existed nothing
  downstream could cite it, no coverage check could count it, and a
  CRUD-shaped backlog item could never be mechanically accepted — its
  replay run reported INCOMPLETE, indistinguishable from an item nobody
  had looked at.

  A capability with no id (a document written before this contract) is
  reported as unidentified, never back-assigned in place: this document is
  archive-then-replace and ids arrive on the next regeneration.
-->

{{capabilities}}

## Workflows

{{workflows_content}}

## UI Inventory

{{ui_inventory}}

## Named Gaps

{{named_gaps}}
