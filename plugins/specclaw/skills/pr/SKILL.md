---
description: Use when a verified change is ready for a GitHub pull request.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/pr.md` and follow it instead of this file.

# specclaw pr (lean)

1. `specclaw-validate-change .specclaw <change> pr`. Stop if `## Verify` has no `**Verdict:**`.
2. Run `specclaw-pr .specclaw <change>`. It commits the change folder (including `shots/`), pushes, and opens the PR: title from `change.md`'s heading; body from Problem, Mock Delta, Acceptance Criteria and Verify.
3. Report the PR URL. Do not open a PR any other way.
