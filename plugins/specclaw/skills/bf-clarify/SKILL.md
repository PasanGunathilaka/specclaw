---
description: Turn extraction signals and the standard shaping-question bank into a numbered, human-answerable question set in `.specclaw/analysis/clarifications.md`. `--resolve` promotes answers into decisions.md; `--options-pack` packages blocking questions as a client decision paper. Run in the legacy repo after the analysis commands.
---

# specclaw bf-clarify

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Turn the implicit uncertainty in `.specclaw/analysis/*.md`, plus the shaping questions no amount of code extraction can surface, into one explicit, numbered decision record. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`architecture`/`domain`/`rebuild-plan` pattern.

**Three question families** share one `clarifications.md` and one `--resolve` pipeline — see `templates/clarifications.md`'s HTML comment for the authoritative field-by-field breakdown:

- **`CQ-NNN`** — extracted from `.specclaw/analysis/*.md` by the extraction agent (unchanged from before this upgrade). Allocated per-repo, in extraction order.
- **`SQ-NNN`** — the standard bank (`references/clarify-standard-questions.md`, shipped with the plugin). IDs are **fixed by the bank file itself**, not allocated per-repo — `SQ-001` means "target platform" in every project. `Type`/`Blocking`/`Options`/`Proposed default` are spliced in verbatim from the bank file by `render`, identical everywhere; only `Finding`/`Why it matters`/`Source`/`Answer` are project-specific.
- **`UQ-NNN`** — per-repo custom questions from `.specclaw/analysis/custom-questions.md`, ingested by `render` directly (no agent involved). Allocated per-repo, in file order. **`render` scaffolds this file itself**: the first time a Mode A run (default or `--bank-only`) finds nothing at `.specclaw/analysis/custom-questions.md`, it copies `templates/custom-questions.md` there verbatim, and the run summary reports the scaffold. Edit the scaffolded file and re-run to turn its questions into real `UQ-NNN`s. **The invariant that matters most: once anything exists at that path — even an empty file, even a malformed one — it is never overwritten, re-rendered, or otherwise touched again, by any later run, no matter how it got there or what it contains.** It becomes user-authored the moment it exists. **De-duplicated by each question's original heading text**, recorded in its `Source` field — editing an already-ingested heading's wording later does **not** retroactively rewrite the rendered `UQ-NNN`; it reads as a brand-new question with a new ID. Edit the rendered question in `clarifications.md` instead if you want to change it.

**Three modes**, chosen by which flag the user's invocation carries: `--resolve` selects Mode B, `--options-pack` selects Mode C, neither selects Mode A. Mode A additionally accepts `--bank-only`. **The three flags are mutually exclusive** — if an invocation carries more than one, say so and ask which was meant rather than picking one. Mode C runs no extraction, spawns no bank agent, and writes neither `clarifications.md` nor `decisions.md`: it is a read-and-package pass over what Modes A and B already wrote.

## Mode A — extract (default: no flag)

Runs both layers every time unless `--bank-only` is passed: extraction (`CQ-NNN`, unchanged) and the bank/custom layer (`SQ-NNN`/`UQ-NNN`, new).

1. **Collect:**
   ```bash
   specclaw-bf-clarify collect .specclaw [--bank-only]
   ```
   Reports which of the five known analysis documents (`codebase-report.md`, `architecture.md`, `domain-model.md`, `functional-spec.md`, `rebuild-backlog.md`) are present, and — if `clarifications.md` already exists — the next free `CQ-NNN` ID plus a de-dup hint list of existing questions' IDs/titles/sources. **If it exits non-zero (and `--bank-only` was not passed), surface its stderr message to the user verbatim and stop** — it means none of the five documents exist yet; don't retry, don't fabricate a question set from nothing. With `--bank-only`, this gate is skipped entirely — the bank/custom layer needs no analysis documents at all, which is exactly why `--bank-only` is the natural thing to run immediately after `/specclaw:bf-analyze`, before `/specclaw:bf-architecture` or `/specclaw:bf-domain` have even run: several bank answers (target platform, database engine, hosting) should become ADRs that then constrain everything the later analysers and `/specclaw:bf-rebuild-plan` produce.

   The same JSON also reports `bank_path` (resolved), `new_sq_ids` (bank ids this project has never seen — the **only** ones the bank agent evaluates; every other bank id was already rendered or marked Not applicable in a prior run and is never re-evaluated), whether `custom-questions.md`/`.specclaw/adr/`/`decisions.md` are present, and `pending_questions` (whether `.specclaw/analysis/pending-questions.md` exists, plus its `open[]` entries and `open_count`) and `next_id_after_ingestion` (the id the extraction agent must start from — `next_id` plus `open_count`, since ingestion below always claims ids first).

