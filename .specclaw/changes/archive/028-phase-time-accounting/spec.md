# Spec: Phase time accounting

**Change:** 028-phase-time-accounting
**Created:** 2026-08-01
**Status:** 🟢 Approved

## Overview

Long specclaw phases are *acceptably* slow — the work is genuinely large — but **unaccountably** so.
Nothing records where the wall-clock went, so nobody can tell a legitimate 40-minute build from a
stalled one. Supervisors kill healthy runs; the same slow step gets paid for on every change; "the
build takes long" is unfalsifiable and therefore never gets fixed.

The measurements already exist in pieces — `run-long`'s heartbeat, its `duration_s` sidecar, the
`Duration` column in `templates/status.md` that no script has ever written. This change captures,
attributes and reports them.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Heartbeat interval | **60s**, `run-long`'s existing default, everywhere. One number, one place: `verify.heartbeat_seconds`. |
| 2 | Commit the JSONL? | **No.** `timeline.md` is committed; `timeline.jsonl` is gitignored. Raw span records churn every PR and the rendered view is what a reviewer reads. |
| 3 | Baseline scope | **This project's own archived changes only.** A default table shipped with the plugin would be a median of somebody else's hardware, test suite and network — unfalsifiable and wrong for every project. A project with no history prints no baseline, and says so. |
| 4 | Model attribution on propose/plan spans | Recorded **when the caller supplies it**, never inferred. A span that guesses its model is worse than one that admits it does not know. |
| 5 | Warn above a multiple of the median? | **Yes**, `⚠ N.N× median` on the span's line in the report. Descriptive only — it changes no exit code, because a slow run is not a failed one. Factor: `timing.anomaly_factor`, default 3. |
| 6 | Where the progress line goes under the loop | **stdout and `loop-log.md`.** stdout is what a watchdog sees; the log is what survives the session. |

## Requirements

### Functional Requirements

- **FR1** — `specclaw-timer start <dir> <change> <span-id> [--kind task|wave|phase|cmd] [--label S] [--parent P] [--model M] [--attempt N]` appends one JSON line to `changes/<change>/timeline.jsonl`.
- **FR2** — `specclaw-timer stop <dir> <change> <span-id> [--status ok|fail|retry]` appends a close record. **Append-only** — concurrent wave tasks cannot clobber each other, and a crashed run leaves an open span rather than losing the record.
- **FR3** — `specclaw-timer report <dir> <change> [--format md|json] [--baseline]` renders the ledger: total wall clock, a split by kind, the three slowest spans, the retry count, and one row per span. An unclosed span renders `⏱ still running`, never a zero.
- **FR4** — `--baseline` compares each span's duration against the median for spans with the same `kind` **and** `label` across that project's archived changes, and marks any at or above `timing.anomaly_factor` × median.
- **FR5** — `specclaw-timer report --format md` is the content of `timeline.md`; `--write` installs it.
- **FR6** — `specclaw-timer agent-runs <dir> <change>` prints the `Agent Runs` table body — task, agent, model, status, duration — so the column that has existed since the template was written is finally filled from a record rather than from prose.
- **FR7** — `specclaw-progress <dir> <change>` prints one line naming the **active step**, its elapsed time, and the current bottleneck. That is the whole point: it lets an operator or a watchdog judge liveness instead of guessing.
- **FR8** — Every timer call is **non-fatal**. A broken ledger must never fail a build; `specclaw-timer` exits 0 on every path except a usage error (exit 2).
- **FR9** — `specclaw-build` wraps each task and each wave in a span, recording `model` and `attempt`.
- **FR10** — `specclaw-run-long` folds its existing `duration_s` into the ledger as a `cmd` span when `--change` is given. Without it, behaviour is unchanged.
- **FR11** — `specclaw-verify` opens one `phase` span per run; `specclaw-loop log-turn` opens one per turn and timestamps the `## Turn N` heading it already writes.
- **FR12** — `specclaw-pr` and `specclaw-azdo-pr` share a **Time accounting** section in the PR body: total wall clock, the split by phase, the three slowest spans, the retry count.
- **FR13** — `specclaw-update-status` shows elapsed time per active change in the dashboard.
- **FR14** — Config `timing:` — `enabled` (true), `heartbeat_seconds` (60), `anomaly_factor` (3), `progress` (`normal` | `quiet` | `verbose`). `timing.enabled: false` makes every timer call a no-op.
- **FR15** — `specclaw-init` adds `changes/*/timeline.jsonl` to the project's `.gitignore`.

### Non-Functional Requirements

- **NFR1** — No new dependency. `jq` optional; the ledger is one flat JSON object per line, written and read by this script.
- **NFR2** — Timer calls add no measurable latency to a build: one `date` and one `>>` per span.
- **NFR3** — Shellcheck-clean.

## Acceptance Criteria

- **AC-1** — `start` then `stop` yields a closed span whose `duration_s` is the elapsed seconds.
- **AC-2** — Two spans started concurrently and closed in either order both survive intact.
- **AC-3** — A span started and never stopped renders `⏱ still running` and is excluded from totals.
- **AC-4** — `report --format md` names the total, the split by kind, the slowest three and the retry count.
- **AC-5** — `report --format json` is parseable.
- **AC-6** — `agent-runs` emits one pipe-delimited row per task span carrying its model and duration.
- **AC-7** — `--baseline` with no archived history prints the report **and** says there is no baseline — never a silently absent column.
- **AC-8** — With history, a span at ≥ `anomaly_factor` × median is marked; one below it is not.
- **AC-9** — `timing.enabled: false` makes `start`/`stop` write nothing and exit 0.
- **AC-10** — A corrupt `timeline.jsonl` line is skipped with a warning; the report still renders.
- **AC-11** — `specclaw-progress` names the active span, its elapsed time and the slowest span so far.
- **AC-12** — `specclaw-timer` exits 0 when the change dir does not exist.
- **AC-13** — `run-long` without `--change` writes no ledger entry and behaves exactly as before.
- **AC-14** — The PR body builder emits a Time accounting section when a ledger exists and omits it entirely when none does.
- **AC-15** — `templates/config.yaml` carries the `timing:` block, and `.gitignore` seeding covers `timeline.jsonl`.
