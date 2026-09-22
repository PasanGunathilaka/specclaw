# Tasks: Per-change concurrency lock, deferred-task state, and a party-review spawn budget

**Change:** 038-change-concurrency-lock-and-review-budget
**Created:** 2026-09-20
**Total Tasks:** 15

## Summary

Three independent mechanisms (concurrency lock, deferred task state, party spawn budget) built as
foundation scripts first (Wave 1), wired into their consumers (Wave 2), then covered by tests and
registered in CI (Wave 3). Waves 1–2's tasks are grouped by feature but have no cross-feature
dependencies, so a build with `parallel_tasks > 1` can run same-wave tasks from different features
concurrently without file collisions.

## Tasks

### Wave 1 — Foundation scripts

- [x] `T1` — Create `specclaw-change-lock` and its config default
  - Files: `plugins/specclaw/bin/specclaw-change-lock` (new), `plugins/specclaw/templates/config.yaml`
  - Estimate: medium
  - Kind: impl
  - Notes: `acquire <specclaw_dir> <change> --phase <phase> [--force]`, `release <specclaw_dir> <change>`, `status <specclaw_dir> <change>`. Model the atomic claim on `specclaw-browser-lock`'s `mkdir` pattern (spec.md FR1–FR8; design.md Key Decision 1–2). Lock lives at `changes/<change>/.lock/meta.json` (`{pid, phase, started_at, host}`). Staleness = wall-clock age vs. `git.lock_stale_minutes` (default 120) — never PID `kill -0`. `--force` clears a stale lock only; it must still refuse a live one. Add `git.lock_stale_minutes: 120` to `templates/config.yaml`'s `git:` block, commented with its purpose. Make executable (`chmod +x`) and add a `.cmd` shim only if other `bin/` scripts without Windows equivalents don't require one — check `plugins/specclaw/bin/*.cmd` naming convention first (only `auth-azdo`/`auth-jira` currently have `.cmd` shims; do not add one unless the pattern says otherwise).

- [x] `T2` — Add the `deferred` task state to `specclaw-parse-tasks`
  - Files: `plugins/specclaw/bin/specclaw-parse-tasks`
  - Estimate: medium
  - Kind: impl
  - Notes: Recognize `[>]` as `status="deferred"` in the awk parser. Parse two new detail lines into the JSON task object: `Deferred-Reason:` → `deferred_reason`, `Deferred-Blocked-On:` → `deferred_blocked_on` (empty string when absent, same convention as `files`/`depends`). Add `deferred` to the `--status` validator's accepted set (both the `usage` text and the case statement). `--count` output becomes `"<done> <total> <failed> <deferred>"` — add an `n_deferred` awk counter alongside `n_done`/`n_failed`. A `[>]` task with no `Deferred-Reason:` is still counted deferred; print one stderr warning naming its task id (mirror the existing `n_skipped` warning style, spec.md FR17). Update the script's own `--help`/usage text and header comment to document the new format.

- [x] `T3` — Add the party spawn-budget ledger
  - Files: `plugins/specclaw/bin/specclaw-party`, `plugins/specclaw/templates/config.yaml`
  - Estimate: small
  - Kind: impl
  - Notes: Add `spawn-budget record <specclaw_dir> <change> <spawns>` (appends one JSON line — `{date, change, spawns, at}`, UTC date — to `.specclaw/party/session-spawns.jsonl`, creating the directory/file lazily) and `spawn-budget check <specclaw_dir>` (sums `spawns` across lines matching today's UTC date, prints one integer, `0` when the file doesn't exist). Add `party.session_spawn_cap` to `templates/config.yaml`'s `party:` block, shipped commented-out/unset (design.md FR21 — absent means no cap). Read it only through the existing `party_val`/`get` machinery already in this file — do not add a second config reader.

### Wave 2 — Wire the lock into every dispatch entry point; wire deferred-state and spawn-budget into their consumers

- [x] `T4` — Acquire/release the lock in `specclaw-build`
  - Files: `plugins/specclaw/bin/specclaw-build`
  - Estimate: small
  - Kind: impl
  - Depends: T1
  - Notes: `cmd_setup`: call `specclaw-change-lock acquire <specclaw_dir> <change> --phase build` before any branch/worktree mutation; `die` with the lock script's own stderr message on refusal. `cmd_finalize`: call `specclaw-change-lock release <specclaw_dir> <change>` as the last step, suffixed `|| true` (a release failure must never mask the build's real result — design.md Key Decision 4).

