# Spec: Per-change concurrency lock, deferred-task state, and a party-review spawn budget

**Change:** 038-change-concurrency-lock-and-review-budget
**Created:** 2026-09-20
**Status:** 🟡 Draft

## Overview

Three independent, additive safeguards, bundled into one change because they came out of the same
retrospective and share no code:

1. **A per-change concurrency lock.** Today nothing stops two separate dispatches (a `plan` fork and
   a `build` dispatch, or a `verify` fork and a `pr` fork) from running against the same change at
   the same time. Both write into the same files — or, under `worktree-per-change`, the same worktree
   directory — and the loser's writes are silently lost. This adds a dispatch-level lock, independent
   of `git.strategy`, that fails a second dispatch fast instead of letting it race.
2. **A `deferred` task state.** A task blocked on a sibling change that hasn't landed yet has no
   status distinct from `pending` (looks unstarted), `failed` (looks broken) or `blocked` (does not
   exist as a task-level marker — `pending`/`in_progress`/`complete`/`failed` are the only four). This
   adds a fifth marker that is visibly not-yet-buildable-through-no-fault-of-its-own, and excludes it
   from the incomplete-task count that gates `verify`.
3. **A party-review spawn budget.** `party.rounds` bounds a single panel's depth, but nothing bounds
   how many panel spawns accumulate across a session's worth of proposals. This adds an opt-in daily
   cap that, once a panel run would exceed it, forces the existing "confirm before spending" prompt
   even when `party.default: true` — so an operator burning through many proposals gets an explicit
   checkpoint instead of the budget draining silently.

All three are off-by-default or fail-open: the lock only ever fires on a genuine concurrent dispatch,
the `deferred` marker is opt-in per task, and `party.session_spawn_cap` is unset by default (no cap,
current behavior unchanged).

## Requirements

### Functional Requirements

**Concurrency lock**

