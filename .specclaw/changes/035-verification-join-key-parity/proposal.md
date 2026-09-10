# Proposal: Verification join-key parity — one definition of "this item's fixtures"

**Created:** 2026-09-10
**Status:** 🟡 Draft

## Problem

`specclaw-bf-replay:427-433` states, as a documented and supposedly tested invariant:

> `--item BL-020`'s selection must equal the backlog's own Verification fixture list for BL-020.

It does not, and has not. The two sides join on **different keys**.

`specclaw-bf-rebuild-collect:2608` ORs the scenario's own `Verifies backlog item` field into fixture matching:

```bash
[ "${GM_ITEM[$gid]}" = "$id" ] && touches=true
```

But `templates/CONTRACT.md` and `specclaw-bf-replay` both state plainly that this field is **"metadata, and a cross-check only — never a join key."** `bf-replay` ignores it for selection entirely and merely emits a `WARN` when it disagrees with the acceptance-basis join.

So a scenario can enter an item's `**Verification:**` list without that item's acceptance basis citing anything the scenario pins.

**Observed** (during `033`'s verification, on a deliberately inconsistent document): a scenario pinning `DR-001` and declaring `Verifies backlog item: BL-020` appeared in `BL-020`'s Verification list, while `BL-020`'s basis cited only `CAP-007`. The backlog reported `fixtures: GM-001, GM-002`; `bf-replay resolve BL-020` selected `GM-002`.

**Why this was invisible until now:** nothing ever computed both sides and compared them. `033`'s own `tasks.md` claimed its T9 suite covered this invariant; what actually existed was a byte-identity assertion over the two scripts' shared extractor functions — a different property entirely, since identical helper functions can still be fed different inputs or consumed differently by their callers. `033` added the first genuine end-to-end assertion (its AC-5) and it passes only because that change's fixture keeps the document self-consistent.

**Why it matters.** The Verification line is what a human reads to decide whether an item is ready to accept, and `--item` is what mechanically accepts it. When they disagree:

- an item can read `VERIFIABLE — fixtures: GM-001, GM-002` in the backlog and then be accepted on the strength of `GM-002` alone;
- a `NO BASELINE DATA` item can look verifiable, or the reverse;
- `033`'s new exit-0 path (`NO BEHAVIOUR TO VERIFY`) is computed from the acceptance basis, so an item whose Verification line was populated only via `GM_ITEM` could present a green backlog row and a gating replay run at the same time.

## Proposed Solution

Make the acceptance basis the **single** definition of "this item's fixtures", on both sides.

Remove the `GM_ITEM` clause from `specclaw-bf-rebuild-collect`'s matching so an item's fixtures are exactly those whose pinned ids intersect its declared acceptance basis — the same join `bf-replay` already performs, through the already-byte-identical `strip_non_basis_fields` / `extract_basis_ids` / `BASIS_ID_RE` trio that `033` established.

`verifies_backlog_item` keeps its documented role: metadata and a cross-check. Where it disagrees with the basis join, **report it** — the same `WARN`-and-do-not-decide treatment `bf-replay` and `bf-baseline record` already apply to this exact disagreement, rather than silently letting one side widen.

### Why this is not a trivial deletion

This changes fixture-matching semantics for **every existing project**. A scenario that declares `Verifies backlog item: BL-0##` while pinning no id that item's basis cites currently appears in that item's Verification list and would stop appearing.

That is the correct outcome per `CONTRACT.md` — such a scenario was never actually verifying that item's acceptance basis — but the visible effect on a real backlog is items moving from `VERIFIABLE` to `PENDING CAPTURE` or `NO BASELINE DATA`. That is a **truer** report, not a regression, and the change must say so loudly rather than let a team discover it as apparent breakage.

## Scope

### In Scope
- Remove the `GM_ITEM` OR-clause from `specclaw-bf-rebuild-collect`'s fixture/scenario matching.
- Route that matching through the same basis extraction `bf-replay` uses, so the two sides share one definition rather than two that happen to agree.
- A `WARN` (never a failure, never a silent widening) when `verifies_backlog_item` names an item whose basis cites nothing that scenario pins — naming both the scenario and the item, on the same terms as the existing module-consistency WARN.
- A migration note in the run summary: how many items changed Verification state as a result, so the effect is visible on the run that causes it rather than discovered later.
- Tests: the invariant asserted end-to-end on an **inconsistent** document (the case that currently diverges), both sides computed and compared; the WARN fires; no item silently changes state without being counted.
- `templates/rebuild-backlog.md` and `CONTRACT.md` updated to state that the acceptance basis is the only join key, in the field descriptions a human actually reads.

### Out of Scope
- Any change to `bf-replay`'s selection. It is already correct; this change brings the other side to it.
- The `{DR-###, CAP-###}` union itself — delivered by `033`.
- Any new scenario class — that is `034`.
- Changing what `verifies_backlog_item` is *for*. It stays metadata and a cross-check.

## Impact

- **Files affected:** ~5 — `specclaw-bf-rebuild-collect`, 2 templates, the test suite, plus a CI-registered assertion
- **Complexity:** small in diff, medium in consequence
- **Risk:** **medium-high on existing projects, low on correctness.** The code change is a deletion plus a WARN. The risk is entirely in the behaviour change landing unannounced on a real backlog, which the migration note exists to prevent.

## Open Questions

1. **Should the first run after this change refuse to proceed until a human acknowledges the diff?** Proposed default: no — report loudly, do not gate. A backlog regenerates from source documents on every run, and gating a read-only planning command on an acknowledgement is heavier than the situation warrants. Raised because the alternative is defensible if teams are relying on the current, wider lists.
2. **Should `verifies_backlog_item` disagreement become a Named Gap in the rendered backlog, not just a run-time WARN?** Proposed default: yes for the count, no for per-item prose — a run-time WARN is easy to miss, but a per-item note on every mismatched scenario would bloat a document whose Gate/Verification lines are already dense.
3. **Is there a project relying on `GM_ITEM` matching deliberately** — i.e. scenarios that intentionally declare an item without pinning its rules? Proposed default: assume not, since `CONTRACT.md` has always said the field is not a join key, but the migration count will reveal it on first run and is the reason that count is in scope.

## Notes

- Discovered during `033-capability-acceptance-basis` verification, by its AC-5 assertion. Full reproduction in `.specclaw/changes/033-capability-acceptance-basis/verify-report.md` under **Pre-existing findings**.
- Deliberately excluded from `033` and from `034`: both are additive, and this one changes matching semantics for existing projects. Folding it into either would have shipped an unreviewed behaviour change inside another change's verification.
- Related learning: `L17` — an invariant nothing computes on both sides is not tested, however confidently the comment says otherwise.

---

**To proceed:** Review this proposal and approve to begin planning.
