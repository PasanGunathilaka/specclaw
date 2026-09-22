# Code Review Report: 038-change-concurrency-lock-and-review-budget

**Reviewed:** 2026-09-20
**Model:** claude-sonnet-5
**Verdict:** CHANGES_REQUESTED

## Summary

24 files reviewed across three independent mechanisms (concurrency lock, deferred task state,
party spawn budget). The lock and spawn-budget mechanisms are solid and well tested. One
finding blocks: the deferred-task `--count` warning does not meet its own spec's acceptance
criterion, and the shipped test suite pins the wrong behavior instead of catching it —
`verify-report.md` also marks AC-8 PASS despite the mismatch. 1 BLOCK, 3 WARN, 2 NOTE.

## Findings

### [BLOCK] plugins/specclaw/bin/specclaw-parse-tasks:139-146 — Correctness / Design adherence
**Problem:** Spec FR17 requires: *"prints one stderr warning per such task"* and AC-8 requires,
specifically for `--count`: *"a warning naming that task's id is printed to stderr."* The shipped
`emit_task()` only names the task id when **not** counting:
```awk
if (status == "deferred" && deferred_reason == "") {
    n_missing_reason++
    if (!counting)
      printf "WARNING: `%s` is deferred with no Deferred-Reason\n", task_id > "/dev/stderr"
  }
```
In `--count` mode, `END` prints only an aggregate with no id:
```awk
if (n_missing_reason > 0)
      printf "WARNING: %d deferred task(s) missing Deferred-Reason\n", n_missing_reason > "/dev/stderr"
```
Verified directly:
```
$ specclaw-parse-tasks --count dtest.md
WARNING: 1 deferred task(s) missing Deferred-Reason
1 2 0 1
```
No task id is named in `--count` mode, which is exactly the mode AC-8 is about. The test suite
(`run-parser-tests.sh` Case 10i) locks in the wrong behavior rather than catching it — its own
comment says *"in --count mode it is one summary line, matching the existing n_skipped
precedent"* — and `verify-report.md` marks AC-8 PASS on the strength of that same test, so this
divergence from the written spec shipped uncaught through both build and verify.
**Fix:** Either (a) make `--count` mode print one named warning per missing-reason task (matching
FR17/AC-8 literally), or (b) if the aggregate-only behavior is the intended, better design (it does
match the `n_skipped` precedent), update `spec.md` FR17/AC-8 to describe an aggregate warning
instead of a per-task named one, so the spec and the shipped behavior agree. Ship one or the other —
right now the spec makes a promise the code and its own tests do not keep.

### [WARN] plugins/specclaw/skills/plan/SKILL.md:60-65,89 — Correctness (lock lifecycle)
**Problem:** Step 1 acquires the lock for every `plan` dispatch unconditionally, before the size is
even known. Step 4's size table says, for a spike: *"present it, get an explicit noted, and go
straight to `/specclaw:archive`. `build`, `verify` and `pr` are refused for a spike — say so rather
than attempting them."* Step 10 (`**Release the concurrency lock:**`) is the only place the lock
acquired in step 1 is released, and neither step 10 nor the spike row in step 4's table clarifies
whether a spike run continues through steps 5–10 (release included) or exits toward `/specclaw:archive`
before reaching them. `archive/SKILL.md` (read in full) contains no lock handling at all, so if a
spike run does stop short of step 10, the lock is left held until `git.lock_stale_minutes` (120m
default) expires — a self-inflicted stale lock on exactly the size tier (spike) this feature does not
mention anywhere in spec.md's Edge Cases or design.md's Notes.
**Fix:** Make step 10 (or the spike row in step 4) state explicitly that the release still runs for a
spike before/instead of handing off to `/specclaw:archive`, removing the ambiguity — this is one
sentence, and it closes a class of orphaned-lock bug this same change already had to fix once for
`specclaw-verify collect` (design.md Key Decision 3).

