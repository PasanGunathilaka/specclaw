---
description: Implement planned tasks by executing them wave-by-wave, committing each, and logging errors and learnings. Reads tasks.md and drives the build loop. The longest-running phase of the specclaw lifecycle. Run after /specclaw:plan has produced spec.md, design.md, and tasks.md.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/build.md` and follow it instead of this file.

# specclaw build (lean)

1. `specclaw-validate-change .specclaw <change> build`, then `specclaw-build setup .specclaw <change>` (creates the branch). Commit `.specclaw/mock/index.html` and the change folder: `specclaw(<change>): mock + change`.
2. For each pending task in `change.md`, in order:
   - Mark it in progress with `specclaw-update-task-status .specclaw/changes/<change>/change.md <T> in_progress`.
   - Write the minimum code that meets its ACs, following the project's existing patterns.
   - Tests: **at most one per AC**, written only for the ACs this task delivers. No speculative tests or abstractions.
   - Run the project's test command. On failure, fix and retry up to `loop.max_iterations` times (default 2). Then mark the task `failed` and stop with the error.
   - On success: `specclaw-update-task-status … <T> complete`, then `specclaw-build commit .specclaw <change> <T> "<title>" <files…>`.
3. No review agents, no party panel, no learnings files. Do the work directly; spawn a subagent only for a large task that is independent of the others.
4. `specclaw-update-status .specclaw`. If `specclaw-gh-sync` is on PATH and `github.sync: true`, run `specclaw-gh-sync update .specclaw <change>`; skip silently otherwise. Say which screen now matches its mock section. Next step: `/specclaw:verify`.
