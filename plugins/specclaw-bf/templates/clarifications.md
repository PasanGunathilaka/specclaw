# Clarifications: {{title}}

**Date generated:** {{date}}
**Documents swept:** {{docs_swept}}

<!--
  This file is drafted by /specclaw-bf:bf-clarify (extract mode) and re-rendered
  on every subsequent run — never freehand-edited except for the fields a
  human fills in below each question.

  THREE question families, sharing one field structure and one --resolve
  pipeline, distinguished only by ID prefix and where their content comes
  from:

    CQ-NNN — Extracted from .specclaw/analysis/*.md by the clarify-
             extractor agent. Allocated per-repo, in extraction order.
    SQ-NNN — The standard bank (plugins/specclaw/references/clarify-
             standard-questions.md). IDs are FIXED by the bank file
             itself, not allocated per-repo — SQ-001 always means "target
             platform," in every project. Type/Blocking/Options/Proposed
             default are bash-owned, spliced in verbatim from the bank
             file on every render; only Finding/Why it matters/Source/
             Answer/Decided by/Date are ever agent- or human-authored for
             an SQ. Once an SQ has been rendered here (or listed under
             Not applicable below), it is never re-evaluated by a later
             run — a bank question doesn't flip-flop between applicable
             and not applicable across runs.
    UQ-NNN — Per-repo custom questions, ingested by bash (no agent
             involved) from .specclaw/analysis/custom-questions.md.
             Allocated per-repo, in file order, same permanence rules as
             CQ. De-duplicated by each question's original heading text,
             recorded in its Source field — editing an already-ingested
             heading in custom-questions.md later does NOT retroactively
             rewrite the rendered UQ; edit it here instead.

  Per-question block format — every question in every family follows this
  exact structure:

  ### <CQ|SQ|UQ>-NNN — <short title>

  - **Type:** DECISION | DATA | SCOPE | DEFECT | MECHANICAL | TARGET-GAP | CONFLICT
  - **Blocking:** yes — <what it blocks> | no
  - **Source:** <doc § section and/or file:line (CQ); "Standard bank vN" or
    a cited ADR/decision (SQ); custom-questions.md + the original heading
    text (UQ)>
  - **Finding:** <what was found and why it's uncertain>
  - **Why it matters:** <consequence of leaving this unresolved>
  - **Options:**
    1. <option>
    2. <option>
  - **Proposed default:** <an option number, or "adopt as-is">
  - **Answer:**
  - **Decided by:**
  - **Date:**

  Display ordering on every (re-)render: each family renders as its own
  section (Standard -> Custom -> Extracted, then Not applicable at the
  end), and WITHIN each family, blocking questions first, then grouped by
  Type in this fixed order — DECISION, DATA, SCOPE, DEFECT, MECHANICAL,
  TARGET-GAP, CONFLICT. IDs in all three families are permanent
  identifiers, not position — a re-run may move a block to a different
  place on the page but must never change its ID, and must never touch an
  Answer/Decided by/Date field a human has already filled in.

  A standard-bank question the agent judged inapplicable to this repo
  never disappears silently — it's listed one line each under "Not
  applicable" below, with the reason, for auditability.

  To answer a question: type your answer directly after "**Answer:**" (one
  line, or several up to the next "**Decided by:**" line), fill in
  "**Decided by:**" (your name) and "**Date:**" (YYYY-MM-DD). Then run
  `/specclaw-bf:bf-clarify --resolve` to promote it into decisions.md.
-->

## Summary

{{summary}}

## Standard Questions

{{standard_questions}}

## Custom Questions

{{custom_questions}}

## Extracted Questions

{{questions}}

## Not Applicable

{{not_applicable}}
