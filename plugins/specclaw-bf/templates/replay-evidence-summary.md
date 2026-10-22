# Replay Evidence — {{target}}

<!--
  The one mutable file in this evidence tree — regenerated in full on
  every /specclaw-bf:bf-replay run for this change (and by --prune-evidence).
  Everything else under replay-evidence/run-<id>/ is written once and
  never touched again. Written in plain language on purpose: this page is
  for the client, not just the dev team.
-->

This page tracks every automated check comparing the rebuilt application's behaviour against recordings of how the original application actually behaved. Each row below is one such check: real, previously captured scenarios from the old application are replayed against the new one, and the counts show how many matched exactly, how many behaved differently in a way the team already reviewed and explicitly decided to allow, how many behaved differently with no such decision on file, how many failed outright, and how many couldn't be checked at all (each with a stated reason — never a silent skip). Newest run first. No commentary beyond the numbers — the numbers are the evidence.

**Wording differences are counted separately, on purpose.** A rebuilt application on a different framework reports errors under different type names and in different words while making exactly the same business decision. Those are counted under **Wording Only** and never treated as the application behaving differently — the columns that matter for whether the rebuild is faithful are Match, Allowed Change, and Unexplained Change.

**A verdict marked `*`, with stub ids in the Stubs column, was earned while part of the system was standing in for another part that had not been built yet.** The comparison genuinely ran and genuinely matched — but some of what it matched against was a deliberate, recorded placeholder rather than the real module. That is not a failure and it is not a warning about quality; it is a statement about how much of the system was real at the time. Those runs are re-run once the real module lands, and the `*` disappears when it does. The placeholders themselves are listed in the run's own report, under **Stubs In Effect**.

| Date | Fixtures Replayed | Match | Allowed Change (documented) | Unexplained Change | Wording Only | Awaiting Decision | Error | Not Replayable | Stubs | Overall Verdict | Evidence Folder |
|---|---|---|---|---|---|---|---|---|---|---|---|
{{table_rows}}
