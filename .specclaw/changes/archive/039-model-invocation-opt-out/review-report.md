# Code Review Report: 039-model-invocation-opt-out

**Reviewed:** 2026-09-20
**Model:** claude-sonnet-5
**Verdict:** APPROVED_WITH_NOTES

## Summary

2 findings: 0 BLOCK, 2 WARN, 0 NOTE. All 15 L1 spawn sites, the 9 agent charters, the
narration switch, the deterministic renderer's `report_blocks` path, the `yaml_val` /
`substitute` byte-identity, the T8 lint fix, and the new 45-assertion test suite were
verified against the diff and, where practical, executed. The suite passes (45/45), the
shellcheck gate reports no new findings and no baseline changes, and `AC-1`'s repo-wide
grep returns clean. Both findings are real but neither blocks a defensible narration
switch: one is a stale citation in a reference doc, the other is a rendering gap in an
untested (delta) mode path that costs a one-line mechanical fact, not a broken
byte-identity guarantee.

## Findings

### [WARN] plugins/specclaw/bin/specclaw-bf-quality-render:283 — Correctness
**Problem:** In delta mode, `{{scan_scope}}` is thrown into the generic narration-marker
loop —
```
for tok in scan_scope verdict summary not_comparable regressed improved unchanged methodology provenance; do
  doc="$(substitute "$doc" "{{${tok}}}" "$MARKER")"
done
```
— even though `templates/quality-delta.md:41` (a pre-existing template this change does
not modify) explicitly documents that field as a **mechanical** transcription, not
narration: *"Fill `{{scan_scope}}` from `scan_scope.config_hash` — one line, e.g.
'identical on both sides (sha256:1f3c…)'."* `quality-delta.json` carries exactly that
fact at `.scan_scope.config_hash`, and the collector's own stdout summary
(`specclaw-bf-quality-collect:3142`) already renders the identical one-line sentence:
`"scan scope: identical on both sides — exclusion config " + .scan_scope.config_hash`.
Reproduced directly: rendering a synthetic `quality-delta.json` with
`scan_scope.config_hash: "sha256:abc123"` through `specclaw-bf-quality-render --mode
delta` yields `**Scan scope:** _Not narrated — deterministic mode. Facts below are
collector output._` instead of the one-line fact the template asks for and the artifact
already contains. This path is untested — Groups B/C in `run-narration-gate-tests.sh`
only exercise `--mode legacy`.
**Fix:** Render `{{scan_scope}}` from `.scan_scope.config_hash` (mirroring how `{{path}}`/
`{{date}}`/`{{scope}}` are already handled as literal facts in the legacy/target branch)
and drop it from the `MARKER` loop for delta mode only; keep the other eight tokens in
that loop as genuine narration, matching the design's explicit choice not to extend
rendering logic beyond what's already mechanically available.

### [WARN] plugins/specclaw/references/model-invocation-map.md:49-67 — Design adherence / Correctness
**Problem:** AC-3 requires every row to cite "the `SKILL.md` line that justifies the
call." T1 (the audit) ran before T4 (the L1 edits that added an `mkdir -p` line and an
exit-status-check sentence to each of the 15 sites), and the citations were never
refreshed afterward. Nearly every `SKILL.md:line` reference in the table is now off by
one or more lines from the spawn site it claims to document — e.g. row 1 cites
`bf-analyze/SKILL.md:31` (currently a blank line) when the actual `subagent_type:
"bf-codebase-analyst"` spawn is now on line 32; row 4 cites `bf-baseline/SKILL.md:76`
when the harness spawn is now on line 78; row 14 cites `bf-clarify/SKILL.md:93` when the
options-pack spawn is now on line 96. Verified by `sed -n '<line>p'` against every cited
site in the table and cross-checked with `grep -n subagent_type` on the current files.
The quoted evidence text itself is still accurate — only the line numbers have drifted —
and `.specclaw/learnings.md`'s new `[L19]` entry documents the *general* lesson ("never
cite a line number the change's own edits will move") but was applied only to `spec.md`,
not retroactively to this reference doc, which the design explicitly scoped as "the
line-cited inventory as of the audit."
**Fix:** Either re-run the `grep -n 'subagent_type'` pass used to build the table after
T4/T5 landed and refresh all 15 (of 19) drifted citations, or state explicitly in the
document's header that line numbers are a snapshot as of T1 and may drift — the current
text ("the exact `SKILL.md:line` where the `Agent` tool is invoked") reads as a live
reference, not a snapshot.

_No other findings._ D1 (Correctness of L1): verified all 15 sites — each redirects to a
distinct `.collect/<phase>.json` filename (no two modes share a file, including
`bf-baseline`'s two modes and `bf-ui`'s two modes), each checks the collector's exit
status before spawning, and each passes the path rather than the payload; the three
Mode-A `bf-clarify` spawns (ingestion, extraction, bank) correctly share one collector
invocation and one `clarify-extract.json`. D2 (the renderer, legacy/target path):
byte-identity with `report_blocks.*_md` verified both by reading `render_block`/
`report_block_region` and by running the suite (all `B6` assertions pass); `set -euo
pipefail` is present; a missing `report_blocks` field fails loudly (reproduced with a
corrupted `quality.json`, exit 1, correct message) rather than emitting a report with a
hole. D3 (the switch's failure direction): `bf-quality/SKILL.md`'s Step 2 correctly
states only the literal `false` disables narration and that `--no-model` tightens but
never loosens, and `run-narration-gate-tests.sh` Group A (19 assertions, A1–A19) pins
exactly that asymmetry against a config with three decoy `narration:` keys in unrelated
blocks. D4 (scope creep): T8's touch of `specclaw-bf-quality-collect` (a file otherwise
untouched by this change) is declared in `tasks.md`'s own `Files:` list and justified in
`spec.md`'s Notes section as an operator-approved, in-scope addition — not creep. D5
(test quality): Group G's non-empty guard (`G3`) is real (verified both canonical
extractions are non-empty), and the suite was executed rather than merely read — 45/45
assertions pass, and the `shellcheck-gate.sh` run confirms no new findings and no
baseline mutation. D6 (`# shellcheck disable=SC2295`): confirmed placed on the line
immediately above `yaml_val()`'s definition (line 108, function starts line 109), outside
the `sed -n '/^yaml_val() {/,/^}/p'` window Group G's byte-identity check and T9's own
extraction both use — so the disable cannot mask a real divergence in the compared body,
and the rationale (matches the repo's 7 existing baselined copies, disabled locally
rather than touching the shared baseline) is accurate and consistent with
`shellcheck-baseline.txt`, which the diff leaves untouched. `design.md` is present, so D8
was not skipped; `tasks.md` declares `Files:` per task, so D9 was not skipped — no
undeclared files found outside the `.specclaw/` process artifacts this repo's own
lifecycle commits by convention. No dead code (D10) found in the new files.

## Verdict Rationale

Both findings are real, evidence-backed, and worth fixing, but neither undermines the
change's core claims. The AC-1 grep is clean, the byte-identity guarantee AC-5 depends on
holds and is test-pinned, the failure-direction rule (AC-6/AC-7/AC-8) is correctly coded
and tested against decoy configs, and the T8 fix is narrowly scoped, justified, and
regression-tested. The scan_scope gap is confined to an untested delta-mode path that the
suite never exercises and that no acceptance criterion covers; the stale line citations
degrade the audit document's usefulness as a line-accurate reference but the underlying
classifications and quoted evidence are still correct. APPROVED_WITH_NOTES.
