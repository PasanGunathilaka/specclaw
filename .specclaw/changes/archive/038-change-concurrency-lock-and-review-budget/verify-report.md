# Verification Report: 038-change-concurrency-lock-and-review-budget

**Verified:** 2026-09-19 (initial pass) / 2026-09-20 (post-review remediation)
**Model:** claude-sonnet-5
**Verdict:** PASS

**Revision note:** the initial pass below marked AC-8 PASS on evidence that, on the `code-reviewer`
subagent's independent review, turned out to rest on a spec wording that contradicted the spec's own
cited precedent and the actual implementation (see **Code Review** and the corrected **AC-8** entry
below). That is now fixed at the spec level, matching the implementation and its precedent exactly.
Four other real, smaller gaps the reviewer found (see Code Review) are also fixed. This is the
post-remediation report; nothing here is a re-run of a subagent — every fix was made and
re-verified directly, with fresh command output, before this file was finalized.

## Evidence base

`.specclaw/config.yaml` configures no `build.test_command` / `lint_command` / `build_command`, so
`tests_passed`/`lint_passed`/`build_passed` from `specclaw-verify collect` are vacuously true and
carry no weight here. The real evidence is the project's own bash test suites, each re-run fresh
immediately before writing this report, plus direct reproductions in scratch `mktemp -d` trees for
behavior not yet covered by a named suite. `.specclaw/context.md` and `plugins/specclaw/CLAUDE.md`
were read and checked against throughout (see Issues Found for the one place a rule from
`plugins/specclaw/CLAUDE.md` required a design correction mid-build, already applied).

- `bash plugins/specclaw/tests/run-change-lock-tests.sh` → `27 passed, 0 failed`
- `bash plugins/specclaw/tests/run-parser-tests.sh` → `111 passed, 5 failed` (all 5 are the
  pre-existing `no timeout binary on this macOS host` glob-path cluster — confirmed identical on
  `origin/main` before this change existed; zero regressions)
- `bash plugins/specclaw/tests/run-change-size-tests.sh` → `PASS: 64 FAIL: 0`
- `bash plugins/specclaw/tests/run-party-tests.sh` → `280 passed, 1 failed` (the 1 is a pre-existing,
  unrelated domain-normalization case, confirmed identical on `origin/main`)
- `bash plugins/specclaw/tests/run-bootstrap-hook-tests.sh` → `PASS: 44 FAIL: 0`
- `bash plugins/specclaw/tests/shellcheck-gate.sh` → exit 0, "no new findings (23 known, all in the
  baseline)"
- A full sweep of every other registered suite in `.github/workflows/ci.yml` was also run; every
  failure present was reproduced identically against `origin/main` in a scratch worktree (systemd-run
  absent on macOS; `scc`/`lizard`/`jscpd` dependencies for the quality suite; environment-specific
  blueprint/bf-status cases) — none touch any file this change modifies.

## Acceptance Criteria

- ✅ **AC-1:** Two sequential `acquire` calls for the same change: first succeeds, second (before
  release) fails naming the held phase/start-time — `run-change-lock-tests.sh` Case 2 (`2a`/`2b`
  PASS): refusal text `"'c2' is locked — phase=build started=... age 0m"`.
- ✅ **AC-2:** Stale lock refuses without `--force`, succeeds with it — Case 3 (`3a`/`3b` PASS).
- ✅ **AC-3:** `--force` on a non-stale (live) lock still refuses — Case 3 (`3d`/`3e` PASS): the live
  lock survived the bogus `--force` untouched.