2. **Spawn the ingestion agent** (skip entirely if `--bank-only`, or if Step 1's `pending_questions.open_count` is `0`): `Agent` tool, `subagent_type: "bf-clarify-extractor"`, same model routing as Step 3 below. **This step must complete before Step 3 runs** — the two share the `CQ-NNN` id namespace, and ingestion's ids come first. Pass as context:
   - The collected JSON (stdout of Step 1) — specifically `pending_questions.open`, `next_id`, `existing_questions`.
   - The resolved paths of `.specclaw/analysis/decisions.md` and `.specclaw/analysis/rebuild-backlog.md`, if present.
   - **Tell the agent explicitly it is running in ingest mode**: type every OPEN pending question into `DECISION`/`DEFECT`/`SCOPE`/`TARGET-GAP`, carry its evidence/candidates/proposed-default forward verbatim, and write `PROMOTED: PQ-NNN | CQ-NNN` directives plus the promoted `### CQ-NNN` blocks to `.specclaw/analysis/.clarify-ingest-draft.md` via its own `Write` tool. It must not touch `pending-questions.md` or `clarifications.md` itself — `render` (Step 5) owns both the merge and the promotion rewrite.

3. **Spawn the extraction agent** (skip this step entirely if `--bank-only`): `Agent` tool, `subagent_type: "bf-clarify-extractor"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`) — same routing as the sibling read-only analysis agents (`bf-codebase-analyst`, `bf-architecture-analyst`, `bf-domain-analyst`, `bf-rebuild-planner`), since this is still read-only analysis of already-written documents. Pass as context:
   - The collected JSON (stdout of Step 1).
   - The resolved paths of every present analysis document, for the agent to `Read` directly.
   - **Tell the agent explicitly it is running in extract mode**: draft only new questions, numbering sequentially from the JSON's `next_id_after_ingestion` (not `next_id` — Step 2 already claimed anything between the two), and write them to a transient draft file at `.specclaw/analysis/.clarify-draft.md` via its own `Write` tool, in the exact per-question block format documented in `templates/clarifications.md`'s HTML comment (and in its own agent instructions). It must not read or attempt to edit the existing `clarifications.md` file itself — `render` (Step 5) owns merging.

4. **Spawn the bank agent** (skip only if Step 1's `new_sq_ids` is empty): same `Agent` tool, `subagent_type: "bf-clarify-extractor"`, same model routing — a separate invocation from Step 3, since its inputs differ (the bank file, ADRs, decisions.md, rather than the extraction signals). Pass as context:
   - The collected JSON (stdout of Step 1) — specifically `bank_path`, `new_sq_ids`, `adr_dir`, `decisions_md`, `docs_present`.
   - The resolved paths of every present analysis document, of every file under `.specclaw/adr/` (if present), and of `decisions.md` (if present), for the agent to `Read` directly.
   - **Tell the agent explicitly it is running in bank mode**: for every id in `new_sq_ids` only, judge applicability against that bank entry's own condition, check for a pre-existing answer (an ADR whose own `Status:` field is literally `accepted` — never a `proposed` ADR's undecided recommendation — or a matching `decisions.md` entry), contextualise the wording with this repo's facts, and write the result to `.specclaw/analysis/.clarify-bank-draft.md` via its own `Write` tool, in the exact format documented in its own agent instructions (`NOT-APPLICABLE: SQ-NNN | reason` lines for inapplicable ids; narrow `### SQ-NNN` blocks — Finding/Why it matters/Source/Answer only, never Type/Blocking/Options/Proposed default — for applicable ones).

