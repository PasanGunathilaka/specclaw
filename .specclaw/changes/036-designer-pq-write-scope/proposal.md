# Proposal: A pending question the designer cannot write is lost silently

**Created:** 2026-09-10
**Status:** 🟡 Draft

## Problem

`bf-baseline-designer`'s **Ask, Don't Guess** step appends a `PQ-NNN` to `.specclaw/analysis/pending-questions.md` when one of its six triggers fires. That file is **outside** `.specclaw/baseline/`, the directory the designer otherwise writes.

Discovered during `034`'s smoke test. The designer correctly identified a real `T3` finding in the target app — two mechanisms independently set an invoice to POSTED, one enforcing a business rule and one enforcing nothing — designed the pending question for it, marked the affected scenario `⚠ PROVISIONAL — pending PQ-012`, and then **could not write the question**, because that run's write scope was confined to `.specclaw/baseline/`.

The visible outcome was almost right and therefore dangerous:

- `scenarios.md` carried `⚠ PROVISIONAL — pending PQ-012`
- `record` read that marker and correctly marked the fixture `PROVISIONAL`
- every downstream report showed a fixture blocked on a pending question
- **`PQ-012` did not exist in any file**

So the marker pointed at nothing. A reader chasing `PQ-012` finds no question, no proposed default, and no evidence — and `/specclaw:bf-clarify` has nothing to ingest, type, or promote to a `CQ-###`. The uncertainty is *visible* but not *actionable*, which is the one state the PROVISIONAL mechanism exists to prevent.

It only surfaced because that run's write scope was explicitly narrowed. But the same shape occurs whenever the agent's write of that file fails for any reason — a permissions refusal, a read-only checkout, a sandbox, a tool denial — and in every one of those cases the run still **reports success**, because writing `seams.md` and `scenarios.md` did succeed.

**Why this matters beyond one run.** `⚠ PROVISIONAL` is load-bearing across four documents: `scenarios.md` carries it, `record` converts it into a manifest `status`, `bf-replay` holds its verdict at `PASS-PENDING-DECISIONS` because of it, and `bf-rebuild-plan` renders it into an item's Gate. All four now rest on a question id that may name nothing.

## Proposed Solution

Make an unwritable pending question **loud rather than silent**, without making the designer's write mandatory (a read-only or sandboxed analysis run is legitimate and should still produce a design).

Two parts:

1. **The designer reports every PQ it intended to write, in its final response**, with the full entry body — id, trigger, blocks, evidence, proposed default. It already reports declined scenarios and provisional markers; an intended-but-unwritten question belongs in the same summary. The orchestrating skill relays it, so a human sees the question even when the file write did not happen.

2. **`specclaw-bf-baseline record` warns when a scenario's `⚠ PROVISIONAL — pending PQ-NNN` marker names an id with no matching entry** in `pending-questions.md` (or no `CQ-NNN` in `clarifications.md`, since a promoted question moves). A **WARN, never a hard failure**: the fixture is genuinely provisional and refusing the whole record would destroy a valid manifest over a documentation gap. This is the same treatment `record` already gives the module-consistency disagreement — report both facts, decide neither.

The pairing matters: part 1 stops the question being lost at the moment it is designed; part 2 catches every marker that already names nothing, including ones written before this change.

## Scope

### In Scope
- `bf-baseline-designer.md` — the intended-PQ reporting requirement in its Output section, for both design and harness mode (harness mode raises `T2`/`T3` for unmappable error conditions and has the identical exposure).
- `skills/bf-baseline/SKILL.md` — relay that report.
- `specclaw-bf-baseline record` — the dangling-marker WARN, with the id and the file it looked in.
- Tests: a marker naming a non-existent `PQ` warns and still records; a marker whose question was promoted to a `CQ` does **not** warn; a well-formed pair is silent.

### Out of Scope
- Making the designer's `pending-questions.md` write mandatory, or failing a run that cannot perform it. A read-only analysis pass is a supported mode.
- `bf-domain-analyst` and the other analysis agents. They share the Ask-Don't-Guess pattern and probably share the exposure, but each writes its own documents and needs its own check — a separate change, deliberately, so this one stays reviewable.
- Anything to do with `PQ-012` itself. That question was raised against a synthetic smoke fixture in a scratchpad directory and is disposable; it is the mechanism that needs fixing, not that entry.

## Impact

- **Files affected:** ~4 — 1 agent, 1 skill, 1 bin script, 1 test suite
- **Complexity:** small
- **Risk:** low. The WARN cannot fail a record, and the reporting requirement adds output rather than behaviour. The only judgement call is whether a promoted `CQ` counts as satisfying the marker — it does, and the test pins it.

## Open Questions

1. **Should `bf-replay` also warn on a dangling marker?** Proposed default: no. `record` is the earliest point the two documents are read together, so warning there catches it before any replay run, and duplicating it downstream would report one gap twice.
2. **Should the designer write the PQ to a fallback location** (e.g. inside `.specclaw/baseline/`) when the canonical path is unwritable? Proposed default: no — a pending question in a non-canonical file is a question `/specclaw:bf-clarify` will never find, which trades a loud gap for a quiet one.

## Notes

- Found by `034`'s end-to-end smoke test, which ran the real designer charter against a representative fixture. Recorded in `.specclaw/changes/034-baseline-nonrule-scenarios/verify-report.md` under **Findings recorded, not fixed here**.
- Related learning: `L14` — a mechanism that can produce a passing or reassuring result must fail closed on every ambiguity. A marker pointing at a missing question is precisely a reassuring result over an unexamined gap.
- Independent of `035-verification-join-key-parity`; neither blocks the other.

---

**To proceed:** Review this proposal and approve to begin planning.
