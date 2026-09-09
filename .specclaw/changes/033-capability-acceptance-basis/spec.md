# Spec: Capability acceptance basis — CAP-### ids and a union selection join

**Change:** 033-capability-acceptance-basis
**Created:** 2026-09-09
**Status:** 🟡 Draft

## Overview

Golden-master scenarios are derived from `domain-model.md`'s `DR-###` business rules and nothing else, so a backlog item whose behaviour is a form plus a persistence write has no fixture, cannot be mechanically accepted, and reports `INCOMPLETE` — indistinguishable from an item nobody looked at.

This change fixes the **accounting**, not the derivation. It introduces one permanent id family, `CAP-###`, on `functional-spec.md` capabilities; adds a Capability Coverage Check to `scenarios.md` so an uncovered capability becomes a stated decision instead of a structural silence; and widens the acceptance basis from `{DR-###}` to `{DR-###, CAP-###}` so a fixture pinning no rule is still selected at every replay scope.

It generates **no new fixtures**. A `bf-baseline` run after this change produces exactly the scenarios it produces today, plus a ledger of what is not covered and why. The scenario classes that fill that ledger are `034-baseline-nonrule-scenarios`, which depends on this.

The hierarchy becomes `MOD-### → BL-0## → {DR-###, CAP-###} → GM-###`.

## Requirements

### Functional Requirements

**FR-1 — `CAP-###` id family.** `functional-spec.md` capabilities carry permanent `CAP-###` ids, assigned in discovery order, reconciled against the prior document by capability content (never by position), tombstoned when a capability disappears, and never renumbered or reused. Same discipline as `DR-###` and `MOD-###`.

**FR-2 — Capability roster survives the archive.** `specclaw-bf-domain-collect collect` emits a `prior_capabilities[]` roster (`{cap_id, title, status}`) plus `next_cap_id`, and adds `cap_ids[]` to each `module_map.prior_modules[]` entry. Required because `/specclaw:bf-domain` archives the prior documents before the agent runs, so an id not handed to the agent cannot survive.

**FR-3 — Modules own capabilities.** `module-map.md` gains `**Owns (capabilities):**` per module, subject to the existing single-owner invariant, and its Coverage Check accounts for every `CAP-###` alongside entities, rules and screens. A capability two modules could own is trigger `T3` — a pending question and a provisional placement, never a silent split.

**FR-4 — `functional-spec.md` becomes a real baseline input.** `specclaw-bf-baseline collect` reads the capability roster and the module→capability ownership index, rather than reporting `functional-spec.md` as a mere presence flag in `SUPP_DOCS`.

**FR-5 — Scenarios may pin capabilities.** `scenarios.md` scenarios carry an optional `- **Capabilities pinned:** CAP-014` field, in the same style as `Business rules pinned`. A scenario may pin rules, capabilities, or both.

**FR-6 — Module tags derive from either family.** A scenario's `Modules` field is derived from the owners of every `DR-###` **and** every `CAP-###` it pins. A scenario pinning only capabilities still gets a module tag; a scenario spanning owners is tagged with all of them, per the existing cross-module rule.

**FR-7 — Capability Coverage Check.** `scenarios.md` closes with a Capability Coverage Check accounting for every `CAP-###`: covered by named `GM-###` id(s), or explicitly excluded with a recorded reason. Structurally parallel to the existing Rule Coverage Check.

**FR-8 — Machine-readable exclusions.** An exclusion entry is written in a fixed, greppable form — `CAP-014 — NOT-REPLAYABLE: <reason>` — with a non-empty reason. The verdict in FR-13 is computed in bash, so a reason only a human can parse gates nothing.

**FR-9 — Manifest carries capabilities.** `specclaw-bf-baseline record` extracts each scenario's `Capabilities pinned` into a `capabilities_pinned` manifest field parallel to `business_rules_pinned`, and stamps `manifest_schema: 4`. It hard-fails on a `CAP-###` with no matching capability in `functional-spec.md`, on the same grounds as the existing unmapped-module-tag failure.

**FR-10 — Module-scoped merge is capability-aware.** `specclaw-bf-baseline merge-scenarios` handles a scenario whose module membership derives from capability ownership, preserving every other module's blocks byte-for-byte and tombstoning per the existing rules.

**FR-11 — Backlog acceptance bases may cite capabilities.** `specclaw-bf-rebuild-collect`'s `extract_dr_ids` returns the union of both families, so `GM_RULES` and `ITEM_RULES` widen together. Item Verification states and the `NO BASELINE DATA` message account for capability citations.

**FR-12 — Replay selects DR-less fixtures at all four scopes.** `specclaw-bf-replay` joins on the union at every site: `backlog_item_dr_ids()`, `backlog_dr_map()`, and every jq `scan()` over `business_rules_pinned`. A fixture pinning only `CAP-###` is selected by `--all`, `--module MOD-###`, `--item BL-###`, and `<change-name>`.

**FR-13 — Verdict split, gated on classification.** Two outcomes replace today's single one:

