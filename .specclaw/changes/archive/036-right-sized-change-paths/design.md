# Design: Right-sized change paths

**Change:** 036-right-sized-change-paths
**Created:** 2026-09-19

## Where size lives, and who may write it

`state.json`, top level, beside `branch`:

```json
{ "change": "036-…", "phase": "build", "branch": "…", "size": "bounded", "phases": { … } }
```

`specclaw-set-phase` remains **the only writer of `state.json`**. That invariant is load-bearing —
the phase used to be edited from six call sites and the trackers lied as a result — so
`specclaw-set-size` does not write the document. It reads the recorded phase and status, validates
the upgrade, and then **calls `set-phase` with the same phase and status plus `--size <new>`**. A
same-rank transition is already allowed and already idempotent about its timestamp, so re-recording
the current phase is a no-op apart from the size.

That also gives `set-size` its precondition for free: a change with no recorded phase has nothing to
re-record, so it exits 2 telling the operator to record a phase first, rather than inventing one.

## The ratchet

```
spike (0) → bounded (1) → architectural (2)
```

Rank comparison only. A downgrade and a no-op are **both** refused, and refused *by name* —
`"refusing to downgrade 036-… from architectural to bounded"` — the same discipline
`stub-append --strategy item-split` uses. Silence here would be the worst outcome: a downgrade that
appeared to work would quietly drop `design.md` from the required set of a change that had already
been judged to need one.

Absent size is treated as `architectural`, which makes it the **top** of the ratchet. So a change
that predates this feature cannot be "upgraded" — there is nowhere to go — and cannot be downgraded
either. Existing changes are inert, which is exactly FR3's promise.

## Size-aware validation

`validate-change` gains one read and four branches:

```bash
change_size() {   # fail-open: anything unexpected → architectural
  sed -n 's/.*"size"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' state.json | head -1
}
```

A regex read rather than `jq`, because `validate-change` is the gate every phase passes through and
it may not add a dependency to do it. Unparseable, absent, or an unrecognised value all yield
`architectural` — the behaviour every change has today.

The branches:

- **build** — `design.md` is appended to the required list only when the size is `architectural`.
- **build / verify / pr on a spike** — a single refusal that names the recovery. A spike does not
  fail these gates for want of a file; it is not *allowed* to enter them, which is a different
  sentence and reads as one.
- **archive on a spike** — `findings.md` replaces `verify-report.md`.

Everything else is untouched, including non-strict mode: the refusals go through `fail`, so
`workflow.strict: false` turns them into warnings like every other check.

## Why the dashboard glyph is not a fourth column

`⚡ spike` / `▫ bounded` / `▣ architectural` renders inside the existing phase cell rather than as a
new column. `specclaw-update-status` builds a fixed-width table that several tests match on, and a
new column is a change to every row of a document whose whole job is to be diffable. The glyph
carries the same information in the space already there.

## What is deliberately not automated

Nothing upgrades a size on its own. Build and the loop can *detect* that a task's `files:` list has
grown past the spec's file map — that is mechanical — but the upgrade itself changes what the
operator approved, so the mechanism halts with `size-upgrade-needed` and names the command. This is
the same line the plugin already draws for `party.block` and for `--fix` on `reconcile`: detection is
arithmetic, and consequence is a decision.

## Test plan

`tests/run-change-size-tests.sh`, bash + coreutils, CI-registered: the state round-trip and
carry-over, the validation matrix per size (15 combinations), every ratchet refusal, the status.md
row, the re-required `design.md` after an upgrade, and non-strict degradation.