- ✅ **AC-4:** `release` on an absent lock exits 0, idempotently — Case 4 (`4a`/`4b` PASS).
- ✅ **AC-5:** `specclaw-build setup` refuses when locked; `finalize` releases even after a recorded
  build failure — Case 5 (`5a`–`5d` PASS), and reproduced live during this build: `finalize`
  released the change's own lock correctly even across a retry (confirmed via `specclaw-change-lock
  status` reading `unlocked` after finalize both times it ran).
- ✅ **AC-6:** `specclaw-pr`/`specclaw-azdo-pr` refuse when locked and release via their `EXIT` trap
  on a `die` path — Case 6 (`6a`–`6e` PASS for both scripts). Note: `specclaw-azdo-pr` required
  moving the acquire ahead of its `AZDO_TOKEN`/org/project/repo checks — caught by this exact test
  (`6b` initially failed because those checks `die` before a later-placed lock ever fired) and fixed
  before this report; see `design.md`'s File Changes Map row for `specclaw-azdo-pr`.
- ✅ **AC-7:** A deferred task with all others complete does not block the `verify` gate —
  `run-change-size-tests.sh` `T19a` PASS (`gate ... verify` → `0`); `T19c` confirms a genuinely
  pending task still blocks it (`1`), so the exclusion is specific to `deferred`, not a general
  loosening.
- ✅ **AC-8** *(corrected — see Code Review)*: A `[>]` task missing `Deferred-Reason:` still counts as
  deferred and warns. In JSON/`--status deferred` mode the warning names the task
  (`` `T3` is deferred with no Deferred-Reason ``, `run-parser-tests.sh` Case 10i PASS). In `--count`
  mode it is one aggregate summary (`WARNING: 1 deferred task(s) missing Deferred-Reason`), matching
  the `n_skipped` precedent exactly — `spec.md`'s FR17/AC-8 originally claimed `--count` names the
  task id too, which was wrong on two counts: it contradicted the very `n_skipped` precedent it cited,
  and it didn't match the shipped (correct) implementation. Spec text corrected, not the code.
- ✅ **AC-9:** The new 4th `--count` field does not corrupt any existing caller's `failed` count —
  verified for `specclaw-build` (this change's own 15/15/0 build-phase record in `state.json`,
  produced by the patched `cmd_finalize`), `specclaw-validate-change` (`T19` above), and
  `specclaw-bootstrap-snapshot` (`run-bootstrap-hook-tests.sh` `T4b`: `1/2 tasks, 0 failed`, not
  corrupted). `specclaw-reconcile`/`specclaw-update-status` were fixed with the identical
  4-variable-read pattern and verified by direct invocation in a scratch fixture during build (not by
  a new named test case in either script's own suite — see Issues Found).
- ✅ **AC-10:** With `session_spawn_cap` unset, the confirm-before-spending step is unchanged —
  `specclaw-party get <dir> session_spawn_cap` returns empty on a fixture with no cap set
  (`run-party-tests.sh`, "SB session_spawn_cap unset by default reads empty" PASS), and
  `skills/propose/SKILL.md`'s own text gates the entire spawn-budget block on that value being
  non-empty before touching the existing `party.default` check.
- ✅ **AC-11:** A low cap forces the ask even under `party.default: true` — verified by static
  presence assertion against `skills/propose/SKILL.md` (`run-party-tests.sh`, "SB propose forces the
  ask even under party.default: true" PASS, matching the literal text `even if \`party.default\` is
  \`true\``) plus the underlying arithmetic (`spawn-budget check` sums correctly — see AC-12). The
  ask itself is prose in a model-driven skill, not a script, so no bash test can drive a live
  confirm-or-decline; this is the same limitation every other `party` SKILL.md behavior in this
  suite already accepts (e.g. the existing "Confirm before spending" step has never had a live-ask
  test either).
- ✅ **AC-12:** After a panel runs, the ledger gains one line and `spawn-budget check` reflects it —
  `run-party-tests.sh` "SB record appends, never rewrites" PASS (`wc -l` → `3` after two `record`
  calls plus one manually-appended decoy line), "SB check sums today's spawns across changes" PASS
  (`16`), "SB check ignores a different day's line" PASS (still `16` after a 2020-dated decoy).

## Test Results

```
run-change-lock-tests.sh:      27 passed, 0 failed
run-parser-tests.sh:           111 passed, 5 failed (pre-existing, unrelated — see Evidence base)
run-change-size-tests.sh:      PASS: 64   FAIL: 0
run-party-tests.sh:            280 passed, 1 failed (pre-existing, unrelated — see Evidence base)
run-bootstrap-hook-tests.sh:   PASS: 44   FAIL: 0
shellcheck-gate.sh:            exit 0, no new findings
```

