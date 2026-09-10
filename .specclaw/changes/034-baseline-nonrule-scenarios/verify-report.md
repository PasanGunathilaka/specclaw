# Verify Report: 034-baseline-nonrule-scenarios

**Change:** 034-baseline-nonrule-scenarios
**Verified:** 2026-09-10
**Verdict:** ✅ **PASS** — regression proof and end-to-end smoke test both clean

---

## Test evidence

**591 assertions across six suites, 0 failures.**

| Suite | Result | Baseline |
|---|---|---|
| `run-nonrule-scenario-tests.sh` (new) | **37 / 0** | n/a — added here |
| `run-capability-selection-tests.sh` | **78 / 0** | 78 / 0 (`033`) |
| `run-replay-classification-tests.sh` | **204 / 0** | 204 / 0 |
| `run-bf-status-tests.sh` | **133 / 0** | 133 / 0 on pristine `main` |
| `run-stub-registry-tests.sh` | **50 / 0** | 50 / 0 on pristine `main` |
| `run-item-split-tests.sh` | **89 / 0** | 89 / 0 on pristine `main` |

shellcheck: zero findings in the touched file. `shellcheck-baseline.txt` byte-identical to `main`. The full `shellcheck-gate.sh` still exits 1 on the pre-existing CRLF drift documented in `033`'s report — unrelated, and no file this change touches appears in it.

**`specclaw-verify collect`'s `tests_passed: true` remains VACUOUS** — `config.yaml` carries empty test/lint/build commands, so all three gates pass on empty output. The counts above come from running the suites directly.

---

## Acceptance criteria

**Instruction criteria (AC-1..AC-7, AC-12)** — doc-lint, all green in the new suite. Each pins the *specific bounding words* whose removal is the regression, and two are negative assertions (no class may be phrased per-form or per-field).

**Mechanical criteria (AC-8..AC-11b)** — all green: a round-trip-shaped scenario records cleanly, reaches the manifest, keeps `manifest_schema: 4`, adds no field, does not flip to `SUPERSEDED` (with the companion assertion proving that mechanism fires), and the NFR-3 tripwire confirms **zero `bin/` scripts modified**.

**A planning error was corrected mid-build rather than papered over.** The spec's first draft stated AC-1..AC-7 as "`bf-baseline` derives exactly one round-trip per entity". Scenario derivation is done by the `bf-baseline-designer` **agent**, not by bash, so that is not assertable by a deterministic suite. Writing a test that builds a `scenarios.md` by hand and then asserted things about it would have been the same self-verification `033` was burned by. The criteria were split into instruction (doc-lint, labelled as the weaker guarantee) and mechanical (execution), and the smoke test below covers what the lint cannot.

---

## End-to-end smoke test

A representative brownfield fixture, built so the anti-explosion rules are **measurable**: **2 entities × 6 fields × 2 forms** (naive expansion: 24 scenarios), one named composite workflow with a hardcoded business-significant parameter, defaultable fields on both entities, one resolved T6 (`CQ-004`, promoted from `PQ-011`), and one `DR-001` rule.

The real `bf-baseline-designer` charter was run against it — not a simulation — because that is the only way to confirm the classes are actually derived.

### The four classes are produced

| Class | Derived | Bound | ✓ |
|---|---|---|---|
| Entity round-trip | `GM-004` (Invoice), `GM-005` (Product) | 1 per entity | ✅ |
| Named composite workflow | `GM-008` — asserts the two-call sequence's end state | 1 per workflow | ✅ |
| Persisted defaults | `GM-006` (Invoice), `GM-007` (Product) | 1 per entity-with-defaults | ✅ |
| Resolved T6 | `GM-009` — Number ascending, case-insensitive | 1 per answered question | ✅ |

Alongside them, unchanged: `GM-001`/`GM-002` (rule-derived from `DR-001`) and `GM-003` (the pre-existing coexisting-mechanisms class).

### Anti-explosion respected

| Check | Result |
|---|---|
| Round-trip scenarios | **2** — one per entity, not 12 (per field) or 4 (per form) |
| Defaults scenarios | **2** — one per entity-with-defaults |
| Composite-flow scenarios | **1** — one per named workflow |
| Resolved-T6 scenarios | **1** — one per answered question |
| Scenarios naming a **form** | **0** |
| Scenarios for a **single field** | **0** |
| Bounded-class total | **6** = `2E + C + T` = 2(2) + 1 + 1. Naive expansion was 24. |

The designer also declined per-field and per-form round-trips *explicitly*, citing one whole-shape assertion catching the same divergence "at a sixth of the capture cost" — so the reasoning transferred, not merely the count.

**Fail-closed behaviour observed on the first pass.** Before the fixture had any query code, the designer *declined* the T6 scenario and classified `CAP-003` `NOT-REPLAYABLE` with a code-backed reason, because no non-UI seam could observe list ordering. That was correct — the fixture had a resolved ordering decision and no code that orders. Adding `InvoiceQuery.ListAll` with an explicit case-insensitive `OrderBy` made the class fire, and `CAP-003` moved to `covered by GM-009`.

