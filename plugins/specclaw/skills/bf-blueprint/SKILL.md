---
description: Synthesize decisions.md, module-map.md, architecture.md and rebuild-backlog.md into `.specclaw/analysis/target-architecture.md` — the target blueprint, with Mermaid C4 diagrams and a legacy-to-target mapping where every row cites the decision sanctioning it. Run in the legacy repo after /specclaw:bf-clarify --resolve.
---

# specclaw bf-blueprint

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Write `.specclaw/analysis/target-architecture.md`: the **target** architecture of a brownfield rebuild, synthesised from decisions already recorded. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`architecture`/`domain`/`clarify`/`rebuild-plan` pattern.

**Why this command exists.** The pipeline was asymmetric. The legacy side had `architecture.md`, `domain-model.md` and `module-map.md`; the target side had its architecture scattered across `decisions.md`, ADRs, `bootstrap-plan.md` and the backlog — nothing that showed the shape of the thing being built, and nothing anyone could put in front of a client.

**It derives, it never decides.** Every claim about the target rests on a recorded `SQ`/`CQ`/`UQ` decision and cites it by id. Nothing here chooses a stack, a database, a hosting model or an auth approach; where no decision exists, that part of the blueprint renders `PROVISIONAL(<id>)`. Changing what this document says means answering a question in `clarifications.md` and re-running `--resolve` — never editing the blueprint.

**It runs in the legacy repo.** Like every other `bf-` analysis command, it writes into `.specclaw/analysis/` here, and is never run in the rebuild repo. The output travels into the new repo as readability, never as something a verdict is computed from.

## Step 1 — Collect

```bash
specclaw-bf-blueprint collect .specclaw
```

**If it exits non-zero, surface its stderr message to the user verbatim and stop.** There is one refusal, and it names every missing document and the command that produces each: `architecture.md` (`/specclaw:bf-architecture`), `module-map.md` (`/specclaw:bf-domain`), `decisions.md` (`/specclaw:bf-clarify`, then `--resolve`). Don't retry, don't attempt a partial blueprint from partial input, and never substitute your own reading of the codebase for a missing decision record.

**Two things are deliberately *not* refusals:**

- **An unconfirmed `module-map.md`.** A `PROPOSED` status is a `WARN` carried into the blueprint's own header, never a stop — the same soft-block treatment `/specclaw:bf-rebuild-plan` gives it. Relay it; the fix is a human editing that document's `Status:` line.
- **Unresolved blocking questions.** They never stop the run. They make the blueprint `PROVISIONAL`, which is a true and useful state — a rebuild with three open questions still has a knowable target shape everywhere else.

On success it emits one JSON object: the `MOD-###` module roster; the legacy container/component inventory extracted structurally from `architecture.md`'s own Mermaid blocks (or `machine_readable: false` when that structure is absent, in which case the agent sources the mapping table from the document's sections and cites them); every clarify question's `DECIDED`/`UNDECIDED`/`NOT-APPLICABLE` status with the file that proves it; `unresolved_blocking_ids`; the exact `blueprint_status_line`; and any warnings.

**Decision status is computed here and only here.** The agent is handed the verdict and never re-derives it — a status inferred by an agent re-reading markdown is exactly the kind of quietly-wrong claim this split prevents, and it is why the header's `COMPLETE`/`PROVISIONAL` line can be trusted.

## Step 2 — Spawn the blueprint agent

`Agent` tool, `subagent_type: "bf-blueprint-architect"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`) — same routing as its sibling analysis agents, since this is read-only synthesis of already-written documents rather than build work. Pass as context:

- The collected JSON from Step 1.
- The resolved paths of `architecture.md`, `module-map.md`, `decisions.md`, and — when `inputs` says they are present — `rebuild-backlog.md`, `domain-model.md` and `clarifications.md`, for the agent to `Read` directly.
- **The project root**, so it can append to `pending-questions.md` if it has to ask rather than guess.

The agent writes **a draft file**, `.specclaw/analysis/.blueprint-draft.md` — never `target-architecture.md` itself. See `agents/bf-blueprint-architect.md` for the ten section markers it must emit and the diagram/fence conventions.

## Step 3 — Render

```bash
specclaw-bf-blueprint render .specclaw .specclaw/analysis/.blueprint-draft.md
```

