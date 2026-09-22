# Proposal: Skill-trigger evals and a description lint — prove that utterances route to the right verb

**Created:** 2026-09-19
**Status:** 🟡 Draft
**Source of the idea:** `obra/superpowers` — the harness acceptance test in `CLAUDE.md` (*"Let's make a react todo list" must auto-trigger `brainstorming`, paste the transcript*), the headless `claude -p` suite in `tests/claude-code/`, and the description doctrine in `skills/writing-skills/SKILL.md:144-181` (*"Description = when to use, NOT what the skill does"*). Adapted: specclaw keeps a small fixture table and a bash lint; it does not adopt their eval harness or TDD-for-skills methodology wholesale.

## Problem

specclaw's conversational routing is asserted, never tested:

- The README promises *"i have a proposal" fires `/specclaw:propose`*. No test checks it. `tests/`
  has 20 bats suites for the bash layer and zero for whether any utterance reaches any skill.
- **Descriptions drift toward workflow summaries.** `skills/propose/SKILL.md`'s description is ~90 words
  and narrates party mode; `bf-*` descriptions run to full paragraphs. superpowers measured the failure
  this causes: an agent given a description that summarised the workflow *followed the description and
  skipped the skill body* (one review instead of the two the flowchart required). Every extra sentence
  in a description is a chance for the model to stop reading there.
- **Trigger regressions are invisible.** When 033 lands a router and 034 a debug skill, the routing
  table and the descriptions must agree, and both will be edited by people who cannot see the effect.
  Today the only feedback is an operator noticing weeks later that "the tests fail" no longer routes.
- **No baseline.** We cannot say whether 033's bootstrap improved anything because nobody measured
  routing before it.

superpowers turned this into a gate: a new harness integration is refused without a transcript showing
the acceptance utterance auto-triggered the right skill, and skill edits must show before/after eval
results.

## Proposed Solution

**1. A trigger fixture table.** `tests/fixtures/triggers.tsv`, one row per canonical utterance:

```
utterance	expect	note
i have a proposal	propose	README promise
we should add dark mode to the dashboard	propose	implicit new work
the build is broken since the last commit	debug	034; until then: loop|none
tests are failing on T5	debug	
proposal 028 is approved, plan it	plan	
go ahead and build 028	build	
are we done? does it pass?	verify	
open the PR	pr	
where do things stand	status	
what does specclaw-parse-tasks do	none	read-only question — must NOT route
set up azure devops auth	none	disable-model-invocation skill
```

Both positive and **negative** rows, because over-triggering is the failure mode superpowers' own
doctrine produces and the one a "more controlled" framework must guard against.

**2. The headless runner.** `tests/run-trigger-tests.sh`: for each row, create a temp project with a
seeded `.specclaw/` (and, for state-dependent rows, a `STATUS.md` fixture with a build in progress),
run `claude -p "<utterance>" --output-format json --max-turns 1` with the local plugin loaded, and
assert on the **`Skill` tool invocation** in the JSON — not on prose. Pass = expected skill name
invoked (or no `Skill` call for `none`). Prints a routing matrix and writes it to
`tests/results/triggers-<date>.md`. Opt-in (`SPECCLAW_TRIGGER_EVALS=1`, needs a key); CI runs it on a
nightly schedule and on any PR touching `skills/*/SKILL.md` or `hooks/`. Never on every push — it
costs API calls.

**3. The description lint.** `tests/run-description-lint-tests.sh`, pure bash, runs on every push:
each `SKILL.md` description must be ≤ 300 characters, must state a triggering condition (contains
`Use when`, `Run after`, `Invoke when`, or a *when*-clause the lint recognises), and for
model-invocable skills must not contain workflow narration markers (`then`, `step`, `→` chains,
`first … then`). `disable-model-invocation: true` skills are exempt from the trigger clause. A
baseline file lists current offenders (same pattern as `shellcheck-baseline.txt`) so the lint lands
green and the offender list only shrinks.

**4. Rewrite the descriptions.** All ~30 skill descriptions rewritten to trigger-first, ≤ 300 chars,
process moved into the body where it belongs. The lifecycle sentence ("the first step in propose → plan
→ …") lives once in `using-specclaw` (033), not in every description. Run the trigger suite **before**
and **after** the rewrite; both matrices are committed to the change dir as the evidence that it helped
(or did not).

**5. Contributor rule.** Plugin `CLAUDE.md` gains three lines: any PR that edits a `SKILL.md` description
or the router must include the trigger matrix in its body. `specclaw-pr` appends it automatically when
`tests/results/triggers-*.md` is newer than the base branch.

## Scope

### In Scope
- `tests/fixtures/triggers.tsv`, `tests/run-trigger-tests.sh`, results directory, CI wiring (nightly +
  path-filtered).
- `tests/run-description-lint-tests.sh` + baseline; registered in the always-on CI job.
- Description rewrite across `skills/*/SKILL.md`; before/after matrices committed to the change dir.
- `specclaw-pr` matrix attachment; plugin `CLAUDE.md` rule.

### Out of Scope
- superpowers' `writing-skills` methodology (pressure scenarios, RED/GREEN for prose) as a specclaw
  skill. The lint and the matrix are the enforceable subset.
- Judging *how well* a skill executed once invoked — that is what verify/review already measure.
  This suite tests routing only.
- Cross-harness evals (Codex, Gemini). Claude Code only.
- The router content itself (033) and new skills (034). This change measures them.

## Impact

- **Files affected:** ~35 (estimated) — ~30 `SKILL.md` frontmatter edits (mechanical), 2 new test
  scripts, 1 fixture, CI workflow, `specclaw-pr`, plugin `CLAUDE.md`.
- **Complexity:** medium — the runner is small; the care is in making the rewrite not change
  behaviour except for the better, which is exactly what the before/after matrix is for.
- **Risk:** low — the lint lands with a baseline so nothing goes red on day one; the trigger suite is
  opt-in and costs only when it runs. The one real risk is `claude -p` output-format churn; pin the
  assertion to the tool-use block shape and fail loudly if the shape changes.

## Open Questions

1. **How many reps per utterance?** Routing is stochastic; superpowers uses 5. Ten rows × 5 reps × 2
   runs is 100 headless calls per rewrite — acceptable nightly, not per PR. Confirm budget.
2. **Which model runs the eval?** Routing behaviour differs by model; the matrix should record it and
   the nightly should run on the default `claude` model plus one cheap one.
3. **Does the lint accept a description that has no `Use when` but reads as a condition** (e.g. "Show
   the project's dashboard")? Define the accepted openers precisely or the lint becomes a style war.
4. **Should state-dependent rows** (same utterance, different `STATUS.md`) be in scope now, or wait for
   033's snapshot to exist? Lean: include two rows now so 033 has a target to hit.

---

**To proceed:** Review this proposal and approve to begin planning.
