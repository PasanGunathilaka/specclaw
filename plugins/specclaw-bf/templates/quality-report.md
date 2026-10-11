# Code Quality Report: {{title}}

**Path measured:** {{path}}
**Date measured:** {{date}}
**Scope:** {{scope}}

<!--
  WRITTEN BY THE QUALITY NARRATION AGENT, FROM ONE JSON ARTIFACT AND NOTHING
  ELSE. Every status, severity and rollup below was computed in bash before this
  document existed. Nothing here re-derives, adjusts or second-guesses one.

  ── CLIENT-SAFE BODY ────────────────────────────────────────────────────────

  Everything above "## Internal provenance" must survive being pasted into a
  client deck. So the body names no internal command, agent, script, or the
  framework itself.

  This is the ONE document in .specclaw/analysis/ that hides its producing
  command. Every other one names it freely. That is deliberate and is not a
  defect to be fixed: a quality report is the artifact most likely to be
  forwarded outside the team, and a reader who cannot tell an internal pipeline
  name from a finding will treat both as noise.

  Two things it does NOT mean:

    - Measuring-tool names belong in the body. "Complexity was measured with
      lizard" is a methodology statement a client is entitled to, and removing
      it makes every number unauditable. It is the internal pipeline that stays
      out, not the instrument.

    - It is not a licence to be vague. "This module's largest function has a
      cyclomatic complexity of 34 against a threshold of 20" is client-safe.
      "Quality concerns were identified" is just useless.

  ── THREE BLOCKS ARE COPIED, NOT WRITTEN ────────────────────────────────

  Three regions of this document are bounded by anchors that look like

    <!-- quality-report:scan-funnel:begin -->  …  <!-- quality-report:scan-funnel:end -->

  Between each pair goes ONE field from the artifact's `report_blocks`, pasted
  verbatim, character for character, with nothing added and nothing reflowed:

    scan-funnel        report_blocks.scan_funnel_md
    module-rollup      report_blocks.module_rollup_md
    coverage-sentence  report_blocks.coverage_sentence_md

  A bash lint runs after this document is written and diffs each region against
  the field it came from. A single changed byte fails the run and names the
  region, so there is no version of this that "mostly" works.

  This exists because the previous report invented a MOD-010 row for a
  nine-module artifact, summed the rollup as "6 HIGH, 3 WARN, 1 PASS" for a set
  holding five HIGH, and reported "1,892 measured files" for a funnel of 2,232
  enumerated, 340 excluded, 1,892 in scope, of which 1,022 sized, 652
  function-measured and 466 duplication-measured. Every one of those numbers
  already existed, correctly, in the artifact. What did not exist was any reason
  the document had to agree with it.

  So: no figure in this report is arrived at by adding, subtracting, counting or
  reading off a table. Prose may REFER to a number that appears in a block. It
  may never produce one.

  ── SCOPE AND COVERAGE COME FIRST, AND NEITHER IS A CAVEAT ──────────────────

  The Scan Scope and Measurement Coverage sections sit ABOVE the findings,
  deliberately, and in that order. A reader who takes a module rollup at face
  value without knowing that complexity was unmeasurable for a third of the
  tree — or that a third of the tree was never in scope — has been misled, and
  putting either at the bottom under "limitations" is exactly how that happens.

  They answer two different questions and both have to be asked. Scope says
  which FILES were looked at; coverage says which METRICS could be computed for
  them. A file left out of the scan and a metric no tool could compute are both
  reported, never inferred, and never quietly netted off against each other.

  NOT-MEASURED is a result, never a gap to be filled. No value in this document
  is ever estimated, extrapolated or inferred. The three reasons and what each
  one actually means to a reader:

    language_unsupported  no available tool parses this language for this
                          metric. Permanent; installing something does not fix
                          it.
    tool_missing          the tool that measures this was not installed when
                          the measurement ran. Fixable, and worth saying so.
    parse_error           the tool ran and could not read these files. State
                          the count; do not speculate.

  ── MODULE NUMBERS DESCRIBE THE CITED SLICE ─────────────────────────────────

  Nothing in this project maps a source file to a module. The module map maps
  modules to entities, rules, services and screens; the file-to-module join
  therefore uses only the file paths each module cites in its own Evidence
  bullets, and Evidence is a sample of a boundary rather than an inventory of
  one.

  So a large MOD-UNASSIGNED bucket is the EXPECTED result on a map nobody has
  enriched, and it means each module's numbers cover its cited files rather than
  the whole module. Say so where the rollup is reported. Never redistribute
  unassigned files by guesswork — the remedy is more citations in the map.
-->

## Summary

{{summary}}

<!--
  Two or three sentences a delivery lead can act on: how much was measured, how
  many modules sit at HIGH, and the single thing most worth attention. No
  hedging, no throat-clearing.
-->

## Scan scope

<!-- quality-report:scan-funnel:begin -->
{{scan_funnel}}
<!-- quality-report:scan-funnel:end -->

{{scan_scope}}

