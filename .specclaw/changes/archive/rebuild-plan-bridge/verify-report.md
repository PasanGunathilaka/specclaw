# Verification Report: rebuild-plan-bridge

**Verified:** 2026-07-24
**Model:** claude-sonnet-5
**Verdict:** PASS

## Quotes (evidence extracted before judging)

- AC1: `specclaw-discover-context .specclaw list` → `0	1	.specclaw/analysis/architecture.md` / `0	3	.specclaw/analysis/codebase-report.md` / `0	5	.specclaw/analysis/domain-model.md` / `0	6	.specclaw/analysis/functional-spec.md` (all rank `0`), and the same run **without** the pin produced empty output — proving the pin, not incidental inclusion, causes the bypass.
- AC2: `specclaw-rebuild-collect collect .specclaw` on a project with none of the four docs → `ERROR: missing analysis document(s) — run the producing command first:` followed by all four `- .specclaw/analysis/<doc> (run /specclaw:<cmd>)` lines, exit code `1`.
- AC3/AC4: dynamically executed the shipped `agents/rebuild-planner.md` persona (via a fresh agent) against a realistic 3-capability fixture → wrote 3 backlog items, each with a non-blank, quote-anchored "Verification inputs needed" field; `grep -c "{{" backlog.md` → `0` (no leftover placeholders). Coverage Check section: `Capability: Technician Login — covered by Item 1.` / `... Record Reading — covered by Item 2.` / `... Export Report — covered by Item 3.` A separate zero-capability fixture run correctly wrote `No capabilities found — insufficient evidence to build a backlog` rather than fabricating items.
- AC5: `git diff origin/main main --stat -- plugins/specclaw/skills/{propose,plan,build,verify,pr}` → **empty output**; `git diff origin/main main --stat --diff-filter=M -- plugins/specclaw/bin plugins/specclaw/agents ...` → **empty output** (zero modified files; only 2 new files: `rebuild-planner.md`, `specclaw-rebuild-collect`).
- AC6: `bash plugins/specclaw/tests/run-parser-tests.sh` → `84 passed, 0 failed`, including `PASS: 12a` through `12f`.
- AC7: `plugins/specclaw/.claude-plugin/plugin.json` → `"version": "0.5.7"`; `.claude-plugin/marketplace.json` → `"version": "0.5.7"` (specclaw entry).
- AC8: literal execution of the skill's Step 2 (`mkdir -p .specclaw/analysis/archive; mv .specclaw/analysis/rebuild-backlog.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-rebuild-backlog.md`) against a project with an existing backlog → file moved to `.specclaw/analysis/archive/2026-07-24-172932-rebuild-backlog.md`, original path cleared. Pattern is byte-identical in structure to `skills/analyze/SKILL.md`'s own archive step.

## Acceptance Criteria

- ✅ **AC1 (pin bypasses exclusion):** Confirmed against the live, unmodified `specclaw-discover-context` script in a real git-tracked fixture project — all four docs at rank `0` in `list`, full content present in `emit`'s digest. Control run with `pin: []` produced no output at all for these paths, proving the default `.specclaw/` exclusion is genuinely bypassed by the pin rather than coincidental.
- ✅ **AC2 (missing-docs guard):** `specclaw-rebuild-collect collect` on a project with zero analysis docs exits `1` and names all four missing files plus the exact producing command (`/specclaw:analyze`, `/specclaw:architecture`, `/specclaw:domain` × 2) verbatim to stderr — no vague "run the analysis commands first."
- ✅ **AC3 (backlog shape):** Empirically verified by running the actual shipped `rebuild-planner` agent definition against a realistic fixture (3 capabilities, entities, business rules, a proprietary-format risk, a COM-component risk). Every item's "Verification inputs needed" field was non-blank and grep-clean of unfilled `{{...}}` template tokens.
- ✅ **AC4 (coverage check):** Same dynamic run produced a Coverage Check section explicitly marking all three functional-spec capabilities as "covered by item N." A second run with an empty Capabilities section correctly emitted the "No capabilities found" fallback instead of fabricating coverage.
- ✅ **AC5 (lifecycle untouched):** `git diff --stat` (and `--diff-filter=M`) against `skills/propose|plan|build|verify|pr`, all of `bin/`, and all of `agents/` shows **zero** modified files — only two brand-new files added.
- ✅ **AC6 (tests pass):** `bash plugins/specclaw/tests/run-parser-tests.sh` → `84 passed, 0 failed`, Case 12 (rebuild-collect) sub-assertions 12a–12f all pass.
- ✅ **AC7 (version bump):** `plugin.json` and `marketplace.json` both read `"0.5.7"`.
- ✅ **AC8 (archive-before-overwrite):** Skill's Step 2 bash sequence, executed literally against a project with a pre-existing `rebuild-backlog.md`, moves it to `.specclaw/analysis/archive/<timestamp>-rebuild-backlog.md` before a new one would be written — identical mechanism to `analyze`'s own archive step.

