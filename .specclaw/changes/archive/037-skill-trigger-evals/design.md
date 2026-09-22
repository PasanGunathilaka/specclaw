# Design: Skill-trigger evals and a description lint

**Change:** 037-skill-trigger-evals
**Created:** 2026-09-19

## Two gates at two prices

| Gate | Cost | Runs |
|---|---|---|
| `run-description-lint-tests.sh` | zero — bash, no network | every push |
| `run-trigger-tests.sh` | API calls × rows × reps | nightly, and on PRs touching `skills/**/SKILL.md` or `hooks/**` |

A routing suite that spends money on every push is a suite someone switches off, and a switched-off
suite is worse than no suite because the badge still says it exists. So the cheap structural rules
are always-on, and the expensive behavioural measurement is opt-in behind `SPECCLAW_TRIGGER_EVALS=1`.

## The lint's accepted set is closed, and that is the whole design

Open question 3 asked whether a description that reads as a condition without saying *"Use when"* —
*"Show the project's dashboard"* — should pass. It should not, and the reason is in the question:
*"define the accepted openers precisely or the lint becomes a style war."*

Any list broad enough to admit "Show …" also admits "Manage …", "Create …", "Produce …",
"Synthesize …" — which is every description in the repo, at which point `TRIGGER` checks nothing.
So the accepted set is exactly:

```
Use when · Use after · Use before · Run after · Run before
Invoke when · Invoke immediately when · Trigger when · …when <condition>
```

The consequence is a large day-one offender list. **That is the intended shape**, and it is what the
baseline is for: the lint lands green, the list is visible, and it only shrinks.

## Why the baseline is copied from shellcheck-gate, exactly

`<path> <RULE>` pairs, no line numbers, sorted, compared with `comm` under `LC_ALL=C`. Three
properties come along with the format and all three matter here:

- Editing an unrelated part of a `SKILL.md` does not churn the baseline.
- A fixed offence is **reported as prunable** rather than silently accepted, so the list cannot
  quietly stop shrinking.
- A new skill has no entries, so the rules bind from its first commit — which is the actual point.
  The offender list is a debt register for 35 files written before the rule existed, not a licence.

## The runner asserts on the tool call, never on prose

```bash
claude -p "<utterance>" --output-format json --max-turns 1
```

and the assertion is on a `Skill` tool-use block naming the expected skill. Asserting on prose
("I'll use the propose skill") would pass on a model that *said* the right thing and invoked nothing
— which is precisely the failure this suite exists to catch.

`--max-turns 1` keeps a row to one decision. Hit rate over `SPECCLAW_TRIGGER_REPS` reps is the
measurement, because routing is stochastic and a single sample is an anecdote.

**Fail loudly on shape change.** If `claude` is missing, or the JSON carries no recognisable
tool-use block for any row, the runner exits non-zero with what it saw. The named risk in the
proposal is `claude -p` output-format churn, and the failure mode to avoid is a suite that starts
reporting 0% routing and reads as a routing regression.

## State-dependent rows

Two rows share an utterance and differ only in seeded state:

```
the tests are failing    debug    build-in-progress   033: snapshot says a build is live
the tests are failing    propose  clean               …same words, clean tree, no change dir
```

They are the sharpest possible test of 033's claim that injecting recorded state makes routing
controlled rather than persuasive: identical input, different correct answer, and the only
difference is what the snapshot said.

## What this change does not do

It does not rewrite the descriptions. See the spec's *Deliberately deferred* section — the proposal
requires before/after matrices as the evidence, and this commit builds the thing that produces them.

## Test plan

`tests/run-description-lint-tests.sh` is itself the lint; its behaviour is pinned by
`tests/run-lint-meta-tests.sh` (AC-1 … AC-14) using synthetic `SKILL.md` fixtures in a temp tree, so
the lint's rules are tested without depending on what the real skills happen to say today.
