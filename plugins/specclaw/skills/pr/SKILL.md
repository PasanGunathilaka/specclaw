---
description: Create a GitHub pull request for a verified change. Reads verify-report.md, opens a PR with title from proposal and body from spec, enforces the configured test policy. Requires the gh CLI authenticated. Run after /specclaw:verify produces a verify-report.md. For Azure DevOps PRs, use /specclaw:pr-azdo instead.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/pr.md` and follow it instead of this file.

# specclaw pr (lean)

1. `specclaw-validate-change .specclaw <change> pr`. Stop if `## Verify` has no `**Verdict:**`.
2. Run `specclaw-pr .specclaw <change>`. It commits the change folder (including `shots/`), pushes, and opens the PR: title from `change.md`'s heading; body from Problem, Mock Delta, Acceptance Criteria and Verify.
3. Report the PR URL. Do not open a PR any other way.
