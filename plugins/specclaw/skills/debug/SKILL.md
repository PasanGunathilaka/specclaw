---
description: Use when a bug, test failure, build failure, or unexpected behaviour is reported or observed, before proposing any fix.
---

# specclaw debug

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

## The Iron Law

**No fix without a stated root cause.**

One hypothesis at a time. The smallest change that tests *that* hypothesis. A wrong hypothesis is
withdrawn and replaced — never fixed on top of.

The cost of breaking this law is not a wasted turn. It is a codebase carrying three speculative
changes, none of which addressed the problem, and no record of what was ruled out — so the next
person starts from zero.

## Phase 1 — Evidence

Before forming any theory:

1. **Read the whole error.** Not the first line. Stack traces name the boundary that failed; the
   first line names the boundary that noticed.
2. **Reproduce it with one command.** Write that command down — it is the record's `reproduce` field
   and the thing the fix must be proved against. If it cannot be reproduced on demand, say so
   explicitly; an unreproducible bug is a different investigation.
3. **Find when it last worked.** `git log`, `git diff` since that point. A bug that appeared in a
   known window has a much smaller search space than one that did not.
4. **In multi-component paths, instrument the boundaries before theorising.** Print or log what
   crosses each seam. A guess about which side is wrong costs more than the two minutes of
   instrumenting that answers it.

Observations only in this phase. "The config is probably not loading" is not an observation.

## Phase 2 — Compare

Find the nearest thing in this repo that works — the sibling test that passes, the other caller of
the same function, the module that does the same job correctly — and list **every** difference
between it and the failing case. Most root causes are in that list.

## Phase 3 — One hypothesis

Write it down, in this form:

```
Hypothesis: <mechanism> because <evidence>
```

`because` is not optional. A hypothesis with no evidence behind it is a guess, and guesses are what
this protocol exists to stop.

Then make the **smallest change that tests it** — often a print, an assertion, or a one-line
condition, not the fix. If it is wrong: **withdraw it, record why, form a new one.** Do not leave
the failed attempt in the tree, and never stack a second fix on the first.

## Phase 4 — Fix and prove

1. **Failing test first**, where the project has a test framework. The test should fail for the
   stated root cause and pass once it is removed.
2. **One fix.** Targeted at the root cause, not at the symptom. A `try`/`except` around the failing
   call, a retry, a widened type, a bumped timeout — each of these makes the symptom go away without
   touching the cause, and each will be back.
3. **Re-run the reproduction command from Phase 1 and paste its output.** No fix is done because it
   looks right. Evidence before assertions, always.

## Three strikes — stop and question the design

After **three withdrawn hypotheses on the same failure**, stop. Do not form a fourth.

Three correct-looking theories that each turned out to be wrong is not bad luck; it usually means the
thing being debugged is not the thing that is broken. Write an **architecture question** for the
operator instead of a fourth fix: what was ruled out, what that implies, and which design decision
now looks wrong.

The loop enforces the same rule mechanically. `specclaw-loop decide` counts investigation records on
one `failure_sig` whose every hypothesis is `withdrawn`, and halts with
`"halt_reason": "architecture-question"` once `loop.architecture_question_limit` (default 2) of them
exist. Follow that halt verbatim — it is exactly this rule, applied by a script.

## Red flags — every one of these means STOP

| Thought | What it actually means |
|---------|------------------------|
| "Let me just try X and see" | No hypothesis. Go back to Phase 3. |
| "It's probably Y, let me fix that" | "Probably" is a guess. Get evidence first. |
| "I'll make a few changes and re-run the tests" | Two changes at once means neither is tested. |
| "One more attempt" (after three) | That is the architecture question. Write it. |
| "The test is wrong" | Sometimes true. Say *why*, with evidence, before touching it. |
| "Let me add a retry / bump the timeout" | Symptom fix. Name the cause first. |
| "Let me wrap it in try/except to be safe" | This hides the bug from the next person. |
| "It works now, I'm not sure why" | Then it is not fixed. Find out why. |
| "This is too small to record" | The record is two commands long. Write it. |

## Record it — `specclaw-log-error --investigation`

Every investigation ends in `errors.md`, whether it came from a loop turn or from a human asking
"why is this failing". Build the payload and file it:

```bash
cat > /tmp/inv.json <<'JSON'
{
  "symptom": "verify exits 1 with no output on a clean tree",
  "task": "T5",
  "failure_sig": "<the sig from specclaw-loop signature, if this is a loop turn>",
  "reproduce": "specclaw-verify .specclaw my-change",
  "reproduce_exit": "1",
  "evidence": "verify-report.md is written but empty; collect ran with an unset test_command",
  "hypotheses": [
    "withdrawn: the report template is missing — it is present and readable",
    "upheld: collect exits early on an empty test_command and the caller reads its exit code as a verdict"
  ],
  "fix": "treat an unset test_command as skipped, not failed",
  "commit": "a1b2c3d",
  "proof": "same command → exit 0, report lists 1 skipped gate",
  "spec_gap": false
}
JSON
specclaw-log-error .specclaw <change> --investigation /tmp/inv.json
```

Rules the script enforces, so you do not have to remember them:

- Every hypothesis string **must** start `upheld:` or `withdrawn:`. Anything else is refused
  (exit 2) — the verdict is what the three-strikes counter reads, and a record it cannot read is
  worse than no record, because it looks like one.
- `symptom` is required. A record with no observed symptom is a guess.
- `spec_gap: true` prints the `specclaw-log-learning … spec_gap …` command to run. Run it — a root
  cause that was really a gap in the spec is the single most valuable thing this journal collects.

## Where the record goes, and what happens next

| Situation | Record into | Then |
|-----------|-------------|------|
| A build is in progress on a change | that change's `errors.md` | continue the build / loop |
| A defect in an existing change, no build running | that change's `errors.md` | fix under that change |
| A defect with no change at all | ask: is this part of an existing change, or new work? | new work → `/specclaw:propose`, with the investigation record as the Problem statement |

**Never block on the ceremony.** If no change dir exists, investigate first and offer
`/specclaw:propose` after — an investigation record makes a far better bug-fix proposal than prose,
because it already names the cause, the evidence and the proof.

## Relationship to the loop

When `/specclaw:loop` is driving, this protocol is what the fix agent is held to:
`specclaw-build-context --failure-record` prepends the Root-Cause Protocol to its payload, and its
report must end with the investigation record. The loop's instruction is the *smallest diff that
removes the root cause* — same size discipline as before, aimed at the right target.

The reward-hack guard stays where it is. It is the backstop for the crudest symptom fix (editing the
test); this protocol is what stops the subtler ones.
