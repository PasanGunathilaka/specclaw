---
description: Move a completed change to .specclaw/changes/archive/ under its existing name. Closes the GitHub Issue (if sync is enabled) and optionally creates a git tag. Use after a change is merged — the PR is complete and the change should leave the active list.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/archive.md` and follow it instead of this file.

# specclaw archive

1. `specclaw-validate-change .specclaw <change> archive`. Stop if it fails; the PR should be merged.
2. `specclaw-set-phase .specclaw <change> archived done`, **before** the move.
3. `git mv` the folder to `.specclaw/changes/archive/<change>/`, keeping the name unchanged.
4. `specclaw-update-status .specclaw`. If `specclaw-gh-sync` is on PATH and `github.sync: true`, run `specclaw-gh-sync close .specclaw <change>`; skip silently otherwise.