- FR1. A new script, `specclaw-change-lock`, supports `acquire <specclaw_dir> <change> --phase <phase> [--force]`, `release <specclaw_dir> <change>`, and `status <specclaw_dir> <change>`.
- FR2. `acquire` claims `changes/<change>/.lock/meta.json` (directory + file, mirroring the atomic-`mkdir` claim pattern already used by `specclaw-browser-lock`) recording `{pid, phase, started_at, host}`, and exits 0.
- FR3. `acquire` against a change with an existing, non-stale lock refuses (exit 1) and prints the existing lock's phase, start time, and host to stderr — regardless of whether the new request is for the same phase or a different one (the "any phase" default from the proposal's open question: both recorded collisions were same-or-adjacent-phase, so the stricter default catches both without a phase-aware exception to get wrong).
- FR4. Staleness is computed by wall-clock age only (`now - started_at`), never by PID liveness — a lock spans a whole skill dispatch (multiple, separately-invoked `bin/` calls over minutes to hours), not one continuously running process, so `kill -0` on the recorded PID would be meaningless. The threshold is `git.lock_stale_minutes` (default 120, added to `templates/config.yaml`).
- FR5. `acquire` against a stale lock without `--force` refuses (exit 1) and tells the caller to pass `--force`. `acquire --force` against a lock that is **not** stale still refuses — `--force` only ever overrides a lock already classified stale; it never silently clears a live one.
- FR6. `acquire --force` against a stale lock clears it and acquires fresh, and prints (to stderr) that a stale lock was force-cleared, naming its former phase and age.
- FR7. `release` removes the lock directory if present; idempotent (removing an absent lock is not an error).
- FR8. `status` prints `unlocked` or the held lock's `phase`, `started_at`, `host`, and age.
- FR9. `specclaw-build setup` acquires the lock (phase `build`) before doing any git-branch/worktree work, and refuses to proceed (matching its existing die-on-error behavior) if the acquire fails. `specclaw-build finalize` releases the lock as its last step, best-effort (`|| true` — a broken release must not mask a real build failure).
- FR10. `skills/verify/SKILL.md` acquires the lock (phase `verify`) in Step 0, immediately after `specclaw-validate-change ... verify` passes — **not** inside `specclaw-verify collect` itself, because `collect` is also used standalone as a read-only evidence dump (`run-parser-tests.sh` Case 5 runs it directly against this repo's own real changes); embedding the acquire there would make a read-only inspection claim exclusive access and leave an orphaned lock for any caller that never reaches `update-status`. This was corrected during build after that exact regression surfaced. `specclaw-verify update-status` releases it as its last step, best-effort.
- FR11. `specclaw-pr` and `specclaw-azdo-pr` acquire the lock (phase `pr`) as their first action and release it via a `trap ... EXIT`, so a `die` on any code path still releases.
- FR12. `skills/plan/SKILL.md` acquires the lock (phase `plan`) immediately after `specclaw-validate-change ... plan` passes, and releases it as its final step — including the `--author-spec` path, where the lock stays held across the human approval pause (a long pause is exactly what the staleness window and `--force` exist to recover from).
- FR13. A change with no existing lock file behaves exactly as before acquire/release existed — no new file appears until the first `acquire` call.

**Deferred task state**

- FR14. `templates/tasks.md` gains a fifth marker, `[>]` deferred, alongside `[ ]`/`[~]`/`[x]`/`[!]`, and two new optional per-task detail fields: `Deferred-Reason:` (required whenever the marker is `[>]`) and `Deferred-Blocked-On:` (free text naming the sibling change, when known).
- FR15. `specclaw-parse-tasks` recognizes `[>]` as status `deferred`, extracts `deferred_reason` and `deferred_blocked_on` into its JSON task objects, accepts `deferred` as a valid `--status` filter value, and its `--count` output grows a fourth integer: `<done> <total> <failed> <deferred>`.
- FR16. Every existing caller of `specclaw-parse-tasks --count` (`specclaw-bootstrap-snapshot`, `specclaw-reconcile`, `specclaw-update-status`, `specclaw-build`, `specclaw-validate-change`) is updated to read the fourth field, so none of them corrupt their `failed` count by absorbing the new field as trailing words in a three-variable `read`.
- FR17. `specclaw-parse-tasks` on a `[>]` task missing `Deferred-Reason:` still counts it as `deferred` (a script cannot refuse to count a task), but warns — visible, never silently accepted as spec-compliant. In JSON/`--status` output mode, the warning names the task's id (one line per such task). In `--count` mode it is **one aggregate summary line**, not one per task — following the *exact* existing `n_skipped` precedent (a checkbox with no backtick id): `--count`'s calling contract is "one line of integers plus at most a small, fixed number of summary warnings," and a file with many deferred tasks would otherwise flood a caller that greps `--count`'s stderr with N warning lines. This correction was made after `code-reviewer`'s change-038 review caught the spec's original wording ("one stderr warning per such task," matching AC-8's original "naming that task's id" for `--count` specifically) contradicting both the precedent it claimed to follow and the actual implementation.
- FR18. `specclaw-update-task-status` accepts `deferred` as a status and `[>]` as its marker, both directions (`status_to_marker`, `marker_to_status`).
- FR19. `specclaw-validate-change`'s `count_incomplete` becomes `total - done - deferred` (was `total - done`), so a `verify` dispatch is not blocked by tasks correctly deferred to a sibling change. `count_complete` and `count_total` are unchanged — a deferred task is not done, it is excluded from the gate.
- FR20. `templates/status.md`'s Task Progress block gains a `**Deferred:** {{deferred}}` line alongside `Completed` and `Failed`.

**Party-review spawn budget**