- [x] `T5` — Acquire/release the lock for `specclaw-verify`
  - Files: `plugins/specclaw/bin/specclaw-verify`, `plugins/specclaw/skills/verify/SKILL.md`
  - Estimate: small
  - Kind: impl
  - Depends: T1
  - Notes: **Corrected during build** (`code-reviewer`'s change-038 review caught this description as stale): the acquire does NOT live inside `cmd_collect` — `collect` is also used as a standalone read-only evidence dump (`run-parser-tests.sh` Case 5 runs it against this repo's own real changes), so a lock-acquiring `collect` claims exclusive access on a read-only call and orphans a lock for any caller that never reaches `update-status`. The acquire lives in `skills/verify/SKILL.md`'s Step 0 instead (mirroring `plan`'s placement), immediately after `specclaw-validate-change ... verify` passes; only `release` (idempotent, safe even if nothing was ever acquired) stays inside `cmd_update_status`, as its last step, `|| true`.

- [x] `T6` — Acquire/release the lock in `specclaw-pr` and `specclaw-azdo-pr`
  - Files: `plugins/specclaw/bin/specclaw-pr`, `plugins/specclaw/bin/specclaw-azdo-pr`
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: Both scripts are single monolithic invocations, so acquire (phase `pr`) as the very first action in each, then `trap 'specclaw-change-lock release "$SPECCLAW_DIR" "$CHANGE_NAME" || true' EXIT` immediately after a successful acquire, so every `die` exit path still releases (design.md Key Decision 4, spec.md FR11/AC6). Use whatever variable names each script already holds for the specclaw dir/change name — do not introduce new ones.

- [x] `T7` — Acquire/release the lock in the plan skill
  - Files: `plugins/specclaw/skills/plan/SKILL.md`
  - Estimate: small
  - Kind: docs
  - Depends: T1
  - Notes: Immediately after step 1's `specclaw-validate-change ... plan` passes, add `specclaw-change-lock acquire .specclaw <change> --phase plan`; stop and report if it refuses. Add a final step releasing the lock (`specclaw-change-lock release .specclaw <change>`) that runs on both the `--author-spec` path and the single-shot path — including after the `--author-spec` approval pause, not before it (spec.md FR12: the lock stays held across the human review gate).

- [x] `T8` — Add `deferred` to `specclaw-update-task-status`
  - Files: `plugins/specclaw/bin/specclaw-update-task-status`
  - Estimate: small
  - Kind: impl
  - Depends: T2
  - Notes: `status_to_marker`: `deferred) echo "[>]" ;;`. `marker_to_status`: `"[>]") echo "deferred" ;;`. Update the script's header comment listing statuses/markers.

- [x] `T9` — Exclude `deferred` from `specclaw-validate-change`'s incomplete-task gate
  - Files: `plugins/specclaw/bin/specclaw-validate-change`
  - Estimate: small
  - Kind: impl
  - Depends: T2
  - Notes: `count_fields`'s fallback `"0 0 0"` → `"0 0 0 0"`. Add `count_deferred() { count_fields "$1" | awk '{print $4+0}'; }`. Change `count_incomplete` to `awk '{print ($2+0)-($1+0)-($4+0)}'` (total − done − deferred, spec.md FR19). `count_total`/`count_complete` unchanged.

- [x] `T10` — Fix the other `--count` callers for the new 4th field
  - Files: `plugins/specclaw/bin/specclaw-bootstrap-snapshot`, `plugins/specclaw/bin/specclaw-reconcile`, `plugins/specclaw/bin/specclaw-update-status`
  - Estimate: small
  - Kind: impl
  - Depends: T2
  - Notes: Each currently does `read -r a b c <<< "$(... --count ... || echo '0 0 0')"`. Add a fourth variable and change the fallback literal to `'0 0 0 0'` in all three, so the new deferred field doesn't get absorbed into the `failed` variable by `read`'s overflow behavior (design.md Key Decision 5, spec.md FR16/AC9). None of the three need to *use* the deferred count — this task is purely about not corrupting `failed`.

- [x] `T11` — Document the `deferred` marker in templates
  - Files: `plugins/specclaw/templates/tasks.md`, `plugins/specclaw/templates/status.md`
  - Estimate: small
  - Kind: docs
  - Depends: T2
  - Notes: `tasks.md`: add `- \`[>]\` Deferred` to the Legend, and add `Deferred-Reason:`/`Deferred-Blocked-On:` to the task-format code block (mark them "required when marker is `[>]`" / "optional"). `status.md`: add `**Deferred:** {{deferred}}` under Task Progress, alongside `Completed`/`Failed`.

