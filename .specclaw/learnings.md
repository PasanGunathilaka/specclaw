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

## [L11] best_practice — specclaw-detect-patterns update_pattern uses BSD-incompat...

**When:** 2026-09-18 19:30 UTC
**Category:** best_practice
**Priority:** medium
**Status:** pending

### Detail
specclaw-detect-patterns update_pattern uses BSD-incompatible sed (grouped {s///} and 'a\' with text on the same line), so on macOS the recurrence bump and the occurrence line are silently skipped with sed errors on stderr. get_all_pat_ids was fixed here because clustering could not be verified without it; update_pattern was left alone as out of scope.

### Action
Fix update_pattern's sed portability in its own change, or port it to awk as specclaw-status-row already did for the same class of defect.

---

## [L12] spec_gap — Proposal 037 step 4 (rewrite ~35 skill descriptions to tr...

**When:** 2026-09-18 19:55 UTC
**Category:** spec_gap
**Priority:** high
**Status:** pending

### Detail
Proposal 037 step 4 (rewrite ~35 skill descriptions to trigger-first form) was NOT implemented alongside the lint. The proposal itself requires a before/after trigger matrix as the evidence a rewrite helped, and producing one needs API spend that was not authorised in the implementing session. Rewriting blind would have been ~35 unmeasured behaviour changes to the routing surface, under a change whose entire purpose is to stop exactly that.

### Action
Clear description-lint-baseline.txt entries skill-by-skill, each with a before/after matrix from SPECCLAW_TRIGGER_EVALS=1 run-trigger-tests.sh. The bf-* family is the bulk of the debt and no fixture row covers it — add rows first.

---

## [L13] design_gap — Placing a dispatch-lock acquire inside a bin/ subcommand ...

**When:** 2026-09-19 20:46 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
Placing a dispatch-lock acquire inside a bin/ subcommand that is also called standalone as a read-only diagnostic (specclaw-verify collect, exercised directly by run-parser-tests.sh Case 5) turned a read-only call into a lock-acquiring one and left an orphaned lock in a real change directory.

### Action
Before anchoring a lock/mutation to a bin/ subcommand, grep tests/*.sh for standalone invocations of that subcommand against the real repo; if any exist, anchor in the SKILL.md dispatch boundary instead.

---

## [L14] agent_issue — specclaw-build finalize merged the feature branch into lo...

**When:** 2026-09-20 05:15 UTC
**Category:** agent_issue
**Priority:** high
**Status:** pending

### Detail
specclaw-build finalize merged the feature branch into local main under git.strategy: branch-per-change, contradicting CLAUDE.md ('never commit directly to main') and the build skill's own rule that build ends at 'branch pushed'. Nothing was pushed and no work was lost (all 9 commits were on the feature branch; the merge tree was identical to the feature tip), but main had to be reset to origin/main by hand before the PR could be opened.

### Action
After specclaw-build finalize, check 'git branch --show-current' and 'git rev-parse main origin/main'. If finalize merged, run: git checkout <feature>; git branch -f main origin/main. Better: treat finalize's merged:true as a signal to verify, not a success.

---

## [L15] agent_issue — A build agent's VERIFICATION footer reported 'Exit: 1' fo...

**When:** 2026-09-20 05:15 UTC
**Category:** agent_issue
**Priority:** high
**Status:** pending

### Detail
A build agent's VERIFICATION footer reported 'Exit: 1' for a correct result: its evidence command was a bare grep asserting ABSENCE, and grep exits 1 when it matches nothing. specclaw-build check-report requires Exit: 0, so a correct task reads as unverified.

### Action
When asking an agent to prove an absence, require the assertion be written so success exits 0 — e.g. 'n=$(grep -rl ... | wc -l); test "$n" -eq 0 && echo PASS' — never a bare grep.

---

## [L16] best_practice — Verification traps in this repo, both hit during this bui...

**When:** 2026-09-20 05:15 UTC
**Category:** best_practice
**Priority:** high
**Status:** pending

### Detail
Verification traps in this repo, both hit during this build: (1) the specclaw-* binaries on PATH resolve to the INSTALLED plugin cache (0.7.3), not the working tree, so a test of an edited bin/ script silently verifies the old code — invoke $BIN_DIR/specclaw-* instead; (2) specclaw-init takes the PROJECT dir, not the .specclaw dir, and silently creates .specclaw/.specclaw when given the latter.

### Action
In any test or manual verification of a bin/ change, invoke the working-tree path explicitly. Never verify a bin/ edit through PATH.

---

## [L17] pattern — The Bash tool's shell here is zsh, where [[ =~ ]] and BAS...

**When:** 2026-09-20 05:15 UTC
**Category:** pattern
**Priority:** medium
**Status:** pending

### Detail
The Bash tool's shell here is zsh, where [[ =~ ]] and BASH_REMATCH do not behave as in bash. yaml_val returned empty for every key when sourced directly in the tool's shell, which looked exactly like a broken config block.

### Action
Run any bash-semantics snippet under bash -c, or as a script. A helper that 'returns nothing' in this shell is not evidence the helper is broken.

---

## [L18] design_gap — A new bin/ script that copies a helper the repo deliberat...

**When:** 2026-09-20 05:15 UTC
**Category:** design_gap
**Priority:** medium
**Status:** pending

### Detail
A new bin/ script that copies a helper the repo deliberately duplicates (yaml_val, substitute) can silently 'tidy' the copy while its own comment claims it was copied verbatim. It happened here: substitute stayed identical, yaml_val drifted. Nothing caught it until a test suite compared them.

### Action
When a change adds a binary that copies a pinned helper, add the byte-identity assertion in the SAME change, and include a non-empty check so a typo'd function name cannot make both sides empty and pass.

---

## [L19] spec_gap — The spec cited SKILL.md line numbers for the 15 sites the...

**When:** 2026-09-20 05:15 UTC
**Category:** spec_gap
**Priority:** medium
**Status:** pending

### Detail
The spec cited SKILL.md line numbers for the 15 sites the change itself would edit — stale before they were read, and off by one at write time. It also named the lint subcommand 'lint' when its real name is 'lint-report'.

### Action
Never cite a line number the change's own edits will move; name the file and the count, and point at a generated inventory. Verify a subcommand's real name from its usage block before writing it into an acceptance criterion.

---
