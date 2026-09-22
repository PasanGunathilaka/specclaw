# Spec: Skill-trigger evals and a description lint

**Change:** 037-skill-trigger-evals
**Created:** 2026-09-19
**Status:** 🟢 Approved

## Overview

specclaw's conversational routing is asserted and never tested. The README promises *"i have a
proposal" fires `/specclaw:propose`*; 20 bats suites cover the bash layer and zero cover whether any
utterance reaches any skill. When 033 lands a router and 034 a debug skill, the routing table and
~35 skill descriptions have to agree, and both will be edited by people who cannot see the effect.

This change builds the measurement: a fixture of canonical utterances with **negative rows**, a
headless runner that asserts on the `Skill` tool invocation rather than on prose, and a pure-bash
description lint that runs on every push.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Reps per utterance | **5**, overridable with `SPECCLAW_TRIGGER_REPS`. Nightly only — never per push. |
| 2 | Which model | Whatever `SPECCLAW_TRIGGER_MODEL` names, default `sonnet`; the model is **recorded in the matrix**, because a routing result without its model is not a result. |
| 3 | What the lint accepts as a trigger clause | A **closed, listed set**: `Use when`, `Use after`, `Use before`, `Run after`, `Run before`, `Invoke when`, `Invoke immediately when`, `Trigger when`, or a `when …` clause. Nothing else. An open-ended list of imperative openers would accept every description ever written and turn the lint into a style war — which is exactly what Q3 warns against. The consequence is a large day-one offender list, which is what the baseline is for. |
| 4 | State-dependent rows now or later? | **Now** — two rows, so 033's snapshot has a target to hit. |

## Requirements

### Functional Requirements

- **FR1** — `tests/fixtures/triggers.tsv`: tab-separated `utterance`, `expect`, `state`, `note`.
  `expect` is a verb name or `none`. `state` is `clean` or a fixture name whose `STATUS.md` /
  change state is seeded before the run.
- **FR2** — The fixture carries **negative rows** (`expect = none`). Over-triggering is the failure
  mode a MUST gate produces, and a routing suite with only positive rows cannot see it.
- **FR3** — `tests/run-trigger-tests.sh` runs each row `SPECCLAW_TRIGGER_REPS` times against a temp
  project seeded with `.specclaw/`, asserting on the **`Skill` tool invocation** in
  `claude -p --output-format json`, never on prose.
- **FR4** — It is **opt-in**: without `SPECCLAW_TRIGGER_EVALS=1` it prints why it is skipping and
  exits 0. It costs API calls; a suite that spends money by default is a suite people disable.
- **FR5** — It writes `tests/results/triggers-<date>.md`: a matrix of row × hit-rate, plus the model,
  the rep count and the plugin version. A result with no model recorded is not a result.
- **FR6** — If the `claude` CLI is absent, or the JSON shape it returns is not the one asserted on,
  the runner **fails loudly** rather than reporting green. Output-format churn is the one real risk.
- **FR7** — `tests/run-description-lint-tests.sh` is pure bash, runs on every push, and checks every
  `skills/*/SKILL.md` description against three rules:
  | Rule | Check |
  |---|---|
  | `LEN` | ≤ 300 characters |
  | `TRIGGER` | contains one of the closed set of trigger clauses |
  | `NARRATION` | contains no workflow-narration marker (`→`, ` then `, `Step `, `first … then`) |
- **FR8** — `disable-model-invocation: true` skills are **exempt from `TRIGGER`** — nothing routes to
  them by description — and still subject to `LEN` and `NARRATION`.
- **FR9** — `tests/description-lint-baseline.txt` lists current offenders as `<path> <RULE>` pairs,
  no line numbers, exactly as `shellcheck-baseline.txt` does. The lint fails on anything **not** in
  the baseline, and reports baseline entries that no longer occur so the list only shrinks.
- **FR10** — A new or renamed skill starts with **no** baseline entries, so the rules bind from its
  first commit.
- **FR11** — `specclaw-pr` appends the newest `tests/results/triggers-*.md` to the PR body when it
  is newer than the base branch.
- **FR12** — The plugin `CLAUDE.md` states the contributor rule: a PR editing a `SKILL.md`
  description or the router carries the trigger matrix.
- **FR13** — CI: the lint runs in the always-on job. The trigger suite runs on a nightly schedule and
  on PRs touching `skills/**/SKILL.md` or `hooks/**` — **never** on every push.

### Non-Functional Requirements

- **NFR1** — The lint is bash + coreutils, no network, no API key, no `jq`.
- **NFR2** — The lint's own failure output names the file, the rule and the offending text, so a
  contributor can act on it without reading the lint.

## Acceptance Criteria

- **AC-1** — The lint passes on the repo as it stands (every current offender is baselined).
- **AC-2** — A description over 300 characters that is not baselined fails with `LEN` and the count.
- **AC-3** — A description with no trigger clause that is not baselined fails with `TRIGGER`.
- **AC-4** — A description containing `→` fails with `NARRATION`.
- **AC-5** — A `disable-model-invocation: true` skill is not failed for `TRIGGER`.
- **AC-6** — …but is still failed for `LEN`.
- **AC-7** — A baselined offender does not fail.
- **AC-8** — A baseline entry whose offence is fixed is reported as prunable, and does **not** fail
  the run.
- **AC-9** — Every accepted trigger clause in the closed set is accepted.
- **AC-10** — The fixture parses: every row has 4 fields and an `expect` that is `none` or a real
  skill directory name.
- **AC-11** — The fixture contains at least two negative rows and at least two state-dependent rows.
- **AC-12** — `run-trigger-tests.sh` without `SPECCLAW_TRIGGER_EVALS=1` prints the reason and exits 0.
- **AC-13** — With the flag set but no `claude` on PATH, it exits **non-zero** — a missing tool is
  not a pass.
- **AC-14** — `specclaw-pr`'s body builder includes a trigger matrix when one is present and newer
  than the base branch, and omits the section entirely when none is.

## Deliberately deferred: the description rewrite

Step 4 of the proposal — rewriting ~35 descriptions to trigger-first form — is **not in this
commit**, and the reason is the proposal's own: *"Run the trigger suite before and after the rewrite;
both matrices are committed to the change dir as the evidence that it helped (or did not)."*

Rewriting 35 descriptions without that baseline would be ~35 unmeasured behaviour changes to the
routing surface, shipped under a change whose entire purpose is to stop exactly that. The lint is
built to land green with an offender list that only shrinks, so the rewrite is a follow-up that can
be done skill-by-skill with evidence:

```
SPECCLAW_TRIGGER_EVALS=1 bash plugins/specclaw/tests/run-trigger-tests.sh   # before
# …rewrite…
SPECCLAW_TRIGGER_EVALS=1 bash plugins/specclaw/tests/run-trigger-tests.sh   # after
```

Both matrices land in `tests/results/` and in the change dir. This is recorded as a learning, not
silently dropped.

## Edge Cases

- A `SKILL.md` with no `description:` at all → reported as `TRIGGER`, not skipped.
- A description spanning two YAML lines → the lint reads the first line only and says so; the
  fixture pins that a folded description is flagged rather than half-read.
- `tests/results/` absent → `specclaw-pr` omits the section, silently. It is not an error.