5. **Render:**
   ```bash
   specclaw-bf-clarify render .specclaw <cq_draft_or_-> <bank_draft_or_-> <ingest_draft_or_->
   ```
   Pass `-` for whichever draft its producing step was skipped (`--bank-only` → `-` for both the CQ and ingest drafts; `new_sq_ids` empty → `-` for the bank draft; no open pending questions → `-` for the ingest draft). If nothing exists yet at `.specclaw/analysis/custom-questions.md`, scaffolds it verbatim from `templates/custom-questions.md` first (never if anything is already there, however it got there). Archives the prior `clarifications.md` (if any — same `.specclaw/analysis/archive/` directory the other analysis commands use), merges preserved blocks from every family with the new drafts (the ingest draft's promoted `CQ-NNN` blocks merge through the identical path as the extraction draft's), splices in the bank file's own `Type`/`Blocking`/`Options`/`Proposed default` for every new `SQ-NNN`, ingests any new entries from `custom-questions.md` into `UQ-NNN` blocks in-line (tolerant of missing `Type`/`Blocking`/`Options` — defaults rather than errors; this includes a freshly-scaffolded file's own example questions, ingested the same as any other content), re-sorts each family independently (blocking first, then by type in taxonomy order), recomputes the summary header (now counting `CQ`/`SQ`/`UQ` separately), writes `.specclaw/analysis/clarifications.md` in section order **Standard → Custom → Extracted → Not applicable**, applies every `PROMOTED: PQ-NNN | CQ-NNN` directive from the ingest draft as a surgical single-line Status rewrite to `pending-questions.md` (never a full rewrite of that file), and deletes whichever draft file(s) were passed. **If it exits non-zero, surface its stderr message to the user verbatim and stop.**

6. **Present a short summary:** total question count broken down by family (Extracted/Standard/Custom), count by type, count blocking, count unanswered, how many pending questions were promoted this run (and their new `CQ-NNN` ids), which standard-bank questions were pre-answered (and from which ADR/decision), which were judged not applicable (and why), whether `custom-questions.md` was scaffolded this run (relay `render`'s scaffold line verbatim so the user knows to edit it and re-run), and — if any — which of the five source documents were missing from this sweep (from Step 1's `docs_missing`).

## Mode B — resolve (`--resolve`)

1. **Collect:**
   ```bash
   specclaw-bf-clarify resolve-collect .specclaw
   ```
   Requires `clarifications.md` to already exist (fails with a message to run Mode A first, otherwise) and at least one answered question. Splits questions **from all three families** into answered/unanswered by whether `**Answer:**` is filled in. **If it exits non-zero, surface its stderr message to the user verbatim and stop.**

2. **Spawn the resolution agent:** `Agent` tool, `subagent_type: "bf-clarify-extractor"`, same model routing as Mode A. Pass as context:
   - The collected JSON (stdout of Step 1 — an ID map only, not question content).
   - The resolved path of `.specclaw/analysis/clarifications.md`, for the agent to `Read` directly.
   - **Tell the agent explicitly it is running in resolve mode**: for every ID in `answered_ids` only — whichever family it belongs to — judge whether the decision is significant enough to be promoted to an ADR in the new repo, and write one pipe-delimited line per answered ID (`id|yes-or-no|suggested_adr_title|one_line_rationale`) to a transient file at `.specclaw/analysis/.clarify-adr.txt` via its own `Write` tool. It must not re-derive or restate the decisions themselves — that part is mechanical and owned by `resolve-render`.

3. **Render:**
   ```bash
   specclaw-bf-clarify resolve-render .specclaw .specclaw/analysis/.clarify-adr.txt
   ```
   Archives the prior `decisions.md` (if any), mechanically transcribes every answered question from every family into a decision entry tagged with its origin **Family** (`Extracted` | `Standard bank` | `Custom (per-repo)`, derived from the ID prefix), splices in the agent's ADR-candidate annotations, lists unanswered questions, writes `.specclaw/analysis/decisions.md`, and deletes the transient ADR file. **If it exits non-zero, surface its stderr message to the user verbatim and stop.**

4. **Present a short summary:** how many decisions were recorded (broken down by family), which (if any) are flagged as ADR promotion candidates, and which questions remain unanswered.

