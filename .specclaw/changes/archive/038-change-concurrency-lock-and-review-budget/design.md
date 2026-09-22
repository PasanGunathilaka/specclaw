# Design: Per-change concurrency lock, deferred-task state, and a party-review spawn budget

**Change:** 038-change-concurrency-lock-and-review-budget
**Created:** 2026-09-20

## Technical Approach

Three independent mechanisms, each following an existing pattern in this codebase rather than
inventing a new one:

1. **Concurrency lock** — a new `bin/specclaw-change-lock`, modeled directly on
   `specclaw-browser-lock`'s atomic-`mkdir` claim, but with **wall-clock staleness** as the only
   liveness signal (no PID `kill -0` check). `specclaw-browser-lock`'s PID check is valid because a
   slot is held for the lifetime of one running process; a change-dispatch lock spans an entire skill
   run — `specclaw-build setup` and `specclaw-build finalize` are two *separately invoked* processes,
   bridged only by the filesystem, so there is no single PID whose liveness would mean anything by the
   time anyone re-checks it.

2. **Deferred task state** — a fifth checkbox marker (`[>]`) alongside the four
   `specclaw-parse-tasks`/`specclaw-update-task-status` already know (`[ ] [~] [x] [!]`), plumbed
   through the one shared counter (`--count`) so every caller sees it consistently instead of five
   separate re-implementations.

