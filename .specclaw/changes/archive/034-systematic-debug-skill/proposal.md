# Proposal: `/specclaw:debug` — a root-cause-first debugging protocol that triggers itself and feeds the loop

**Created:** 2026-09-19
**Status:** 🟡 Draft
**Source of the idea:** `obra/superpowers` `skills/systematic-debugging/SKILL.md` (Iron Law, four phases, three-strikes rule, red-flags table). Adapted, not copied — none of its six reference files come along.

## Problem

Debugging is the one activity where specclaw currently has *no* skill, and it is the activity where an
agent does the most damage fastest:

- **Interactively**, when the operator says "the build is broken" or "this test fails", nothing routes.
  The model reads the error, guesses a fix, applies it, and if the guess was wrong applies another one on
  top. Every such fix bypasses the paper trail — no change dir, no `errors.md` entry, no learning.
- **Autonomously**, the loop's fix agent is instructed to make *"the smallest diff to turn the failing
  gate green"* (plugin `CLAUDE.md`, Loop section). That is an incentive to fix the symptom. The
  reward-hack guard (`guard_action: revert-tests`) exists precisely because agents *do* reach for the
  cheapest green — editing the test. The guard catches the crudest form; it cannot catch a `try/except`
  around the failing call.
- **The error journal records outcomes, not reasoning.** `templates/errors.md` is a heading and a rule;
  `specclaw-log-error` writes error text + attempt + resolution. There is no place for "what I think the
  root cause is and what evidence says so", so the same class of bug is re-investigated from zero on the
  next change and `specclaw-detect-patterns` has only the error strings to cluster on.
- **Three failed fixes look like two failed fixes plus one more try.** `loop.no_progress_limit` halts on
  no gate improvement, but it cannot distinguish "the fix agent is thrashing on symptoms" from "the
  architecture is wrong". superpowers names the second case explicitly: after three failed fixes, stop
  and question the design — *"this is NOT a failed hypothesis, this is a wrong architecture."*

The superpowers skill is good because it is short on technique and long on discipline: **no fix
without a stated root cause**, one hypothesis at a time, smallest test of that hypothesis, and a
recognition table for the moments an agent talks itself out of the process.

## Proposed Solution

**1. New skill `skills/debug/SKILL.md`** (~150 lines). Frontmatter description is trigger-only:
*"Use when a bug, test failure, build failure, or unexpected behaviour is reported or observed, before
proposing any fix."* Body:

- **Phase 1 — Evidence.** Read the whole error. Reproduce it with one command. `git diff`/`git log`
  since it last worked. In multi-component paths, instrument the boundaries before theorising.
- **Phase 2 — Compare.** Find the nearest working example in the repo; list every difference.
- **Phase 3 — One hypothesis.** Written down as `Hypothesis: X because Y`. Smallest change that tests
  it. Wrong → new hypothesis, never a second fix on top of the first.
- **Phase 4 — Fix and prove.** Failing test first where a framework exists; single fix; re-run the
  reproduction command and paste its output.
- **Three strikes.** After three failed hypotheses the skill stops and writes an *architecture question*
  for the operator instead of a fourth fix.
- **Red-flags table** (≤ 10 rows) — "just try X and see", "probably Y, let me fix that", "add a few
  changes and run the tests", "one more attempt".
- **Where the record goes** (below). Nothing else: no timeout guide, no polluter-finder script, no
  test-pressure fixtures. specclaw's version fits on one page by design.

**2. A structured investigation record in `errors.md`.** Extend `specclaw-log-error` with
`--investigation` taking a small JSON payload, rendering:

```
### E3 — <symptom, one line>                          2026-09-19 10:52 UTC · change 032 · T5
**Reproduce:** `bats tests/run-party-tests.sh -f tally`  → exit 1
**Evidence:** findings-r2/ empty while findings-r1/ has 4 files (ls output)
**Hypothesis 1:** tally reads r2 first and treats missing as zero → withdrawn: code checks r1 count first
**Hypothesis 2:** exit 2 path never reached because `set -e` aborts on `ls` of missing dir → upheld
**Fix:** guard `ls` with `[ -d ]`  (commit a1b2c3d)
**Proof:** same command → exit 0, 4 findings tallied
```

