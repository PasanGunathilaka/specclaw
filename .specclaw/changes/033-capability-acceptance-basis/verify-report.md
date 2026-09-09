# Verify Report: 033-capability-acceptance-basis

**Change:** 033-capability-acceptance-basis
**Verified:** 2026-09-09
**Verdict:** ✅ **PASS** — with one pre-existing finding recorded for its own change

Every acceptance criterion is proven by an assertion that fails when the behaviour
is absent. That bar matters here, because the first verification pass of this
change reported all criteria met while three of them had no assertion at all and
the headline behaviour did not work. Five defects were found *after* the build
phase declared itself verified; all five are fixed, and the assertions that would
have caught each are now in the suite.

**One finding is deliberately not fixed:** a pre-existing invariant violation in
`specclaw-bf-rebuild-collect`, surfaced by the new AC-5 assertion. It predates
this change and its fix alters behaviour for every existing project. See
**Pre-existing findings**.

---

## Test evidence

**554 assertions across five suites, 0 failures.**

| Suite | Result | Baseline on pristine `main` |
|---|---|---|
| `run-capability-selection-tests.sh` (new) | **78 / 0** | n/a — added by this change |
| `run-replay-classification-tests.sh` | **204 / 0** | 204 / 0 |
| `run-bf-status-tests.sh` | **133 / 0** | 133 / 0 |
| `run-stub-registry-tests.sh` | **50 / 0** | 50 / 0 |
| `run-item-split-tests.sh` | **89 / 0** | 89 / 0 |

Eight suites exercise the four `bin/` scripts this change touches. The first
verification pass ran two of them. The remaining three that carry assertions over
`specclaw-bf-rebuild-collect` were established against a pristine `main` extracted
to a separate tree (`git archive main`) and run on both sides, because a raw
failure count on this Windows checkout is unreadable on its own — several suites
fail here for environmental reasons unrelated to any change. All three were clean
on `main` and remain clean on this branch, so this change breaks nothing in them.

**`specclaw-verify collect` reported `tests_passed: true`. That value is VACUOUS
and is not evidence.** `config.yaml` carries an empty `test_command`,
`lint_command` and `build_command`, so all three gates pass trivially with empty
output. The evidence above comes from suites executed directly.

**shellcheck:** zero findings across all five modified scripts.
`plugins/specclaw/tests/shellcheck-baseline.txt` is byte-identical to `main`.

**The full `shellcheck-gate.sh` exits 1, for pre-existing reasons.** 17 of 44
`bin/` scripts carry CRLF against `.gitattributes`' `plugins/specclaw/bin/* text
eol=lf` declaration, producing 219 × SC1017 plus SC1073/1072/1009 × 17. None of
the files this change touches appears in that output. AC-15's actual requirement
(baseline unmodified, no new findings attributable to this change) holds; the gate
should pass on Linux CI. The CRLF drift is worth its own cleanup.

---

## Acceptance criteria

| AC | Status | Evidence |
|---|---|---|
| **AC-1** — DR-less fixture selected by `--all` | ✅ MET | `run-capability-selection-tests.sh`, real `resolve --all` → `GM-001,GM-002,GM-003` |
| **AC-2** — selected by `--module` owning its capability | ✅ MET | real `resolve MOD-002` → `GM-002,GM-003`; `MOD-001` → `GM-001,GM-003` unchanged |
| **AC-3** — selected by `--item` citing the capability | ✅ MET | real `resolve BL-020` → `GM-002` |
| **AC-3b** — `Maps to capability:` does not widen selection | ✅ MET | fixture names `CAP-012` there, which `GM-003` pins; selection stays `GM-002` |
| **AC-4** — selected by `<change-name>` | ✅ MET | real `resolve po-form` → `GM-002`, equal to the `--item` result |
| **AC-5** — `--item` selection ≡ backlog `Verification:` list | ✅ MET | `bf-rebuild-collect render` → `VERIFIABLE — fixtures: GM-002`; `resolve BL-020` → `GM-002`. **Holds only on a well-formed document — see Pre-existing findings** |
| **AC-6** — schema-3 manifest still runs | ✅ MET | rule-only `MOD-001` resolves against schema 3; a capability-citing item refuses with `CAP_SCHEMA_MIN` naming the fix and the id |
| **AC-7** — no fixture flips to `SUPERSEDED` | ✅ MET | all `VERIFIABLE` after a second record over unchanged scenarios, **plus** a third assertion proving the mechanism fires on genuinely changed text |
| **AC-8** — full classification exits 0 and prints reasons | ✅ MET | asserted **at the CLI**: exit code, rendered verdict `NO BEHAVIOUR TO VERIFY`, and the reason text present in the report |
| **AC-9** — partial classification gates | ✅ MET | all-of quantifier; partial → 1 |
| **AC-10** — empty reason gates | ✅ MET | at the CLI: exit 2 |
| **AC-11** — unclassified zero-fixture item gates | ✅ MET | at the CLI: exit 2, renders `INCOMPLETE` |
| **AC-12** — `CAP-###` ids permanent | ✅ MET | `next_cap_id` = `CAP-013` from a document whose max is 12 including a tombstone; ids preserved out of document order; template-comment examples excluded |
| **AC-13** — unmapped `CAP-###` fails the record | ✅ MET | nonexistent and tombstoned pins both exit 1 naming the id and the active roster |
| **AC-14** — union regex identical in both scripts | ✅ MET | data-driven identity table, 9 functions × carriers, vacuity-guarded |
| **AC-15** — shellcheck gate | ⚠️ MET IN SUBSTANCE | baseline unmodified, zero findings in touched files; full gate fails on pre-existing CRLF (above) |
| **AC-16** — new suites registered in CI | ✅ MET | `ci.yml` grep + exec bit `100755` in the git index |

