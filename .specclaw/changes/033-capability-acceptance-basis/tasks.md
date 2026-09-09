# Tasks: Capability acceptance basis — CAP-### ids and a union selection join

**Change:** 033-capability-acceptance-basis
**Created:** 2026-09-09
**Total Tasks:** 11

## Summary

Five waves. Wave 1 establishes the document contracts (ids, fields, the load-bearing classification literal) that everything else reads. Wave 2 threads the capability roster through the two `collect` scripts so ids survive the archive-then-rewrite. Wave 3 is the change's critical section — the paired widening of both id extractors, preceded by an audit of the filter it depends on. Wave 4 adds the schema floor and the classification-gated verdict. Wave 5 tests, registers, and relays.

The ordering constraint that matters: **T6 must widen both scripts in one commit.** `specclaw-bf-replay:427-433` declares a tested invariant that `--item`'s selection equals the backlog's own Verification list, computed from `ITEM_RULES ∩ GM_RULES`. Widening one side alone breaks it with no error. T5 exists because that widening rests on a line filter whose adequacy has not been verified against capability ids appearing in prose (design R-2).

## Tasks

### Wave 1 — Document contracts

- [x] `T1` — Add the `CAP-###` contract to the four templates
  - Files: `plugins/specclaw/templates/functional-spec.md`, `plugins/specclaw/templates/module-map.md`, `plugins/specclaw/templates/scenarios.md`, `plugins/specclaw/templates/CONTRACT.md`
  - Estimate: medium
  - Kind: docs
  - Notes: One coherent contract edit, so one task. `functional-spec.md` gains the id-bearing capability shape plus permanence/reconciliation/tombstone rules in its HTML comment; `module-map.md` gains `**Owns (capabilities):**` and its Coverage Check accounts for `CAP-###`; `scenarios.md` gains `- **Capabilities pinned:**`, the Capability Coverage Check section, and the `CAP-014 — NOT-REPLAYABLE: <reason>` literal **with an explicit never-reformat warning** in the same style the existing `⚠ PROVISIONAL` marker carries (design D-5); `CONTRACT.md` documents `capabilities_pinned` and `manifest_schema` 4. Edit templates and their comments only — never a generated document, or existing fixtures flip to `SUPERSEDED` (design R-3).

- [x] `T2` — Teach both agents to assign and pin capabilities
  - Files: `plugins/specclaw/agents/bf-domain-analyst.md`, `plugins/specclaw/agents/bf-baseline-designer.md`
  - Estimate: medium
  - Kind: docs
  - Depends: T1
  - Notes: `bf-domain-analyst` — rubric row 5 assigns and reconciles `CAP-###` by capability content not position, carries tombstones, and takes `next_cap_id` only for genuinely new capabilities; Module Grouping Rule gains capability ownership under the existing single-owner invariant; `T3` explicitly covers a contested capability. `bf-baseline-designer` — pin capabilities on a scenario, derive `Modules` from capability ownership when the scenario pins no `DR-###`, and author the Capability Coverage Check. **Add no scenario class here** — that is `034`, and adding one would make this change generate fixtures it promised not to (design R-6).

### Wave 2 — Roster plumbing

- [x] `T3` — Emit the capability roster from `bf-domain-collect`
  - Files: `plugins/specclaw/bin/specclaw-bf-domain-collect`
  - Estimate: medium
  - Kind: impl
  - Depends: T1
  - Notes: Add `prior_capabilities[]` (`{cap_id, title, status}`), `next_cap_id`, and `cap_ids[]` on each `module_map.prior_modules[]` entry. Required because `/specclaw:bf-domain` archives the prior documents before the agent runs — an id not handed to the agent cannot survive (FR-2). Compute `next_cap_id` as the maximum on disk plus one, per call; **no counter or index file** (NFR-4). Tombstones count toward the next free id. Force base ten on the digit run (`$((10#$n))`).

- [x] `T4` — Read capabilities in `bf-baseline` collect / record / merge
  - Files: `plugins/specclaw/bin/specclaw-bf-baseline`
  - Estimate: large
  - Kind: impl
  - Depends: T1, T3
  - Notes: `collect` — read the capability roster and module→capability ownership; `functional-spec.md` stops being a bare `SUPP_DOCS` presence flag. `record` — extract `Capabilities pinned` into `capabilities_pinned` as a scanned string mirroring `business_rules_pinned` (not an array), stamp `manifest_schema: 4`, and hard-fail an unmapped `CAP-###` naming the id and the fix, matching the existing unmapped-module-tag behaviour (AC-13). `merge-scenarios` — handle a scenario whose module membership derives from capability ownership, preserving other modules' blocks byte-for-byte. Every new field reads empty when absent (NFR-5).

### Wave 3 — The paired widening (critical section)

- [x] `T5` — Audit the acceptance-basis line filter before widening it
  - Files: `plugins/specclaw/bin/specclaw-bf-replay`, `plugins/specclaw/tests/run-capability-selection-tests.sh`
  - Estimate: medium
  - Kind: test
  - Depends: T4
  - Notes: Design R-2. `backlog_item_dr_ids()` strips `Gate:`, `Verification:`, `UI fidelity:` and human status-note lines before grepping, precisely because ids appear in prose there. Widening the grep to `CAP-###` means any capability id in *surviving* prose silently joins the acceptance basis. Read that filter against real backlog fixtures containing prose capability mentions, add a test asserting a `CAP-###` in a filtered region does **not** enter the basis, and **if the filter proves insufficient, tighten it in this task** rather than accepting a wider basis. Do not widen anything yet.