Recomputes every decision status from scratch (never trusting the draft), enforces three gates, archives the prior `target-architecture.md` into the same `.specclaw/analysis/archive/` directory the other analysis commands use, splices the draft into the template around the bash-computed status header and Open Questions section, writes `.specclaw/analysis/target-architecture.md`, and deletes the draft. **If it exits non-zero, surface its stderr message to the user verbatim and stop** — every failure names exactly what is wrong.

The three gates, and what each one protects:

| Gate | Refuses | Why |
|---|---|---|
| **Citation** | A mapping-table data row with no `SQ`/`CQ`/`UQ` id, no `PROVISIONAL(<id>)`, and no `RETIRED-BY-DECISION` | A target element nobody decided is exactly what the table exists to make impossible |
| **Real ids** | A row citing an id that is not a real question | A citation resolving to nothing reads as sanctioned and is not — worse than an uncited row, because it looks answered |
| **Module coverage** | A missing section for an active `MOD-###`, or a section for one the map does not define | A silent omission is indistinguishable from an oversight; a withdrawn module is a tombstone, not a thing to design |

**Full regeneration, every run.** There is no hand-preserved zone anywhere in this document — unlike `rebuild-backlog.md`'s human-added status notes. A re-run archives the prior version and writes a new one wholesale. Nothing is lost, because nothing in it is authored here: every fact it holds lives in `decisions.md`, `module-map.md` or `architecture.md`.

## Step 4 — Present a summary

- The **blueprint status** verbatim: `COMPLETE`, or `PROVISIONAL` with the count and the ids. Never soften a `PROVISIONAL` into "mostly complete".
- How many modules got a component view, and **name any module rendered as a `PROVISIONAL` placeholder** together with the question blocking it — that is a work list, and burying it in the file wastes it.
- The mapping table's row count, and any row marked `RETIRED-BY-DECISION` (a legacy capability a decision explicitly drops is worth saying out loud).
- **Surface `render`'s warnings verbatim.** The `module-map.md` unconfirmed warning in particular: repeat the one-sentence reason — this blueprint's module grouping rests on a proposal no human has signed off, and confirming it is an edit to that document's own `Status:` line.
- Any `PQ-###` the agent raised this run, and what it holds provisional.
- **Remind the user to `git add .specclaw/analysis/target-architecture.md`** — grounding the lifecycle in these documents via `context.pin` only works once `git ls-files` can see them, since `specclaw-discover-context` enumerates candidates that way.

## Step 5 — Show what comes next

```bash
specclaw-bf-status .specclaw --next
```

Render its output **verbatim**, after the summary above — never instead of it. Read-only, writes nothing, costs a second.

A `PROVISIONAL` blueprint and an unconfirmed `module-map.md` both surface there, and neither is a stop — exactly as this command treats them. Relay them as the guidance states them rather than restating the status in your own words.

**Only if this run completed.** Steps 1 and 3 both say to surface stderr and stop; that means stop. A run that did not finish must never print a next step, which would read as though the phase advanced when it did not.

**Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.

## What this command does not do

`/specclaw:bf-blueprint` decides **nothing**. It never chooses a stack, a database engine, a hosting model, an auth approach or a UI framework — those are `SQ`/`CQ` decisions made by named humans through `/specclaw:bf-clarify`, and a blueprint that quietly picked one would be inventing the most consequential half of a rebuild. Where a decision is missing, it renders `PROVISIONAL` and says which question would settle it.

It creates nothing under `.specclaw/changes/` and calls no lifecycle skill or script. It never writes into `decisions.md`, `clarifications.md`, `module-map.md`, `architecture.md` or `rebuild-backlog.md` — it only reads them. Its one write outside its own output is an appended `PQ-###` when the agent hits something it cannot ground, which is the ordinary ask-don't-guess path every analysis agent shares.

It never runs in the rebuild repo, and nothing in the rebuild repo reads its output as evidence. `target-architecture.md` is a **readability artifact** there, exactly as `module-map.md` is: `/specclaw:bf-replay` computes its verdicts from `manifest.json` and `decisions.md`, and would compute them identically if this file were absent.

It is not a substitute for `/specclaw:bf-bootstrap`. This document describes the target; that command creates it. `bf-bootstrap` reads `decisions.md` directly and would behave identically if this blueprint had never been generated — deliberately, so that no scaffold ever rests on a synthesised document rather than on the decisions themselves.

It never clears a `PROVISIONAL` marker by hand, and never needs to: markers are recomputed from nothing on every run, so answering a question under `decisions.md`'s `## Decisions` and re-running clears every marker that rested on it automatically.