No `build.test_command`/`lint_command`/`build_command` are configured for this project, so
`specclaw-verify collect`'s own `tests_passed`/`lint_passed`/`build_passed` fields are vacuously
`true` and are not cited as evidence above.

## Code Review

**Code Review:** CHANGES_REQUESTED (initial) → all findings fixed — 1 BLOCK, 3 WARN, 2 NOTE

The `code-reviewer` subagent (whole-change mode, all 10 dimensions) reviewed all 24 changed files
against `spec.md`/`design.md`/`tasks.md` and wrote its findings to `review-report.md`. Every finding
was independently reproduced by direct command before being accepted, then fixed:

1. **[BLOCK] `specclaw-parse-tasks` `--count`-mode warning didn't name the task id, contradicting
   `spec.md`'s original FR17/AC-8 wording.** Reproduced: `--count` on a fixture with a reasonless
   `[>]` task printed only `WARNING: 1 deferred task(s) missing Deferred-Reason` — no id. The
   *implementation* was correct (it deliberately matches the `n_skipped` precedent: one aggregate
   summary in `--count` mode, one per-task named warning in JSON/`--status` mode); the *spec text*
   was wrong, asserting per-task naming for `--count` specifically while simultaneously citing the
   `n_skipped` precedent it contradicted. **Fixed:** `spec.md` FR17 and AC-8 rewritten to accurately
   describe the two-mode behavior that was already shipped and already tested correctly. No code or
   test changed — both were already right.
2. **[WARN] `plan`'s spike path never released the lock before diverting to `/specclaw:archive`.**
   Reproduced by reading `skills/plan/SKILL.md`'s size table and `skills/archive/SKILL.md` (no lock
   handling at all) side by side — a spike-sized change would hold its `plan`-phase lock until
   `git.lock_stale_minutes` (120m) expired. **Fixed:** the spike table row now states the release
   explicitly, before handing off to archive.
3. **[WARN] `tasks.md`'s `T5` still described the pre-correction plan** (acquire inside
   `cmd_collect`) even though the actual, corrected implementation (acquire in
   `skills/verify/SKILL.md`) was already reflected in `design.md`. **Fixed:** `T5`'s `Files:` and
   Notes rewritten to match what actually shipped.
4. **[WARN] `specclaw-build cmd_setup` had no existence check before calling `specclaw-change-lock
   acquire`,** so a typo'd change name would create a stray `changes/<typo>/.lock/` directory via the
   lock's own `mkdir -p`. Reproduced by inspection of `cmd_setup`'s call order. **Fixed:** a
   `[[ -d ... ]] || die` guard now runs before the lock acquire; re-verified with
   `run-change-lock-tests.sh` (`27 passed, 0 failed`, unchanged) plus five other suites that exercise
   `specclaw-build` (`run-memory-parallelism-tests.sh`, `run-timing-tests.sh`,
   `run-staged-files-tests.sh`, `run-task-review-tests.sh`, `run-change-size-tests.sh` — all
   unchanged pass counts).
5. **[NOTE] `specclaw-change-lock`'s `write_meta` interpolated `$phase`/`$host` into JSON
   unescaped.** Low real-world risk (both are internal/system-derived today) but cheap to close.
   **Fixed:** added a one-line `json_esc` helper (mirroring `specclaw-party`'s `json_str`) and routed
   both fields through it.
6. **[NOTE] `design.md` said `party.session_spawn_cap` ships "commented-out"; the shipped
   `config.yaml` ships a bare, valueless key instead** (functionally identical — both read as unset —
   but not literally what the doc said). **Fixed:** `design.md` and `spec.md` FR21 reworded to
   describe what actually shipped, which is the better of the two (self-documenting, not hidden
   behind `#`).

Full findings, evidence, and reasoning: `review-report.md`. Nothing in the original 24-file diff
needed a behavioral rewrite — every BLOCK/WARN was a doc/spec/robustness gap the reviewer's
independent read caught, not a functional defect in the shipped mechanisms.

## Summary

**Passed:** 12/12 criteria
**Failed:** 0/12 criteria
**Code Review:** CHANGES_REQUESTED → fixed (1 BLOCK, 3 WARN, 2 NOTE — all resolved, see Code Review)
**Verdict:** PASS