Every field is a line the *human* can check. `specclaw-detect-patterns` gains the `Hypothesis` and
`Fix` lines as inputs, so patterns cluster on causes, not error strings.

**3. Wire the protocol into the loop fix agent.** `specclaw-build-context --failure-record` prepends
the Phase 1–3 requirement to the fix agent's payload: *state the root cause hypothesis and the evidence
before writing the diff; the diff must target the hypothesis*. The fix agent's report must end with the
investigation record; the skill writes it to `errors.md` and the loop log. This replaces "smallest diff
to turn the gate green" with "smallest diff that removes the root cause" — same size discipline, right
target.

**4. Three strikes → a named halt reason.** `specclaw-loop decide` already halts on
`no_progress_limit`. Add `halt_reason: architecture-question` when the last N investigation records
on the same `failure_sig` each carry a *withdrawn* hypothesis: `escalate` then posts the accumulated
hypotheses to the operator as "here is what was ruled out; the design may be wrong" — a far better
escalation message than "no progress in 2 turns".

**5. Routing.** Change 033's router sends bug/failure utterances here. When a build is in progress on the
change in question, the skill records into that change's `errors.md`; otherwise it asks whether this is
a defect in an existing change (→ that change) or a new one (→ `/specclaw:propose` with the
investigation record attached as the Problem statement — which, incidentally, produces far better
bug-fix proposals than prose).

## Scope

### In Scope
- `skills/debug/SKILL.md` — protocol, three-strikes, red flags, record format, routing paragraph.
- `bin/specclaw-log-error --investigation` and the rendered block in `errors.md`.
- `specclaw-build-context --failure-record` payload change; fix-agent prompt in
  `references/agent-prompts.md`.
- `specclaw-loop`: `architecture-question` halt reason and its escalation text.
- `specclaw-detect-patterns`: read `Hypothesis`/`Fix` lines.
- bats: log-error rendering, loop halt-reason classification, pattern clustering on the new lines.
  Shellcheck-clean.

### Out of Scope
- superpowers' companion documents (`root-cause-tracing.md`, `defense-in-depth.md`,
  `condition-based-waiting.md`, `find-polluter.sh`, the three `test-pressure-*.md`). Deliberately: the
  protocol is the learning, the technique library is theirs.
- A hard `PreToolUse` block on `Edit` until a hypothesis is recorded. Advisory in this change; measure
  first.
- Changing the reward-hack guard. It stays as the backstop.
- Test-driven-development as a separate skill. Phase 4 says "failing test first"; the full TDD skill is
  a later, separate question.

## Impact

- **Files affected:** ~8 (estimated) — 1 new SKILL.md, `specclaw-log-error`, `specclaw-build-context`,
  `specclaw-loop`, `specclaw-detect-patterns`, `references/agent-prompts.md`, `templates/errors.md`,
  1–2 bats suites.
- **Complexity:** medium — the skill text is the hard part; the bash changes are additive fields.
- **Risk:** low — fail-open; the loop's existing halts are untouched; `--investigation` is optional so
  every current `log-error` caller keeps working.

## Open Questions

1. **Does the interactive protocol always require a change dir?** A one-line typo fix found while
   debugging is still a change; but forcing `propose` for every defect may push people off the tool.
   Lean: record to the active change if one exists, otherwise offer propose — never block.
2. **How many withdrawn hypotheses trigger `architecture-question`?** superpowers says three fixes.
   With `max_iterations: 5` default, three leaves little room; consider 2 withdrawn on the same
   `failure_sig`.
3. **Where does the fix agent's hypothesis live when the loop is disabled** (`loop.enabled: false`)?
   Same `errors.md`, written by the build skill's retry path?
4. **Should `learnings.md` get an automatic entry when the root cause was a spec gap** (the fix changed
   behaviour the spec did not specify)? That is exactly the `spec_gap` category `specclaw-log-learning`
   already has.

---

**To proceed:** Review this proposal and approve to begin planning.
