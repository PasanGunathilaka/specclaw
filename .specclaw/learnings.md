# Learnings: claude-plugin-packaging

Build learnings, spec gaps, and patterns discovered.

**Categories:** spec_gap | design_gap | pattern | best_practice | agent_issue

---

## [L1] design_gap — specclaw-validate-change count_incomplete uses naive '^- ...

**When:** 2026-05-15 07:37 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
specclaw-validate-change count_incomplete uses naive '^- \[ \]' grep that matches code-block examples in tasks.md legend

### Action
Update count_incomplete to ignore content inside fenced code blocks, or change tasks.md template to use indented example block (4-space prefix) instead of fenced block

---

## [L2] agent_issue — specclaw-azdo-issue create exited silently with exit 1 wh...

**When:** 2026-05-15 14:51 UTC
**Category:** agent_issue
**Priority:** high
**Status:** pending

### Detail
specclaw-azdo-issue create exited silently with exit 1 when grep pipeline in existing_wi_id() returned no match — set -e + pipefail propagated through command substitution

### Action
Always append || true to grep | head | sed pipelines used inside command substitution; consider documenting this pattern in references/agent-prompts.md

---

## [L3] design_gap — specclaw-validate-change count_incomplete() matches '- [ ...

**When:** 2026-05-20 17:10 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
specclaw-validate-change count_incomplete() matches '- [ ]' inside the tasks.md template legend's 'Task format' code fence — false positive blocks verify even when all tasks are complete. Affects the default template at /templates/tasks.md.

### Action
Either (a) make count_incomplete skip lines inside code fences, or (b) change the legend example to use a non-matching marker (e.g. '* [ ]' or indented inside the fence). Best fixed in a follow-up change.

---

## [L4] design_gap — specclaw-verify-context fails on macOS with 'sed: 1: inva...

**When:** 2026-05-20 17:11 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
specclaw-verify-context fails on macOS with 'sed: 1: invalid command code f' — BSD sed incompatibility, blocks the verify pipeline on Darwin.

### Action
Audit specclaw-verify-context for sed -i / sed -E flag portability, similar to the v0.2.5 cross-platform sed fix. Follow-up change.

---

## [L5] design_gap — Spec did not specify behavior when spec.md already exists...

