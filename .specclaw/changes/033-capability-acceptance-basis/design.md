# Design: Capability acceptance basis — CAP-### ids and a union selection join

**Change:** 033-capability-acceptance-basis
**Created:** 2026-09-09

## Technical Approach

The change is a **widening**, not a new mechanism. Every id family in this system already flows through the same pipeline shape: an agent assigns permanent ids into a document, a `collect` script reads the prior roster back so ids survive the archive-then-rewrite, `record` extracts them into `manifest.json`, and `bf-replay` joins on them. `CAP-###` reuses that pipeline end to end. Nothing new is invented; one more family is threaded through it.

Three properties make this tractable:

1. **The join is already funnelled.** Each side has exactly one function that turns a document block into a list of ids — `backlog_item_dr_ids()` in `specclaw-bf-replay`, `extract_dr_ids` in `specclaw-bf-rebuild-collect`. Widening those two is what makes the union real; every jq `scan()` downstream is then widened to match the same alternation.

2. **The schema floor precedent already exists.** `MODULE_SCHEMA_MIN=3` gates only the join that reads `module_ids`, leaving `--all`/`<change>`/`--item` working against older manifests. `CAP_SCHEMA_MIN=4` copies that shape exactly, so adopting this costs a project that ignores capabilities nothing.

3. **The verdict is decidable in bash.** No agent participates in the exit-code decision. It is a grep for a fixed literal plus an all-of quantifier over the item's own basis — the same tier as the `module_ids` join, with nothing re-derived.

The sequencing constraint that governs the whole build: **the two widenings must land together.** `specclaw-bf-replay:427-433` declares a tested invariant that `--item BL-020`'s selection equals the backlog's own Verification list for `BL-020`, computed from `ITEM_RULES ∩ GM_RULES`. Widening one side alone breaks it silently — the run selects fixtures the backlog does not claim, or vice versa, with no error. Wave 2 therefore carries both scripts and the identity test as one unit.

## Architecture

Data flow for a capability, from discovery to acceptance:

```
bf-domain-analyst                 assigns CAP-014 into functional-spec.md
  │                               and CAP-014 into module-map.md's
  │                               MOD-002 "Owns (capabilities)"
  ▼
specclaw-bf-domain-collect        reads prior_capabilities[] + next_cap_id
  │                               back out (ids survive the archive)
  ▼
specclaw-bf-baseline collect      emits the capability roster + the
  │                               module→capability ownership index
  ▼
bf-baseline-designer              writes "Capabilities pinned: CAP-014",
  │                               derives Modules from CAP ownership when
  │                               the scenario pins no DR, and writes the
  │                               Capability Coverage Check
  ▼
specclaw-bf-baseline record       extracts capabilities_pinned into
  │                               manifest.json; stamps schema 4;
  │                               hard-fails an unmapped CAP-###
  ▼
specclaw-bf-rebuild-collect       extract_dr_ids returns {DR,CAP};
  │                               GM_RULES and ITEM_RULES widen together
  ▼
specclaw-bf-replay                joins the union at all four scopes;
                                  computes the classification-gated verdict
```

