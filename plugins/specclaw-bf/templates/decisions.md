# Decisions: {{title}}

**Date generated:** {{date}}
**Source:** .specclaw/analysis/clarifications.md

<!--
  This is the clean, pinnable decision record /specclaw-bf:bf-clarify --resolve
  produces from clarifications.md's answered questions, swept across all
  three question families (CQ-NNN/SQ-NNN/UQ-NNN). Every entry below is a
  mechanical transcription of an already-answered question — the
  Answer/Decided by/Date fields are transcribed, never reinterpreted. Each
  entry carries a **Family:** line (Extracted | Standard bank | Custom
  (per-repo)) derived mechanically from the question's ID prefix, so a
  reader can tell at a glance whether a decision came from this repo's own
  code, the plugin's standard bank, or a per-repo custom question.
  Re-running --resolve is idempotent: it always reflects the current state
  of clarifications.md's answered blocks, replacing this file's prior
  content wholesale (the prior version is archived, never lost).

  Pin this file — add `.specclaw/analysis/decisions.md` to config.yaml's
  `context.pin` (raise `max_lines` accordingly) and `git add` it, so every
  downstream /specclaw:propose, /specclaw:plan, and /specclaw:build cites
  these decisions as grounding instead of re-deriving them. Discovery
  enumerates via `git ls-files` — an untracked file is invisible to it.
-->

## Decisions

{{decisions}}

## ADR Promotion Candidates

{{adr_candidates}}

## Outstanding Questions

{{unanswered}}
