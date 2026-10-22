# Code Quality Comparison: {{title}}

**Legacy measured:** {{legacy_path}} @ {{legacy_date}}
**Target measured:** {{target_path}} @ {{target_date}}
**Date compared:** {{date}}
**Scan scope:** {{scan_scope}}

<!--
  WRITTEN BY THE QUALITY NARRATION AGENT FROM ONE JSON ARTIFACT. Every
  classification below — improved / unchanged / regressed / NOT-COMPARABLE — was
  computed in bash. Nothing here re-derives one, and nothing here softens one.

  Client-safe body, same rule as the quality report: no internal command, agent,
  script or framework name above "## Internal provenance". Measuring-tool names
  stay, because a comparison whose instruments are hidden cannot be audited.

  ── THE ONE LIE THIS DOCUMENT EXISTS TO REFUSE ──────────────────────────────

  A dimension measured on only one side is NOT-COMPARABLE. It is not an
  improvement.

  This matters more here than anywhere else in the pipeline, because the
  flattering reading is so easy to reach for. A legacy system in a language no
  available tool parses for complexity reports NOT-MEASURED. The rebuild, in a
  well-supported language, reports PASS. Nothing has been shown to have got
  better: nobody knows what the legacy figure was. Presenting that as a win is
  the single most misleading thing this comparison could do, and it would be
  presented to exactly the audience least able to catch it.

  So NOT-COMPARABLE gets its own section, ahead of the wins, and each entry says
  which side was unmeasured and why.

  ── DIFFERENT THRESHOLDS MEANS NO COMPARISON ────────────────────────────────

  When thresholds_match is false the two snapshots were classified against
  different policies, so every status comparison is between two different
  questions. That goes at the TOP of the document, not in a footnote.

  ── THE SCAN SCOPE IS IDENTICAL ON BOTH SIDES, BY CONSTRUCTION ──────────────

  Fill {{scan_scope}} from scan_scope.config_hash — one line, e.g. "identical on
  both sides (sha256:1f3c…)". Both snapshots measured the same set of file
  categories, because the comparison REFUSES to run otherwise: two sides scoped
  differently have different denominators, and subtracting one from the other
  produces a delta that looks real and means nothing.

  So this is a fact to state once, not a caveat to hedge with, and there is no
  mismatch case to narrate — a mismatched pair never reaches this document at
  all. Do not speculate about what a differently-scoped comparison might have
  shown.

  Which files each scope covered is in the quality report's Scan Scope section.
  Do not restate the category tables here.

  ── WHAT A REGRESSION IS ────────────────────────────────────────────────────

  A status band worsening at module level: PASS -> WARN, PASS -> HIGH, or
  WARN -> HIGH. A value that worsened without crossing a band is reported in the
  detail table but is not a regression, because the thresholds are the stated
  policy and everything inside a band is by definition within it. Changing that
  judgement is a config change, not a reading of this document.
-->

## Verdict

{{verdict}}

<!--
  In gated mode, the gate verdict quoted exactly, with the regression count and
  every regressed module/metric named. In advisory mode, say plainly that this
  comparison gated nothing.

  If thresholds_match is false, that statement comes first and qualifies
  everything below it.
-->

## Summary

{{summary}}

<!--
  Counts of improved / unchanged / regressed / NOT-COMPARABLE dimensions, then
  two or three sentences on what the comparison actually establishes — bounded
  by how much of it was comparable at all.
-->

## Not Comparable

{{not_comparable}}

<!--
  DELIBERATELY BEFORE THE IMPROVEMENTS. Every dimension measured on one side
  only, with which side was unmeasured and the reason. Plus any module present
  in one snapshot and not the other, which has no counterpart and therefore
  nothing to compare.

  Each entry states what is NOT known, not what might be true.
-->

## Regressed

{{regressed}}

<!--
  Every regressed module/metric with both statuses and both values. No
  softening, no explaining away, and nothing added that the artifact does not
  list.
-->

## Improved

{{improved}}

<!--
  Every improved module/metric with both statuses and both values. Each one is a
  real, measured improvement on a dimension measured on BOTH sides — that is
  what earns it this section rather than the Not Comparable one above.
-->

## Unchanged

{{unchanged}}

## Methodology

{{methodology}}

<!--
  Which tool produced which metric on each side, the thresholds both were
  classified against, and how a regression is defined. Then the limitation, said
  plainly: this compares structural properties of source code between two
  codebases. It does not establish that the target behaves like the legacy
  system. Behavioural equivalence is a different question, answered by
  fixture-based replay, and no number in this document speaks to it.
-->

---

## Internal provenance

<!--
  DELETE THIS SECTION BEFORE THE REPORT LEAVES THE TEAM.
-->

{{provenance}}