The union regex is the one piece of logic that must be identical in two standalone executables with no sourcing convention between them. Per the repo's documented pattern, both copies are kept byte-identical and a test pins that identity — the same treatment already applied to other deliberately-duplicated helpers.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/templates/functional-spec.md` | modify | `CAP-###`-bearing capability shape; HTML-comment contract for permanence, reconciliation and tombstones |
| `plugins/specclaw/templates/module-map.md` | modify | `**Owns (capabilities):**` field; Coverage Check accounts for `CAP-###` |
| `plugins/specclaw/templates/scenarios.md` | modify | `- **Capabilities pinned:**` field; Capability Coverage Check section; `NOT-REPLAYABLE` marker warning (load-bearing string, never reformat) |
| `plugins/specclaw/templates/CONTRACT.md` | modify | `capabilities_pinned` field; `manifest_schema` 4; the classification literal |
| `plugins/specclaw/agents/bf-domain-analyst.md` | modify | Rubric row 5 assigns/reconciles `CAP-###`; Module Grouping Rule owns capabilities; `T3` covers a contested capability |
| `plugins/specclaw/agents/bf-baseline-designer.md` | modify | Pin capabilities; derive `Modules` from CAP ownership; author the Capability Coverage Check |
| `plugins/specclaw/bin/specclaw-bf-domain-collect` | modify | `prior_capabilities[]`, `next_cap_id`, `cap_ids[]` on `prior_modules[]` |
| `plugins/specclaw/bin/specclaw-bf-baseline` | modify | `collect` reads the capability roster; `record` extracts `capabilities_pinned`, stamps schema 4, hard-fails unmapped ids; `merge-scenarios` is CAP-aware |
| `plugins/specclaw/bin/specclaw-bf-rebuild-collect` | modify | `extract_dr_ids` → union; Verification computation; `NO BASELINE DATA` message |
| `plugins/specclaw/bin/specclaw-bf-replay` | modify | Union regex constant; `backlog_item_dr_ids()`; `backlog_dr_map()`; jq `scan()` sites; `CAP_SCHEMA_MIN`; the gated verdict |
| `plugins/specclaw/skills/bf-domain/SKILL.md` | modify | Relay capability counts and any provisional capability placement |
| `plugins/specclaw/skills/bf-baseline/SKILL.md` | modify | Relay the Capability Coverage Check; state the widget/layout exclusion in "What this command does not do" |
| `plugins/specclaw/tests/run-capability-selection-tests.sh` | create | Selection at four scopes, the paired-join invariant, verdict/exit codes, id permanence, regex identity |
| `.github/workflows/ci.yml` | modify | Register the new suite (NFR-3) |

## Data Model Changes

**`manifest.json`** — one new per-fixture field, one version move:

```json
{
  "manifest_schema": 4,
  "fixtures": [
    {
      "scenario_id": "GM-031",
      "business_rules_pinned": "",
      "capabilities_pinned": "CAP-014",
      "module_ids": ["MOD-002"]
    }
  ]
}
```

`capabilities_pinned` mirrors `business_rules_pinned` exactly — a string scanned for ids, not an array — so the existing jq idiom applies unchanged and an absent field scans to empty.

**`functional-spec.md`** — capabilities gain ids and tombstones. **`module-map.md`** — one new field per module. **`scenarios.md`** — one new optional scenario field plus one new section. No file is rewritten in place; every document in this pipeline is already archive-then-replace.

**Deliberately absent:** any capability index, counter, or cache file. `next_cap_id` is the maximum on disk plus one, computed per call (NFR-4).

## API Changes

**No CLI change.** No new command, no new scope, no new flag anywhere. `specclaw-bf-replay`'s four selection scopes keep their exact invocation shape; only the set they join on widens.

**One exit-code change,** and it is the sole outward-visible behaviour change: an item resolving to zero fixtures whose every basis capability carries a `NOT-REPLAYABLE` classification with a non-empty reason now exits `0` instead of `2`. Every other zero-fixture path keeps exit `2`. This is intentional and is the point of the change; it is also the one thing that alters CI outcomes, so AC-8 through AC-11 pin all four corners of it.

## Key Decisions

**D-1 — One id family, not three.** `WF-###` and `ENT-###` are not minted. A workflow is reached through the capability that exposes it (the Composite-Flow Rule already mandates that cross-reference) and an entity round-trip through the create/edit capability that writes it. Two `GM-###` pinning one `CAP-###` already express "capability covered, sequence not covered", so the distinction survives without a third family and three id families' worth of plumbing.

**D-2 — Widen at the source function, not at each call site.** Both scripts funnel through one extractor each. Widening those two makes every downstream consumer correct by construction; widening call sites individually would leave the next-added site wrong by default.

**D-3 — Keep the two regexes byte-identical and pin it with a test.** These are standalone executables with no sourcing convention, and the repo already documents this exact pattern for deliberately-duplicated helpers. The identity test is what stops AC-5 from breaking silently six months from now.

**D-4 — Per-field schema floor rather than a hard manifest bump.** `CAP_SCHEMA_MIN=4` gates only capability joins. A project that never records a capability keeps running against schema 3 with no message and no migration.

**D-5 — The classification literal is load-bearing.** `CAP-014 — NOT-REPLAYABLE: <reason>` is grepped, exactly as `⚠ PROVISIONAL` and the `### CODE` error-map headings already are. The template says so, because a reformat silently stops the detection — the same failure mode `templates/scenarios.md` already warns about for the PROVISIONAL marker.

**D-6 — Exit 0 quantifies all-of over the item's own basis.** A partially classified basis is not partially accepted. Any-of would let one classified capability green-light an item whose other capabilities nobody examined, which is the original conflation wearing a new label.

