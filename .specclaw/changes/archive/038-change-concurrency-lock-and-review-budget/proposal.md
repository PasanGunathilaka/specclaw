# Proposal: Per-change concurrency lock, deferred-task state, and a party-review spawn budget

**Created:** 2026-09-20
**Status:** 🟡 Draft
**Source of the idea:** a 14.5h `mi-auto-mode` session in a consumer repo (`audit-assure`),
retrospectively mined and recorded at that repo's `.specclaw/LEARNINGS.md`. Cross-checked against
this repo's own history before drafting — see "What this proposal deliberately does not
re-propose" below.

## Problem

Three concrete failures recurred during that session that nothing currently in specclaw prevents:

**1. No per-change concurrency guard.** Two different collisions happened because two live
forks/agents were dispatched against the *same change* at the same time: a `plan`-only fork for
one change built tasks it wasn't authorized to while a separate `build` dispatch also ran, and a
`verify`-only fork opened a PR itself while a separately-dispatched `pr` fork raced it, corrupting
shared `state.json` fields. `specclaw-set-phase`'s design comment states plainly that concurrent
writes are "not locked, by design — the loser's write is lost, never a corrupt file." That
tolerates a *lost update*; it does not prevent *two agents legitimately believing they each own
the only active dispatch for a change*. `git.strategy: worktree-per-change` does not close this
either — a second dispatch against a change with an existing worktree just resumes the same
worktree directory (`specclaw-build`'s `-d "$worktree_path"` branch), so both agents still write
into the same files concurrently.

**2. No task state for "correctly deferred, not failed."** A change with later tasks depending on
a not-yet-built sibling change had to be manually descoped across `proposal.md`, `spec.md`,
`tasks.md`, and `design.md` for lack of a formal status value distinct from `done`/`failed`/
`blocked`. In a dependency-heavy backlog (as `audit-assure`'s own numbered-change graph is), this
recurs every time a change's scope brushes against a sibling that hasn't landed yet.

**3. No cap on party-review spawn volume per session.** In one session, 20 of 25 party-panel
spawns concentrated on 2 of ~24 proposals, each getting extra ad hoc rounds beyond
`config.yaml`'s `rounds` setting — because nothing in `specclaw-party` enforces that setting as a
ceiling; an operator asking "should we do a 3rd round?" outside the tool's own round mechanism is
indistinguishable, cost-wise, from the tool doing it. That specific ad hoc behavior is really a
consumer-repo instruction-following gap (addressed there, in that repo's own CLAUDE.md), but
specclaw currently has no visibility or cap on *aggregate* spawn volume across a session's worth
of proposals either way, so a repo with many pending proposals (this repo currently has seven —
028, 029, 033, 034, 035, 036, 037) has no signal for "review depth is being spent unevenly."

## What this proposal deliberately does not re-propose

Checked against this repo's own changes before drafting, to avoid duplicating work already done
or already queued:

- **Fork self-report trust** — already fully specified by pending proposal
  `035-task-review-gate` ("a task is not done because its agent said so": verification-footer +
  optional per-task review gate). That proposal should simply be prioritized for planning; nothing
  new is needed here.
- **Branch-per-change vs. worktree-per-change** — `git.strategy: worktree-per-change` already
  exists in `specclaw-build`/config.yaml. The `audit-assure` repo simply isn't using it; that's a
  config recommendation for that repo, not a gap here. (It also wouldn't have prevented failure #1
  above on its own — see Problem section.)
- **Change sizing / ceremony scaling (spike/bounded/architectural)** — already substantially
  implemented (the current `propose/SKILL.md` step 4b matches pending proposal
  `036-right-sized-change-paths` closely); if `036`'s `status.md` still reads "awaiting planning"
  despite matching shipped behavior, that is itself a `STATUS.md` desync worth checking separately,
  not something this proposal should re-touch.
- **Party round count as a fixed config ceiling** — `config.yaml`'s `party.rounds` already exists
  and is read as the round count; there is no code path that does a 3rd round on its own. The
  problem observed was an operator inventing an out-of-band round, which is a consumer-side
  instruction-following fix, not a code gap — except for the aggregate-spawn-visibility gap
  (item 3 above), which this proposal does address.

## Proposed Solution

**1. Per-change concurrency lock.** `specclaw-set-phase` (or a new small `specclaw-change-lock`
helper it and `specclaw-build`/`specclaw-plan`/`specclaw-verify`/`specclaw-pr` all call) writes a
`changes/<change>/.lock` file on dispatch start (`{pid, phase, started_at, host}`) and removes it
on normal completion. A second dispatch against a change with a live, unstale lock (same phase or
any phase) fails fast with a clear message naming the existing lock's phase and start time, instead
of silently racing. A lock older than a configurable staleness window (e.g. `git.lock_stale_minutes`,
default 120) is reported as stale and may be force-cleared with an explicit flag — never silently
ignored. This is orthogonal to `git.strategy`; it applies whether branch-per-change or
worktree-per-change is configured, because the race is about concurrent *dispatch*, not about
which git mechanism the dispatch uses.

**2. Formal `deferred` task state.** Add `deferred` alongside `pending`/`in_progress`/`done`/
`failed`/`blocked` in the `tasks.md` template and in `specclaw-build`'s task-state vocabulary.
A `deferred` task carries a required one-line reason and, when known, the sibling change it's
blocked on (free text, not a hard cross-repo reference — this repo doesn't assume the blocking
change lives in the same `.specclaw/changes/`). `specclaw-validate-change`'s incomplete-task count
excludes `deferred` tasks from "must finish before verify" the same way it already excludes tasks
outside the current wave, but `status.md`'s task table renders them distinctly (e.g. `⏸ deferred`)
so they're never confused with `done`.

**3. Party-review spawn budget.** New `config.yaml` key `party.session_spawn_cap` (default: unset
= no cap). When set, `specclaw-party panel` tracks cumulative spawns-would-cost for the current
day/session (a simple counter file under `.specclaw/party/`) and, once a panel run would exceed the
cap, refuses to auto-proceed even if `party.default: true` — it forces the "confirm before
spending" ask (step 4b in `propose/SKILL.md`) regardless of that setting, so an operator burning
through many proposals in one sitting gets an explicit checkpoint rather than the budget draining
silently across proposals nobody chose to prioritize for deep review.

## Scope

### In Scope
- `changes/<change>/.lock` write/check/stale-detection/force-clear, wired into
  `specclaw-build`, `specclaw-plan` (if it exists as a separate binary), `specclaw-verify`,
  `specclaw-pr`/`specclaw-azdo-pr`.
- `deferred` task state: `templates/tasks.md`, `specclaw-build` task-state handling,
  `specclaw-validate-change` incomplete-count exclusion, `status.md` render glyph.
- `party.session_spawn_cap` config key, counter file under `.specclaw/party/`, and the
  forced-confirm behavior in `specclaw-party panel`/`skills/propose/SKILL.md` step 4b.
- bats coverage for: concurrent dispatch refusal, stale-lock force-clear, deferred-task exclusion
  from incomplete count, spawn-cap forcing the confirm ask even under `party.default: true`.

### Out of Scope
- Rewriting `specclaw-set-phase`'s existing "not locked, by design" state.json write model —
  this proposal adds a *dispatch* lock, not a state.json write lock; the two are independent and
  the existing design comment's reasoning (lost update over corruption) still stands for the
  state.json file itself.
- Any change to `035-task-review-gate` or `036-right-sized-change-paths` — those proposals stand
  as already written; this proposal neither duplicates nor modifies them.
- Cross-repo dependency tracking for the `deferred` task state's "blocked on" field — it stays
  free text, not a structured link.

## Impact

- **Size:** bounded (spike / bounded / architectural)
- **Files affected:** ~8 (estimated) — `specclaw-set-phase` or new `specclaw-change-lock`,
  `specclaw-build`, `specclaw-verify`, `specclaw-pr`, `specclaw-azdo-pr`, `templates/tasks.md`,
  `specclaw-validate-change`, `specclaw-party`, `templates/config.yaml`, `skills/propose/SKILL.md`
- **Complexity:** medium (small / medium / large)
- **Risk:** low (low / medium / high) — additive; every new behavior is off by default
  (`session_spawn_cap` unset, lock check only fires on genuine concurrent dispatch) or fails safe
  (stale-lock requires an explicit force flag, never auto-clears)

## Open Questions

- Should the concurrency lock also refuse a *different phase* against a change with a live lock
  (e.g. `verify` dispatched while `build` is still running), or only refuse the *same* phase?
  The `mi-auto-mode` collisions were both same-or-adjacent-phase (plan-vs-build, verify-vs-pr), so
  either answer would have caught them — proposing "any phase" as the simpler, stricter default,
  open to narrowing at spec time.
- Is `.specclaw/party/` an acceptable new directory, or should the spawn counter live inside
  `state.json`/`STATUS.md` instead to avoid one more top-level path?

---

**To proceed:** Review this proposal and approve to begin planning.