<!--
  WHAT WAS MEASURED, AND WHAT WAS DELIBERATELY NOT. Short — a paragraph and a
  small table — and it comes FIRST, ahead of coverage, because it answers the
  earlier question. Coverage says which metrics could be computed for the files
  that were looked at; this says which files were looked at.

  Read it from the artifact's `exclusions` block and from nowhere else:

    exclusions.categories       each category and whether it was applied
    exclusions.extra_excludes   this project's own additions
    exclusions.include_overrides  files deliberately measured despite matching
    exclusions.census.by_category  how many files each category accounted for

  THE FUNNEL IS THE BLOCK, AND THE BLOCK IS NOT YOURS TO WRITE. `{{scan_funnel}}`
  is `report_blocks.scan_funnel_md`, pasted verbatim between its anchors. Every
  file count in this section is in it. Do not restate one of its figures in a
  form the block does not use, do not total two of its rows, and do not describe
  the in-scope count as the number of files that were "measured" — the block
  distinguishes the list every metric received from what each metric managed on
  it, and that distinction is the reason it exists.

  AN EXCLUDED FILE IS A DECISION, NOT AN ABSENCE. The block above already gives
  the totals; your prose says what the exclusions WERE, from `census.by_category`
  — "of the files outside the scan's scope, dependency and build output
  accounted for the largest share, then test code, then generated migrations".
  Positively, never as a caveat, an apology or a limitation, and never left
  implied: a reader who assumes every file was measured has been misled just as
  badly as one who assumes every metric was.

  Say in one sentence why production code is what gets measured: a hotspot in a
  generated migration or a vendored dependency is a finding about a code
  generator or a third party, not about this codebase, and leaving it in
  distorts every module rollup it lands in.

  A `disposition` of `measured_separately` is NOT an exclusion. Those files were
  measured, into their own bucket, and are reported apart from the production
  modules rather than left out. Say which bucket and where its numbers are.

  If `include_overrides` is non-empty, name what was forced back in and note
  that it was a deliberate choice.

  The census counts FILES, not lines. Do not convert one into the other, do not
  estimate the volume of code skipped, and do not describe the excluded share as
  a percentage of the codebase's size — the artifact does not carry that figure
  and inventing it is exactly the kind of number that gets quoted back.
-->

## Measurement Coverage

{{coverage}}

<!--
  Per language: file count, which metrics were computed, and every metric that
  was not — with its reason translated into plain language and its file count.
  Close with one concrete sentence naming the consequence, e.g. "cyclomatic
  complexity was not measurable for the 58 Pascal source files; those files
  report size and duplication only".

  Then the module-grouping caveat: how many files landed under MOD-UNASSIGNED,
  how many were cited by more than one module and therefore left unassigned, and
  whether the module grouping itself is confirmed or still a proposal.
-->

## Module Rollup

<!-- quality-report:module-rollup:begin -->
{{module_rollup}}
<!-- quality-report:module-rollup:end -->

{{module_rollup_notes}}

<!--
  THE TABLE IS NOT YOURS TO BUILD. `{{module_rollup}}` is
  `report_blocks.module_rollup_md`, pasted verbatim between its anchors: one row
  per module with files, LOC, the status of each dimension and the overall
  rollup, then a closing line giving the module count and the count at each
  status. A dimension nobody could measure already reads NOT-MEASURED rather
  than PASS, because those are different claims and collapsing them turns "we
  did not look" into "we looked and it was fine".

  Do not add a row, remove a row, reorder rows, reformat a cell, or restate the
  status counts. This is the section that grew a tenth module out of nothing and
  mis-summed its own statuses, and both were arithmetic performed by prose.

  `{{module_rollup_notes}}` is where your prose goes, BELOW the table. Read the
  rows and say what they mean: which module most deserves attention and why,
  which dimension is driving a rollup, and — where a module's rollup rests on
  fewer measured dimensions than another's — that its status is the narrower
  claim. Name modules by the ids in the table. Never name one that is not in it.
-->

## Top Duplication Hotspots

{{duplication_hotspots}}

<!--
  WHERE the duplication is. The Module Rollup above says how MUCH — a
  percentage per module — and a percentage is not something anyone can act on.
  This section names the pairs.

  Read it from `duplication_clones` and nowhere else. Every entry is already
  scoped, ordered and thresholded; render, do not re-rank.

  One line per clone, top `capture.clone_report_top_m` by duplicated lines:

    `src/Billing/InvoiceCalc.cs:44-59` ↔ `src/Quotes/QuoteCalc.cs:58-73`
    — 16 duplicated lines — MOD-004

  Append, only when the artifact carries them:
    - ` — FunctionName()` after a side whose `function` is non-null
    - ` — cross-module` when `cross_module` is true, and name BOTH module ids
      (`MOD-001 ↔ MOD-004`) rather than one — a clone spanning two modules is a
      coupling finding, and showing one id hides half of it
    - ` — QI-###` when `qi_id` is non-null

  NEVER SHOW THE DUPLICATED CODE. The artifact deliberately does not carry it,
  so there is nothing to paste even by accident — but do not go and read the
  files to quote it either. Line ranges point at the code for anyone who wants
  it; a report that embeds source is one that cannot be forwarded.

  A `function` of `null` means no function could be attached MECHANICALLY —
  either the language has no function-level measurement here, or the clone
  straddles two functions, or nothing met the containment rule. Render the
  file:range alone. Never substitute the nearest function name, never infer one
  from the file name, and do not remark on the absence line by line.

  TRUNCATION IS STATED, not implied. When `census.clones_captured` is less than
  `census.clones_in_scope`, close with one line naming both numbers and the
  total duplicated lines — e.g. "showing the 10 largest of 137 clone pairs
  found in scope, covering 4,210 duplicated lines in total". When
  `census.clones_outside_scope` is non-zero, say that too: those pairs had at
  least one side outside the measured scope and were not examined.

  ZERO CLONES IS A RESULT. Say plainly that no duplicate blocks were found at
  or above the detection threshold, and say it next to the coverage — "no
  clones found" means much less when duplication was NOT-MEASURED for most of
  the tree. Do not omit the section.
