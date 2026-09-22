# Error Journal: 040-codex-plugin-packaging

Build errors and their resolutions.

---

## [T5] Investigation 1 — GitHub reports PR #84 as DIRTY and refuses merge

**When:** 2026-09-20 08:21 UTC
**Status:** upheld
**Failure-Sig:** pr-84-status-dashboard-conflict
**Reproduce:** `git merge-tree $(git merge-base origin/main HEAD) origin/main HEAD` → exit 0
**Evidence:** The merge tree reports changed-in-both for .specclaw/STATUS.md. Main records change 039 as verify PASS, while the PR records it as build done and adds change 040 as PR raised.
**Hypothesis 1 (upheld):** independently updated dashboard snapshots conflict because both branches modify the same status rows after their common base
**Fix:** Rebase PR #84 on current main and resolve .specclaw/STATUS.md to the current 040 dashboard state while retaining main's 039 status. (commit c8ae2bf)
**Proof:** Rebase completes, package validation passes, GitHub reports a clean merge state, and PR #84 merges.

---
