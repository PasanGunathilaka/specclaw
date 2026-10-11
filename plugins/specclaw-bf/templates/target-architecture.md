# Target Architecture: {{title}}

**Path analyzed:** {{path}}
**Date generated:** {{date}}
**Plugin version:** {{plugin_version}}

{{status_header}}

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder token
  inside this comment's own prose (not even to describe it) — the render
  step's template substitution is a first-occurrence string replace, and a
  token named here would be consumed by this comment instead of the real
  placeholder below. Refer to placeholders by section name instead.

  WHAT THIS DOCUMENT IS. The legacy side of a brownfield rebuild is richly
  documented — architecture.md, domain-model.md, module-map.md. The target
  side used to be scattered across decisions.md, ADRs, bootstrap-plan.md and
  the backlog, with nothing that showed the shape of the thing being built.
  This is that document: the target architecture, synthesised from decisions
  already made, in the same C4 vocabulary the legacy view uses so the two can
  be read side by side.

  IT IS DERIVED, NEVER DECIDED HERE. Every claim about the target rests on a
  recorded decision and cites it by id. Nothing in this file decides
  anything: a target element that no SQ/CQ/UQ sanctions is a gate violation
  and the render step refuses it, and a claim resting on a still-open
  question renders PROVISIONAL(<id>) rather than becoming a confident box in
  a diagram. Changing what this document says means answering a question in
  clarifications.md and re-running --resolve, never editing here.

  THE STATUS BLOCK above is bash-computed, never agent-drafted: the
  COMPLETE/PROVISIONAL verdict and the ids behind it, the warnings, and the
  inputs consumed. Recomputed from scratch every run.

  FULLY REGENERATED EVERY RUN. There is no hand-preserved zone anywhere in
  this file — unlike rebuild-backlog.md's human-added status notes. A
  re-run archives the prior version into .specclaw/analysis/archive/ and
  writes a new one wholesale, exactly like architecture.md and decisions.md.

  WRITTEN IN THE LEGACY REPO. This document is produced by
  /specclaw-bf:bf-blueprint alongside every other analysis output and is never
  created or edited in the rebuild repo. It travels into the new repo as
  readability, never as something a verdict is computed from.

  ── Diagrams ─────────────────────────────────────────────────────────────

  Mermaid's native C4 diagram types: C4Context for the system context,
  C4Container for the container view, C4Component for one view per module.
  One Context diagram, one Container diagram, and one Component diagram per
  MOD-###, grouped under "## MOD-###" headings that mirror rebuild-backlog.md's
  own module grouping so the two documents line up module for module.

  A module whose target shape is entirely undecided gets a SINGLE
  PROVISIONAL placeholder box naming the question that blocks it — never an
  invented design. A speculative component diagram is worse than an empty
  one: it reads as a plan.

  ── The legacy-to-target mapping table ──────────────────────────────────

  One row per legacy container/component from architecture.md. Four columns:

    | Legacy element | Target element | Sanctioning decision | Status |

  Status is one of:
    DECIDED               — the target element rests on a recorded decision
    PROVISIONAL(<id>)     — it rests on a question still open
    RETIRED-BY-DECISION   — a decision explicitly drops this legacy element,
                            and the cited id is that decision

  EVERY ROW CITES SOMETHING. A target element with no sanctioning citation
  and no PROVISIONAL/RETIRED marker is a gate violation, and the render step
  fails the run naming the row. That check is the whole point of the table:
  it is the one place where "what we are building" is forced to line up,
  element by element, with "what somebody actually decided".
-->

## Target Overview

{{overview}}

## Target Stack, Persistence, Hosting and Auth

<!--
  Four short subsections, every claim carrying the id of the decision that
  sanctions it, or rendering PROVISIONAL(<id>) when the question is open.
  These are the four things every downstream reader — /specclaw-bf:bf-bootstrap
  most of all — needs stated in one place.
-->

{{stack_sections}}

## System Context

```mermaid
{{context_diagram}}
```

{{context_narrative}}

## Containers

```mermaid
{{container_diagram}}
```

{{container_narrative}}

## Components by Module

{{component_sections}}

## Legacy → Target Mapping

{{mapping_table}}

## Data Migration Approach

{{data_migration}}

## Deployment View

{{deployment}}

## Open Questions

<!--
  Bash-computed from clarifications.md + decisions.md: every blocking
  question still unanswered, and what it holds PROVISIONAL in this document.
  Answer these with /specclaw-bf:bf-clarify (then --resolve) and re-run
  /specclaw-bf:bf-blueprint — the markers clear by regeneration alone.
-->

{{open_questions}}
