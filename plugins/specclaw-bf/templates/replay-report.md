# Replay Report: {{target}}

**Date:** {{date}}
**Stack:** {{stack}}
**Legacy commit:** {{legacy_commit_sha}}
**Backlog item:** {{bl_item}}
**Selected fixtures:** {{selected_count}}
**Overall verdict:** {{overall_verdict}}{{stub_taint_suffix}}
**Rendered by:** specclaw v{{plugin_version}} — baseline recorded by specclaw v{{manifest_plugin_version}} (manifest schema {{manifest_schema}})
{{empty_selection_notice}}
{{evidence_block}}

## Summary

| Outcome | Count |
|---|---|
| Exact match | {{match_count}} |
| Behavioural divergence — sanctioned | {{behavioural_sanctioned_count}} |
| Behavioural divergence — **unsanctioned** | {{behavioural_unsanctioned_count}} |
| Representation-only difference | {{representation_count}} |
| Unmapped error code | {{unmapped_error_code_count}} |
| Error | {{error_count}} |
| Not replayable — seam-layer mismatch | {{seam_mismatch_count}} |
| Not replayable — other | {{not_replayable_other_count}} |

<!--
  Every count above is computed mechanically by `specclaw-bf-replay compare`
  from the declared data in templates/CONTRACT.md — never asserted by an
  agent. The three-way split matters:

  - BEHAVIOURAL means outcome, threw, error_code, or any other field that is
    neither representation-class nor normalized differs. This is the rebuild
    deciding something different from the legacy app. Unsanctioned, it FAILs
    the run.
  - REPRESENTATION means ONLY the raw exception type/message differed
    (CONTRACT.md (b.2)). The business decision was identical. This never
    FAILs a run; both raw values are kept below as evidence.
  - UNMAPPED ERROR CODE means an error neither agent could confidently map to
    this project's error-map.md vocabulary, so nobody guessed one
    (CONTRACT.md (h)). It holds the run at PASS-PENDING-DECISIONS.

  Every DIVERGES row's sanction citation was independently re-verified by
  `specclaw-bf-replay sanction-check` against decisions.md's own
  `### CQ-0NN —` headings; an agent's claim alone never promotes a row to
  SANCTIONED. Only behavioural rows are ever put to the auditor at all.
-->

## Module Rollup

<!--
  Per-module counts, each module's own verdict (computed by the SAME four-step
  order as the overall verdict in CONTRACT.md (j.3), over that module's own
  subset), and — always, never omitted — how many of its fixtures are shared
  with another module. Computed in bash by `specclaw-bf-replay render` from
  manifest-declared module_ids; no agent asserts any of it.

  THE CROSS-MODULE HONESTY RULE. A fixture whose pinned rules span modules
  counts toward EVERY module it touches, and the Shared column names the other
  modules. This is not bookkeeping detail: a shared fixture is the record of a
  flow that crosses a module boundary, and it is exactly the thing that breaks
  when one module is rebuilt in isolation. A module verdict that silently
  excluded its shared flows would be a false verdict — so "MOD-002: PASS" is
  always accompanied by how much of that PASS depends on another module still
  behaving as it did.

  This section changes NO verdict and NO exit code. The overall verdict below
  is computed over the whole selected set exactly as it always was; a module
  rollup is a reporting view over the same rows, not a second gate.
-->

{{module_rollup}}

## Stubs In Effect

<!--
  The dependency bypasses this run's verdict rests on (templates/CONTRACT.md
  (m)). An ACTIVE entry listed here means: some of what these fixtures were
  compared against was a deliberate placeholder for a module that has not been
  built yet, chosen by a named human on a recorded date.

  WHAT THIS DOES AND DOES NOT MEAN. The comparison genuinely ran and genuinely
  produced the verdict above — taint changes no verdict, no divergence class,
  and no exit code. What it qualifies is the verdict's STANDING: a PASS here
  says the rebuild matched recorded behaviour while standing on something
  unreal, and names exactly what. Whether that is acceptable is a human
  judgement about a traceable decision, which is the most this format can
  honestly offer.

  A RETIRING entry taints nothing — the stub code is reported removed and this
  run is its retirement verification. A clean verdict retires it; a FAIL sends
  it back to ACTIVE.

  Computed in bash by `specclaw-bf-replay resolve`/`render` from the registry's
  own declared `Consumed by` field joined against each fixture's
  `verifies_backlog_item`. No agent asserts any of it.
-->

{{stubs_in_effect}}

## Item Split In Effect

<!--
  Present when this run's backlog item has a non-COMPLETE IS-### split
  (templates/CONTRACT.md (o)) — i.e. part of the item was deliberately
  deferred and has not been built yet.

  A DIFFERENT CLAIM FROM STUB TAINT ABOVE, and the difference is the whole
  point. A stub qualifies a verdict's STANDING: what it was measured against
  was not real. A split qualifies its SCOPE: the comparison was entirely
  sound, but only half the item exists to compare. Nothing here was faked, so
  nothing here is tainted.

  WHAT IT DOES AND DOES NOT MEAN. This run changes no verdict, no divergence
  class and no exit code — a split enters none of them. What it changes is
  that this run CANNOT BE THE ITEM'S FINAL ACCEPTANCE, and says so on its own
  face rather than leaving a reader to notice.

  DEFERRED-SCOPE FIXTURES ARE REPORTED, NEVER EXCLUDED. A fixture pinning a
  deferred rule still runs and still counts. Dropping it from the exercised
  set would change what the run FAILs on — the one thing a completeness
  marker must never do — and would hide a real regression behind a scope
  note. So a FAIL among the deferred-scope fixtures is expected and
  explained; a PASS among them is a SURPRISE WORTH INVESTIGATING, because it
  means either the deferred scope was quietly built after all, or the split's
  rule partition is wrong.

  Computed in bash by `resolve`/`render` from the split entry's own declared
  `Rules deferred` joined against each fixture's `business_rules_pinned`. No
  agent asserts any of it.