5. **Remind the user** to `git add .specclaw/analysis/clarifications.md .specclaw/analysis/decisions.md` (and `.specclaw/analysis/custom-questions.md`, if present), and to consider adding `decisions.md` to `config.yaml`'s `context.pin` (raising `max_lines` accordingly) so downstream `/specclaw:propose`, `/specclaw:plan`, and `/specclaw:build` cite it as grounding — same recipe `docs/rebuild-workflow.md` documents for the other analysis outputs, since `context` discovery enumerates via `git ls-files`.

## Mode C — options pack (`--options-pack`)

Package every **undecided blocking** question — from any of the three families — as a client-readable decision paper at `.specclaw/analysis/options-pack.md`. This is the document you put in front of the person who actually gets to choose: it states each open question in their language, lays out 2–3 real options with what each one means for *this* system, and recommends one.

**It is not a decision mechanism, and it must never be described as one.** Nothing is ever recorded in the pack. A client's choice is written into `clarifications.md`'s own `**Answer:**`/`**Decided by:**`/`**Date:**` fields — attributed to the named human who made it — and Mode B then promotes it into `decisions.md`. That is the same single path a decision has always travelled. If you ever find yourself about to write an answer into `options-pack.md`, you are in the wrong file.

1. **Collect:**
   ```bash
   specclaw-bf-clarify options-pack-collect .specclaw
   ```
   Requires `clarifications.md` to exist (fails with a message to run Mode A first, otherwise). **If it exits non-zero, surface its stderr message to the user verbatim and stop.**

   This step, and only this step, decides what is decided. It reads `clarifications.md` and `decisions.md` and emits, per question in every family: `id`, `title`, `family`, `type`, `blocking`, a resolved `status` of `DECIDED`/`UNDECIDED`/`NOT-APPLICABLE`, the `status_source` file that proves that verdict, and — for a decided one — the `answer`, `decided_by` and `date`. It also emits `counts` and the three id rosters (`undecided_blocking_ids`, `decided_blocking_ids`, `not_applicable_blocking_ids`). **Never re-derive any of this yourself, and never ask the agent to** — a status the agent inferred by reading markdown is exactly the kind of quietly-wrong claim this split exists to prevent.

   **Zero undecided blocking questions is a clean, honest state, not an error.** `collect` exits 0 with an empty `undecided_blocking_ids`; skip step 2 entirely and go straight to step 3 with `-`. The pack still gets written — it just says nothing is pending, and lists what was decided and by whom. A project that has already answered everything gets a real document out of this command, not a refusal.

2. **Spawn the options agent** (skip entirely if `undecided_blocking_ids` is empty): `Agent` tool, `subagent_type: "bf-clarify-extractor"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`) — same routing as every other mode of this command, since this is still reading already-written documents. Pass as context:
   - The collected JSON (stdout of Step 1).
   - The resolved paths of every present analysis document (`docs_present`), for the agent to `Read` directly — the options it writes must be grounded in what those documents actually say about this system, with `file:line` or `doc §` citations.
   - **Tell the agent explicitly it is running in options-pack mode**: for every id in `undecided_blocking_ids` **only**, draft one client-facing block and write them all to `.specclaw/analysis/.options-pack-draft.md` via its own `Write` tool, in the format its own instructions document. It must not touch `options-pack.md`, `clarifications.md`, or `decisions.md` — `options-pack-render` owns the output file, and the other two are not this mode's to edit at all.

3. **Render:**
   ```bash
   specclaw-bf-clarify options-pack-render .specclaw <draft_or_->
   ```
   Pass `-` when Step 2 was skipped. Recomputes every status from scratch (never trusting the draft), **refuses** a draft that is missing a block for an undecided blocking id or that carries a block for anything else, archives the prior `options-pack.md` into the same `.specclaw/analysis/archive/` directory the other analysis commands use, and writes `.specclaw/analysis/options-pack.md`. Bash writes the header counts, the **Already Decided** section (transcribed answer + decider + date), the **Not Applicable** section, and every `**Client decision:** ⬜ pending` line; the agent's blocks supply only the restatement, options, trade-offs and recommendation. Deletes the draft on success. **If it exits non-zero, surface its stderr message to the user verbatim and stop.**