**D-7 — No back-assignment migration for existing `functional-spec.md` documents.** `bf-domain` already archives-then-rewrites, so ids arrive on the next regeneration. A migration script would be a second writer of a document the agent owns, against the repo's one-writer-per-state pattern. Cost: a project that never re-runs `bf-domain` gets no capability accounting — reported, not silently tolerated (NFR-7).

## Risks & Mitigations

**R-1 — The paired widening drifts.** *Highest risk in the change.* Widening `extract_dr_ids` without `backlog_item_dr_ids()` (or vice versa) breaks the `--item` ≡ Verification invariant with no error — selection quietly disagrees with the backlog's own claim. **Mitigation:** both scripts and the identity test land in one wave (T4–T6 in `tasks.md`); AC-5 asserts the invariant for a capability-only item; AC-14 asserts regex identity.

**R-2 — The widened grep over-matches.** `backlog_item_dr_ids()` filters out `Gate:`, `Verification:`, `UI fidelity:` and human status-note lines before grepping, precisely because ids appear in prose there. A `CAP-###` mentioned in surviving prose — a note, a dependency sentence — would silently join the acceptance basis. **Mitigation:** T4 re-reads that filter against real backlog fixtures containing prose capability mentions before widening, and adds a test asserting a `CAP-###` in a filtered region does **not** enter the basis. If the existing filter proves insufficient, tighten it in the same task rather than accepting a wider basis.

**R-3 — An existing fixture flips to `SUPERSEDED`.** `record` derives that status from the scenario's text hash; if template edits reach existing scenario text, every captured fixture reads as needing recapture — expensive and alarming. **Mitigation:** AC-7 tests a pre-change recorded fixture set through a post-change `record`. Template edits touch the template and its HTML comments only, never generated documents.

**R-4 — The exit-code change lands in someone's green CI.** A pipeline gating on `bf-replay` sees a previously-`INCOMPLETE` item start passing. **Mitigation:** it can only happen where a human wrote a classification with a reason, which is an explicit act; no classification, partial classification or empty reason all keep exit 2. Documented in the change's own notes rather than assumed benign.

**R-5 — `manifest_schema: 4` read by an older plugin.** A project mixing versions could hand a schema-4 manifest to a plugin that only knows 3. **Mitigation:** pre-existing condition of the schema mechanism, already handled by `MANIFEST_SCHEMA_MIN`'s guard, which fails with a clear message rather than misreading. No new exposure.

**R-6 — Scope creep into `034`.** The temptation while touching `bf-baseline-designer.md` is to add a scenario class "while we're here", which would make this change generate fixtures it promised not to. **Mitigation:** the spec states the change generates no new fixtures; `034` owns the classes. A design/tasks review that finds a scenario class here should reject it.

## Grounding sources

- `.specclaw/context.md` — *"Where a helper function is deliberately duplicated between two standalone executables (no sourcing convention exists between them), the copies are kept byte-identical and a test pins that identity."* → D-3, NFR-6, AC-14.
- `.specclaw/context.md` — *"Derived, not stored. Facts already present on disk are recomputed, never cached in a counter or index file. A second copy of a fact is a thing that drifts."* → NFR-4, and the decision to compute `next_cap_id` per call.
- `.specclaw/context.md` — *"One writer per piece of state."* → D-7's rejection of a back-assignment migration script.
- `.specclaw/context.md` — *"Every test suite must be registered in `.github/workflows/ci.yml`. An unregistered suite silently never runs — this has happened twice in this repo."* → NFR-3, AC-16, and the explicit `ci.yml` row in the file map.
- `.specclaw/context.md` — *"`tests/shellcheck-gate.sh` must pass with `shellcheck-baseline.txt` unmodified."* → NFR-2, AC-15.
- `.specclaw/context.md` — *"Mixed old/new states are supported steady states, not errors. No lifecycle command may fail because a folder predates a convention."* → NFR-5, NFR-7, D-4.
- `plugins/specclaw/bin/specclaw-bf-replay:194-204` — the `MODULE_SCHEMA_MIN` comment explaining a deliberately separate, higher floor → D-4.
- `plugins/specclaw/bin/specclaw-bf-replay:427-433` — the stated `--item` ≡ backlog-Verification invariant → R-1, AC-5.
