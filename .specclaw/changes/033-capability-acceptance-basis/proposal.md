# Proposal: Capability acceptance basis — CAP-### ids and a union selection join

**Created:** 2026-09-09
**Status:** 🟡 Draft

## Problem

The brownfield pipeline derives every golden-master scenario from `domain-model.md`'s numbered `DR-###` business rules, and from nothing else. `specclaw-bf-baseline collect` hard-fails without that document (`specclaw-bf-baseline:388`), and `functional-spec.md` — the document holding capabilities, workflows and the UI inventory — is carried only as a presence flag in `SUPP_DOCS` (`specclaw-bf-baseline:196`), used by the design agent for stack detection and seam candidates, never for scenario derivation.

That is defensible for *deriving* scenarios. It is not defensible for *accounting*, and three concrete failures follow from it:

1. **Capabilities have no identity.** `templates/functional-spec.md` is four bare placeholders — `{{capabilities}}`, `{{workflows_content}}`, `{{ui_inventory}}`, `{{named_gaps}}`. No `CAP-###`, no tombstones, no reconciliation. Nothing downstream can cite a capability, because there is no id to cite. Every sibling document in the system has a permanent id family (`DR-###`, `MOD-###`, `BL-0##`, `GM-###`, `SCR-###`, `CQ-###`); this one alone does not.

2. **Nothing counts, so nothing is missing.** `scenarios.md` closes with a Rule Coverage Check over `DR-###` — every rule is either covered by a `GM-###` or explicitly excluded with a reason. There is no equivalent check over capabilities. A missing rule is loud; a missing capability is structurally invisible. The gap is therefore not a decision anyone made, and no artifact records that it was even considered.

3. **The pipeline already knows this and says so.** The Composite-Flow Rule (`bf-domain-analyst.md:82`) requires that a single form submit firing two or more backend calls be recorded as its own named workflow, and states the reason outright: *"client-side orchestration is behavior no backend rule enforces and no backend-level fixture can verify — a rebuild that reimplements each backend command correctly will still silently drop the sequence."* That finding lands in `functional-spec.md`, which has no ids and no coverage check. It is diagnosed precisely and then verified by nothing.

Downstream the gap does not surface as a gap — it surfaces as absence of data, which reads identically to absence of work:

- `specclaw-bf-rebuild-collect:2374` — `NO BASELINE DATA — baseline has been run, but no scenario in scenarios.md cites this item's rules`
- `specclaw-bf-replay:1030` — `its acceptance basis pins no DR rule at all ... nothing to compare against ... INCOMPLETE (exit 2)`

A backlog item whose behaviour is a form and a persistence write can never be mechanically accepted, and its `INCOMPLETE` is indistinguishable from an item nobody has looked at. `bf-e2e` asserts against `GM-*.json` and so inherits the same coverage; `bf-ui` covers screens but is explicitly visual fidelity by human sign-off, never fixture replay.

## Proposed Solution

Introduce **one** new permanent id family, `CAP-###`, on `functional-spec.md` capabilities, and make the acceptance basis a **union of two id families** rather than a single one. No new command, no new replay scope, no new CLI surface — the four existing selection scopes keep their exact shape and the set they join on gets wider.

The hierarchy becomes `MOD-### → BL-0## → {DR-###, CAP-###} → GM-###`.

**Why one family and not three.** Composite flows and entity round-trips do not get their own families. A workflow is reached through the capability that exposes it — the Composite-Flow Rule already requires that cross-reference — and an entity round-trip is reached through the create/edit capability that writes it. Two `GM-###` scenarios pinning one `CAP-###` express "capability covered, its composite sequence not covered" exactly as two scenarios pinning one `DR-###` already do, so nothing is lost by declining to mint `WF-###` and `ENT-###`.

### The selection chain, per scope

The requirement is that a capability- or composite-flow fixture pinning **no** `DR-###` is still selected at all four scopes. Each is satisfied as follows:

