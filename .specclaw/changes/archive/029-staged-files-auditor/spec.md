# Spec: Staged-files auditor

**Change:** 029-staged-files-auditor
**Created:** 2026-08-01
**Status:** 🟢 Approved

## Overview

PRs ship the wrong file set in both directions, and both are silent. **Planning artifacts go
missing** — reported three separate times on one PR in the keyflow channel. **Unrelated junk gets
swept in** — `specclaw-loop`'s escalation runs `git add -A`, and this repo's own working tree has
carried `.session-id.rotated-*` files, `watchdog-kills.jsonl` and an untracked `GOALS.md`, none of
which belong to any change and none of which are gitignored.

Root cause, stated once: **nothing verifies the branch's file list against the change's declared
scope.** `specclaw-validate-change` checks that artifacts exist *on disk*; it never asks whether they
are *committed to the branch*, and nothing at all asks whether extra files came along.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Should `undeclared` ever block on its own? | **No — WARN only.** Legitimate ripples (a barrel export, a lockfile beside a real dep change) are common, and a gate that blocks a correct PR is worse than the silent failure it replaces. |
| 2 | Is the auditor worth its token cost? | **Spawn it conditionally**: only when `required-missing` or `suspicious` is non-empty, or `undeclared` exceeds `pr.audit_undeclared_threshold` (default 3). Layer 1 already catches every failure actually reported. |
| 3 | Are `tasks.md` file lists reliable? | **Not entirely** — which is exactly why `undeclared` is WARN and never BLOCK. The lists are a *scope signal*, not a contract. |
| 4 | Does any automation depend on build opening the PR? | **No.** `specclaw-build` contains no `gh pr create` and its finalize summary names no PR; `/specclaw:auto` and `/specclaw:loop` both route through `/specclaw:pr`. The fix is therefore a documented prohibition, not a code removal — and the suite pins that no `pr create` reappears in build. |
| 5 | Should the loop's fallback still `git add -A` when `tasks.md` is unparseable? | **No.** It falls back to the change dir plus `git add -u` — tracked modifications only — and **names every uncommitted path in the escalation note**. Work in progress on tracked files is preserved; the filesystem is not. |
| 6 | Config `junk_patterns` or `.gitignore`? | **Both.** specclaw ships defaults for the classes seen in the wild, and the report tells the operator which paths belong in `.gitignore`, because that is the real fix. |

## Requirements

### Functional Requirements

- **FR1** — `specclaw-check-staged <dir> <change> [--base B] [--json] [--strict]` classifies every
  path in `origin/<base>...HEAD` plus `git status --porcelain` into four buckets:
  | Bucket | Rule | Verdict |
  |---|---|---|
  | `required-missing` | a mandatory artifact absent from the branch diff | **BLOCK** |
  | `declared` | the path appears in some task's `Files:` list, or is inside the change dir | OK |
  | `undeclared` | changed on the branch, declared by no task | WARN |
  | `suspicious` | matches a junk pattern | **BLOCK** unless allowlisted |
- **FR2** — The mandatory artifact set is size-aware where 036 applies and otherwise
  `proposal.md`, `spec.md`, `tasks.md`, `status.md`, `verify-report.md`. `design.md` is required only
  for an architectural change. **The set itself is not changed by this change.**
- **FR3** — Exit 0 when no bucket yields BLOCK, 1 when any does, 2 on a usage error.
- **FR4** — `--json` emits the four buckets; `--strict` additionally treats `undeclared` as BLOCK,
  for a CI-side check that wants no judgement calls.
- **FR5** — Default junk patterns cover the classes seen in the wild: `.session-id*`,
  `*-kills.jsonl`, `*.log`, `.env*`, `*.swp`, `.DS_Store`, `node_modules/`.
- **FR6** — `pr.allowed_extra_paths` (globs always fine undeclared) and `pr.junk_patterns`
  (project additions) extend the defaults; `workflow.staged_files_audit` and
  `workflow.staged_files_block` gate the agent and the hard stop respectively.
- **FR7** — `workflow.staged_files_block` ships **`false`**, the same one-release rollout
  `workflow.code_review_block` took. `required-missing` and `suspicious` still exit non-zero so a
  caller can choose; `specclaw-pr` honours the flag.
- **FR8** — `agents/staged-files-auditor.md` defines the judgement seat: given the classified list,
  `spec.md` scope, task file lists and `git diff --stat`, it writes `staged-files-report.md` with one
  line per flagged path and a verdict from
  `APPROVED | APPROVED_WITH_NOTES | CHANGES_REQUESTED`. Tools: Read, Grep, Bash (read-only git).
- **FR9** — `specclaw-pr` and `specclaw-azdo-pr` run the check **before staging** and die on BLOCK
  when `staged_files_block` is true; they re-run it **after committing** and abort if `suspicious` is
  non-empty; they link the report in the PR body when one exists.
- **FR10** — `specclaw-loop escalate` replaces `git add -A` with a scoped add: the change dir, the
  paths declared in `tasks.md`, and `git add -u` for tracked modifications. Everything else is
  **named in the escalation note as left in the working tree, not committed**.
- **FR11** — `skills/loop/SKILL.md`'s documented fix-commit step drops `git add -A` for the same
  scoped form.
- **FR12** — `skills/build/SKILL.md` states that build never creates or announces a PR; it ends at
  *"branch pushed — run `/specclaw:verify`, then `/specclaw:pr`"*.
- **FR13** — `skills/pr/SKILL.md` documents the gate and the escape hatches.

### Non-Functional Requirements

- **NFR1** — The check is deterministic, needs no model and makes no network call.
- **NFR2** — Path normalisation must survive the worktree strategy, which changes `cwd`.
- **NFR3** — Shellcheck-clean; bash + coreutils.

## Acceptance Criteria

- **AC-1** — A branch missing `spec.md` from its diff reports `required-missing` and exits 1.
- **AC-2** — A branch whose files are all declared reports no WARN and exits 0.
- **AC-3** — A file changed but declared by no task lands in `undeclared` and does **not** exit 1.
- **AC-4** — `--strict` makes that same case exit 1.
- **AC-5** — `.session-id.rotated-3` lands in `suspicious` and exits 1.
- **AC-6** — A `suspicious` path listed in `pr.allowed_extra_paths` is reclassified as declared.
- **AC-7** — A project junk pattern from `pr.junk_patterns` is honoured alongside the defaults.
- **AC-8** — Everything inside `.specclaw/changes/<change>/` counts as declared.
- **AC-9** — `--json` output parses and carries all four buckets.
- **AC-10** — A usage error exits 2, distinct from a BLOCK's 1.
- **AC-11** — `design.md` is required for an architectural change and not for a bounded one.
- **AC-12** — The loop's escalation commits the change dir and tracked modifications, and **does not**
  commit an untracked junk file.
- **AC-13** — The escalation note names each uncommitted path.
- **AC-14** — Neither `specclaw-build` nor `skills/build/SKILL.md` contains a PR-creation command.
- **AC-15** — `workflow.staged_files_block` ships `false`.