---

## Non-functional requirements

| NFR | Status | Note |
|---|---|---|
| NFR-1 bash + coreutils; jq in `bin/` only | ✅ | suite uses jq only against JSON artefacts, per the existing convention |
| NFR-2 shellcheck, baseline unmodified | ✅ | one SC2015 and one SC2016 fixed rather than baselined |
| NFR-3 CI registration | ✅ | asserted by AC-16 |
| NFR-4 derived, not stored | ✅ | `next_cap_id` = max on disk + 1 per call; no counter file |
| NFR-5 absent means empty | ✅ | schema-3 manifest with no `capabilities_pinned` resolves; absent `functional-spec.md` yields `CAP-001` |
| NFR-6 paired widening kept identical | ✅ | identity table; it caught real drift during this pass |
| NFR-7 mixed states are steady states | ✅ | no `functional-spec.md`, no capabilities, and pre-schema manifests all work |
| NFR-8 base ten on digit runs | ✅ | `$((10#$cnum))` |

---

## Defects found after the build phase declared itself verified

| Defect | Origin | Caught by |
|---|---|---|
| `NO BEHAVIOUR TO VERIFY` never produced exit 0 — `resolve` printed it, `render` set 2 unconditionally | this change | code review |
| The verdict message dropped its final reason; a single-capability basis printed none | this change | code review |
| `finalize` referenced a `cmd_render` local → `set -u` abort → **no evidence package written** | this change (while fixing the above) | pre-existing suite |
| Roster validation failed open when every capability was withdrawn | this change (while fixing WARN-4) | new AC assertion |
| `strip_non_basis_fields` matched no bulleted field, leaking a `CAP-###` into the basis | this change | new end-to-end test |
| Three fail-open holes in the exit-0 gate (fenced example, nonexistent id, dual-form entry) | this change | code review, each reproduced |

Six further defects came from *generating* code through a layer of escaping rather
than writing it directly: a jq capture group that made every join inert, an
apostrophe terminating a single-quoted jq program, `local a=$1 b=$a` under
`set -u`, a `\\*\\*` awk pattern from a Python-generated patch, and explanatory
comments written inside a quoted heredoc. **Every one passed `bash -n`.** Every one
was caught only by running something.

---

## Pre-existing findings — not fixed by this change

### The `--item` ≡ `Verification:` invariant is violated on an inconsistent document

`specclaw-bf-replay:427-433` documents as *tested* that `--item BL-020`'s selection
equals the backlog's own `**Verification:**` fixture list. It does not, and has not.

`specclaw-bf-rebuild-collect:2608` ORs the scenario's `Verifies backlog item` field
in as a join key:

```bash
[ "${GM_ITEM[$gid]}" = "$id" ] && touches=true
```

`templates/CONTRACT.md` and `specclaw-bf-replay` both state that field is
*"metadata, and a cross-check only — never a join key"*; `bf-replay` ignores it for
selection and merely WARNs on disagreement. The two sides therefore join on
different keys. Observed: a scenario pinning `DR-001` while declaring
`Verifies backlog item: BL-020` appears in `BL-020`'s Verification list even though
`BL-020`'s basis cites only `CAP-007`, so the backlog listed `GM-001, GM-002`
while replay selected `GM-002`.

**Why it was invisible:** nothing computed both sides and compared them. This
change's own `tasks.md` T9 claimed coverage for that invariant; what existed was a
byte-identity assertion over the two extractors, which cannot detect a divergence
in what each side *does* with them.

**Why it is not fixed here:** the fix is deleting that clause, which changes
fixture-matching for every existing project — a scenario that only declares
`Verifies backlog item` and pins no matching id would drop out of Verification
lists. That needs its own spec, and its own regression run against the suites
baselined above. Folding it into this change would ship an unreviewed behaviour
change inside someone else's verify pass.

**Recommendation:** propose it as its own change, citing this report.

### Environmental

- 17 of 44 `bin/` scripts carry CRLF against `.gitattributes`, making
  `shellcheck-gate.sh` unpassable locally. Independent of this change.
- `.specclaw/config.yaml` sets `github.repo: chan4lk/specclaw` — a third-party
  remote — with `github.sync: true`. `specclaw-gh-sync` would file issues there
  rather than on `origin`. Not touched by this change.

---

## Unmet task notes

- **T8 / NOTE-8** — T8 asked for per-module exclusion accounting so a module
  cannot reach 100% by excluding everything invisibly. What landed is one global
  `n_notreplayable` on the Verification counts line, correctly separated from
  `VERIFIABLE`. The per-module rollup gets nothing. Recorded rather than silently
  closed.
- **NOTE-2 / NOTE-5** — `not_replayable_reason` is now section-scoped (NOTE-2
  addressed). A shared-reason line naming two ids still classifies only the last
  (NOTE-5); fail-closed, so the other keeps gating, but the author gets no signal.

---

## `context.md` compliance

Bash + coreutils throughout; jq only in `bin/` and against JSON artefacts.
Derived-not-stored honoured (`next_cap_id`). One-writer-per-state honoured — no
new writer of `state.json`, and the classification is decided once in `resolve`
and recorded, rather than re-read by each consumer. Duplicated helpers kept
byte-identical and pinned by a test, per the documented convention; the prose
around them collapsed to a pointer after it had already drifted. Base ten forced
on digit runs read from disk. Every new test suite registered in `ci.yml`.

---

## Scope

No version bump, per the operator's standing instruction. No remote writes:
`github.sync` was toggled off locally to clear the phase gates and restored;
`specclaw-gh-sync` was never called. `034-baseline-nonrule-scenarios` remains at
proposal only, correctly blocked behind this change.