-->

{{item_split_section}}

## Fixtures

| Scenario | Verdict | Class | Sanction | Stubs | Detail |
|---|---|---|---|---|---|
{{fixture_table_rows}}

## Behavioural Divergences

<!--
  The rebuild decided something different from the legacy application. Each
  line is the mechanical fact only — field, legacy value, rebuild value — with
  no interpretation attached by any agent. An unsanctioned entry here is why
  this run FAILs.
-->

{{behavioural_divergence_detail}}

## Representation-Only Differences

<!--
  Same business decision, different framework surface: the raw exception type
  or message differed while outcome, error_code, threw, and every other
  compared field agreed. Recorded here in full — both raw values retained —
  because it IS useful evidence of how the rebuild expresses errors. It is not
  a divergence in behaviour and does not affect the verdict.
-->

{{representation_detail}}

## Seam-Layer Mismatches

<!--
  A fixture captured at one layer whose replay test targeted another
  (CONTRACT.md (i)). Forced to NOT REPLAYABLE by `compare`, mechanically,
  regardless of what the mapper agent claimed — a service-layer fixture
  replayed through HTTP measures transport and middleware, not the business
  rule the fixture pins. The fix is a replay test at the captured layer, never
  a comparison at whichever layer happened to be reachable.
-->

{{seam_mismatch_list}}

## Normalization Warnings

<!--
  A normalized_fields path that resolved against the captured fixture but
  matches nothing in the rebuild's actual output — meaning the rebuild
  reshaped the very field the path was meant to exclude, so it is no longer
  being excluded from anything. Never changes a verdict; always worth fixing,
  because a dead normalization path silently stops normalizing.
-->

{{normalization_warning_list}}

## Not Replayable

{{not_replayable_list}}

## Open Decisions Blocking PASS

<!--
  Soft-block, not a refusal to run: an exercised (MATCH/DIVERGES/ERROR)
  fixture whose underlying scenario still rests on an open pending question,
  whose scenario definition changed since capture (SUPERSEDED), or whose error
  could not be mapped to a semantic code, never reaches a plain PASS — no
  matter how clean its own comparison came back. This section, and the
  -PROVISIONAL / -SUPERSEDED suffixes on the affected rows in the Fixtures
  table above, clear automatically with no manual cleanup: once the cited
  PQ/CQ is answered under decisions.md's ## Decisions, once the fixture is
  recaptured, or once the code is added to error-map.md.
-->

{{open_decisions_blocking_pass}}

## DR Rules Left Uncovered

_Business rules from domain-model.md not exercised by any REPLAYABLE fixture in this run (MATCH, DIVERGES, or ERROR — NOT REPLAYABLE fixtures don't count as coverage):_

{{dr_uncovered_list}}

## Verdict

**{{overall_verdict}}**{{stub_taint_suffix}}

Evaluated in this order, mechanically (`templates/CONTRACT.md` (j.3)):

1. **INCOMPLETE** — nothing was actually exercised. Either the selected fixture set was non-empty and every fixture in it came back NOT REPLAYABLE, or the selection was empty in the first place: a valid, active backlog item with genuinely no fixtures mapped to it (see the header notice). Both are the same fact about this run — no comparison happened — so both take this verdict and exit code 2. An empty selection is a clean result, not a broken precondition, and it is never reported as a PASS. Exit code 2.
2. **FAIL** — at least one ERROR, or at least one **behavioural** divergence with no sanctioning decided CQ. "Looks more correct" is never a sanction. Exit code 1.
3. **PASS-PENDING-DECISIONS** — no failure above, but at least one exercised fixture is PROVISIONAL (an open pending question still blocks the rule it pins), SUPERSEDED (its scenario definition changed since capture — recapture it), or carries an unmapped error code. Gates CI/PR exactly like FAIL (exit code 1); analysis and build keep moving, but this run is not yet citable as final proof.
4. **PASS** — everything else: every exercised fixture matched, or diverged behaviourally under a decided CQ. Representation-only differences do not hold a run back from PASS. Exit code 0.

Order matters: an unsanctioned behavioural divergence is **always** FAIL. No provisional, superseded, or unmapped state ever converts it into PASS-PENDING-DECISIONS.

**Stub taint appears in none of the four rules and in no exit code** (`CONTRACT.md` (m.3)). An `(with active stubs: …)` suffix on the verdict above marks a result as resting on a recorded placeholder; it never softens a FAIL, and a stub-tainted FAIL is reported as FAIL with exit code 1 exactly as any other. Unlike PROVISIONAL — which *does* hold a run at PASS-PENDING-DECISIONS, because an open question means nobody has decided what correct is — a stub leaves the comparison itself sound. What is qualified is its standing, and standing is reported rather than computed.

{{ui_fidelity_footer}}
