# Verification Report: domain-command

**Verified:** 2026-07-22
**Model:** Claude Sonnet 5
**Verdict:** PASS

## Note on evidence-collection tooling (read before the rest of this report)

The templated verify-context payload's "Implementation (changed files)" section contained only **one** file (`plugins/specclaw/bin/specclaw-domain-collect`), even though this change touches ~14 files across 6 tasks. This is a **pre-existing, confirmed bug in `specclaw-verify`'s `cmd_collect`**, already flagged by prior verify passes on `analyze-command`/`architecture-command`. I independently confirmed the mechanism by reading `plugins/specclaw/bin/specclaw-verify` directly:

```
123    # If no backticks, try comma-separated plain text
124    if [ ${#file_paths[@]} -eq 0 ] 2>/dev/null; then
```

`file_paths` is one shared array across every `Files:` line in `tasks.md`, and the comma-fallback branch only fires when that array's **grand total** is still zero — not when the *current line* contributed nothing. `tasks.md`'s first `Files:` line (T1: `plugins/specclaw/bin/specclaw-domain-collect`, no backticks) populates the array via the fallback, so every subsequent task's `Files:` line (T2's three files, T3's, T4's, T5's two, T6's three) is silently dropped from then on. This is out of scope for this verification (not part of domain-command's own diff) — noted for operator awareness only, not fixed here.

To work around it, I independently `Read` every file listed in my task instructions directly from disk (not from the templated payload) before judging any acceptance criterion, and ran the test suite myself rather than trusting any pasted summary.

## Acceptance Criteria

- ✅ **AC1:** "`specclaw-domain-collect collect .specclaw` (no path) defaults to the repository root; output is valid JSON containing every field `specclaw-analyze-codebase collect` produces (merged, not nested) plus the new domain-specific fields." — `cmd_collect()`: `local target_path="${2:-.}"` defaults to repo root. The assembly is a genuinely flat heredoc: `{ ${delegated_body}, "forms": [...], "xaml_forms": [...], ... }` (lines 767-786 of `specclaw-domain-collect`) — I grepped the whole file for `delegated_collect` and found **no matches**, confirming there is no nested wrapper key anywhere. Test `11a` (which I ran myself) passed: `PASS: 11a merged output has every delegated field plus every new domain field`, checking all 8 delegated fields (`path`, `project_root`, `top_level_dirs`, `manifests`, `loc_by_extension`, `test_locations`, `dependency_graph`, `discovered_docs`) plus all 8 new fields are present at the top level.

- ✅ **AC2:** "Against a fixture with one well-formed text-format `.dfm`, `forms[]` contains one entry with `parseable: true`, the correct `root_name`/`root_class`, at least one `controls[]` entry with a `caption`, and at least one `handlers[]` entry naming a menu item's `OnClick` handler." — `MainForm.dfm` fixture: `object MainForm: TMainForm` / `Caption = 'Main Form'` / `object OKButton: TButton ... Caption = 'OK' ... OnClick = OKButtonClick`. Tests `11b`, `11c` both passed (`root_name`/`root_class`/`root_caption` correct; `{"name": "OKButton", "class": "TButton", "caption": "OK"}` present).

- ✅ **AC3:** "Against the malformed/binary-format `.dfm` fixture, `forms[]` contains an entry with `"parseable": false` and a reason string — no crash, no attempted parse, no silent omission from the array." — `Broken.dfm` fixture is literally `FAKEBINARYDFMSTUB0000000000000000000000`. `parse_one_dfm()`'s guard: `if ! [[ "$first_nonblank" =~ ^(object|inherited)([^A-Za-z0-9_]|$) ]]; then printf '{"file": "%s", "parseable": false, "reason": "%s"}' ...; return 0; fi`. Test `11e` passed: `PASS: 11e Broken.dfm: parseable:false with reason, no crash`.

- ✅ **AC4:** "A `handlers[]` entry whose `handler_name` has a matching procedure implementation in a scoped `.pas` file produces a corresponding `handler_implementations[]` ... entry with the correct file; a handler with no matching implementation in scope produces no such entry." — `MainForm.pas` has `procedure TMainForm.OKButtonClick(Sender: TObject);` with a body; `RecentFileClick` (from the nested menu) has no implementation anywhere in the fixture. Tests `11f` (`handler_implementations: OKButtonClick resolves to MainForm.pas:20`) and `11g` (`RecentFileClick (no impl in fixture) correctly absent`) both passed — `11g`'s comment explicitly distinguishes the `handler_implementations[]` shape from the unrelated `forms[].handlers[]` occurrence of the same name (confirmed by `11d`), avoiding a false-positive substring match.

- ✅ **AC5:** "Against a fixture `.pas` file containing an enum type declaration, `type_declarations[]` contains an entry with `kind: "enum"` and the full, correctly-ordered `values[]` list." — `Types.pas`: `TWaterQuality = (wqNone, wqChem, wqTrace, wqAge);`. Test `11h` passed: `{"name": "TWaterQuality", "kind": "enum", "values": ["wqNone", "wqChem", "wqTrace", "wqAge"], ...}`.

- ✅ **AC6:** "Against the same fixture's `record`/`class` type declaration, `type_declarations[]` contains an entry with the correct `kind` and no fabricated field list." — `Types.pas`: `TReading = record Value: Double; Timestamp: TDateTime; end;`. `parse_one_pas_types()`'s `PAS_TYPE_RECORD_CLASS_RE` branch only ever emits `{"name": ..., "kind": ..., "file": ..., "line": ...}` — I read the whole function and confirmed there is no code path anywhere that attempts to parse a field list for `record`/`class` entries (the JSON shape itself has no field-list key). Test `11i` passed: `{"name": "TReading", "kind": "record", "file": "domain/ui/Types.pas"...}`.

- ✅ **AC7:** "Against the fixture's `const` block, `const_declarations[]` contains the correct name/value pairs for simple scalar values." — `Types.pas`: `MaxReadings = 100;` / `DefaultUnit = 'ppm';`. Test `11j` passed for both.

- ✅ **AC8:** "Against a fixture `Valid*`-named routine with a guard clause, `validation_routine_candidates[]` contains an entry whose captured body includes the guard clause's text, correctly bounded (does not include the following routine's code)." — `Types.pas`'s `ValidateReading` has `if Value < 0 then begin Result := False; Exit; end;` immediately followed by an unrelated `ComputeAverage` function. Test `11k` passed, explicitly asserting the captured body contains `'if Value < 0 then'` **and** does not contain `'ComputeAverage'`.

- ✅ **AC9:** "A `.dpr` fixture's first `Application.CreateForm` call produces the correct `main_form_hint`; scoping `[path]` to exclude the `.dpr` file leaves `main_form_hint` absent while `forms[]` still contains every detected form." — `MainApp.dpr`: `Application.CreateForm(TMainForm, MainForm);`. Test `11m` passed (`"main_form_hint": "TMainForm"`). Test `11n` (scoping to `domain/ui`, excluding the only `.dpr`) passed, asserting `"main_form_hint": null` **and** both `MainForm.dfm` and `Broken.dfm` still present in `forms[]`.

- ✅ **AC10:** "A fixture `.xaml` file's element/`x:Name`/`Content`-shaped attributes are captured in an `xaml_forms[]`-equivalent field at the depth FR5 specifies." — `MainWindow.xaml`'s direct child `<Button x:Name="SubmitButton" Content="Submit" />` (depth 1 under root `<Window>`). `parse_one_xaml()` only captures at `parent_depth -eq 1`. Test `11o` passed: `{"name": "Button", "x_name": "SubmitButton", "content": "Submit"}`.

- ✅ **AC11:** "A fixture `.cshtml` ... file appears in the output marked detection-only ... never silently absent, never deep-parsed." — `Index.cshtml` (`@page` / `<h1>Demo Page</h1>`). `gather_other_ui_files()` matches `*.cshtml|*.razor|*.aspx|*.ascx` and always emits `"parseable": false, "reason": "not deep-parsed in v1 — detection only"`. Test `11p` passed.

- ✅ **AC12:** "A scope with zero `.dfm`/`.xaml`/`.pas`/`.cs`/`.dpr` files yields empty arrays for every new field — no crash." — Test `11q` (scoped to the pre-existing `sub/` fixture dir) passed, asserting `"forms":[]`, `"xaml_forms":[]`, `"other_ui_files":[]`, `"handler_implementations":[]`, `"type_declarations":[]`, `"const_declarations":[]`, `"validation_routine_candidates":[]`, and `"main_form_hint":null` all present with no script abort (every `gather_*` function is a best-effort loop over an empty match set, returning an empty string).

- ✅ **AC13:** "`collect .specclaw <subdir>` scopes every new field the same way `manifests`/`dependency_graph` are already scoped — an entity whose source file falls outside `<subdir>` never appears." — Scoping to `domain/ui` excludes `TUnitA` (declared in the pre-existing fixture root, outside `domain/ui`) while still including `TWaterQuality` and the `OKButtonClick` handler resolution. Test `11r` (both of its two assertions) passed.

- ✅ **AC14:** "`/specclaw:domain <bad-path>` stops with a clear error before collection or agent spawn." — `specclaw-analyze-codebase` (unmodified dependency) dies early on a bad path: `[ -d "$project_root/$target_path" ] || die "path does not exist: $target_path"`, `*) die "path resolves outside the project root: $target_path" ;;`, `"$specclaw_dir_abs") die "path may not be the specclaw directory itself: $target_path" ;;`. `specclaw-domain-collect`'s `cmd_collect()` calls this as its very first step and propagates immediately: `delegated="$(bash "$analyze_bin" collect "$specclaw_dir" "$target_path")" || exit $?` — before any of its own file re-enumeration or extraction runs. `skills/domain/SKILL.md` step 1: "If it exits non-zero, surface its stderr message to the user verbatim and stop — don't retry, don't guess a different path."

- ✅ **AC15:** "On a repo with no prior `domain-model.md`/`functional-spec.md`, running `/specclaw:domain` creates both files under `.specclaw/analysis/` with all eight rubric sections present ..., every entity/rule/capability traceable to a quoted file, and every domain-meaning claim prefixed `Inference:` (or `Inference (low confidence):`)." — As with the analogous ACs in the prior `analyze-command`/`architecture-command` verify passes (and as this change's own `design.md` explicitly anticipates: *"Two agent-written files instead of one raises the same 'no live end-to-end artifact will exist at verify time' gap ... same handling: verify will grade the skill/agent's wiring and instructions, not an observed run, exactly as precedent already set twice."*), I did **not** spawn a real `domain-analyst` agent run — that's outside what this verify pass can do. I graded the **wiring/instructions** instead: `agents/domain-analyst.md`'s eight-row rubric table (Entities/Relationships/Business Rules/Enumerations → `domain-model.md`; Capabilities/Workflows/UI Inventory/Named Gaps → `functional-spec.md`) is present; its Output section states: *"If a dimension has no findings you can anchor to a collected fact or an opened file, write 'No findings — insufficient evidence.' for that section rather than leaving it blank."* (exact spec wording); its Domain Inference Rule states: *"Every such meaning finding must be prefixed `Inference:`. Low-confidence guesses must be flagged further, e.g. `Inference (low confidence): ...`"*; its Evidence Discipline section requires every claim to be "anchored to either a collected fact ... or a quote from a file you actually opened via your `Read` tool." The wiring is correct; I am not asserting a real run was observed.

- ✅ **AC16:** "Running `/specclaw:domain` a second time archives **both** prior documents (byte-identical) into `.specclaw/analysis/archive/` before writing new ones." — `skills/domain/SKILL.md` step 2: `mkdir -p .specclaw/analysis/archive` then two separate `mv` commands (one per file), followed by: *"Skip each `mv` independently if that specific file doesn't exist yet — one may exist without the other on an unusual prior run."* This is explicitly phrased as two independently-skippable operations, not a single combined check, matching AC16/NFR5's requirement (`mv` itself is byte-preserving, so the archived copy is byte-identical by construction). This is agent-interpreted orchestration prose (not a deterministic script), same pattern as the single-file precedent in `skills/architecture/SKILL.md` ("Skip this step if `.specclaw/analysis/architecture.md` doesn't exist yet"), extended here to two independently-gated files.

- ✅ **AC17:** "`agents/domain-analyst.md` frontmatter declares `tools: [Read, Write, Bash]` and documents the eight-row rubric, the Domain Inference Rule, and the Mechanical Recording Rule." — Frontmatter: `tools: [Read, Write, Bash]`, `model: sonnet`. The file contains an eight-row `| # | Dimension | ... |` table (Entities, Relationships, Business Rules, Enumerations, Capabilities, Workflows, UI Inventory, Named Gaps), a `# Domain Inference Rule` section, and a `# Mechanical Recording Rule` section reading: *"This is a hard rule, not a suggestion. When a `validation_routine_candidates[]` entry's real-world intent is not evident ... you must record the rule mechanically ... for example: 'rejects values > 100 — reason not evident.' Do not invent a plausible-sounding business rationale ..."* — matches FR11's wording precisely, and is a distinctly-named, standalone section (not folded into Evidence Discipline).

- ✅ **AC18:** "`plugin.json` and `marketplace.json` versions match each other, one patch increment above pre-change values." — Both files currently read `"version": "0.5.6"`. Git history: `plugins/specclaw/.claude-plugin/plugin.json` at commit `9143f62` (the last commit before any `domain-command` work began) was `"0.5.5"` in both files; the final `domain-command` commit `0827a56` ("T6 — README row + version bump 0.5.5 -> 0.5.6") bumped both to `"0.5.6"` in the same commit. Synced, one patch increment above the value this change started from. (Note: `main` itself is still at `0.5.4`, one patch behind, because the prior `architecture-command` change — commit `9143f62` — is also not yet merged to `main`; that is a merge-order fact, not a defect in this change's own version bump.)

- ✅ **AC19:** "`tests/run-parser-tests.sh` includes the new case(s) and the full suite passes." — Case 11 (`11a` through `11r`, 19 pass/fail assertions total, counting `11r`'s two independent checks) is present, covering FR3-FR10/AC1-AC13. I ran the suite myself from the repo root: **`75 passed, 0 failed`** (56 pre-existing + 19 new, all green — see Test Results below for the full transcript).

- ✅ **AC20:** "`README.md`'s Commands table includes a `/specclaw:domain [path]` row describing it as a read-only domain/functional documentation command." — `README.md` line 115: `| `/specclaw:domain [path]`| Write domain/functional documentation (entities, rules, capabilities, workflows, UI inventory) of an existing/legacy codebase to `.specclaw/analysis/domain-model.md` + `.specclaw/analysis/functional-spec.md` (read-only) |`.

## Non-Functional Requirements

- ✅ **NFR1 (language-agnostic-safe):** Confirmed by test `11q` — zero-eligible-file scope yields empty arrays/null for every new field, no crash.
- ✅ **NFR2 (grounded, not invented):** `agents/domain-analyst.md`'s Evidence Discipline section: *"A claim you cannot anchor this way is not a finding: drop it rather than report a vague suspicion. Never attribute a business rule, workflow step, entity structure, or relationship to code you have not read in this run."* Wiring-level pass, same caveat as AC15 (no live run observed).
- ✅ **NFR3 (portability):** No new external dependency — plain bash + coreutils (`grep`, `sed`, `mktemp`, `git`/`find`), `jq` used only optionally for output validation with a printed-either-way fallback: `if command -v jq &>/dev/null; then ... else printf '%s\n' "$output"; fi`.
- ✅ **NFR4 (no lifecycle coupling):** `skills/domain/SKILL.md`: *"Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`architecture`/`patterns`/`status` pattern."* Grepped `specclaw-domain-collect`, `domain-analyst.md`, and `SKILL.md` for `validate-change`/`STATUS.md`/`changes/` — no matches in the script; only the above self-describing sentence in the skill.
- ✅ **NFR5 (safe re-run):** Same evidence as AC16 — both documents archived, independently gated, before either is overwritten.
- ✅ **NFR6 (malformed input never crashes the collector):** Confirmed by test `11e` (`Broken.dfm`) plus code inspection: every extractor uses `2>/dev/null || true` / `[ -r "$abs_file" ] || return 0` guards despite `set -euo pipefail` at the top of the script, and the full suite (including the deliberately malformed fixture) ran to completion with 0 failures and no script abort.

## Test Results

Ran directly from the repo root:
```
bash plugins/specclaw/tests/run-parser-tests.sh
```

Full Case 11 output (all 19 assertions passed):
```
--- Case 11: specclaw-domain-collect collect — forms, handlers, types, consts, validation candidates, main_form_hint, xaml, cshtml, scoping ---
PASS: 11a merged output has every delegated field plus every new domain field
PASS: 11b MainForm.dfm: parseable, correct root_name/root_class/root_caption
PASS: 11c MainForm.dfm: top-level control caption (OKButton = 'OK')
PASS: 11d MainForm.dfm: deep (3+ levels) menu item's OnClick handler captured in handlers[]
PASS: 11e Broken.dfm: parseable:false with reason, no crash
PASS: 11f handler_implementations: OKButtonClick resolves to MainForm.pas:20
PASS: 11g handler_implementations: RecentFileClick (no impl in fixture) correctly absent
PASS: 11h type_declarations: TWaterQuality enum with full, ordered values[]
PASS: 11i type_declarations: TReading record, name/kind only (no fabricated fields)
PASS: 11j const_declarations: MaxReadings=100 and DefaultUnit='ppm' correctly captured
PASS: 11k validation_routine_candidates: ValidateReading body includes guard clause, bounded (no bleed into ComputeAverage)
PASS: 11l validation_routine_candidates: CanRedo (false positive) still surfaced as a candidate
PASS: 11m main_form_hint: TMainForm detected from MainApp.dpr's Application.CreateForm call
PASS: 11n main_form_hint absent when .dpr excluded from scope; forms[] still fully populated
PASS: 11o xaml_forms: direct-child element x:Name + Content captured at the specified depth
PASS: 11p other_ui_files: Index.cshtml marked detection-only
PASS: 11q sub/ scoping (zero eligible files): every new field is an empty array/null, no crash
PASS: 11r domain/ui scoping excludes out-of-scope TUnitA (fixture root, outside domain/ui)
PASS: 11r domain/ui scoping still includes in-scope entities (TWaterQuality, OKButtonClick resolution)
```

Final summary line (obtained by my own run, not copied from any prior report):
```
==================================================
75 passed, 0 failed
```

This matches `status.md`'s self-reported "75 passed, 0 failed (56 pre-existing + 19 new)" — independently reproduced, not just trusted.

## Issues Found

1. **Pre-existing `specclaw-verify` `cmd_collect` file-collection bug (non-blocking, out of scope, operator awareness only).** `bin/specclaw-verify`'s `Files:`-line parser (`if [ ${#file_paths[@]} -eq 0 ] 2>/dev/null; then` at line 124) checks the array's grand total rather than the current line's contribution, so once the first task's `Files:` line populates the fallback array, every subsequent task's `Files:` entries are silently dropped from the verify-context payload. This is unrelated to `domain-command`'s own diff and was already flagged by prior verify passes on `analyze-command`/`architecture-command`. **Fix:** reset a per-line accumulator before the backtick loop and always attempt the comma-fallback per line when that line's own accumulator is empty, not the global one.

2. **Design.md describes the `.dfm`/type-declaration/business-rule extraction as awk-based; the shipped implementation is pure bash.** `design.md`'s pseudocode sections are explicitly framed as "the real implementation is one per-file awk script invoked once per scoped .dfm file" and use fenced ` ```awk ` blocks, but I grepped the entire shipped `specclaw-domain-collect` for `awk` and found zero matches — every extractor is a `while IFS= read -r line` loop with `[[ "$line" =~ $SOME_RE ]]` bash regex matching. This is a deviation from `design.md`'s stated approach, but a harmless one (arguably simpler — no external `awk` process per file — and NFR3's "plain bash + coreutils" requirement is satisfied either way). Non-blocking; noted per the task's request to flag deviations even when harmless.

3. **Spec Edge Case not exercised by any test: multi-line enum identifier lists.** `spec.md`'s Edge Cases section states: "An enum declaration whose identifier list spans multiple lines before its closing `);` → parsed as one accumulated statement, same technique the `uses`-clause extractor already uses." The shipped `parse_one_pas_types()` does implement this accumulation (the `accumulating`/`buf` logic), but the only enum fixture (`TWaterQuality` in `Types.pas`) is declared entirely on one line: `TWaterQuality = (wqNone, wqChem, wqTrace, wqAge);`. No fixture/assertion exercises the multi-line accumulation path. **Recommendation:** add a second enum fixture with a wrapped identifier list in a follow-up change; non-blocking since the code path is present and was read directly, but it is currently unverified by any test.

4. **Spec Edge Case not specifically exercised by any test: forward-declaration false-match protection.** `status.md` records "two bugs found and fixed during implementation (bash `\b` word-boundary not matching in this environment; forward-declaration false-match on routine-body bounding)." I confirmed the bail-out logic is genuinely present in `gather_validation_candidates`'s `parse_one_validation_file()`: the "find the first `begin`" scan bails without emitting if it hits *another* routine signature or an `interface`/`implementation` keyword line first — `if [[ "${lines[$j]}" =~ $sig_re ]] || [[ "${lines[$j]}" =~ $PAS_IMPLEMENTATION_RE ]] || [[ "${lines[$j]}" =~ $PAS_INTERFACE_RE ]]; then break; fi` followed by `$found_begin || continue`. However, neither `Types.pas`'s `ValidateReading`/`CanRedo` (both declared with immediate bodies, never forward-declared in the `interface` section) nor any other Case 11 fixture actually constructs a genuine forward-declared `Valid*`/`Check*`/`Can*`-named routine to exercise this specific bail-out path — test `11k` verifies general body-bounding (doesn't bleed into the next routine) via the ordinary depth-counted `begin`/`end;` scan, which is a related but distinct code path from the forward-declaration bail-out. **Recommendation:** add a dedicated fixture in a follow-up; non-blocking, the code was read directly and the logic is sound on inspection.

5. **`\b` word-boundary spot-check: one remaining usage, confirmed harmless, but the C# handler-resolution path it lives in has zero test coverage.** I grepped the whole script for `\b` and found exactly one live regex usage, in `resolve_handler_implementations()`'s `.cs` branch: `` grep -nE "\b${handler_name}[[:space:]]*\(" ``. Every other regex in the script (the `object`/`inherited` first-line check, `VALIDATION_BEGIN_RE`, etc.) deliberately avoids `\b` via explicit character-class alternatives like `([^A-Za-z0-9_]|$)`, consistent with the claimed fix. I independently tested both engines in this exact environment: GNU grep 3.0's `grep -E '\bHandlerName\('` **matches correctly**, while bash 5.2's native `[[ "$line" =~ \bHandlerName\( ]]` **does not match at all**. So the one remaining `\b` (inside a `grep -E` call, not a bash `[[ =~ ]]`) is not actually broken — the fix was correctly scoped to where the bug actually manifests. That said, no `.cs` fixture exists anywhere in `tests/fixtures/analyze/domain/`, so the entire C# side of FR7 (handler-to-implementation resolution) is unexercised by any test — not a spec violation (FR16 only mandates `.pas`-side coverage), but worth the operator's awareness.

6. **Edge Case wording vs. FR10 implementation: possible spec overreach, not an implementation defect.** `spec.md`'s Edge Cases section states: "A `.pas` file with no `interface`/`implementation` section markers at all ... → yields no type/const/**routine** entries for that file, not a crash." Reading the code: `gather_type_declarations`/`gather_const_declarations` are indeed gated on an `interface`/`implementation` section being present (matches FR9's own explicit "Pascal `interface` sections" framing). But `gather_validation_candidates` (FR10, business-rule candidates) scans every scoped `.pas`/`.cs` file's routine signatures **unconditionally** — FR10's own requirement text never mentions interface/implementation gating. So a `.pas` file with a `Valid*`-named routine but no `interface`/`implementation` markers at all would still surface a `validation_routine_candidates[]` entry, which is consistent with FR10 as literally written but arguably inconsistent with this one Edge Case sentence's blanket "no ... routine entries" claim. Untested either way; flagging as a spec-wording nit for the operator, not a code defect (the code correctly implements FR10 and FR9 as each is separately, explicitly worded).

## Summary

**Passed:** 20/20 criteria
**Failed:** 0/20 criteria
**Verdict:** PASS