- [x] `T12` — Wire the spawn-budget check into the propose skill
  - Files: `plugins/specclaw/skills/propose/SKILL.md`
  - Estimate: medium
  - Kind: docs
  - Depends: T3
  - Notes: In step 4a/b ("Confirm before spending"): before the existing `party.default` check, run `specclaw-party get .specclaw session_spawn_cap` (no `--default` — absent means skip this whole check). When set, compute `specclaw-party spawn-budget check .specclaw` (today's cumulative) + this panel's bill (`seats × rounds`, already computed for the existing message) and compare to the cap. If it would be exceeded, force the confirm-before-spending ask **even when `party.default` is true**, and add the cap and cumulative total to the message (spec.md FR24). After the panel actually runs (post-tally in step e, whichever seats/rounds actually executed — `seats` alone if round 2 was skipped, `seats × 2` otherwise), call `specclaw-party spawn-budget record .specclaw <change> <spawns>` (spec.md FR25). A panel the operator declined records nothing.

### Wave 3 — Tests

- [x] `T13` — Test the concurrency lock
  - Files: `plugins/specclaw/tests/run-change-lock-tests.sh` (new), `.github/workflows/ci.yml`
  - Estimate: medium
  - Kind: test
  - Depends: T1, T4, T5, T6, T7
  - Notes: Cover: acquire/release round-trip; second acquire on a live lock refuses and names the phase/start-time (AC1); acquire on a stale lock refuses without `--force` and succeeds with it (AC2); `--force` on a non-stale lock still refuses (AC3); `release` on an absent lock exits 0 (AC4); `specclaw-build setup` refuses when locked and `finalize` releases even after a recorded build failure (AC5); `specclaw-pr`/`specclaw-azdo-pr` release via the trap on a `die` exit path (AC6) — use a real git repo fixture the way `run-phase-state-tests.sh` does. Register the new suite in `.github/workflows/ci.yml` (an unregistered suite silently never runs — plugin CLAUDE.md).

- [x] `T14` — Test the deferred task state end to end
  - Files: `plugins/specclaw/tests/run-parser-tests.sh`, `plugins/specclaw/tests/run-change-size-tests.sh`, `plugins/specclaw/tests/run-bootstrap-hook-tests.sh`
  - Estimate: medium
  - Kind: test
  - Depends: T2, T8, T9, T10, T11
  - Notes: `run-parser-tests.sh`: `[>]` parses to `status: "deferred"` with its detail fields in the JSON; `--count` emits the 4th integer correctly; `--status deferred` filters correctly; a `[>]` task missing `Deferred-Reason:` still counts and warns (AC7, AC8). `run-change-size-tests.sh` — the actual home of `specclaw-validate-change` coverage, not `run-phase-state-tests.sh` as originally guessed: a `tasks.md` with one deferred task and the rest complete passes the `verify` incomplete-count gate, and a genuinely pending task still blocks it (AC7). `run-bootstrap-hook-tests.sh` (T4b): a deferred task renders as `1/2 tasks, 0 failed`, proving the 4th `--count` field did not spill into `t_failed` (AC9, for `specclaw-bootstrap-snapshot` specifically — `specclaw-reconcile`/`specclaw-update-status` were verified manually against the same fixture shape since neither has an existing suite asserting `--count`'s exact output).

- [x] `T15` — Test the party spawn budget
  - Files: `plugins/specclaw/tests/run-party-tests.sh`
  - Estimate: medium
  - Kind: test
  - Depends: T3, T12
  - Notes: `spawn-budget record` then `check` round-trips the daily sum; a second day's fixture data does not roll into today's total; with no cap set, the confirm-before-spending path is unchanged under `party.default: true` (AC10); with a low cap and `party.default: true`, the ask still fires and its message names the cap and cumulative total (AC11); after a panel run, `session-spawns.jsonl` gains exactly one line with the correct spawn count (AC12). Follow this suite's existing fixture-with-decoy-keys convention (plugin CLAUDE.md's `party_val` section) for the new `session_spawn_cap` config read.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
- `[>]` Deferred

**Task format:**
```
- [ ] `T<n>` — <title>
  - Files: <files to create/modify>
  - Estimate: small | medium | large
  - Kind: docs | test | config | refactor | impl | migration   (optional; hints the build subagent's role, tools, and model)
  - Depends: <task ids> (if any)
  - Notes: <additional context>
```

The optional `Kind` hint is consumed by `build.dynamic_agents` (when enabled) to
synthesize a specialized subagent per task. Omit it and build classifies
heuristically, defaulting to `impl`.