-->

## Thresholds Applied

{{thresholds}}

<!--
  The exact threshold values this run classified against, so any number above
  can be checked against the policy that produced it. A status without its
  threshold is an opinion.
-->

## Hotspots

{{hotspots}}

<!--
  Top N by severity then value (default 15), each with its permanent QI-### id,
  module, file, function, metric, measured value, and the threshold it crossed.

  QI ids are permanent and are never renumbered or reused, so the same hotspot
  carries the same id across every report — which is what makes two reports
  months apart comparable at all.

  If any entry is `resolved`, list those separately and say what it means: the
  hotspot no longer exceeds its threshold, and the id is kept rather than
  deleted so the history stays readable. A resolved entry is never presented as
  a current problem, and never dropped silently.

  `excluded-by-scope` IS NOT `resolved`, and the two never share a list. It
  means the file that hotspot names is no longer inside the scan scope — the
  measurement stopped, nothing was fixed. Give it its own short list, name the
  category that excluded each one, and say the difference in a sentence. A
  reader who reads "excluded-by-scope" as "dealt with" has been told the
  opposite of the truth, and it is the flattering direction, which is why it
  needs saying rather than implying.

  An empty hotspot list is stated plainly — together with the coverage, because
  "nothing reached the threshold" reads very differently when half the tree was
  NOT-MEASURED.
-->

## Data anomalies

{{anomalies}}

<!--
  OBSERVATIONS ONLY. NEVER A CAUSE.

  If something in the artifact looks inconsistent, duplicated, surprising or
  simply wrong, it goes here — stated as what you observed, with the ids, files
  and values that show it, and then you stop. You do not say why. You do not
  offer a likely explanation, a probable cause, a "this usually means", or a
  mechanism. You have one file and no way to check any of it.

  The rule exists because of one paragraph. A previous report found two hotspots
  it could not tell apart and explained them: "jscpd and lizard each flag
  overlapping spans". Both findings were function-length findings from lizard,
  jscpd had nothing to do with either, and the real cause was an identity
  collision in the program that produced the file. The explanation was fluent,
  plausible, entirely invented, and it sent every reader away from the actual
  defect. An unexplained observation would have surfaced it the same day.

  Write:      "QI-025, QI-026 and QI-027 all report metric function_length on
              src/AuthController.cs, with values 210, 180 and 150."
  Never:      "...because the two tools overlap on the same span."
  Also never: "...which is likely a duplicate", "...presumably", "...this
              appears to be", or any other hedge that is a cause with a hedge in
              front of it.

  If there is nothing to report, say so in one line. An empty section is a
  finding: it says the artifact was internally consistent as far as you could
  see, and that is worth stating.
-->

## Methodology

<!-- quality-report:coverage-sentence:begin -->
{{coverage_sentence}}
<!-- quality-report:coverage-sentence:end -->

{{methodology}}

<!--
  Which tool produced which metric, how files were selected, and how a status
  band is assigned. Enough that a sceptical reader can reproduce the numbers.

  Selection is already stated, by the block above: `{{coverage_sentence}}` is
  `report_blocks.coverage_sentence_md`, verbatim, between its anchors. Your prose
  goes under it and says which tool produced which metric and how a band is
  assigned. Do not restate the selection mechanism in your own words.

  That block replaces a claim this template used to make and that was false in the
  flattering direction: that every metric "shares a denominator". They share a
  SCOPE — one exclusion pass, one in-scope list, handed to all three tools — and
  what each metric then managed on that list differs by hundreds of files,
  because no tool parses every language. A reader told the denominators match
  will read a duplication percentage computed over 466 files as covering the
  same 1,892 the scan scoped. Scope and coverage are two facts, and the sentence
  states both, each from its own count.

  The full scope is in the Scan Scope section above; do not restate the category
  tables here.

  Also state plainly what this report does NOT claim: it measures structural
  properties of source code. It says nothing about whether the software is
  correct, whether it does what its users need, or whether it is fit to ship.
  A codebase can sit entirely at PASS and still be the wrong system.
-->

---

## Internal provenance

<!--
  DELETE THIS SECTION BEFORE THE REPORT LEAVES THE TEAM. It is the only place
  internal command, script and framework names appear, which is what makes the
  rest of the document safe to forward as-is.
-->

{{provenance}}