**When:** 2026-05-24 14:24 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
Spec did not specify behavior when spec.md already exists and /specclaw:plan is run without the flag (EC6 implied 'don't overwrite' but FR7 said 'behaves exactly as today')

### Action
Resolved in T3 by adding explicit 'if spec.md exists, skip spec step' branch in plan/SKILL.md; should be backported into spec.md FR7 wording on a future iteration

---

## [L6] agent_issue — specclaw-gh-sync create detects Issues disabled on the ta...

**When:** 2026-07-16 09:01 UTC
**Category:** agent_issue
**Priority:** medium
**Status:** pending

### Detail
specclaw-gh-sync create detects Issues disabled on the target repo and exits 0 with a skip warning, recording nothing in status.md. specclaw-validate-change plan/build gates then hard-fail (strict mode) on the missing 'GitHub Issue' line — a permanently unpassable gate while github.sync: true. Same condition treated as skip by one component, fatal by another.

### Action
validate-change should detect the issues-disabled condition, or gh-sync should record 'GitHub Issue: disabled' in status.md, so gates warn instead of block.

---

## [L7] design_gap — yaml_get in specclaw-build-context does not strip inline ...

**When:** 2026-07-16 09:22 UTC
**Category:** design_gap
**Priority:** low
**Status:** pending

### Detail
yaml_get in specclaw-build-context does not strip inline YAML comments — commit_prefix renders as '"specclaw"       # Prefix for auto-commits' inside coding-agent payload commit instructions. yaml_val in validate-change already handles this; yaml_get predates it.

### Action
Port yaml_val's comment-stripping into yaml_get (or reuse yaml_val) in a lifecycle-bug-fixes follow-up change.

---

## [L8] design_gap — specclaw-browser-lock cmd_acquire writes $$ — the PID of ...

**When:** 2026-07-25 05:37 UTC
**Category:** design_gap
**Priority:** high
**Status:** pending

### Detail
specclaw-browser-lock cmd_acquire writes $$ — the PID of the short-lived browser-lock process itself — into the slot file, so slot_live() always sees a dead PID: 'status' reports 0/N while a slot is demonstrably held, and a concurrent acquire reclaims a live slot as stale. verify.playwright.max_browsers therefore does not gate concurrency for any subprocess caller (only for a caller that sources the script). Pre-existing since v0.5.9, found while wiring T9.

### Action
Follow-up change: record the caller's PID (or a heartbeat/flock) instead of $$, and add a concurrency test that two sequential acquires cannot both win the same slot

---

## [L9] design_gap — yaml_val strips a trailing single quote unconditionally a...

**When:** 2026-07-25 05:37 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
yaml_val strips a trailing single quote unconditionally after stripping double quotes, so any config value ending in ' — e.g. test_command: "sh -c 'npm test'" — is read back truncated and dies with 'unexpected EOF while looking for matching'. Pattern is duplicated across 6+ bin scripts.

### Action
Fix the quote-stripping to be paired-only, in one shared helper; add a parser test with a nested-quote command

---

## [L10] design_gap — specclaw-verify-context never forwards e2e evidence to th...

**When:** 2026-07-25 05:37 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
specclaw-verify-context never forwards e2e evidence to the verify agent: it maps only test_output/lint_output/build_output, and references/agent-prompts.md has no {{e2e_output}} placeholder. FR9's guarantee currently depends on the agent voluntarily re-reading collect output.

### Action
Add an {{e2e_output}}/e2e_state slot to specclaw-verify-context and agent-prompts.md — neither file is in this change's file map, so either extend T12 or open a follow-up

---

## [L11] best_practice — A test that re-implements the logic under test verifies t...

**When:** 2026-09-09 13:13 UTC
**Category:** best_practice
**Priority:** high
**Status:** promoted

### Detail
A test that re-implements the logic under test verifies the duplicate, not the code. The selection tests for this change never invoked specclaw-bf-replay at all (grep -c 'bash $REPLAY_BIN' returned 0) — a local sel() function re-implemented the production jq. 51 assertions passed while a real filter bug sat in production: strip_non_basis_fields was anchored at '^\*\*' and so matched NOTHING on a bulleted '- **Label:**' document, leaking a CAP-### from 'Maps to capability:' into the acceptance basis and selecting another item's fixtures. Rewriting the group to drive the real resolve subcommand failed on the first run and exposed it.

### Action
When a test needs the same query as production, INVOKE production. If setup cost is the reason for a local copy, that cost is the test's job — model the seed on an existing suite's fixture helper (run-replay-classification-tests.sh seed_replay) rather than reimplementing the assertion target. Add a suite-level guard: assert the suite actually executes the binary it claims to test.

---

## [L12] pattern — 'Harmless by accident' is a recurring failure shape in th...

**When:** 2026-09-09 13:14 UTC
**Category:** pattern
**Priority:** high
**Status:** promoted

### Detail
'Harmless by accident' is a recurring failure shape in this codebase, and it surfaced three times in one change. A filter, guard or join is written for one id family, is subtly wrong, and nobody notices because the fields it mishandles happen to carry a DIFFERENT family. (1) bf-replay filtered non-basis fields while bf-rebuild-collect filtered nothing — harmless only because Gate carries CQ-### and Verification carries GM-###, never DR-###. (2) strip_non_basis_fields matched no bulleted field at all — harmless for the same reason. (3) jq scan() with a capture group returned captures instead of matches — inert rather than wrong, so it looked correct. Adding a second id family broke all three at once.

### Action
When adding an id family, do not just widen the regex: enumerate every filter, guard and join the OLD family flowed through and ask what each one was silently getting away with. Assume any asymmetry between two readers of the same document is load-bearing until proven otherwise.

---

## [L13] best_practice — Template HTML comments are live data to any parser readin...

**When:** 2026-09-09 13:14 UTC
**Category:** best_practice
**Priority:** medium
**Status:** promoted

### Detail
Template HTML comments are live data to any parser reading the generated document. functional-spec.md and scenarios.md both document their new sections BY EXAMPLE, and generated documents keep the comments — so an unstripped parser read CAP-014/CAP-015 as real ids (next_cap_id came out CAP-016 instead of CAP-013) and read the example 'NOT-REPLAYABLE:' line as a real classification, which would have handed a green exit code to an item nobody examined.

### Action
Any new reader of a templated document strips HTML comments before scanning, and the test fixture must include the REAL template comment rather than a simplified one — a fixture without it cannot catch this class of bug.

---

## [L14] best_practice — A gate that can return exit 0 must fail closed on every a...

**When:** 2026-09-09 15:04 UTC
**Category:** best_practice
**Priority:** high
**Status:** promoted

### Detail
A gate that can return exit 0 must fail closed on every ambiguity, and 'is it parseable' is the wrong bar. The NOT-REPLAYABLE classification gates the only path where a zero-fixture replay run passes instead of gating, and three separate inputs armed it by ACCIDENT rather than by malice: a visible fenced example (the designer agent's own instructions illustrate the two entry forms inside a fence), a classified id that does not exist (one typo), and an id recorded as both covered-by-GM and not-replayable (a stale line left after a fixture was finally captured). None required an attacker; all three were reachable by a careless or automated author, and each turned a red gate green while the document itself contained the contradicting evidence.

### Action
For any parser whose output can produce a passing exit code: skip fenced regions and HTML comments, require the token to open its line, validate every cited id against its authoritative roster, and refuse contradictory records outright rather than picking one. Write the test for each hole as a REPRODUCTION first — all three here were confirmed reachable before being fixed.

---

## [L15] design_gap — A fact that two subcommands both need is a function, neve...

**When:** 2026-09-09 15:04 UTC
**Category:** design_gap
**Priority:** high
**Status:** promoted

### Detail
A fact that two subcommands both need is a function, never a local in one of them. Fixing the exit-0 verdict, the classification was declared as a local in cmd_render, but the compute_verdict_summary call site lives in cmd_finalize -- a different subcommand. Under set -u that is an unbound-variable abort, so 'finalize' silently wrote NO evidence package at all: a worse failure than the bug being fixed, since the evidence package is the committed proof of mechanical verification. It was caught only by a pre-existing suite I had not written.

### Action
When wiring a new fact into a multi-subcommand script, grep for EVERY call site of the consumer before choosing where the value lives, and prefer a reader function over a local the moment a second subcommand needs it. Also: bash -n does not catch this -- only running each subcommand does.

---

## [L16] pattern — Six defects in this change came from GENERATING code thro...

**When:** 2026-09-09 18:30 UTC
**Category:** pattern
**Priority:** high
**Status:** promoted

### Detail
Six defects in this change came from GENERATING code through a layer of escaping rather than writing it directly, and every one passed bash -n: a jq capture group that silently made every join inert, an apostrophe terminating a single-quoted jq program, 'local a=$1 b=$a' under set -u, a '\*\*' awk pattern produced by a Python patch script, and explanatory # comments written INSIDE a quoted heredoc (which injected eleven lines of prose into the fixture the comment was explaining). The escaping layer -- python writing bash, bash writing awk/jq, heredocs writing markdown -- is where the defects live, not the logic.

### Action
Prefer the Edit tool over a generator script for anything containing backslashes, quotes or fence characters. When a generator is unavoidable, immediately grep the RESULT for the literal you intended rather than trusting the substitution reported success. And after any heredoc edit, cat the generated artefact once: bash -n cannot see that a comment landed inside it.

---

## [L17] design_gap — An invariant nothing computes on both sides is not tested...

**When:** 2026-09-09 18:30 UTC
**Category:** design_gap
**Priority:** high
**Status:** promoted

### Detail
An invariant nothing computes on both sides is not tested, however confidently it is documented. specclaw-bf-replay:427-433 states as TESTED that --item's selection equals the backlog's own Verification fixture list. It never was: specclaw-bf-rebuild-collect:2608 ORs the scenario's 'Verifies backlog item' field in as a join key while CONTRACT.md and bf-replay both state that field is metadata and never a join key, so the two sides join on different keys and can disagree. This change's own tasks.md claimed T9 covered that invariant; what existed was a byte-identity assertion over the two extractors -- a different property entirely, since identical functions can still be fed different inputs or consumed differently.

### Action
When a doc comment claims an invariant is tested, grep for the test before believing it. To test an equality between two producers, RUN BOTH and diff the outputs -- never assert that their shared helper is identical and call that the invariant.

---

## [L18] pattern — A PROVISIONAL marker can point at a question that does no...

**When:** 2026-09-10 05:16 UTC
**Category:** pattern
**Priority:** medium
**Status:** promoted

### Detail
A PROVISIONAL marker can point at a question that does not exist, and every downstream consumer will still report it correctly. 034's smoke test had the designer mark a scenario '⚠ PROVISIONAL — pending PQ-012', record convert that into a PROVISIONAL manifest status, and every report show a fixture blocked on a pending question -- while PQ-012 existed in no file, because the designer's Ask-Don't-Guess write targets .specclaw/analysis/pending-questions.md and that run's write scope was confined to .specclaw/baseline/. The run reported success, because the files it was scoped to write were written.

### Action
When a marker in document A is resolved against an entry in document B, something must check the pair. Report the intended entry in the agent's final response so it survives a failed write, and warn at the earliest point both documents are read together. Filed as change 036.

---

## [L19] best_practice — A smoke fixture must contain the CODE the behaviour under...

**When:** 2026-09-10 05:16 UTC
**Category:** best_practice
**Priority:** medium
**Status:** promoted

### Detail
A smoke fixture must contain the CODE the behaviour under test needs, not just the DOCUMENT describing it. 034's first smoke run could not exercise the promoted-T6 class because the fixture carried a RESOLVED ordering decision (CQ-004) and no code that orders anything -- so the designer correctly declined the scenario and classified the capability NOT-REPLAYABLE. That was right behaviour on a wrong fixture, and it initially read like a gap in the feature.

### Action
When building a fixture to test whether behaviour X is derived, add the observable seam X needs and verify the fixture can distinguish success from the fail-closed path. Here that meant an explicit case-insensitive OrderBy, plus arrange values whose case-sensitive and case-insensitive orders DIFFER -- otherwise the fixture cannot tell a correct sort from a case-blind one.

---
