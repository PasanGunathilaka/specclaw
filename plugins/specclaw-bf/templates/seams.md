# Baseline Seams: {{title}}

**Date generated:** {{date}}
**Grounded in:** .specclaw/analysis/domain-model.md{{supplementary_docs_note}}

<!--
  A seam is a place where the legacy app's behaviour can be observed as
  input -> output without driving its UI. Every candidate must be ranked
  into exactly one of these classes, and every seam entry must declare its
  `seam_layer` — the closed enum in templates/CONTRACT.md (i):

  | Class                     | seam_layer      | Cost   | Fidelity | Notes |
  |----------------------------|-----------------|--------|----------|-------|
  | Pure function              | `pure-function` | lowest | highest  | No setup, fully deterministic. Capture these first. |
  | Stateful service boundary   | `service`       | medium | high     | Needs a database arrange step per scenario. |
  | Data/persistence boundary   | `persistence`   | medium | medium   | Good for cascade and delete-rule behaviour. |
  | HTTP/API boundary           | `http`          | medium | medium   | Request in, response out. Real, but it also measures routing, serialization, and middleware — prefer an inner layer when the same rule is reachable there. |
  | UI automation               | *(none)*        | highest| lowest   | Excluded — explain why in this document, don't just omit it. |

  Declare the layer explicitly per seam entry, e.g. `- **Seam layer:**
  service`. Each scenario in scenarios.md copies its seam's declared layer
  verbatim, and /specclaw-bf:bf-replay mechanically enforces that the replay
  test targets that same layer — so a layer chosen loosely here becomes a
  seam-mismatch downstream, not a silently weaker comparison.

  Every ranking must be justified with a real citation (file:line, or a
  quote from an analysis document) — a seam listed without justification is
  not a finding. Determinism findings belong in "Capture Blockers" below,
  not folded into a seam's description.

  /specclaw-bf:bf-baseline does not run the legacy app and does not capture
  fixtures itself — this document designs the harness; a human runs the
  capture (`--harness` then `--record`). That boundary is deliberate, not a
  gap to paper over.
-->

## Seam Ranking

{{seam_ranking}}

## Excluded: UI Automation

{{ui_exclusion_rationale}}

## Capture Blockers (Determinism Audit)

{{determinism_audit}}

## Recommended Seam

{{recommended_seam}}
