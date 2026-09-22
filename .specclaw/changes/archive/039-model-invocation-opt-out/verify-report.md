# Verify Report: 039-model-invocation-opt-out

**Verdict: PASS**

**Verified:** 2026-09-20 · branch `specclaw/039-model-invocation-opt-out` · HEAD `4fd3a51`

## Acceptance criteria

| AC | Verdict | Evidence |
|---|---|---|
| **AC-1** — no bf skill passes collector stdout as agent context | ✅ | `grep -rl 'collected JSON\|stdout of Step' skills/bf-*/SKILL.md` → 0 files (was 15). Pinned by test E1. |
| **AC-2** — each site names the same `.collect/<phase>.json` in command and context | ✅ | Every path appears exactly twice (redirect + pass-as-context); `clarify-extract.json` 4× = one collect feeding three Mode-A spawns. 15 pass sites. |
| **AC-3** — `references/model-invocation-map.md`, one row per spawn site | ✅ | 19 rows, **1 narration / 18 judgement**, each with a cited line and a verbatim quote. Three citations independently spot-checked against source; all 19 now pinned by test H1. |
| **AC-4** — `bf.narration: false` produces the report without spawning | ✅ ¹ | Renderer produces `quality-report.md` standalone (no agent). The skill's branch is markdown, so the *decision rule* is what the suite pins (Group A, 19 assertions), not the skill's runtime behaviour. See caveat below. |
| **AC-5** — the rendered report passes `lint-report` unmodified | ✅ | `REPORT-LINT: PASS — every MOD-###, every QI-### and all three computed blocks agree`. Independently re-verified by the orchestrator: all three anchored regions byte-identical to their `report_blocks.<field>` (254/253B, 181/180B, 363/362B — the 1B is the trailing newline `$()` strips on both sides). Tests B6, C1, C2. |
| **AC-6** — every narrated section carries the marker | ✅ | 10 markers in legacy mode, 8 in delta; no `{{placeholder}}` and no template instruction comment survives. Tests B7, B8, B9. |
| **AC-7** — absent/`true` behaves exactly as today | ✅ | `off`, `no`, `0`, empty and absent all leave narration ON; only the literal `false` disables. Tests A7–A13, against a config carrying decoy `narration:` keys in three other blocks and an inline trailing comment. |
| **AC-8** — `--no-model` tightens, never loosens | ✅ | Tests A14–A19, including the explicit asymmetry: no token turns narration back on against `bf.narration: false`. |
| **AC-9** — suite registered in CI; shellcheck clean with baseline unmodified | ✅ | `ci.yml:71`. Registration checked **both ways**: every suite named in a workflow exists, every suite on disk is named in a workflow (`run-trigger-tests.sh` → `trigger-evals.yml`, by design). `shellcheck-gate.sh` rc=0, `git status` on `shellcheck-baseline.txt` clean. |
| **AC-10** — `specclaw-init` adds the `.collect/` ignore once | ✅ | Second init adds nothing; exactly one entry. Tests F1, F2. |
| **AC-11** — `lint-report` reaches a verdict on a zero-entry QI registry | ✅ | Before: rc=1, **no stdout, no stderr**. After: `REPORT-LINT: PASS`, rc=0. Tests D2 (exit code) **and** D3 (non-empty output) — an exit-code-only assertion would not have caught the original symptom. |

¹ **Caveat on AC-4.** `skills/bf-quality/SKILL.md` is an instruction document, not executable code. What is machine-verified is the renderer (it runs, standalone, and its output lints clean) and the branch's decision rule (Group A). That the model actually takes the branch is not something this repo can assert in bash today — true of every specclaw skill, not new here, but it is the weakest link in this AC and should be read as such.

## Gates

No `test_command` / `lint_command` / `build_command` is configured for this project, so `specclaw-verify collect` returned empty gate output. The real gates are the bash suites CI runs; **all 30 were executed**.

- **20 passed, 10 failed.**
- **All 10 failures are pre-existing on `origin/main`**, established by running each one in a clean `git worktree` at `origin/main` (`79939ac`) and diffing the failing-assertion sets after normalising temp paths, PIDs, SHAs and timings:

| Suite | Baseline | Branch | |
|---|---|---|---|
| `run-bf-status-tests.sh` | 129 pass / 4 fail | identical | pre-existing |
| `run-blueprint-tests.sh` | 125 / 14 | identical | pre-existing |
| `run-change-numbering-tests.sh` | 6 failing assertions | identical | pre-existing |
| `run-long-orchestration-tests.sh` | 240 / 32 | same assertions (timing 35s vs 39s only) | pre-existing |
| `run-parser-tests.sh` | 5 failing | identical | pre-existing |
| `run-party-tests.sh` | 1 failing | identical | pre-existing |
| `run-phase-state-tests.sh` | 1 failing | identical | pre-existing |
| `run-quality-tests.sh` | 327 / 9 | 327 / 9, identical assertions | pre-existing |
| `run-replay-classification-tests.sh` | 4 failing | identical | pre-existing |
| `run-synth-agent-tests.sh` | 1 failing | identical | pre-existing |

`run-quality-tests.sh` matters most, because **T8 edits that script** — its failing set is byte-identical to baseline, so the fix introduces no regression.

- **`run-narration-gate-tests.sh`: 46 passed, 0 failed, 0 skipped.**
- **`shellcheck-gate.sh`: rc=0**, baseline unmodified.

## Code review

**Code Review:** APPROVED_WITH_NOTES — 2 findings: 0 BLOCK, 2 WARN, 0 NOTE. **Both fixed** in `4fd3a51`:

1. `--mode delta` stamped the narration marker over `{{scan_scope}}`, a mechanical fact the artifact already carries. Now filled from `scan_scope.config_hash`; delta mode is exercised.
2. The audit's line citations went stale inside this change (T1 ran before T4 moved the lines). Spawn citations re-anchored and pinned by Group H; prose evidence citations drop the volatile `:line`, keeping the quote as the anchor.

Fixing (2) surfaced a third defect of the same family: `bf-[a-z-]+` cannot match `bf-e2e`, so one of nineteen rows fell silently out of both the fix and the new check. Class widened to `[a-z0-9-]`, and H1 now has a floor of 19 so the omission fails loudly instead of passing quietly. Both new assertions (G1, H1) were verified by injecting the drift they exist to catch.

## Scope

28 files, every one declared in a task. Two tasks were added during build and recorded in `spec.md` (AC-11, the scope note) and `tasks.md`: **T8** (pre-existing `|| true` fix, operator-approved) and **T9** (`yaml_val` byte-identity, found by T6).