| Scope | Current join | Change required |
|---|---|---|
| `--all` | every fixture in the manifest | **None.** A DR-less fixture is already selected. Needs a regression test proving it, not a code change. |
| `--module MOD-###` | jq `index($mod)` on `module_ids` (`specclaw-bf-replay:731`) | **No replay code change.** Works once `record` can derive `module_ids` for a DR-less scenario — which requires module-map to own capabilities (below). |
| `--item BL-###` | `backlog_item_dr_ids()` (`specclaw-bf-replay:462`) greps `DR-[0-9]{3}` out of the item's acceptance-basis block | Widen that one regex to the union. Every consumer inherits it. |
| `<change-name>` | resolves the change's cited BL item, then the `--item` path | **Inherits.** No separate change. |

### The extension points

The join is already funnelled through single shared functions on both sides, which is what keeps this change small:

- **`specclaw-bf-replay`** — `backlog_item_dr_ids()` (`:462`) and its reverse `backlog_dr_map()` (`:484`) each end in one `grep -oE 'DR-[0-9]{3}'`. Widening those two, plus the ~8 jq `scan("DR-[0-9]{3}")` sites (`:723`, `:847`, `:963`, `:980`, `:1423`, `:2003`), to a single shared alternation makes the acceptance basis a union at source.
- **`specclaw-bf-rebuild-collect`** — both `GM_RULES` (`:1465`, from scenarios) and `ITEM_RULES` (`:1685`, from backlog items) call one shared `extract_dr_ids`. Widening that single function preserves the `ITEM_RULES ∩ GM_RULES` join automatically, because both sides widen together.

**This pairing is the change's central correctness constraint.** `specclaw-bf-replay:427-433` states a tested tool-internal invariant: *"`--item BL-020`'s selection must equal the backlog's own Verification fixture list for BL-020"*, computed from that same `ITEM_RULES ∩ GM_RULES` join. Widening one side without the other silently breaks it. The two must land in the same commit, with a test asserting the equality holds for a DR-less item.

### Backward compatibility

- **New manifest field `capabilities_pinned`**, parallel to `business_rules_pinned` (`specclaw-bf-baseline:1036`). Absent reads as empty, never as an error.
- **`manifest_schema` 3 → 4**, and a new `CAP_SCHEMA_MIN=4` floor following the `MODULE_SCHEMA_MIN=3` precedent verbatim (`specclaw-bf-replay:198`): a separate, higher floor than `MANIFEST_SCHEMA_MIN`, so a project that ignores capabilities pays exactly nothing and `--all`/`<change>`/`--item` runs keep working against a schema-3 manifest. Only a join that actually reads the new field requires the new floor, and it says so with the same fix instruction the existing guards use.
- **Existing fixtures must not become `SUPERSEDED`.** `record` computes that status from the scenario's own text hash. Adding a field to the *template* does not alter existing scenario text, so already-captured fixtures stay `VERIFIABLE`. This is an explicit acceptance criterion, not an assumption — it needs a test against a recorded fixture set.

### Verdict distinction

Split the current single outcome in two, so "decided not to cover" stops reading as "not covered":

- `NO BASELINE DATA` — an acceptance basis cites ids, no fixture pins any of them. Unchanged meaning, still `INCOMPLETE` (exit 2).
- `NO BEHAVIOUR TO VERIFY (CAP-### excluded: <reason>)` — the Capability Coverage Check explicitly excluded every capability behind this item, with a stated reason. An item accepted with nothing to check, not an item nobody checked.

## Scope

