# Spec: Model-invocation opt-out for the bf-* commands

**Change:** 039-model-invocation-opt-out
**Created:** 2026-09-20
**Status:** 🟡 Draft

## Overview

The `bf-*` pipeline spends context in two separable ways. This change addresses both, with two
independent levers.

**L1 — collector payloads stop transiting the orchestrator.** Nine bf skills, at fifteen spawn
sites, tell the orchestrator to pass *"the collected JSON (stdout of Step 1)"* into the subagent
prompt. To pass it, the orchestrator must hold it. `specclaw-bf-analyze-codebase collect .specclaw .`
emits **229,770 bytes (~57k tokens)** on this repo — a small one. `bf-quality` already avoids this:
its collector *"writes `.specclaw/analysis/quality.json` and emits it on stdout"*
(`bin/specclaw-bf-quality-collect:91`) and its skill passes *"the resolved path of the JSON artifact
it is to narrate — it reads that file directly"* (`skills/bf-quality/SKILL.md:71`). L1 generalises
that existing pattern to the other nine. No config, no opt-in, no behaviour change.

**L2 — a switch for narration spawns.** Some bf agents narrate an artifact that is already final.
`bf-quality`'s analyst is told *"every status, severity, rollup and verdict in the JSON is already
final"* (`bf-quality:75`) and that three report sections are collector-rendered markdown it pastes
**verbatim** between anchors (`bf-quality:79`). When the budget is tight, that run should be
skippable. `bf.narration: false` skips the spawn and renders the report deterministically from the
collector's own `report_blocks.*_md`, marking every un-narrated section.

**And the audit is a deliverable, not a preamble.** All 19 bf spawn sites are classified
*narration* (skippable) or *judgement* (never skippable) with cited evidence, in
`references/model-invocation-map.md`. That table is what makes L2 safe to extend later.

## Requirements

### Functional Requirements

- **FR-1** — Each of the nine bf skills that currently inline collector stdout instead redirects the
  collector to `.specclaw/analysis/.collect/<phase>.json` and passes **that path** to the agent.
  Affected sites, by skill: `bf-analyze` 1, `bf-architecture` 1, `bf-baseline` 2 (design +
  harness), `bf-blueprint` 1, `bf-bootstrap` 1, `bf-clarify` 5 (one per mode), `bf-domain` 1,
  `bf-rebuild-plan` 1, `bf-ui` 2 — **15 sites**. Line numbers are deliberately not cited here:
  this task's own edits move them, so a line number in the spec would be stale before it was read.
  `references/model-invocation-map.md` carries the line-cited inventory as of the audit.
- **FR-2** — Each affected agent charter states that its facts arrive as a **file path** it reads,
  not as inline JSON, so the charter and the skill agree.
- **FR-3** — `references/model-invocation-map.md` classifies every bf spawn site (19) as
  `narration` or `judgement`, each row citing the `SKILL.md` line that justifies the call, and
  naming the deterministic fallback for every `narration` row.
- **FR-4** — `config.yaml` gains a `bf:` block with `narration: true`. When it reads `false`,
  `/specclaw:bf-quality` skips the `bf-quality-analyst` spawn.
- **FR-5** — With narration off, `specclaw-bf-quality-render` writes the report from
  `quality.json` + the matching template: the three anchored `report_blocks.*_md` regions verbatim,
  every narrated section replaced by
  `_Not narrated — deterministic mode. Facts below are collector output._`
- **FR-6** — A `--no-model` token anywhere in `/specclaw:bf-quality`'s ARGUMENTS forces narration
  off for that run, whatever the config says. There is no token that forces it *on* against a
  `false` config — an opt-out may be tightened per run, never loosened.
- **FR-7** — `specclaw-init` appends an idempotent, grep-guarded `.gitignore` block for
  `.specclaw/analysis/.collect/`, in the same shape as the existing `timeline.jsonl` block
  (`bin/specclaw-init:57`).

### Non-Functional Requirements

- **NFR-1** — Bash + coreutils only; `jq`/`python3` permitted in `bin/`, test suites stay jq-free.
- **NFR-2** — `tests/shellcheck-gate.sh` passes with `shellcheck-baseline.txt` **unmodified**.
- **NFR-3** — The new suite is registered in `.github/workflows/ci.yml` in the same change.
- **NFR-4** — Paths are quoted; the config value is read with the existing `yaml_val` helper,
  duplicated byte-identically per the repo's standing convention.
- **NFR-5** — No collector's output schema changes. L1 changes *where the bytes go*, not what they are.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- **AC-1** — `grep -rn 'stdout of Step\|collected JSON' plugins/specclaw/skills/bf-*/SKILL.md`
  returns **no** line that instructs passing the payload as agent context. (Today: 15.)
- **AC-2** — Each of the nine skills names `.specclaw/analysis/.collect/<phase>.json` both in its
  collector command and in the context it passes to the agent, and the two agree.
- **AC-3** — `plugins/specclaw/references/model-invocation-map.md` exists and carries one row per
  bf spawn site (19 rows), each with a classification, a cited `SKILL.md:line`, and — for every
  `narration` row — the deterministic fallback that would replace it.