- [x] `T6` — Widen both id extractors, identically, in one commit
  - Files: `plugins/specclaw/bin/specclaw-bf-replay`, `plugins/specclaw/bin/specclaw-bf-rebuild-collect`
  - Estimate: large
  - Kind: impl
  - Depends: T5
  - Notes: **Both scripts in one commit — this is the change's critical section.** Define the union alternation once as a constant, **byte-identical in both files**, per the repo's documented convention for a helper duplicated across standalone executables with no sourcing convention (design D-3). `specclaw-bf-replay`: `backlog_item_dr_ids()` (`:462`), `backlog_dr_map()` (`:484`), and every jq `scan("DR-[0-9]{3}")` site (`:723`, `:847`, `:963`, `:980`, `:1423`, `:2003`). `specclaw-bf-rebuild-collect`: `extract_dr_ids`, which feeds both `GM_RULES` (`:1465`) and `ITEM_RULES` (`:1685`) — widening it widens both sides together, which is what preserves the `--item` ≡ Verification invariant. Widen at the source function, never at individual call sites (design D-2).

### Wave 4 — Schema floor and verdict

- [x] `T7` — Add `CAP_SCHEMA_MIN` and the classification-gated verdict
  - Files: `plugins/specclaw/bin/specclaw-bf-replay`
  - Estimate: large
  - Kind: impl
  - Depends: T6
  - Notes: `CAP_SCHEMA_MIN=4` as a separate, higher floor than `MANIFEST_SCHEMA_MIN`, gating only joins that read `capabilities_pinned`, with the same message shape as the `MODULE_SCHEMA_MIN` guard (`:194-204`) — `--all`/`<change>`/`--item` keep working against schema 3 (AC-6). Then the verdict: `NO BEHAVIOUR TO VERIFY` exits **0** only when the item resolves to zero fixtures **and every** `CAP-###` in its own basis carries a `NOT-REPLAYABLE` classification with a non-empty reason — **all-of, not any-of** (design D-6). Unclassified, partially classified, and empty/whitespace reasons all keep `NO BASELINE DATA` / exit 2. Zero fixtures is never itself success. Update the `:1030` and `:753` messages off "no DR rule at all". Reason strings are matched by literal grep — quote every path, never interpolate an id into a regex unanchored.

- [x] `T8` — Account for capability citations in rebuild Verification
  - Files: `plugins/specclaw/bin/specclaw-bf-rebuild-collect`
  - Estimate: medium
  - Kind: impl
  - Depends: T6
  - Notes: The Verification computation and the `NO BASELINE DATA` message (`:2374`, `:2377`) reflect that an acceptance basis may cite capabilities. An item whose basis is capability-only and whose capabilities are all classified should not read as unverifiable. Keep the per-module coverage rollup consistent with proposal open question 2: an explicitly excluded capability leaves the denominator, and the exclusion count is reported separately so a module cannot reach 100% by excluding everything invisibly.

### Wave 5 — Tests, registration, relay

- [ ] `T9` — Write the capability-selection test suite
  - Files: `plugins/specclaw/tests/run-capability-selection-tests.sh`
  - Estimate: large
  - Kind: test
  - Depends: T7, T8
  - Notes: Covers AC-1 through AC-14. Selection of a DR-less fixture at all four scopes; the paired-join invariant for a capability-only item (AC-5); schema-3 compatibility (AC-6); no `SUPERSEDED` flip against a pre-change recorded fixture set (AC-7); all four verdict corners — full classification exits 0, partial exits 2, empty reason exits 2, unclassified exits 2 (AC-8–AC-11); `CAP-###` permanence across a regeneration that reorders capabilities (AC-12); unmapped `CAP-###` refusal (AC-13); and the regex identity between the two scripts (AC-14). **Suite stays jq-free** (NFR-1). Selection is a separate concern from classification, so this is its own suite rather than a widening of `run-replay-classification-tests.sh`.

- [ ] `T10` — Register the suite and clear the shellcheck gate
  - Files: `.github/workflows/ci.yml`, `plugins/specclaw/tests/run-capability-selection-tests.sh`
  - Estimate: small
  - Kind: config
  - Depends: T9
  - Notes: Kept a separate task deliberately: an unregistered suite silently never runs, and per `.specclaw/context.md` *"this has happened twice in this repo."* Assert registration by grepping `ci.yml` for the suite path (AC-16). Then `tests/shellcheck-gate.sh` must pass with `shellcheck-baseline.txt` **unmodified** — fix any new finding, or add a targeted `# shellcheck disable=SCxxxx` with a written rationale. Never append to the baseline (NFR-2, AC-15).

- [ ] `T11` — Relay capabilities in the two skill docs
  - Files: `plugins/specclaw/skills/bf-domain/SKILL.md`, `plugins/specclaw/skills/bf-baseline/SKILL.md`
  - Estimate: small
  - Kind: docs
  - Depends: T7
  - Notes: `bf-domain` — report capability counts and name any capability placed provisionally with its `PQ-NNN`, alongside the existing module relay. `bf-baseline` — relay the Capability Coverage Check in the Mode A summary (covered vs excluded counts, naming excluded ids), and state the widget/layout/navigation exclusion in **"What this command does not do"** so that boundary is deliberate rather than incidental. Depends on T7 because the verdict's final message wording is what these docs relay.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:**
```
- [ ] `T<n>` — <title>
  - Files: <files to create/modify>
  - Estimate: small | medium | large
  - Kind: docs | test | config | refactor | impl | migration   (optional; hints the build subagent's role, tools, and model)
  - Depends: <task ids> (if any)
  - Notes: <additional context>
```

The optional `Kind` hint is consumed by `build.dynamic_agents` (when enabled) to
synthesize a specialized subagent per task. Omit it and build classifies
heuristically, defaulting to `impl`.
