# UI Fidelity Review: {{change}}

**Date generated:** {{date}}
**Backlog item:** {{bl_item}}
**UI fidelity policy:** {{policy}} (SQ-013)
**Legacy commit the screenshots were captured at:** {{legacy_commit_sha}}
**Screens in scope:** {{screen_count}} · **Rows needing a signature:** {{row_count}}

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder
  token inside this comment's own prose — filling this template is a dumb
  global string replace and would corrupt the comment.

  THIS FILE IS EVIDENCE, NOT A COMPUTED VERDICT. Nothing in it is a
  pass/fail produced by specclaw. Every row is a question put to a named
  human, and the row is only answered when that human types their name and
  the date into it. An unsigned row is an open question; an unsigned file
  proves nothing at all.

  That is deliberate, and it is the reason this exists as a separate
  artifact from /specclaw-bf:bf-replay. Behavioural fidelity is proved
  mechanically, by diffing recorded legacy outputs against the rebuild's
  actual outputs. Visual fidelity is not: UI stays excluded from the
  golden-master seam taxonomy (templates/seams.md's "Excluded: UI
  Automation"), no fixture compares a screenshot, and specclaw never
  claims pixel-identity. A person looks at the two and says whether they
  match, on the record, with their name against it.

  WHAT TO DO WITH IT: complete every row, then commit this file with the
  change's PR, alongside the replay evidence package. Together they are
  the change's full fidelity record — mechanical proof for behaviour,
  signed human review for appearance.

  ROW TYPES:
    - Token rows appear under every policy. The Expected column is the
      legacy value with its source; the "Where to check" column is a
      path:line in the NEW repo that a bf-ui-analyst run located. A
      NOT FOUND there is a real finding, not an omission — it means the
      token has no definition in the rebuild yet.
    - Layout rows appear only under FAITHFUL. Under THEME-ONLY the layout
      is deliberately reinterpreted for the target platform, so a layout
      row would assert a requirement the decision explicitly waived.
-->

## How to complete this review

1. Open the legacy screenshot referenced for each screen below. Its sha256 is recorded so you can confirm you are looking at the same file that was captured — if the hash no longer matches, the evidence changed and the review is void.
2. Open the same screen in the rebuilt application, and the `Where to check` location in the new code.
3. For each row, decide whether the rebuild satisfies it, then fill in **Verified by** (your name), **Date** (YYYY-MM-DD), and **Notes** (required whenever the row is not satisfied — say what differs).
4. Commit the completed file with the PR.

## Screens

{{review_sections}}

## Missing Legacy Evidence

<!--
  Screens or states in scope for this change whose legacy screenshot was
  never captured (they are in ui-manifest.json's missing list, or absent
  from it entirely). A reviewer cannot complete those rows: there is
  nothing to compare against. Capture them per screenshot-checklist.md and
  re-run /specclaw-bf:bf-ui --record, then regenerate this file.
-->

{{missing_evidence}}

## Locations Not Found in the New Repo

<!--
  Every token or layout point whose location in the rebuild could not be
  found. Each is either work not done yet or a token the rebuild
  deliberately dropped — both need a human's judgement, which is why they
  are listed here rather than quietly rendered as an empty cell.
-->

{{not_found_list}}

---

_This review is complete only when every row above carries a name and a date. specclaw does not, and cannot, complete it._
