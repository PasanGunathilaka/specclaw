# Design: Per-task review gate and evidence-before-done

**Change:** 035-task-review-gate
**Created:** 2026-09-19

## Two halves at two prices, and they ship differently on purpose

| Half | Cost | Ships |
|---|---|---|
| verification footer | one line of bash per task | **on**, unconditionally |
| per-task review gate | one extra agent spawn per task | **off** (`build.task_review: off`) |

The footer is not a feature with a trade-off. A task that cannot show it ran anything should not be
`done`, and the check that establishes that is a `grep`. Making it configurable would be offering to
switch off honesty.

The gate is the opposite: it doubles spawns per task in `full` mode, and its value — how many wave-1
defects it actually catches before wave 2 builds on them — is precisely what has not been measured.
So it ships inert, exactly as `workflow.code_review_block` and `party.default` did, and the default
moves after one build with each setting.

## `check-report`: a script decides, the model only supplies evidence

```
specclaw-build check-report <report-file> [--task T5]
  exit 0  footer present, Command: non-empty, Exit: 0
  exit 1  no-verification-evidence: <which of the three>
```

The three failures are distinguished in the detail text, because "your report is wrong" is not
actionable and the retry payload quotes this line back to the agent.

**The footer is read from the END of the file.** A report often quotes its own earlier attempts, and
an `Exit: 0` in narrative prose or in a quoted command block is not evidence of anything. The parser
takes the **last** `## Verification` heading and reads only the lines after it — so a retry that
appends a second footer is judged on the retry, which is the correct reading.

This script reads one file. No config, no repo, no network — so a footer check can never fail for a
reason that has nothing to do with the report.

## `review-package`: prepare the diff, do not touch the tree

```
changes/<change>/reviews/<task>.diff
  Base:  <sha>          the commit before this task's first commit
  Head:  <sha>
  ## Task brief        title, Files:, Notes: — lifted from tasks.md
  ## Stat              git diff --stat
  ## Diff              full diff, capped at 4000 lines
```

Two properties matter more than the content:

- **It is read-only with respect to git.** No checkout, no stash, no add. A review step that can
  disturb the working tree is a review step that can lose an in-flight task in a parallel wave.
- **The cap is visible.** A diff truncated at 4000 lines carries an explicit marker. A reviewer handed
  a silently-shortened diff will approve the half it was shown.

The base SHA is resolved from the task's own commits (`specclaw(<change>): <task> —` in the subject);
with none, the package says *"no commits for this task"* rather than failing, because a review of
nothing is a legitimate — and informative — outcome.

## The reviewer is the seat that already exists

No new agent file. `agents/code-reviewer.md` gains a **task-scoped mode**: read the prepared diff file
once, judge spec compliance first and quality second, do not crawl the repo, and raise at most one
named risk per out-of-diff concern. That last clause is what keeps a per-task review cheap; without
it the reviewer re-reads the codebase twelve times per build.

And the whole-change pass gains one sentence — *per-task reviews live at `changes/<change>/reviews/`;
do not repeat findings already recorded there* — so the two seats do not bill twice for the same
finding.

## Retry accounting is shared, deliberately

A `BLOCK` marks the task `failed` and re-enters the **existing** retry path. It does not get a counter
of its own. Two counters would let a task alternate — fail tests, retry, fail review, retry, fail
tests — and exhaust neither, which is a loop with no bound. One notion of "this task is not done", one
budget.

## Test plan

`tests/run-task-review-tests.sh`, bash + coreutils, CI-registered: every `check-report` verdict
including the fenced-`Exit: 0` decoy, the config default, `review-package`'s contents and its
no-commits case, the git-cleanliness assertion either side of a run, and the prompt/template/agent
wiring.