- FR21. A new `party.session_spawn_cap` key in `templates/config.yaml`'s `party:` block, shipped as a bare, documented `key:` with no value (YAML null — the same effect as commenting it out, but visible rather than hidden behind a `#`) — unset means no cap, current behavior unchanged.
- FR22. `specclaw-party` gains a `spawn-budget` subcommand: `spawn-budget record <specclaw_dir> <change> <spawns>` appends one line to `.specclaw/party/session-spawns.jsonl` (`{date, change, spawns, at}`, UTC calendar date as the accounting boundary); `spawn-budget check <specclaw_dir>` sums today's `spawns` and prints that single integer.
- FR23. `.specclaw/party/` (top-level, sibling to each change's own `changes/<change>/party/`) is the accepted location for this cross-change counter — it is a session/day-scoped aggregate, not per-change state, so it does not belong under any single change's directory, `state.json`, or `STATUS.md`.
- FR24. In `skills/propose/SKILL.md` step 4a-b ("Confirm before spending"), before checking `party.default`, the skill computes `today's cumulative spawns (spawn-budget check) + this panel's bill (seats × rounds)` and compares it to `party.session_spawn_cap` (`specclaw-party get .specclaw session_spawn_cap`, no default — an unset cap always skips this check). When the cap is set and would be exceeded, the confirm-before-spending ask fires **even if `party.default: true`**, quoting the cap and the cumulative total in addition to the existing roster/bill line.
- FR25. After a panel actually runs (post-tally, whether or not the operator was asked), the skill records the actual spawn count via `spawn-budget record` — `seats` if round 2 was skipped, `seats × 2` otherwise. A panel that was asked about and declined (operator says no) records nothing — no panel ran.

### Non-Functional Requirements

- NFR1. Every new mechanism is additive and fails open on its own errors: an unwritable `.locks`/`.lock`/`party` directory, missing config, or unreadable file must not itself block a lifecycle phase from proceeding (excluding the lock's *deliberate* refusal on a genuine live collision, which is the point of FR3 — that refusal is not a failure mode, it is the feature).
- NFR2. No existing `config.yaml` written before this change gains new required keys — `git.lock_stale_minutes` and `party.session_spawn_cap` both have safe defaults (120 minutes; no cap) when absent.
- NFR3. All new/changed config reads follow this repo's established block-scoped reading rules: `git.lock_stale_minutes` is read the same way other `git.*` keys already are (`yaml_val` — a top-level, one-level-nested key, no collision risk since no other top-level block defines a `lock_stale_minutes` field); `party.session_spawn_cap` is read exclusively through `specclaw-party get` (`party_val`), per the existing rule that no party-config key may be read any other way.
- NFR4. Bash + coreutils only, consistent with the rest of `bin/`; `jq`/`python3` permitted where already used, test suites stay jq-free (existing `run-parser-tests.sh` exception carries over unchanged).
- NFR5. Every new behavior ships covered by a bash test suite (this repo's convention — not `bats`, despite the originating retrospective's phrasing) registered in `.github/workflows/ci.yml`.

## Acceptance Criteria

- **AC-1** — Two sequential `specclaw-change-lock acquire` calls for the same change: the first succeeds (exit 0, lock file written); the second, before any release, fails (exit 1) and its stderr names the first call's phase and start time.
- **AC-2** — `specclaw-change-lock acquire` on a lock older than `git.lock_stale_minutes` fails without `--force` (exit 1, message says to pass `--force`); the same call with `--force` succeeds and clears the old lock.
- **AC-3** — `specclaw-change-lock acquire --force` on a lock that is **not** stale still fails (exit 1) — `--force` never clears a live lock.
- **AC-4** — `specclaw-change-lock release` on a change with no lock exits 0 (idempotent).
- **AC-5** — `specclaw-build setup` fails fast (does not create a branch/worktree) when the change's lock is already held by another live dispatch; `specclaw-build finalize` releases the lock even when the build itself reports a failed status.
- **AC-6** — `specclaw-verify`, `specclaw-pr`, and `specclaw-azdo-pr` each refuse to start when the change's lock is held, and each releases its own lock on completion — including when `specclaw-pr`/`specclaw-azdo-pr` exit early via `die` (proven via the `trap ... EXIT`).
- **AC-7** — A `tasks.md` with one `[>]` deferred task (with `Deferred-Reason:`) and all other tasks `[x]` complete: `specclaw-parse-tasks --count` reports it in the fourth field, and `specclaw-validate-change ... verify` (or `pr`) does **not** report it as an incomplete task blocking the gate.
- **AC-8** — The same file with the deferred task missing `Deferred-Reason:`: it is still reported as deferred. In JSON/`--status deferred` output, a warning naming that task's id is printed to stderr. In `--count` mode, one aggregate summary warning is printed (matching the `n_skipped` precedent exactly), not a per-task line.
- **AC-9** — `specclaw-parse-tasks --count` output growing a fourth field does not corrupt any existing caller's `failed` count — verified for `specclaw-bootstrap-snapshot`, `specclaw-reconcile`, `specclaw-update-status`, `specclaw-build`, and `specclaw-validate-change`.
- **AC-10** — With `party.session_spawn_cap` unset, `/specclaw:propose`'s confirm-before-spending step behaves exactly as before (asks only when `party.default` is false).
- **AC-11** — With `party.session_spawn_cap` set low enough that today's recorded spawns plus the current panel's bill would exceed it, and `party.default: true`, the confirm-before-spending ask fires anyway, and its message names the cap and the cumulative total.
- **AC-12** — After a panel completes, `.specclaw/party/session-spawns.jsonl` gains one line recording that panel's actual spawn count; `specclaw-party spawn-budget check` reflects the updated daily total on the next call.

## Edge Cases

- **Two `acquire` calls racing on `mkdir` at the exact same instant.** `mkdir` is atomic; exactly one wins, matching `specclaw-browser-lock`'s existing pattern (AC1 covers the sequential case; true simultaneity is a property of `mkdir` itself, not new code, and is not separately tested).
- **A lock directory left behind by a killed process, younger than the staleness window.** Reads as a live lock and refuses acquisition — this is a real gap (no PID-liveness fallback, per FR4's own reasoning), and the documented recovery is the same as any live-but-actually-dead lock: wait out the staleness window or use `specclaw-change-lock release` manually. This is a known, accepted limitation, not a defect to design around.
- **`git.lock_stale_minutes` set to a non-numeric or missing value.** Falls back to the default (120), same pattern as `specclaw-parallel-budget`'s config-value guards.
- **A `[>]` task that later becomes buildable.** Setting it back to `[ ]` (or any other marker) via `specclaw-update-task-status` is a normal transition — `deferred` is not a terminal state and carries no special re-entry rule.
- **A `tasks.md` with `[>]` markers but a stale specclaw install predating this change.** An older `specclaw-parse-tasks` treats `[>]` as an unrecognized marker under its `status = "pending"` default (the awk falls through the `x`/`~`/`!` checks) — visible as a task that looks pending rather than deferred, not a crash. No migration is required in either direction.
- **`specclaw-party spawn-budget check` run on a repo with no `.specclaw/party/session-spawns.jsonl` yet.** Prints `0`, creates nothing — the file is created lazily by the first `record` call.
- **Two `propose` runs on the same UTC calendar day from different timezones.** The accounting boundary is UTC date, consistently, matching every other `date -u` use in this codebase; not "the operator's local day."

## Dependencies

None outside this repo's own `bin/` and `templates/`.

## Notes

- **Scope carried over from the proposal, verbatim:** `specclaw-set-phase`'s existing "not locked, by
  design" `state.json` write model is untouched — this is a *dispatch* lock, a different file and a
  different failure mode, and nothing here relaxes or replaces that design comment. Cross-repo
  dependency tracking for `Deferred-Blocked-On:` stays free text, never a structured link. No change
  to pending proposals `035-task-review-gate` or `036-right-sized-change-paths`.
- **`.locks/playwright/` naming precedent.** `specclaw-browser-lock` already owns `.specclaw/.locks/playwright/`; the change lock uses `changes/<change>/.lock/` (per-change, not a shared pool) to avoid any naming collision or shared-directory contention between the two lock mechanisms.
