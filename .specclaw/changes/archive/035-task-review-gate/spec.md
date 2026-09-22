# Spec: Per-task review gate and evidence-before-done in `/specclaw:build`

**Change:** 035-task-review-gate
**Created:** 2026-09-19
**Status:** 🟢 Approved

## Overview

specclaw reviews a change **once**, at `/specclaw:verify`, over the whole diff. Between build start
and that review every coding agent marks its own homework: a task is `done` when the agent returns,
and nothing checks that it ran anything. A defect in wave 1 is built on by waves 2–4 before anybody
looks, and by the time the reviewer flags it three later tasks depend on it.

Two halves, deliberately priced differently:

- **The footer** — evidence before `done` — ships **on**, unconditionally. It costs nothing but
  honesty.
- **The per-task review gate** — a second reviewer seat per task — ships **off**, because it doubles
  spawns per task and its value has not been measured yet.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Relax the footer for docs-only tasks? | **No.** `Command: ls docs/x.md` · `Exit: 0` is a legitimate footer and costs nothing. An exemption is a hole shaped exactly like the failure. |
| 2 | Default `spec` instead of `off`? | **`off`.** The proposal asks to decide after measuring one build with each setting; shipping a default that doubles spawns before that measurement is the thing being avoided. Same one-release rollout `workflow.code_review_block` and `party.default` took. |
| 3 | Is a `BLOCK` retry bounded separately from the normal task retry count? | **Shared.** A task that fails review and a task that fails tests are both "this task is not done". Two counters would let a task alternate between the two and never exhaust either. |
| 4 | Reviewer model under `dynamic_agents.enabled`? | **`models.review`, always.** Review does not get the expensive tier by default, and the ladder is about implementation difficulty, not about reading a diff. |

## Requirements

### Functional Requirements

- **FR1** — Every coding-agent prompt ends with a required report footer:
  ```
  ## Verification
  Command: <exactly what was run>
  Exit: <code>
  Output (tail): <last ≤ 20 lines>
  ```
- **FR2** — `specclaw-build check-report <report-file> [--task <id>]` exits 0 only when the footer
  exists, `Command:` is non-empty, and `Exit:` is `0`.
- **FR3** — A failing check prints the reason on one line: `no-verification-evidence: <detail>`, and
  exits 1. **A script decides; the model only supplies the evidence.**
- **FR4** — `check-report` distinguishes its three failures by detail text: missing footer, empty
  command, non-zero exit.
- **FR5** — A task may only move to `complete` when `check-report` passes; otherwise it is `failed`
  and re-dispatched through the existing retry path with the footer requirement restated.
- **FR6** — New config `build.task_review: off | spec | full`, default **`off`**. With `off`, build
  behaves exactly as today.
- **FR7** — `specclaw-build review-package <specclaw_dir> <change> <task>` writes
  `changes/<change>/reviews/<task>.diff` containing the base SHA, the head SHA, `git diff --stat`,
  the full diff, and the task's brief (title, `Files:`, `Notes:`) read from `tasks.md`.
- **FR8** — `review-package` is read-only with respect to git: it runs no checkout, no stash, no add.
- **FR9** — The reviewer is the **existing** `code-reviewer` agent, given a task-scoped prompt:
  spec compliance first, then quality; read the diff file once; do not crawl the repo; one named risk
  per out-of-diff check. `spec` mode reviews compliance only, `full` adds quality.
- **FR10** — Verdict handling is bash's: `BLOCK` → the task is `failed`, the findings go to
  `errors.md`, and the normal retry runs. `WARN`/`NOTE` → recorded in `reviews/<task>.md`, the task
  proceeds.
- **FR11** — `templates/status.md`'s `Agent Runs` table gains a `Review` column
  (`—` · `PASS` · `WARN(2)` · `BLOCK→retry`).
- **FR12** — `verify-report.md` lists per-task verdicts, one line each.
- **FR13** — The whole-change reviewer is told that per-task reviews exist at
  `changes/<change>/reviews/` and must not repeat findings already recorded there.
- **FR14** — `specclaw-init` seeds `build.task_review` (it copies `templates/config.yaml`, so the
  template is the seed).

### Non-Functional Requirements

- **NFR1** — With `task_review: off` and a well-formed footer, build's behaviour is byte-identical to
  today apart from the footer check itself.
- **NFR2** — Bash + coreutils. Shellcheck-clean.
- **NFR3** — `check-report` never reads the repo, the network, or config. One file in, one verdict out.

## Acceptance Criteria

- **AC-1** — A report with a complete footer and `Exit: 0` → exit 0.
- **AC-2** — A report with no `## Verification` section → exit 1, detail names the missing footer.
- **AC-3** — `Command:` present but empty → exit 1, detail names the empty command.
- **AC-4** — `Exit: 1` → exit 1, detail names the non-zero exit.
- **AC-5** — A missing report file → exit 1, not a crash.
- **AC-6** — The footer is found when it is the last section, and when other sections follow it.
- **AC-7** — `Exit: 0` inside a fenced block that is **not** the footer does not satisfy the check.
- **AC-8** — `build.task_review` defaults to `off` when absent from config.
- **AC-9** — `review-package` writes `reviews/<task>.diff` carrying the base SHA, the head SHA, a
  `git diff --stat` section, and the full diff.
- **AC-10** — It carries the task's title, `Files:` and `Notes:` from `tasks.md`.
- **AC-11** — It leaves the git index and working tree untouched (`git status --porcelain` identical
  before and after).
- **AC-12** — On a task with no commits, it writes a package that says so rather than failing.
- **AC-13** — `templates/status.md` has a `Review` column in `Agent Runs`.
- **AC-14** — `agents/code-reviewer.md` documents the task-scoped mode and the "do not repeat per-task
  findings" rule for the whole-change pass.
- **AC-15** — The agent prompt reference and `specclaw-build-context` both carry the footer
  requirement.

## Edge Cases

- A report whose footer appears twice → the **last** one wins; a retry appends its own.
- `reviews/` absent → `review-package` creates it.
- `git diff` producing a very large diff → capped at 4000 lines with an explicit truncation marker, so
  a reviewer is never handed a silently-shortened diff.

## Dependencies

None. Independent of 033/034/036/037; branched on top of them only to avoid touching the same files
twice.
