# Agent Hints

Accumulated patterns, best practices, and prevention rules for this repo.
Promoted from learnings and patterns — never from the plugin.

---

## [L11 from 033-capability-acceptance-basis] best_practice — A test that re-implements the logic under test verifies the duplicate,

**Promoted:** 2026-09-09 13:14 UTC
**Category:** best_practice
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
A test that re-implements the logic under test verifies the duplicate, not the code. The selection tests for this change never invoked specclaw-bf-replay at all (grep -c 'bash $REPLAY_BIN' returned 0) — a local sel() function re-implemented the production jq. 51 assertions passed while a real filter bug sat in production: strip_non_basis_fields was anchored at '^\*\*' and so matched NOTHING on a bulleted '- **Label:**' document, leaking a CAP-### from 'Maps to capability:' into the acceptance basis and selecting another item's fixtures. Rewriting the group to drive the real resolve subcommand failed on the first run and exposed it.

### Recommended Action
When a test needs the same query as production, INVOKE production. If setup cost is the reason for a local copy, that cost is the test's job — model the seed on an existing suite's fixture helper (run-replay-classification-tests.sh seed_replay) rather than reimplementing the assertion target. Add a suite-level guard: assert the suite actually executes the binary it claims to test.

---

## [L12 from 033-capability-acceptance-basis] pattern — 'Harmless by accident' is a recurring failure shape in this codebase, 

**Promoted:** 2026-09-09 13:14 UTC
**Category:** pattern
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
'Harmless by accident' is a recurring failure shape in this codebase, and it surfaced three times in one change. A filter, guard or join is written for one id family, is subtly wrong, and nobody notices because the fields it mishandles happen to carry a DIFFERENT family. (1) bf-replay filtered non-basis fields while bf-rebuild-collect filtered nothing — harmless only because Gate carries CQ-### and Verification carries GM-###, never DR-###. (2) strip_non_basis_fields matched no bulleted field at all — harmless for the same reason. (3) jq scan() with a capture group returned captures instead of matches — inert rather than wrong, so it looked correct. Adding a second id family broke all three at once.

### Recommended Action
When adding an id family, do not just widen the regex: enumerate every filter, guard and join the OLD family flowed through and ask what each one was silently getting away with. Assume any asymmetry between two readers of the same document is load-bearing until proven otherwise.

---

## [L13 from 033-capability-acceptance-basis] best_practice — Template HTML comments are live data to any parser reading the generat

**Promoted:** 2026-09-09 13:14 UTC
**Category:** best_practice
**Priority:** medium
**Source change:** 033-capability-acceptance-basis

### Insight
Template HTML comments are live data to any parser reading the generated document. functional-spec.md and scenarios.md both document their new sections BY EXAMPLE, and generated documents keep the comments — so an unstripped parser read CAP-014/CAP-015 as real ids (next_cap_id came out CAP-016 instead of CAP-013) and read the example 'NOT-REPLAYABLE:' line as a real classification, which would have handed a green exit code to an item nobody examined.

### Recommended Action
Any new reader of a templated document strips HTML comments before scanning, and the test fixture must include the REAL template comment rather than a simplified one — a fixture without it cannot catch this class of bug.

---

## [L14 from 033-capability-acceptance-basis] best_practice — A gate that can return exit 0 must fail closed on every ambiguity, and

**Promoted:** 2026-09-09 15:04 UTC
**Category:** best_practice
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
A gate that can return exit 0 must fail closed on every ambiguity, and 'is it parseable' is the wrong bar. The NOT-REPLAYABLE classification gates the only path where a zero-fixture replay run passes instead of gating, and three separate inputs armed it by ACCIDENT rather than by malice: a visible fenced example (the designer agent's own instructions illustrate the two entry forms inside a fence), a classified id that does not exist (one typo), and an id recorded as both covered-by-GM and not-replayable (a stale line left after a fixture was finally captured). None required an attacker; all three were reachable by a careless or automated author, and each turned a red gate green while the document itself contained the contradicting evidence.

### Recommended Action
For any parser whose output can produce a passing exit code: skip fenced regions and HTML comments, require the token to open its line, validate every cited id against its authoritative roster, and refuse contradictory records outright rather than picking one. Write the test for each hole as a REPRODUCTION first — all three here were confirmed reachable before being fixed.

---

## [L16 from 033-capability-acceptance-basis] pattern — Six defects in this change came from GENERATING code through a layer o

**Promoted:** 2026-09-09 18:31 UTC
**Category:** pattern
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
Six defects in this change came from GENERATING code through a layer of escaping rather than writing it directly, and every one passed bash -n: a jq capture group that silently made every join inert, an apostrophe terminating a single-quoted jq program, 'local a=$1 b=$a' under set -u, a '\*\*' awk pattern produced by a Python patch script, and explanatory # comments written INSIDE a quoted heredoc (which injected eleven lines of prose into the fixture the comment was explaining). The escaping layer -- python writing bash, bash writing awk/jq, heredocs writing markdown -- is where the defects live, not the logic.

### Recommended Action
Prefer the Edit tool over a generator script for anything containing backslashes, quotes or fence characters. When a generator is unavoidable, immediately grep the RESULT for the literal you intended rather than trusting the substitution reported success. And after any heredoc edit, cat the generated artefact once: bash -n cannot see that a comment landed inside it.

---

## [L18 from 034-baseline-nonrule-scenarios] pattern — A PROVISIONAL marker can point at a question that does not exist, and 

**Promoted:** 2026-09-10 05:16 UTC
**Category:** pattern
**Priority:** medium
**Source change:** 034-baseline-nonrule-scenarios

### Insight
A PROVISIONAL marker can point at a question that does not exist, and every downstream consumer will still report it correctly. 034's smoke test had the designer mark a scenario '⚠ PROVISIONAL — pending PQ-012', record convert that into a PROVISIONAL manifest status, and every report show a fixture blocked on a pending question -- while PQ-012 existed in no file, because the designer's Ask-Don't-Guess write targets .specclaw/analysis/pending-questions.md and that run's write scope was confined to .specclaw/baseline/. The run reported success, because the files it was scoped to write were written.

### Recommended Action
When a marker in document A is resolved against an entry in document B, something must check the pair. Report the intended entry in the agent's final response so it survives a failed write, and warn at the earliest point both documents are read together. Filed as change 036.

---

## [L19 from 034-baseline-nonrule-scenarios] best_practice — A smoke fixture must contain the CODE the behaviour under test needs, 

**Promoted:** 2026-09-10 05:16 UTC
**Category:** best_practice
**Priority:** medium
**Source change:** 034-baseline-nonrule-scenarios

### Insight
A smoke fixture must contain the CODE the behaviour under test needs, not just the DOCUMENT describing it. 034's first smoke run could not exercise the promoted-T6 class because the fixture carried a RESOLVED ordering decision (CQ-004) and no code that orders anything -- so the designer correctly declined the scenario and classified the capability NOT-REPLAYABLE. That was right behaviour on a wrong fixture, and it initially read like a gap in the feature.

### Recommended Action
When building a fixture to test whether behaviour X is derived, add the observable seam X needs and verify the fixture can distinguish success from the fail-closed path. Here that meant an explicit case-insensitive OrderBy, plus arrange values whose case-sensitive and case-insensitive orders DIFFER -- otherwise the fixture cannot tell a correct sort from a case-blind one.

---