- `NO BEHAVIOUR TO VERIFY (CAP-### excluded: <reason>)` — **exit 0.** Requires that **every** `CAP-###` in the item's acceptance basis carries a `NOT-REPLAYABLE` classification with a non-empty reason (all-of, not any-of), and that the item's basis resolves to zero fixtures.
- `NO BASELINE DATA` — **exit 2, `INCOMPLETE`.** Today's behaviour, and the fallback for every other zero-fixture case: no classification, partial classification, or an empty reason.

Zero fixtures found is never itself success. Absence of a fixture is the symptom both verdicts share; the classification is the only thing separating a decision from an omission, and a run that cannot tell them apart reports the gating one.

**FR-14 — Schema floor.** A new `CAP_SCHEMA_MIN=4` gates only the joins that read `capabilities_pinned`, following the `MODULE_SCHEMA_MIN=3` precedent. `--all`, `<change-name>` and `--item` keep working against a schema-3 manifest.

### Non-Functional Requirements

**NFR-1 — Bash + coreutils.** All `bin/` work stays bash + coreutils; `jq` is permitted in `bin/` only. Test suites stay jq-free.

**NFR-2 — shellcheck gate.** `tests/shellcheck-gate.sh` passes with `shellcheck-baseline.txt` **unmodified**. A new finding is fixed, or carries a targeted `# shellcheck disable=SCxxxx` with a written rationale. Never silenced by appending to the baseline.

**NFR-3 — CI registration.** Any new test suite is registered in `.github/workflows/ci.yml`. An unregistered suite silently never runs, which has happened twice in this repo.

**NFR-4 — Derived, not stored.** No counter, index, or cache of capability ids. `next_cap_id` is computed as the maximum on disk plus one on every call, exactly as `specclaw-next-change-number` does.

**NFR-5 — Absent means empty, never an error.** Every new field — `capabilities_pinned`, `Owns (capabilities)`, `Capabilities pinned`, `cap_ids[]` — reads as empty when absent. A pre-existing document or manifest never becomes invalid because of this change.

**NFR-6 — Paired widening.** The union regex is defined identically in `specclaw-bf-replay` and `specclaw-bf-rebuild-collect`, and a test pins that identity — following the repo's documented convention for a helper deliberately duplicated across standalone executables with no sourcing convention between them.

**NFR-7 — Mixed states are steady states.** A project that never re-runs `bf-domain`, has no `functional-spec.md`, or has capabilities with no ids continues to work with no capability accounting and no failure.

**NFR-8 — Quote every path; never interpolate an id into a regex** without anchoring it as a literal. Ids are read from disk and are subject to the base-ten rule (`$((10#$n))`) wherever their digits are arithmetic.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

**AC-1** — A fixture whose scenario pins only `CAP-014` and no `DR-###` is selected by `specclaw-bf-replay --all`.

**AC-2** — That same fixture is selected by `--module MOD-002` when `MOD-002` owns `CAP-014`, and the report counts it toward that module.

**AC-3** — That same fixture is selected by `--item BL-020` when `BL-020`'s acceptance basis cites `CAP-014`.

**AC-4** — That same fixture is selected by a `<change-name>` run whose change cites `BL-020`.

**AC-5 — The paired-join invariant holds for a capability-only item.** `--item BL-020`'s selected fixture set is **equal** to the fixture list on `BL-020`'s own `**Verification:**` line in `rebuild-backlog.md`, for an item whose basis cites only capabilities. This is the invariant stated at `specclaw-bf-replay:427-433`; it must be asserted by a test, not reasoned about.

**AC-6 — Schema-3 manifests still run.** Against a manifest with `manifest_schema: 3` and no `capabilities_pinned` field, `--all`, `<change-name>` and `--item` complete normally; only a join requiring the new field refuses, with the same shape of message the existing `MODULE_SCHEMA_MIN` guard emits.

**AC-7 — No fixture flips to `SUPERSEDED`.** Given a recorded fixture set captured before this change, a `record` run after it reports every previously-`VERIFIABLE` fixture as still `VERIFIABLE`. Adding a field to a template must not alter existing scenario text hashes.

**AC-8 — Exit 0 requires full classification.** An item whose basis cites `CAP-014` and `CAP-015`, resolving to zero fixtures, with `NOT-REPLAYABLE` recorded for **both** and a non-empty reason on each, exits **0** and prints `NO BEHAVIOUR TO VERIFY` naming both ids and both reasons.

**AC-9 — Partial classification gates.** The same item with `NOT-REPLAYABLE` recorded for `CAP-014` only exits **2** with `NO BASELINE DATA`, and the message names `CAP-015` as the unclassified id.

**AC-10 — Empty reason gates.** A `NOT-REPLAYABLE` entry with an empty or whitespace-only reason exits **2**, and is reported as unclassified rather than accepted.

**AC-11 — Unclassified zero-fixture item gates.** An item citing capabilities with no Capability Coverage Check entries at all exits **2** with `NO BASELINE DATA` — today's behaviour, unchanged.