### `033`'s hardened reader validated on real agent output

The generated `scenarios.md` contains **5** `NOT-REPLAYABLE` mentions — the template comment's `CAP-015` example, three prose references, and a narrative line literally beginning `CAP-003 was classified NOT-REPLAYABLE on the first pass…`. `classified_not_replayable_caps` returns **empty**, and `covered_caps` correctly returns all three capabilities. Both guards earned their place: comment-stripping, and requiring the token to follow the id directly rather than merely appear on the line. This is `033`'s fail-closed design holding on input nobody constructed for it.

### Fixture flow through every consumer

`--record` → 9/9 captured, `manifest_schema: 4`, **8 VERIFIABLE + 1 PROVISIONAL** (`GM-003`, correctly — it carries an unanswered `PQ-012` marker). **6 of the 9 fixtures pin no `DR-###` at all** — precisely the `034` classes — and each carries a module tag derived from capability ownership.

`bf-rebuild-plan` → the headline result:

| Item | Basis | Computed Verification |
|---|---|---|
| `BL-001` | `DR-001`, `CAP-001` | `VERIFIABLE — GM-001, GM-002, GM-003, GM-004, GM-006` |
| `BL-002` | **`CAP-002` only** | `VERIFIABLE — GM-005, GM-007, GM-008` |
| `BL-003` | **`CAP-003` only** | `VERIFIABLE — GM-009` |

`BL-002` and `BL-003` are **capability-only items reading VERIFIABLE**. Before `033` they would have reported `NO BASELINE DATA` permanently; before `034` they would have had nothing to be verifiable *by*.

`bf-replay`, all four scopes:

| Scope | Selection |
|---|---|
| `--item BL-002` | `GM-005, GM-007, GM-008` |
| `--item BL-003` | `GM-009` |
| `--item BL-001` | `GM-001, GM-002, GM-003, GM-004, GM-006` |
| `<change-name>` (`product-catalogue`) | `GM-005, GM-007, GM-008` — equal to its `--item` result |
| `--module MOD-002` | `GM-005, GM-007, GM-008` — a module owning **no rules at all** |
| `--module MOD-001` | `GM-001..GM-004, GM-006, GM-009` |
| `--all` | all 9 |

**`MOD-002` owns zero `DR-###` rules.** Selecting its fixtures at module scope was impossible before `033` and would have selected nothing before `034`.

### The AC-5 invariant, on a real document

Both sides computed independently and compared, per item:

| Item | Backlog `Verification:` | `--item` selection | Verdict |
|---|---|---|---|
| `BL-001` | `GM-001,GM-002,GM-003,GM-004,GM-006` | same | **MATCH** |
| `BL-002` | `GM-005,GM-007,GM-008` | same | **MATCH** |
| `BL-003` | `GM-009` | same | **MATCH** |

Holds on all three, including both capability-only items — on a document a real agent wrote rather than a fixture built to pass.

---

## Findings recorded, not fixed here

- **`035-verification-join-key-parity`** — the pre-existing invariant violation from `033`'s verification (`bf-rebuild-collect` ORs `Verifies backlog item` in as a join key, which `CONTRACT.md` says is never one). Proposed separately and **untouched by this change**; it can alter fixture matching for existing projects. Not started, awaiting approval.
- **`PQ-012`** — the smoke run designed a real T3 finding it could not write (its charter's Ask-Don't-Guess step was outside the write scope I gave it): two mechanisms independently make an invoice POSTED — `InvoiceService.Post`, which enforces `DR-001`, and `CAP-001`'s Status select writing through `Create`, which enforces nothing. A rebuild consolidating that rule would *reject* input the legacy app accepts. `GM-003` carries the `⚠ PROVISIONAL — pending PQ-012` marker and `record` marked its fixture `PROVISIONAL` correctly, so the mechanism worked; the question itself still needs writing.
- **`CB-6`** — an unanswered T6 the smoke run raised and correctly declined to pin: `OrderBy` is a stable sort, so ties keep input order, but `CQ-004` decides only the key and its case-insensitivity. A rebuild ordering in SQL without a tiebreaker would diverge intermittently. Per the class, an unanswered question yields no scenario.
- **T8 / NOTE-8** from `033` — per-module exclusion accounting is still one global counter.
- **CRLF drift** — 17 of 44 `bin/` scripts, making `shellcheck-gate.sh` unpassable locally. Independent of both changes.

---

## `context.md` compliance

No `bin/` changes (NFR-3, asserted). No new template section; `{{capability_coverage}}` untouched. No schema move. New suite registered in `ci.yml` with the exec bit set via `git update-index`. shellcheck findings fixed rather than baselined. No version bump, per the operator's standing instruction. No remote writes: `github.sync` toggled off locally to clear the phase gates and restored.
