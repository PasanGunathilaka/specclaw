# Spec: `/specclaw:debug` — a root-cause-first debugging protocol

**Change:** 034-systematic-debug-skill
**Created:** 2026-09-19
**Status:** 🟢 Approved

## Overview

Debugging is the one activity specclaw has no skill for, and the one where an agent does the most
damage fastest: it reads an error, guesses a fix, and if the guess was wrong stacks another fix on
top. This change adds the protocol (`skills/debug/SKILL.md`), a place to record it
(`specclaw-log-error --investigation`), a way for the loop's fix agent to be held to it
(`specclaw-build-context --failure-record`), and a halt reason for when three hypotheses have been
ruled out and the design — not the code — is what is wrong.

The shape follows the plugin's standing split: **a model judges, a script decides.** Forming a
hypothesis and judging whether the evidence upholds it is irreducibly model work. Counting withdrawn
hypotheses on one `failure_sig` and turning that count into a halt is arithmetic, so it lives in
`specclaw-loop`.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Does the interactive protocol always require a change dir? | **No.** Record into the active change when one exists; otherwise offer `/specclaw:propose` with the investigation attached. Never block a debugging session on ceremony. |
| 2 | How many withdrawn hypotheses trigger `architecture-question`? | **2**, configurable as `loop.architecture_question_limit` (default 2). Three leaves no room under the default `max_iterations: 5`. |
| 3 | Where does the hypothesis live when `loop.enabled: false`? | The same `errors.md`, written by the build skill's retry path. One record format, one location, loop or no loop. |
| 4 | Should a spec-gap root cause write a learning? | **Yes.** `"spec_gap": true` in the payload prints the exact `specclaw-log-learning` command to run; the script does not spawn it (one script, one side effect). |

## Requirements

### Functional Requirements

- **FR1** — `skills/debug/SKILL.md` documents four phases (Evidence → Compare → One hypothesis →
  Fix and prove), the three-strikes rule, a red-flags table, the record format, and routing.
- **FR2** — `specclaw-log-error <dir> <change> --investigation <file|->` appends a structured
  investigation block to `errors.md` from a JSON payload.
- **FR3** — The payload's `hypotheses` is an **array of strings**, each prefixed `upheld:` or
  `withdrawn:`. The prefix is the machine-readable half; the rest is prose.
- **FR4** — An investigation with no `upheld:` hypothesis renders `**Status:** open`; one with an
  upheld hypothesis and a `fix` renders `**Status:** upheld`.
- **FR5** — `--investigation` rejects a payload with no `symptom` (exit 2) and a payload whose
  `hypotheses` entries carry no recognised verdict prefix (exit 2). Refusing is better than filing
  a record the three-strikes counter cannot read.
- **FR6** — `specclaw-loop decide` emits `halt` with `halt_reason: architecture-question` when the
  change's `errors.md` holds `loop.architecture_question_limit` or more investigation blocks that
  carry this turn's `failure_sig` and whose every hypothesis is `withdrawn`.
- **FR7** — Every halt decision gains a stable `halt_reason` slug (`iteration-cap`, `regression`,
  `no-progress`, `oscillation`, `architecture-question`). `action` and `reason` keep their current
  meaning and wording, so existing readers are unaffected.
- **FR8** — `architecture-question` is checked **before** no-progress and oscillation: those two
  would otherwise fire first and report the less useful reason for the same evidence.
- **FR9** — `specclaw-build-context --failure-record` prepends a Root-Cause Protocol block to the
  remediation section requiring a stated hypothesis and its evidence before the diff, and the
  investigation record in the report.
- **FR10** — `specclaw-detect-patterns` clusters investigation blocks on the **upheld hypothesis and
  the fix**, not on the error string.
- **FR11** — `templates/errors.md` documents both entry shapes.

### Non-Functional Requirements

- **NFR1** — Bash + coreutils; `jq` optional, never required. Payload reading reuses the jq-free
  `json_pick` / `json_pick_array` shape already proven in `specclaw-party`.
- **NFR2** — Fail-open: `--investigation` is a new mode, so every existing `log-error` caller is
  byte-identical. A missing or unreadable `errors.md` cannot make `loop decide` fail.
- **NFR3** — Shellcheck-clean against the existing baseline.

## Acceptance Criteria

- **AC-1** — `specclaw-log-error .specclaw c --investigation p.json` appends a block headed
  `## [T5] Investigation 1 — <symptom>` carrying Reproduce, Evidence, numbered Hypothesis lines with
  their verdicts, Fix, Proof and Failure-Sig.
- **AC-2** — A second investigation for the same task numbers itself `Investigation 2`.
- **AC-3** — A payload with no `symptom` exits 2 and writes nothing.
- **AC-4** — A hypothesis string with no `upheld:`/`withdrawn:` prefix exits 2 and writes nothing.
- **AC-5** — All-withdrawn investigations render `**Status:** open`.
- **AC-6** — With two all-withdrawn investigations on sig `abc`, `loop decide … abc` emits
  `"action": "halt"` and `"halt_reason": "architecture-question"`.
- **AC-7** — With one such investigation, `decide` does **not** halt for that reason.
- **AC-8** — Investigations on a *different* sig do not count toward the limit.
- **AC-9** — An investigation with an upheld hypothesis does not count toward the limit.
- **AC-10** — Existing halts still emit their current `reason` text, plus the new slug.
- **AC-11** — `build-context --failure-record` output contains the Root-Cause Protocol block.
- **AC-12** — `detect-patterns scan` clusters two investigations sharing an upheld hypothesis into
  one pattern.
- **AC-13** — `log-error` with no `--investigation` produces byte-identical output to before.

## Edge Cases

- `errors.md` absent when `decide` runs → no architecture-question halt, no error.
- Payload arrives wrapped in a fenced code block (models do this) → the readers flatten and scan, as
  `specclaw-party` already does for `classification.json`.
- A hypothesis containing an escaped quote → `json_pick_array` keeps it whole.
- `failure_sig` absent from the payload → the block records `—` and never counts toward a halt.

## Dependencies

None. 033's router references `/specclaw:debug`; 034 does not depend on 033.

## Notes

Deliberately *not* taken from superpowers: `root-cause-tracing.md`, `defense-in-depth.md`,
`condition-based-waiting.md`, `find-polluter.sh`, the three `test-pressure-*.md`. The protocol is the
learning; the technique library is theirs.