**AC-12 — `CAP-###` ids are permanent.** Regenerating `functional-spec.md` over an existing one preserves every surviving capability's id, assigns `next_cap_id` only to genuinely new capabilities, and leaves a tombstone for a capability that no longer exists. A test asserts no id is renumbered across a regeneration that reorders capabilities.

**AC-13 — An unmapped `CAP-###` fails loudly.** `record` refuses to write a manifest when a scenario pins a `CAP-###` with no matching capability heading in `functional-spec.md`, naming the id and the fix — matching the existing unmapped-module-tag and unmapped-error-code behaviour.

**AC-14 — The union regex is identical in both scripts.** A test asserts the regex/constant defining the id families is byte-identical between `specclaw-bf-replay` and `specclaw-bf-rebuild-collect`, so the two sides cannot drift apart and break AC-5 silently.

**AC-15 — shellcheck gate passes** with `plugins/specclaw/tests/shellcheck-baseline.txt` unmodified (`git diff --exit-code` on that file is clean).

**AC-16 — New suites are registered.** Every test file added by this change appears in `.github/workflows/ci.yml`, asserted by grepping the workflow for each new suite's path.

## Edge Cases

- **A scenario pinning both a `DR-###` and a `CAP-###`.** Its `Modules` tag is the union of both families' owners. If those owners differ, it is a cross-module scenario and every existing cross-module rule applies unchanged — selected by both modules' runs, counted toward each, neither acceptable in isolation on its strength.
- **A capability two modules could own.** The single-owner invariant holds; this is trigger `T3`. Provisional placement under one module plus a `PQ-NNN`, never listed as owned by both — every downstream join depends on single ownership.
- **A pre-existing `functional-spec.md` with no ids.** Capabilities stay unidentified until the document is regenerated. Reported as unidentified rather than back-assigned in place; no migration script (see Notes).
- **An entity or behaviour with neither a `DR-###` nor a `CAP-###`.** Only `--all` can select its fixture. This is a real coverage hole and must be reported by the Capability Coverage Check's unassigned section, not silently tolerated.
- **A `CAP-###` tombstone still cited by a recorded fixture.** Fails loudly, like a module tag naming no module: an id kept claimed is not an id anything can verify.
- **A tombstoned capability's id reused for a new capability.** Forbidden. `next_cap_id` counts tombstones toward the next free id, exactly as withdrawn `GM-###` scenarios already do.
- **A manifest hand-edited to carry `capabilities_pinned` while still declaring `manifest_schema: 3`.** The schema floor governs, so the capability join refuses. The field's presence never implies the schema.
- **An item whose basis cites a `CAP-###` *and* resolves to some fixtures.** Not a zero-fixture case at all; runs normally and the FR-13 verdict logic never engages. Classification is irrelevant when there is something to compare.
- **A classification recorded for a capability that is not in this item's basis.** Ignored for this item's verdict. Exit 0 quantifies over the item's own basis, not over the whole document.
- **`functional-spec.md` absent entirely.** No capability accounting, no new failure — `bf-baseline` already runs without it, and every new field reads empty.

## Dependencies

- **None blocking.** Every extension point exists today: `backlog_item_dr_ids()` and `backlog_dr_map()` in `specclaw-bf-replay`, `extract_dr_ids` in `specclaw-bf-rebuild-collect`, `SUPP_DOCS` in `specclaw-bf-baseline`, and the `MODULE_SCHEMA_MIN` precedent for a per-field schema floor.
- **Blocks:** `034-baseline-nonrule-scenarios`, which adds the scenario classes that populate the ledger this change creates.
- **Test infrastructure:** `plugins/specclaw/tests/run-replay-classification-tests.sh` is the only existing replay suite (registered at `.github/workflows/ci.yml:27`). Selection is a separate concern from classification, so this change adds its own suite rather than widening that one.

## Notes

- **`Kind` in `templates/scenarios.md` is prose** — never validated against an enum, never extracted into the manifest — so `034`'s scenario classes need no contract change. Only `manifest_schema` moves here, 3 → 4.
- **`seam_layer` is untouched.** It stays the closed enum it is; `persistence` already covers constraint behaviour.
- **No version bump.** Per the operator's standing instruction, the plugin version stays at its current value despite the CLAUDE.md version-bump rule.
- **No remote writes.** `github.sync` is toggled off locally to clear the plan gate rather than publishing issues; `specclaw-gh-sync` is not called by this change's lifecycle. Note that `github.repo` is configured as `chan4lk/specclaw` — a third-party remote — which is a pre-existing config bug worth fixing independently.
- **Open question carried forward from the proposal:** whether a `NOT-REPLAYABLE` classification should require a sanctioning `CQ-###`, as a behavioural divergence already does. Deliberately not required in this version — a recorded reason is the bar, matching the Rule Coverage Check. This is the only classification in the system that can turn a gate green without a decision id, and tightening it is the obvious follow-up if review objects.
