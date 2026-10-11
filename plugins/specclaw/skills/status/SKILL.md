---
description: Show the project's specclaw dashboard — active changes, completed changes, pending proposals, blocked work. Reads .specclaw/STATUS.md. Read-only; does not modify state.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/status.md` and follow it instead of this file.

# specclaw status

1. `specclaw-ensure-init .specclaw`, then `specclaw-update-status .specclaw`.
2. Present `.specclaw/STATUS.md`: active changes with progress, pending proposals, recently archived. Show any hint line verbatim.
3. For one change, run `specclaw-validate-change .specclaw <change> status`.
4. If `specclaw-check-update .specclaw` prints a line, show it verbatim.