4. **Present a short summary:** how many blocking questions are pending, decided, and not applicable; the ids and titles of the pending ones with their recommended option; and — if nothing is pending — say so plainly rather than implying work is outstanding.

5. **Tell the user how a decision actually gets recorded**, in one or two sentences, every run: open `clarifications.md`, fill in that question's `**Answer:**`, `**Decided by:**` (**the name of the person who decided** — not "the client", not a company, and never an AI agent) and `**Date:**`, then run `/specclaw:bf-clarify --resolve`. Re-run `--options-pack` afterwards to regenerate the pack. **Remind them to `git add .specclaw/analysis/options-pack.md`** so the pack is reviewable in a PR like every other analysis output.

## Show what comes next — after any mode

Once the mode's own summary is delivered, and only then:

```bash
specclaw-bf-status .specclaw --next
```

Render its output **verbatim**, after that summary — never instead of it. Read-only, writes nothing, costs a second. It runs after **all three modes**, unchanged, because it reads the documents rather than the invocation: whichever of `clarifications.md` / `decisions.md` this run wrote is what it reports on.

Two of its lines come from this command's own state, and both are worth recognising:

- **Unanswered blocking questions are a `Next action`, not a command** — no command can answer them. It names the count and points at `--resolve` as what to run once a human has filled in the `**Answer:**` fields. That is the same path Mode C's step 5 describes, computed rather than restated.
- **A missing `decisions.md` with at least one answered question is a `Next command`: `--resolve`.** It is ranked after the baseline and the backlog deliberately — `bf-blueprint` and `bf-bootstrap` are the two commands that hard-refuse without `decisions.md`, and neither the baseline nor the backlog reads it.

**Only if this run completed.** Every mode has steps that say to surface stderr and stop — Mode A's `collect` and `render`, Mode B's `resolve-collect` and `resolve-render`, Mode C's `options-pack-collect` and `options-pack-render`. That means stop: a run that did not finish must never print a next step, which would read as though the question set had advanced when it did not.

**Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.

## What this command does not do

`/specclaw:bf-clarify` never guesses an answer on the human's behalf — every question it drafts carries a **Proposed default**, never a silent assumption, and a question with no discoverable answer stays a flagged `DATA`, `DECISION`, or `TARGET-GAP` question, never an invented fact. It does not call `/specclaw:propose` or any other lifecycle command, and once a human has filled in a question's `**Answer:**`/`**Decided by:**`/`**Date:**` fields, no later run of either mode ever edits them — only `resolve`'s mechanical transcription reads them, and only to copy them forward into `decisions.md`. It never marks a standard-bank question pre-answered from a `proposed` ADR's undecided recommendation — only an `accepted` ADR (or an existing `decisions.md` entry) counts, and a `proposed` ADR is cited as related context on the still-open question instead. It never re-evaluates a standard-bank question's applicability once rendered or marked Not applicable — that verdict doesn't flip-flop across runs. It never retroactively rewrites an already-ingested custom question if its heading is edited later in `custom-questions.md` — that file is a one-way feed into `clarifications.md`, which becomes the system of record. It scaffolds `.specclaw/analysis/custom-questions.md` from its template only the very first time Mode A finds nothing at that path — once anything exists there, by any means, it is never overwritten, re-rendered, or otherwise touched again; `--resolve` never scaffolds it at all. It never records a decision in `options-pack.md` — that file is fully regenerated on every run, has no hand-preserved zone anywhere in it, and an answer typed into it is lost on the next run without ever reaching `decisions.md`; the pack is a view of `clarifications.md`, never a second place to answer. It never puts a non-blocking question in front of a client, and never attributes a decision to "the client", to a company, or to an agent — a decision with no named human behind it cannot be followed up or revisited, and recording one that way is the gap this pack exists to close. It never ships a curated menu of stacks, vendors or frameworks: every option a client chooses between is generated at run time from this repo's own analysis, and a hardcoded product name in a bash collector or a template would be an architectural defect, not a convenience. It never types a pending question itself before promotion (that judgment belongs to the ingestion agent, not to bash) and never touches any part of `pending-questions.md` beyond the single Status line of a PQ it just promoted this run — every other entry, OPEN or already-promoted, is untouched, in place, forever.
