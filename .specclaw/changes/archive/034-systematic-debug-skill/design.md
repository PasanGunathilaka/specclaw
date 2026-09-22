# Design: `/specclaw:debug`

**Change:** 034-systematic-debug-skill
**Created:** 2026-09-19

## Approach

Four files carry behaviour, three carry prose.

```
skills/debug/SKILL.md          the protocol a model follows      (prose)
templates/errors.md            the record shape                  (prose)
references/agent-prompts.md    the fix agent's obligation        (prose)

bin/specclaw-log-error         --investigation: payload → block  (behaviour)
bin/specclaw-build-context     --failure-record: prepend protocol (behaviour)
bin/specclaw-loop              decide: architecture-question      (behaviour)
bin/specclaw-detect-patterns   cluster on cause, not error text   (behaviour)
```

## The payload, and why it is shaped this way

```json
{
  "symptom": "party tally exits 1 on a clean run",
  "task": "T5",
  "failure_sig": "a1b2c3d4",
  "reproduce": "bats tests/run-party-tests.sh -f tally",
  "reproduce_exit": "1",
  "evidence": "findings-r2/ empty while findings-r1/ has 4 files (ls output)",
  "hypotheses": [
    "withdrawn: tally reads r2 first and treats missing as zero — code checks r1 count first",
    "upheld: set -e aborts on ls of a missing dir, so the exit-2 path is never reached"
  ],
  "fix": "guard the ls with [ -d ]",
  "commit": "a1b2c3d",
  "proof": "same command → exit 0, 4 findings tallied",
  "spec_gap": false
}
```

`hypotheses` is a **flat array of strings with a verdict prefix**, not an array of objects. Two
reasons, and the second is the operative one:

1. The plugin's jq-free reader (`json_pick_array`, lifted from `specclaw-party`) reads string arrays
   and nothing else. Nested objects would mean a real JSON parser, and `jq` is optional here by
   policy.
2. The verdict is the only field a *script* ever needs. Everything else in a hypothesis is prose for
   a human. Putting the machine-readable half in a two-token prefix keeps the parse trivial and
   makes a malformed record **loud** — FR5 refuses a payload whose prefixes do not parse, rather
   than filing a record the three-strikes counter would silently read as zero.

## Rendered block

```
## [T5] Investigation 2 — party tally exits 1 on a clean run

**When:** 2026-09-19 10:52 UTC
**Status:** upheld
**Failure-Sig:** a1b2c3d4
**Reproduce:** `bats tests/run-party-tests.sh -f tally` → exit 1
**Evidence:** findings-r2/ empty while findings-r1/ has 4 files (ls output)
**Hypothesis 1 (withdrawn):** tally reads r2 first … — code checks r1 count first
**Hypothesis 2 (upheld):** set -e aborts on ls of a missing dir …
**Fix:** guard the ls with `[ -d ]` (commit a1b2c3d)
**Proof:** same command → exit 0, 4 findings tallied

---
```

The `## [` prefix matches the existing attempt-entry shape, so `--resolve`'s awk and
`detect-patterns`' `^## ` scanner both keep working without being taught a second grammar.

## Three strikes: where the arithmetic lives

`specclaw-loop decide` gains step 3, between REGRESSION and NO-PROGRESS:

```
arch_question_count <errors.md> <failure_sig>
  → number of "## [.*] Investigation" blocks whose **Failure-Sig:** equals <failure_sig>
    and whose every "**Hypothesis N (...)**" line reads `withdrawn`
```

An investigation with **no** hypotheses does not count (nothing was ruled out). One with any
`upheld` hypothesis does not count (something was learned, and the next turn is a different problem).
The count is over that change's whole `errors.md`, not a window, because a ruled-out cause stays
ruled out.

Ordering: it precedes NO-PROGRESS and OSCILLATION deliberately. On the evidence that trips it, both
of those are *also* true — the signature has not changed — and both would report a worse reason for
the same facts. "Two hypotheses ruled out, here they are, the design may be wrong" is an
escalation an operator can act on; "no progress in 2 turns" is not.

`emit_decision` grows a third argument, the slug. Existing halts keep their exact `reason` strings.

## Alternatives rejected

- **A `PreToolUse` hook blocking `Edit` until a hypothesis exists.** Real teeth, and the proposal
  explicitly defers it: measure the advisory version first. A hard block on the debugging path is
  the one place a false positive costs the most.
- **A separate `investigations.md`.** A second file means a second thing to find, and
  `specclaw-pr` already stages `errors.md`. Same file, distinguishable heading.
- **Counting withdrawn hypotheses in `log-turn` state instead of scanning `errors.md`.** State would
  drift from the record; the record is the thing a human reads.

## Test plan

`tests/run-debug-protocol-tests.sh`, bash + coreutils, registered in CI:
rendering (numbering, status, all fields), both refusals, the no-`--investigation` regression,
the four counting rules for `architecture-question`, slug presence on every halt, and the
build-context prepend.