## Test Results

```
=== specclaw bin parser regression suite ===
...
--- Case 12: specclaw-rebuild-collect collect — existence, line counts, missing-doc errors ---
PASS: 12a all-present: exit 0 (= '0')
PASS: 12b codebase-report.md line count matches wc -l (3)
PASS: 12b architecture.md line count matches wc -l (1)
PASS: 12b domain-model.md line count matches wc -l (5)
PASS: 12b functional-spec.md line count matches wc -l (6)
PASS: 12c project_root reflects the collected project
PASS: 12d partial docs (2 of 4 missing): non-zero exit
PASS: 12e partial docs: stderr names both missing files + producing command
PASS: 12f partial docs: stderr does not name present files as missing

==================================================
84 passed, 0 failed
```
Independently re-run twice (once as a foreground command, once backgrounded) from the repo root — both runs exit `0` with the same `84 passed, 0 failed` tally. No lint/build commands are configured for this repo (`build.lint_command`/`build_command` are empty in `config.yaml`), so there is no additional lint/build output to evaluate.

## Issues Found

1. **`docs/rebuild-workflow.md` omitted the "stale analysis docs" limitation the spec explicitly required** — The spec's Edge Cases section states the staleness limitation must be "stated in `docs/rebuild-workflow.md`, not a silent gap." The verify agent found no such statement anywhere in the shipped doc (only the Fidelity/golden-master limitation was present). **Resolved during this verify pass:** a "Staleness limitation" section was added to `docs/rebuild-workflow.md` immediately after the Fidelity limitation section, stating that `rebuild-plan` trusts each document's own "Date analyzed" field and does not check it against git history, and instructing operators to re-run the three analysis commands if the codebase has changed meaningfully.

If no issues: this was the only one found, and it is now fixed.

## Summary

**Passed:** 8/8 criteria
**Failed:** 0/8 criteria
**Verdict:** PASS

---

**Notes on method:** The verify agent, beyond static reading, independently (a) ran the full `84`-case parser test suite twice from a clean shell; (b) built a real git-tracked fixture project and exercised the unmodified `specclaw-rebuild-collect` and `specclaw-discover-context` binaries directly for AC1/AC2, including a negative control (no pin → empty output) to rule out coincidental inclusion; (c) dynamically executed the shipped `rebuild-planner` agent persona twice — once against a realistic multi-capability fixture, once against a deliberately empty one — to empirically test AC3/AC4 rather than relying on prompt text alone; (d) diffed `origin/main..main` with both `--stat` and `--diff-filter=M` for the hard-constraint paths; (e) read `plugin.json`/`marketplace.json` directly off disk; (f) executed the AC8 archive bash sequence literally against a fixture with a pre-existing backlog file. The one gap found (stale-docs limitation missing from the operator doc) sat outside the 8 numbered acceptance criteria and has been fixed as noted above.