3. **Party spawn budget** — an append-only JSONL ledger under `.specclaw/party/`, read the same way
   every other cross-run count in this repo is read (sum-on-read, no cached total, matching
   `specclaw-timer`'s append-only ledger and the "derived, not stored" principle in `context.md`).

## Architecture

```
propose/SKILL.md ──acquire(plan)──> specclaw-change-lock ──writes──> changes/<c>/.lock/meta.json
plan/SKILL.md    ──acquire(plan)──┘                                          ▲
specclaw-build    ──acquire(build) [setup] / release [finalize]──────────────┤
specclaw-verify   ──acquire(verify) [collect] / release [update-status]──────┤
specclaw-pr       ──acquire(pr) + trap release────────────────────────────────┘
specclaw-azdo-pr  ──acquire(pr) + trap release────────────────────────────────┘

tasks.md `[>]` ──parsed by── specclaw-parse-tasks --count ──4 ints──> {bootstrap-snapshot,
                                                                        reconcile,
                                                                        update-status,
                                                                        build,
                                                                        validate-change}
                                                                        (validate-change excludes
                                                                         deferred from the gate)

propose/SKILL.md step 4b ──check──> specclaw-party spawn-budget check .specclaw/party/session-spawns.jsonl
                          ──record (post-panel)──> appends one line
```

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `bin/specclaw-change-lock` | Create | `acquire`/`release`/`status` subcommands; atomic `mkdir` claim; wall-clock staleness; `--force` clears stale only |
| `templates/config.yaml` | Modify | Add `git.lock_stale_minutes: 120` (git: block); add `party.session_spawn_cap` (party: block) as a bare, documented `key:` with no value — YAML reads this as null/unset, same effect as commenting it out, but self-documenting rather than hidden behind a `#` (corrected wording here after `code-reviewer`'s change-038 review — the shipped config does not literally comment the line out) |
| `bin/specclaw-build` | Modify | `cmd_setup`: acquire lock (phase `build`) before branch/worktree work, `die` on refusal. `cmd_finalize`: release lock as last step, `\|\| true` |
| `bin/specclaw-verify` | Modify | `cmd_update_status`: release lock, `\|\| true`. (Acquire does **not** live in `cmd_collect` — see `skills/verify/SKILL.md` row below and Key Decision 3's correction.) |
| `bin/specclaw-pr` | Modify | Acquire lock (phase `pr`) as first action; `trap 'specclaw-change-lock release ...' EXIT` |
| `bin/specclaw-azdo-pr` | Modify | Same as `specclaw-pr`, but the acquire had to move ahead of the `AZDO_TOKEN`/org/project/repo checks (discovered via `run-change-lock-tests.sh` Case 6: those credential checks `die` before ever reaching a later-placed lock, so the lock never fired) |
| `skills/plan/SKILL.md` | Modify | Step 1: acquire lock (phase `plan`) after `validate-change` passes. Final step: release lock (both `--author-spec` and single-shot paths) |
| `skills/verify/SKILL.md` | Modify | Step 0: acquire lock (phase `verify`) after `validate-change` passes — corrected here rather than inside `specclaw-verify collect` (see Key Decision 3) |
| `templates/tasks.md` | Modify | Add `[>]` deferred to the legend; add `Deferred-Reason:`/`Deferred-Blocked-On:` to the task-format snippet |
| `bin/specclaw-parse-tasks` | Modify | Recognize `[>]` → `status="deferred"`; parse `Deferred-Reason:`/`Deferred-Blocked-On:` detail lines; add `deferred` to `--status`'s valid set; `--count` emits a 4th integer; warn (not skip) on a `[>]` task with no reason |
| `bin/specclaw-update-task-status` | Modify | `status_to_marker`/`marker_to_status`: add `deferred` ↔ `[>]` |
| `bin/specclaw-validate-change` | Modify | `count_fields` fallback `"0 0 0"` → `"0 0 0 0"`; add `count_deferred`; `count_incomplete` = `total - done - deferred` |
| `bin/specclaw-bootstrap-snapshot` | Modify | `read -r t_done t_total t_failed` → `... t_failed t_deferred`; fallback `'0 0 0'` → `'0 0 0 0'` (deferred unused here, read only to keep `t_failed` uncorrupted) |
| `bin/specclaw-reconcile` | Modify | Same `read`/fallback fix as above |
| `bin/specclaw-update-status` | Modify | Same `read`/fallback fix as above |
| `templates/status.md` | Modify | Add `**Deferred:** {{deferred}}` under Task Progress |
| `bin/specclaw-party` | Modify | Add `spawn-budget record <specclaw_dir> <change> <spawns>` / `spawn-budget check <specclaw_dir>` subcommands, reading/writing `.specclaw/party/session-spawns.jsonl` |
| `skills/propose/SKILL.md` | Modify | Step 4a "Confirm before spending": compute cumulative + bill vs. `session_spawn_cap`, force the ask when it would be exceeded; after the panel runs, call `spawn-budget record` |
| `.github/workflows/ci.yml` | Modify | Register the new test suite |
| `tests/run-change-lock-tests.sh` | Create | Lock acquire/refuse/stale/force-clear/release/status coverage |
| `tests/run-parser-tests.sh` | Modify | Extend for `[>]`, `--count`'s 4th field, `deferred` status filter, missing-reason warning |
| `tests/run-phase-state-tests.sh` | Modify | Extend `specclaw-validate-change` coverage for deferred-exclusion from `count_incomplete` |
| `tests/run-party-tests.sh` | Modify | Extend for `spawn-budget`, and the forced-confirm-even-under-`party.default:true` path |

## Data Model Changes

**`changes/<change>/.lock/meta.json`** (new, per-change, git-ignored — matches
`.specclaw/worktrees/` and `.specclaw/.locks/` in never being committed):

```json
{ "pid": 12345, "phase": "build", "started_at": "2026-09-20T14:03:11Z", "host": "operator-mac" }
```

`pid`/`host` are diagnostic only (surfaced in the refusal message and `status` output); staleness is
computed from `started_at` alone, never from `pid` (see Key Decisions).

**`tasks.md` task line**, new optional detail fields (only meaningful on a `[>]` line):

```
- [>] `T7` — <title>
  - Deferred-Reason: waiting on 041-shared-auth-module to land
  - Deferred-Blocked-On: 041-shared-auth-module
```

**`.specclaw/party/session-spawns.jsonl`** (new, top-level, append-only — one line per completed
panel run, across all changes):

```json
{"date":"2026-09-20","change":"038-change-concurrency-lock-and-review-budget","spawns":10,"at":"2026-09-20T14:10:02Z"}
```

`spawn-budget check` sums `spawns` for lines where `date` equals today's UTC date; no other
aggregation, no rewrite, no compaction — the same append-only, sum-on-read shape as
`specclaw-timer`'s ledger, for the same reason (concurrent writers cannot lose each other's lines).

## API Changes

New CLI surfaces (all bash scripts under `bin/`, invoked from `SKILL.md` files exactly like every
existing `specclaw-*` helper):

```
specclaw-change-lock acquire <specclaw_dir> <change> --phase <phase> [--force]
specclaw-change-lock release <specclaw_dir> <change>
specclaw-change-lock status  <specclaw_dir> <change>

specclaw-party spawn-budget record <specclaw_dir> <change> <spawns>
specclaw-party spawn-budget check  <specclaw_dir>
```

Changed CLI surface:

```
specclaw-parse-tasks --count <tasks.md>   # now prints "<done> <total> <failed> <deferred>"
specclaw-parse-tasks --status deferred <tasks.md>   # deferred added to the valid --status set
```

## Key Decisions

1. **Staleness by wall-clock only, never by PID liveness.** `specclaw-browser-lock`'s slot semaphore
   checks `kill -0 $pid` because a slot's holder is one continuously-running process. A change-dispatch
   lock's "holder" is a whole skill invocation spanning multiple, independently-invoked `bin/`
   processes (e.g. `specclaw-build setup` now, `specclaw-build finalize` an hour later) — there is no
   single PID alive for the interval a liveness check would need to cover. The proposal's own FR
   language ("configurable staleness window... may be force-cleared") already assumes this; this
   design makes explicit why PID-liveness, which the codebase's other lock (`browser-lock`) does use,
   is the wrong tool here rather than an oversight.
2. **`--force` clears stale locks only, never live ones.** A flag that could always override the lock
   defeats the entire feature — the two collisions in the proposal's Problem section happened because
   operators (or forks acting on their behalf) believed they had exclusive access; an always-honored
   `--force` would just move that same false belief one step later. `--force` is therefore scoped
   strictly to "I've confirmed the old dispatch is actually gone, past the staleness window."
3. **Lock hooks live inside `bin/` scripts wherever the anchor point is a genuine dispatch boundary
   with no other legitimate caller, and directly in `SKILL.md` otherwise.** `build` (`cmd_setup`),
   `pr`, and `azdo-pr` qualify: nothing calls them read-only, since each one always mutates (branch/
   worktree creation, or the PR itself). `plan` has no dedicated binary at all, so its `SKILL.md`
   carries the acquire/release directly, the same way it already carries `specclaw-validate-change`.
   **`verify` was corrected during build (change 038's own build):** the acquire was originally placed
   inside `specclaw-verify collect`, following this same "put it in the script" instinct — but
   `collect` is also invoked as a standalone, read-only evidence dump (`run-parser-tests.sh` Case 5
   runs it directly against this repo's own real changes to prove no regression), and turning it into
   a lock-acquiring call made a read-only inspection claim exclusive access, leaving an orphaned lock
   in a real change directory the first time that existing test ran. The fix: acquire lives in
   `skills/verify/SKILL.md` Step 0 instead (mirroring `plan`), and only `release` (which is a safe
   no-op when nothing was ever acquired) stays inside `cmd_update_status`. The general rule this
   sharpens: the anchor for an acquire must be a point with **no other legitimate read-only caller** —
   a script having "a natural place to put it" is not sufficient on its own.
4. **`specclaw-pr`/`specclaw-azdo-pr` release via `trap ... EXIT`; `specclaw-build`/`specclaw-verify`
   release via a best-effort final step.** The PR scripts are single monolithic invocations that can
   `die` at many points, so only a trap guarantees release on every exit path. Build and verify are
   already split into separately-invoked subcommands (`setup`/`finalize`, `collect`/`update-status`);
   a trap inside one subcommand's process cannot help a different subcommand's process anyway, so the
   existing "release as the documented last step" pattern is what's available, and it matches how
   `specclaw-set-phase`'s own writes are already treated as best-effort (`\|\| true` throughout the
   timing ledger, for the identical reason: a bookkeeping failure must never mask or block the real
   result).
5. **`--count`'s new 4th field is a breaking change to a shared interface, absorbed everywhere at
   once.** `read -r a b c <<< "1 2 3 4"` silently stuffs `"3 4"` into `c` — every one of the five
   existing callers must add a fourth variable and fix their `'0 0 0'` fallback in the same change, or
   the field addition corrupts `t_failed` checks that currently gate build-phase failure recording.
   This was verified by reading every call site (`bootstrap-snapshot`, `reconcile`, `update-status`,
   `build`, `validate-change`) before committing to the format change, rather than assuming `read`'s
   overflow behavior would be harmless.
6. **A `[>]` task missing `Deferred-Reason:` is still counted `deferred`, with a warning — never
   silently downgraded to `pending`.** Matches `--count`'s existing precedent for a checkbox with no
   backtick id (counted as skipped, warned about, never silently folded into another bucket). Refusing
   to count it as anything would make the task invisible to `--count`'s total, which is worse than an
   incompletely-annotated deferred task.
7. **`.specclaw/party/session-spawns.jsonl` is top-level, not per-change.** It answers "how much has
   this repo spent on panels today," which is a session/day-scoped question that no single change's
   directory, `state.json`, or `STATUS.md` can answer without reading every change — the same reasoning
   `specclaw-timer`'s per-change ledger does *not* apply here, because that ledger's question ("how
   long did *this* change's phases take") is inherently per-change. This resolves the proposal's open
   question in favor of the new top-level path.
8. **The spawn cap is enforced only at the "confirm before spending" checkpoint, never mid-panel.**
   Once round 1 is already spawning, stopping mid-panel would produce a half-run panel with no tally
   and no report — worse than either finishing it or never starting it. The budget's entire mechanism
   is *making the pre-spend ask unavoidable*, not interrupting work in flight.

## Grounding sources

- `plugins/specclaw/CLAUDE.md`: *"`specclaw-set-phase` is the only writer of `changes/<change>/state.json`"* and *"Never write `state.json` directly"* — confirms the new lock file must be a separate document from `state.json`, never routed through `specclaw-set-phase`.
- `plugins/specclaw/CLAUDE.md`: *"`party_val` ... seek to the column-0 `party:` line, read only until the next column-0 key ... No party config value may be read any other way"* — governs FR21/NFR3: `session_spawn_cap` must be read via `specclaw-party get`, never `yaml_val` or a raw grep.
- `plugins/specclaw/CLAUDE.md`, task counting section: *"`specclaw-parse-tasks --count` is the only counter... Nothing may count tasks with `grep`"* — governs FR15/FR16: the deferred count is added to the one shared counter, not reimplemented per caller.
- `plugins/specclaw/CLAUDE.md`, phase time accounting: *"two events per span, never a rewrite"* / *"Nothing needs locking, so a timer call is one `date` and one `>>`"* — the append-only, sum-on-read shape adopted for `session-spawns.jsonl`.
- `bin/specclaw-browser-lock` (read in full): the atomic-`mkdir` claim pattern reused by `specclaw-change-lock`, and the specific reason its PID-liveness check does *not* transfer (see Key Decision 1).
- `bin/specclaw-set-phase` header comment: *"Not locked, by design"* re: `state.json` concurrent writes — confirms this proposal's own "Out of Scope" line that the dispatch lock is orthogonal to, not a replacement for, that design.

## Risks & Mitigations

- **Risk:** A stale-but-not-yet-expired lock (e.g. from a crashed build) blocks a legitimate retry for up to `git.lock_stale_minutes`.
  **Mitigation:** `specclaw-change-lock release <specclaw_dir> <change>` is a documented manual escape hatch; `status` lets an operator see exactly what's held before deciding to force-clear or wait.
- **Risk:** Missing a call site when threading the `--count` format change breaks a script silently (a corrupted `t_failed` that happens to still pass `-gt 0` checks by luck).
  **Mitigation:** every existing `--count` caller was enumerated by `grep -rl -- "--count"` before writing tasks, and each gets an explicit task; `run-parser-tests.sh` gains a case asserting the exact 4-field format.
- **Risk:** `Deferred-Reason:`/`Deferred-Blocked-On:` becoming a second free-text field nobody enforces consistently.
  **Mitigation:** explicitly scoped as free text in both the proposal and this spec (no structured cross-repo link) — the warning-on-missing-reason (FR17) is the only enforcement, matching this repo's existing "visible, never silent" standard rather than inventing a new blocking gate.
- **Risk:** The spawn-budget check reads `.specclaw/party/session-spawns.jsonl` growing unboundedly over a long project lifetime.
  **Mitigation:** out of scope for this change — the file is one JSON line per panel run (not per spawn), so growth is bounded by the number of proposals reviewed, several orders of magnitude smaller than `timeline.jsonl`'s per-span growth, which already ships uncompacted.