### In Scope
- `CAP-###` permanent id family on `functional-spec.md` capabilities — assignment, reconciliation against the prior document, tombstones, never renumbered (same discipline as `DR-###`/`MOD-###`).
- `templates/functional-spec.md` — the id-bearing capability shape and its HTML-comment contract.
- `bf-domain-analyst.md` — rubric row 5 assigns and reconciles `CAP-###`; Module Grouping Rule gains `**Owns (capabilities):**`; the Coverage Check accounts for capabilities alongside entities, rules and screens.
- `templates/module-map.md` — the owns-capabilities field.
- `specclaw-bf-domain-collect` — a `prior_capabilities[]` roster plus `next_cap_id`, and `cap_ids[]` on the `module_map.prior_modules[]` roster, for the same reason the DR/MOD rosters exist: the command archives the prior documents before the agent runs, so ids must be handed to it or they cannot survive.
- `specclaw-bf-baseline collect` — read the capability roster and module→capability ownership; `functional-spec.md` stops being a mere presence flag.
- `templates/scenarios.md` — a `- **Capabilities pinned:**` field and a **Capability Coverage Check** section.
- `bf-baseline-designer.md` — derive a scenario's `Modules` from capability ownership when it pins no `DR-###`; write the Capability Coverage Check.
- `specclaw-bf-baseline record` — extract `capabilities_pinned`; stamp `manifest_schema: 4`; the existing module-tag hard-fail and module-consistency WARN understand CAP-derived module tags.
- `specclaw-bf-baseline merge-scenarios` — a module-scoped merge handles a scenario whose module derives from CAP rather than DR.
- `specclaw-bf-rebuild-collect` — `extract_dr_ids` widened to the union; acceptance bases may cite `CAP-###`; the Verification computation and its `NO BASELINE DATA` message updated.
- `specclaw-bf-replay` — the union join at every site above; `CAP_SCHEMA_MIN`; the new verdict; the `:1030` and `:753` messages renamed off "no DR rule at all".
- Tests: DR-less fixture selected at all four scopes; the `--item` selection ≡ backlog Verification invariant holds for a DR-less item; a schema-3 manifest still runs `--all`/`<change>`/`--item`; existing fixtures do not flip to `SUPERSEDED`.

### Out of Scope
- **The new scenario classes themselves** — entity round-trip, composite flow, defaults-at-rest, promoted T6. This change builds the plumbing and the coverage ledger; a run produces exactly the fixtures it produces today, plus an explicit account of what is not covered. The classes land in `034-baseline-nonrule-scenarios`, which depends on this.
- **Widget type, layout, labels, navigation, client-side-only validation.** Not observable at any non-UI seam, and the UI seam is excluded by construction (`bf-baseline-designer.md:34`). These belong to `bf-ui` (SCR-### plus human sign-off) and `bf-e2e`. This change adds that boundary to bf-baseline's "What this command does not do" so it is deliberate rather than incidental.
- New `WF-###` or `ENT-###` id families (see rationale above).
- Any change to `bf-e2e`, which reads `GM-*.json` and inherits the wider coverage with no edit.
- Any new replay command, scope, or flag.
- Re-capture of existing fixtures.

## Impact

- **Files affected:** ~13 (estimated) — 3 templates, 2 agents, 4 bin scripts, 2 skill docs, plus tests
- **Complexity:** medium (small blast radius per file, but it crosses four commands and one tested cross-command invariant)
- **Risk:** medium — the `ITEM_RULES ∩ GM_RULES` pairing and the fixture-status regression are the two places this can go quietly wrong. Both are test-guarded above. The schema floor follows an existing, working precedent, and every new field is absent-means-empty.

## Open Questions

1. **Should a capability with no `CAP-###` in a pre-existing `functional-spec.md` be back-assigned on the next `bf-domain` run, or left unidentified until the document is regenerated?** Proposed default: back-assign on regeneration only — `bf-domain` already archives-then-rewrites, so ids arrive naturally and no migration script is needed. Flagged because a project that never re-runs `bf-domain` gets no capability accounting.
2. **Does a `CAP-###` excluded by the Capability Coverage Check still count toward a module's rollup denominator in `bf-replay`?** Proposed default: no — an explicitly excluded capability is out of the denominator, and the report states the exclusion count separately, so a module cannot reach 100% by excluding everything without that being visible.
3. **Should `bf-rebuild-plan` auto-cite `CAP-###` into an item's acceptance basis, or require a human?** Proposed default: auto-cite, matching how it already handles `DR-###`, with the Gate/Verification computation flagging any item whose basis is capability-only — that combination is exactly the CRUD-shaped item this change exists to make acceptable, and it is worth a human's eye the first time it appears.
4. **Is `NO BEHAVIOUR TO VERIFY` exit 0 or exit 2?** Proposed default: exit 0 with the reason printed. It is a stated acceptance decision, not incompleteness, and leaving it at 2 would keep CRUD items permanently un-gateable — the original problem. Called out because it is the one place this change alters an exit code, and therefore CI behaviour.

---

**To proceed:** Review this proposal and approve to begin planning.