### [WARN] plugins/specclaw/skills/verify/SKILL.md — Scope creep (D9)
**Problem:** `skills/verify/SKILL.md` is modified by this change (it now carries the lock's
`acquire` call, per design.md's own File Changes Map row and Key Decision 3's correction), but no
task in `tasks.md` declares it. `T5`'s `Files:` list is `plugins/specclaw/bin/specclaw-verify` only,
and `T5`'s own Notes text still describes the pre-correction plan (*"`cmd_collect`: acquire (phase
`verify`) before running any test/lint/build command"*) rather than the shipped design. `design.md`
was updated to reflect the correction (it has its own `skills/verify/SKILL.md` row and Key Decision
3); `tasks.md` was not.
**Fix:** Update `T5`'s `Files:` list and Notes to name `skills/verify/SKILL.md` and describe the
actual (corrected) placement, so tasks.md stops contradicting design.md on where this change's own
key correction landed.

### [WARN] plugins/specclaw/bin/specclaw-build:185-189 — YAGNI / side effect
**Problem:** `specclaw-change-lock acquire`'s `mkdir -p "$(dirname "$lock_dir")"` creates
`changes/<change>/` if it doesn't already exist. `cmd_setup` calls acquire before any check that the
named change actually exists, so `specclaw-build setup .specclaw <typo'd-change-name>` now creates a
stray, otherwise-empty `changes/<typo'd-change-name>/.lock/` directory as a side effect of the lock
call alone (the subsequent branch/worktree logic already had no existence check before this change,
so this is a new artifact, not a new refusal).
**Fix:** Not blocking (the underlying missing-change-name gap pre-dates this change), but worth a
one-line guard in `cmd_setup` — check `[[ -d "$specclaw_dir/changes/$change_name" ]]` before
acquiring — so a typo produces a clean error instead of a stray directory plus a branch/worktree.

### [NOTE] plugins/specclaw/bin/specclaw-change-lock:217-225 — Security / robustness
**Problem:** `write_meta` interpolates `$phase` and `$host` directly into a JSON literal with no
escaping:
```bash
cat > "$meta" <<EOF
{"pid":$$,"phase":"$phase","started_at":"$started_at","host":"$host"}
EOF
```
`$phase` is always one of a closed set of literals from trusted `bin/`/`SKILL.md` callers today, and
`$host` comes from `hostname`, so this is low real-world risk — but a future caller passing an
unsanitized `--phase` value, or a host name containing a `"`, would write malformed JSON that
`json_get`'s `jq` path would then fail to parse.
**Suggestion:** Route both through the `json_str`-style escaping already used in `specclaw-party`
(`json_str "$phase"` / `json_str "$host"`) for defense in depth.

### [NOTE] plugins/specclaw/templates/config.yaml:189 — Design adherence (minor)
**Problem:** design.md's File Changes Map says to add *"commented-out `party.session_spawn_cap`"*.
The shipped template instead ships an uncommented key with no value (`session_spawn_cap:` followed
only by a trailing comment), which is functionally equivalent (`specclaw-party get` reads it as
empty/unset, verified) but not literally what design.md describes.
**Suggestion:** Either comment the key out (`# session_spawn_cap: 20`) to match design.md literally,
or amend the design.md row — cosmetic, no functional difference either way.

## Verdict Rationale

The concurrency-lock and party-spawn-budget mechanisms are well built, thoroughly tested (all new
`run-change-lock-tests.sh` cases pass; `run-party-tests.sh`'s only failure is a pre-existing,
unrelated flake confirmed present on `main`), and each of AC-1 through AC-6 and AC-10 through AC-12
is exercised and green. The deferred-task-state mechanism, however, ships one acceptance criterion
(AC-8, backed by FR17) that its own implementation and its own test suite do not satisfy — the
`--count`-mode warning never names the task id the spec requires, and `verify-report.md` already
(incorrectly) marked AC-8 as passing on the strength of that same test. That is a spec-vs-shipped
divergence a reviewer is specifically positioned to catch, so it blocks. The two lock-lifecycle WARN
findings (the spike path's ambiguous interaction with lock release, and `tasks.md` not reflecting
the mid-build correction to where verify's lock acquire lives) are real gaps worth closing before
merge but do not on their own risk incorrect behavior in the common path. The NOTE items are
low-risk hardening suggestions.
