# Verification Report: analyze-command

**Verified:** 2026-07-21
**Model:** Claude Sonnet 5
**Verdict:** PASS

## Acceptance Criteria

- ✅ **AC1:** `collect .specclaw` (no path) defaults to repo root, valid JSON — `target_path="${2:-.}"` and dispatch `collect) [ $# -ge 2 ] || die ...; cmd_collect "$2" "${3:-.}"` in `plugins/specclaw/bin/specclaw-analyze-codebase`; test 9a confirms `"${out:0:1}" == "{" && "${out: -1}" == "}"` plus all 7 documented top-level fields present, passing.
- ✅ **AC2:** `collect .specclaw <subdir>` scopes `top_level_dirs`/manifests/LOC/test-locations to `<subdir>` only — scoping filter `case "$f" in "$rel_scope"|"$rel_scope"/*) ...` in the script; tests 9h/9i/9j/9k confirm root manifests and `sub/extra.txt`/`sample.qux` are excluded when scoped to `sub` or `tests`, and `tests/` still reports its own file.
- ✅ **AC3:** Fixture with `package.json`, `go.mod`, `.dproj` → one `manifests[]` entry each with correct `type` and deps — test 9b (`"type": "node"`, `"dependencies": ["express", "lodash"]`), 9c (`"type": "go"`, deps from `require()` block), 9d (`"type": "delphi"`, `"dependencies": ["AnalyzeFixture.pas", "Unit1.pas"]`) all pass.
- ✅ **AC4:** `loc_by_extension` matches real `wc -l` — test 9e: `assert_eq "9e loc_by_extension[qux] matches wc -l" "$hand_count" "$qux_loc"` against the 5-line `sample.qux` fixture.
- ✅ **AC5:** `test_locations` includes `tests/` when present, empty when absent — test 9f (`"test_locations": ["tests"`) and test 9i (`sub/` scoping → empty, no `"tests"` match) both pass.
- ✅ **AC6:** `discovered_docs` identical to standalone `specclaw-discover-context ... emit` — test 9g diffs the escaped standalone output against the embedded field: `assert_eq "9g discovered_docs identical to standalone discover-context emit" "$expected_escaped" "$embedded_escaped"`.
- ✅ **AC7:** Bad `[path]` stops before collection/agent — script validates and `die`s before any file enumeration: `[ -d "$project_root/$target_path" ] || die "path does not exist..."`, outside-root check, and `.specclaw`-itself/nested check, all preceding the `mktemp`/enumeration block; `skills/analyze/SKILL.md` Step 1: "If it exits non-zero, surface its stderr message to the user verbatim and stop."
- ✅ **AC8:** Report created with all 5 sections + Suggested First Changes, "insufficient evidence" fallback, claims traceable — `agents/codebase-analyst.md` Output section provides the exact template with `"No recognized manifest formats found — insufficient evidence to characterize a stack."` and generic `"No findings — insufficient evidence."` fallback, plus Evidence Discipline: "A claim you cannot anchor to a file you opened is not a finding: drop it." (This AC is graded on the wiring/instructions that would produce this behavior — see Issues Found for the caveat that no live end-to-end run artifact exists in the repo to observe directly.)
- ✅ **AC9:** Second run archives prior report before writing new one — `skills/analyze/SKILL.md` Step 2: `mv .specclaw/codebase-report.md .specclaw/codebase-reports/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md`, executed before Step 3 (spawn agent)/Step 4 (write new report); `mv` preserves byte-identical content.
- ✅ **AC10:** `codebase-analyst.md` frontmatter + rubric + domain-as-inference — `tools: [Read, Write, Bash]` (matches `code-reviewer.md`'s identical `tools: [Read, Write, Bash]`); Rubric table lists all six dimensions; "Every Domain finding must be prefixed `Inference:`. Low-confidence guesses must be flagged further, e.g. `Inference (low confidence): ...`."
- ✅ **AC11:** Version files match, one patch increment — both `plugins/specclaw/.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` show `"version": "0.5.4"`; prior released version was 0.5.3 per commit `785c5b2 chore: repo polish for discoverability + community health (v0.5.3)`.
- ✅ **AC12:** `run-parser-tests.sh` has the new case, full suite passes — Case 9 (9a–9l, 12 sub-assertions) added and verified present in full (not truncated) at `plugins/specclaw/tests/run-parser-tests.sh` lines 408–574; regression run (per supplement, run twice) reports 48 passed, 0 failed.
- ✅ **AC13:** README Commands table row, described as read-only codebase-analysis — `README.md` line 113: `` | `/specclaw:analyze [path]` | Analyze an existing/legacy codebase and write `.specclaw/codebase-report.md` (read-only) | ``.
  - ⚠️ Edge case: "A repo with zero recognized manifest formats" (spec's Edge Cases #1, ties to NFR1) is not exercised by any test — Case 9's fixture always contains 3 manifests. Code path (`[ -s "$manifests_tmp" ]` false → empty `manifests: []`) looks correct by inspection but is untested.
  - ⚠️ Edge case: "Multiple manifests of the same ecosystem at different levels" (monorepo, spec's Edge Cases #4) — not tested; `gather_manifests` loops per-match so it should produce independent entries, but no fixture/test covers it.
  - ⚠️ Edge case: "A detected manifest file that is empty or malformed" (spec's Edge Cases #5) — not tested; extractors' `|| true` / `2>/dev/null` suggest tolerance, but no malformed-manifest fixture exists.

## Test Results

Per the supplement's directly-gathered evidence (regression suite run twice this session, once at end of build and once at start of verify): **48 passed, 0 failed** both runs, including all 12 new Case-9 sub-assertions (9a–9l) with no regression in pre-existing Cases 1–8. A Windows/Git-Bash cleanup-hang was observed during `rm -rf` of Case 7's nested bare-repo fixtures — this occurred *after* the "48 passed, 0 failed" summary line printed, and is a known slow-cleanup quirk of that environment, not a test failure. Independently, this session read the full Case 9 block directly from `plugins/specclaw/tests/run-parser-tests.sh` (lines 408–574) and confirmed the assertions are real, non-truncated implementations (not placeholder comments) matching AC1–AC6.

`build.test_command`/`lint_command`/`build_command` are unconfigured in this project's `config.yaml` — expected for this repo (a bash-script plugin with no separate lint/build pipeline), not a gap.

## Issues Found

1. **No observed end-to-end live run artifact for AC8/AC9** — No `.specclaw/codebase-report.md` or `.specclaw/codebase-reports/archive/` exists in this repo to confirm the agent-authored report actually renders all sections/fallbacks correctly under a real invocation; verification here rests on the SKILL.md orchestration and `codebase-analyst.md` instructions being correctly wired, not an observed output file. **Fix:** before merge, run `/specclaw:analyze` twice against a real or fixture repo and inspect the resulting `codebase-report.md` and the archived copy.
2. **NFR5 atomicity not explicit for the new report's write** — `codebase-analyst.md`'s Output section says "Write the file once, at the end, after completing all six dimensions," which avoids incremental partial writes but doesn't implement the tmpfile-then-`mv` pattern NFR5 calls out (`specclaw-verify update-status`'s convention). **Fix:** either accept "write once via the agent's Write tool" as sufficiently atomic in practice, or have the agent write to a temp path and `mv` into place for parity with the stated convention.
3. **Untested edge cases** (see AC13's sub-bullets above: zero-manifest repo, same-ecosystem monorepo duplicates, malformed manifest file) — code appears to handle them by inspection but no fixture/test exercises them. **Fix:** add 1–2 more Case 9 sub-assertions (or a Case 10) covering a manifest-less fixture and a malformed `package.json`.
4. **NOTED (non-blocking, pre-existing, out of scope):** `specclaw-verify collect`'s `cmd_collect` file-path extraction has a confirmed bug (per the supplement) — its fallback comma-split logic is gated on the *global* `file_paths` array being empty rather than whether the *current* line matched, so once one `tasks.md` `Files:` line populates the array via fallback, every subsequent task's `Files:` line is silently skipped. This caused the "Changed Files" section fed into this verify run to show only 1 of 14 actual files. It is a pre-existing shared-script bug unrelated to `analyze-command` itself and was not fixed as part of this change; flagged here for the operator's awareness since it surfaced during this verification.

## Summary

**Passed:** 13/13 criteria
**Failed:** 0/13 criteria
**Verdict:** PASS
