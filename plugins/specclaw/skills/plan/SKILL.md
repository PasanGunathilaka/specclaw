---
description: Use when a proposal is approved and needs its tasks and acceptance criteria.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/plan.md` and follow it instead of this file.

# specclaw plan (lean)

1. `specclaw-validate-change .specclaw <change> plan`. Stop if it fails.
2. Read `change.md` and the mock section for this change. Read only the code the tasks will touch.
3. Under `## Tasks` in `change.md`, add the fewest tasks that deliver every AC, in order: **UI first** (the real screen matching the mock), then backend, then integration. Use the task-line format:
   - a `- [ ]` checkbox, the backticked id `T1`, an em dash, and the title naming the ACs it delivers
   - an indented `Files:` line listing paths
   - an optional `Depends:` line
4. Write no other file. Run `specclaw-set-phase .specclaw <change> tasks done`, then `specclaw-update-status .specclaw`. If `specclaw-gh-sync` is on PATH and `github.sync: true`, run `specclaw-gh-sync update .specclaw <change>`; skip silently otherwise.
5. Show the task list and the next step, `/specclaw:build`.
