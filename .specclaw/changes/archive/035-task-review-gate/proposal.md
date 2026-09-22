# Proposal: Per-task review gate and evidence-before-done in `/specclaw:build`

**Created:** 2026-09-19
**Status:** 🟡 Draft
**Source of the idea:** `obra/superpowers` `skills/subagent-driven-development` (task-scoped reviewer reading a diff package) and `skills/verification-before-completion` (no success claim without the command and its output). Adapted, not copied — no implementer/reviewer prompt bundle, no `sdd-workspace` scripts.

## Problem

specclaw reviews a change **once**, at `/specclaw:verify` Step 3.5, over the whole diff. Between
`build` start and that review, every coding agent marks its own homework:

- A task is `done` when the coding agent returns. `specclaw-build` has no check that the agent ran
  anything. Agents routinely report "implemented and tested" having run nothing — superpowers' entire
  `verification-before-completion` skill exists because of this pattern (*"evidence before assertions
  always"*).
- A defect in wave 1 is built on by waves 2–4 before anyone looks. By the time the code-reviewer flags it
  in `review-report.md`, three later tasks depend on it and the loop's fix agent is repairing a pile.
- The whole-change review is *also* the wrong altitude for spec compliance. The reviewer sees 12 tasks
  of diff and asks "is this good code?"; nobody asks per task "did T5 build what T5 said, nothing more,
  nothing less?" — which is how scope creep and `design_gap` learnings arrive at verify time.

superpowers' answer: a fresh reviewer after **each** task, reading a prepared diff package
(base SHA, head SHA, stat, full diff) plus the task brief, returning two verdicts — spec compliance
first, then quality — and a broad whole-branch review only at the end. And the rule that a task's
report must carry the verification command and its output, or it is not a report.

## Proposed Solution

**1. Evidence before `done` — unconditional, cheap, bash-enforced.**

Every coding-agent prompt (`references/agent-prompts.md`, via `specclaw-build-context`) ends with a
required report footer:

```
## Verification
Command: <exactly what was run>
Exit: <code>
Output (tail): <last ≤ 20 lines>
```

`specclaw-build` gains `check-report <report-file>`: a task may only move to `done` when the footer
exists, `Exit:` is `0`, and `Command:` is non-empty. Missing/failing footer → task stays `failed` with
reason `no-verification-evidence`, and the standard retry path re-dispatches with the footer requirement
restated. A script decides; the model only supplies the evidence. This half ships **on by default** — it
costs nothing but honesty.

**2. Optional per-task review gate.** New config `build.task_review: off | spec | full`
(default `off` — build behaves exactly as today).

- After a task's commit, `specclaw-build review-package .specclaw <change> <task>` writes
  `changes/<change>/reviews/<task>.diff` containing base/head SHAs, `git diff --stat`, and the full diff
  with context, plus the task's brief (title, `files:`, acceptance criteria lines it cites).
- The build skill spawns the **existing** `code-reviewer` agent with `models.review`, prompt =
  task-scoped variant: *spec compliance first (built what was asked, nothing more), then quality*;
  read the diff file once, do not crawl the repo, one named risk per out-of-diff check. That last
  clause is lifted from superpowers' reviewer prompt because it is what keeps a per-task review cheap.
- Verdict handling by bash: `BLOCK` → task marked `failed` with the findings written to the task's
  section in `errors.md` and fed into the normal retry; `WARN`/`NOTE` → recorded in
  `reviews/<task>.md`, task proceeds. `spec` mode reviews compliance only; `full` adds quality.
- The whole-change review at verify stays. Its prompt gains "per-task reviews at
  `changes/<change>/reviews/` — do not repeat findings already recorded there", so the two seats do
  not duplicate work.

**3. Report where people look.** `status.md`'s `Agent Runs` table gets a `Review` column
(`—`, `PASS`, `WARN(2)`, `BLOCK→retry`). `verify-report.md` lists per-task verdicts in one line each.

## Scope

### In Scope
- Verification footer in agent prompts; `specclaw-build check-report`; `done` gated on it.
- `build.task_review` config key (template + `specclaw-init` seed); `specclaw-build review-package`;
  task-scoped reviewer prompt for the existing `code-reviewer` agent; verdict → status wiring.
- `reviews/` directory in the change dir; `status.md` Review column; verify-report summary line;
  whole-change reviewer told about per-task findings.
- bats: footer parsing (present/absent/non-zero exit), review-package contents, verdict routing.
  Shellcheck-clean, CI-registered.

### Out of Scope
- A separate implementer-prompt / reviewer-prompt / re-review-prompt file set. One agent, one prompt
  variant.
- Fresh-subagent-per-task as a *new* execution model — build already spawns per task.
- superpowers' "rulings, not stalls" ledger for autonomous runs. Worth its own proposal; unrelated to
  review.
- Reviewing `propose`/`plan` artifacts. Party mode already covers proposals.

## Impact

- **Files affected:** ~9 (estimated) — `specclaw-build`, `specclaw-build-context`,
  `references/agent-prompts.md`, `agents/code-reviewer.md`, `templates/config.yaml`, `bin/specclaw-init`,
  `templates/status.md`, `specclaw-update-status`, `skills/build/SKILL.md`, 1–2 bats suites.
- **Complexity:** medium-large — the wiring touches the longest script in the plugin.
- **Risk:** medium for the gate (doubles spawns per task when `full`; mitigated by default `off`, a
  cheap `models.review`, and the read-the-diff-once prompt), **low** for the footer (a task that cannot
  show it ran anything should not be `done`).

## Open Questions

1. **Should the footer requirement be relaxable** for tasks whose `files:` are docs-only? Lean: no —
   `Command: ls docs/…; Exit: 0` is a legitimate footer and costs nothing.
2. **Default `spec` instead of `off`?** Compliance review on a cheap model is fast and catches exactly the
   scope drift that the Karpathy guardrails (change 012) were meant to prevent. Decide after measuring
   one build with each setting.
3. **Is a `BLOCK` retry bounded separately** from the normal task retry count, or shared?
4. **Where does the reviewer's model come from when `dynamic_agents.enabled`** — the ladder or
   `models.review`? Lean: `models.review`, always; review should not get the expensive tier by default.

---

**To proceed:** Review this proposal and approve to begin planning.