- **AC-4** — With `bf.narration: false`, a `/specclaw:bf-quality` run produces
  `quality-report.md` **without** spawning `bf-quality-analyst`.
- **AC-5** — That deterministically rendered report passes `specclaw-bf-quality-collect lint`
  unmodified: each anchored region is byte-identical to its `report_blocks.<field>`
  (`bin/specclaw-bf-quality-collect:3286`).
- **AC-6** — Every section the analyst would have narrated carries the
  `_Not narrated — deterministic mode…_` marker; no section is silently empty and no collector
  number is paraphrased.
- **AC-7** — With `bf.narration` absent or `true`, `/specclaw:bf-quality` behaves **exactly** as it
  does today — the spawn happens, nothing is stamped. Absence of the key is the shipped default.
- **AC-8** — A `--no-model` token in ARGUMENTS forces the deterministic path even with
  `bf.narration: true`; no token turns narration on against `bf.narration: false`.
- **AC-9** — `tests/run-narration-gate-tests.sh` covers AC-4 through AC-8 and is registered in
  `.github/workflows/ci.yml`. `tests/shellcheck-gate.sh` passes with the baseline unmodified.
- **AC-11** — `specclaw-bf-quality-collect lint-report` reaches a verdict on a QI registry holding
  **zero** `### QI-` entries. Before this change it aborted silently there (`set -euo pipefail` on a
  no-match grep at `:3250`, which lacks the `|| true` its neighbour at `:3256` has), so a report that
  agreed with its artifact reported rc=1 with no message and no verdict.
- **AC-10** — A fresh `specclaw-init` in a scratch repo writes the `.collect/` ignore block once;
  a second run adds nothing.

## Edge Cases

- **`.specclaw/analysis/` does not exist yet** (bf-analyze is the first command run) — the redirect
  must `mkdir -p` the `.collect/` directory, or the collector's output is lost to a shell error and
  the agent is handed a path to nothing.
- **Collector exits non-zero with a partial redirect** — the file exists but is truncated JSON. The
  skill checks the exit status *before* spawning, and reports the collector's failure rather than
  handing the agent a half-written file.
- **The agent cannot read the path** (wrong cwd, relative-path confusion) — pass a repo-relative
  path consistently, the same form `bf-quality` already passes.
- **`quality.json` carries no `report_blocks.<field>`** — the existing lint already fails with
  *"the measurement carries no report_blocks…; re-run the collection step"*. The renderer fails the
  same way rather than emitting a report with a hole in it.
- **`bf.narration` written with an inline comment** (`narration: false   # save tokens`) —
  `yaml_val` strips inline comments before quote-stripping (`bin/specclaw-build:104`), so this is
  already handled; a test pins it.
- **A value that is neither `true` nor `false`** (`off`, `no`, empty) — anything other than the
  literal `false` means narration stays **on**. Fail toward today's behaviour, never toward
  silently skipping a model the operator expected.
- **Stale `.collect/<phase>.json` from a previous run** when the collector fails early — the
  redirect truncates on open, so a failed run leaves an empty or partial file, never a previous
  run's complete one masquerading as fresh.

## Dependencies

- None on other changes. `bf-quality`'s `report_blocks.*_md` and its `lint` subcommand already
  exist (`bin/specclaw-bf-quality-collect:2438-2440, 3266-3286`) and are what the L2 pilot builds on.

## Notes

**Scope added during build, by operator decision (2026-09-20).** AC-11 and task T8 — the one-line
`|| true` fix at `specclaw-bf-quality-collect:3250` and its regression test — were not in the
approved proposal. They were added after T5's verification hit the bug: a zero-entry QI registry is
the normal state of a clean repo, or of any machine without the complexity tooling, and it made
`lint-report` abort silently. AC-5 (the rendered report lints clean) cannot be verified on such a
repo without it. The bug is pre-existing on `main` and lives in a file this change otherwise does not
touch; the operator was asked and chose to fix it here rather than defer it to its own change.

**The two levers answer two different questions, and the proposal's open question is resolved by
shipping both.** L1 is where the *context-window* saving is: ~57k tokens per `bf-analyze` run that
never enter this session. L2 is the switch that was asked for; it buys tokens, wall clock and money,
but not main-session context — a subagent's prompt never enters the orchestrator's window. Saying so
plainly in the config comment is part of the change, so nobody sets `bf.narration: false` expecting
their context window back.

**`.collect/` is a per-run handoff, not a cache.** The repo's standing rule is *"never introduce a
counter, index, or cache for something the filesystem already states."* This file is not a second
copy of a fact consulted later: it is overwritten every run, read once by the agent it was written
for, gitignored, and never a fact source for any other command. `bf-quality`'s `quality.json` is the
same shape and already ships.

**Why `bf-quality` is the pilot and not, say, `bf-analyze`.** Its collector already emits the
pre-rendered markdown blocks, and its `lint` subcommand already verifies a report against the
artifact byte-for-byte. The deterministic path therefore needs no new rendering logic and arrives
with its own verifier. Extending L2 to other sites is a later change, guided by FR-3's table.
