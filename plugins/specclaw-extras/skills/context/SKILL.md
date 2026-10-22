---
description: Use when the user wants to view or change project-wide rules in .specclaw/context.md.
---

# specclaw context

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist.

Manage `.specclaw/context.md` — the project's living architecture document. All lifecycle skills (`plan`, `build`, `verify`) load this file automatically. It is committed to the project repo so it is shared across the team.

## Sub-commands

### show

Print the current contents of `.specclaw/context.md`.

If the file does not exist, print: `No context.md found. Run '/specclaw-extras:context add' to create one.`

### add

Add a new rule, pattern, decision, or constraint to the context document.

1. If `.specclaw/context.md` does not exist, seed it from `$CLAUDE_PLUGIN_ROOT/templates/context.md` first.
2. Ask the operator: *"What would you like to add? Describe the rule, pattern, or decision — and which section it belongs in (Architecture, Style, Patterns, Decisions, Constraints)."*
3. Read the current `context.md`.
4. Write the new entry into the correct section. Keep the entry concise (1-5 lines). Preserve all other sections unchanged.
5. Write the updated file back to `.specclaw/context.md`.
6. Show the updated section to the operator for confirmation.
7. Commit: `git add .specclaw/context.md && git commit -m "docs(context): add <brief description of what was added>"`.

### edit

Rewrite a specific section of the context document.

1. If `.specclaw/context.md` does not exist, seed it from `$CLAUDE_PLUGIN_ROOT/templates/context.md` first.
2. Ask the operator: *"Which section do you want to edit? (Architecture Overview / Coding Style / Key Patterns / Technology Decisions / Constraints / Recent Decisions)"* and *"What should the new content be?"*
3. Read the current `context.md`.
4. Replace only the specified section's content. Preserve all other sections and the document structure (headings, Last updated line).
5. Update the `_Last updated_` line to today's date.
6. Write the updated file back to `.specclaw/context.md`.
7. Show the diff (old vs new section) to the operator.
8. Commit: `git add .specclaw/context.md && git commit -m "docs(context): update <section name> section"`.

### reset

Recreate `context.md` from the template, discarding all current content.

**Warn the operator:** "This will overwrite all current context.md content. Type 'confirm' to proceed."

If confirmed:
1. Copy `$CLAUDE_PLUGIN_ROOT/templates/context.md` to `.specclaw/context.md`.
2. Commit: `git add .specclaw/context.md && git commit -m "docs(context): reset context.md to template"`.
3. Report: "context.md reset. Use '/specclaw-extras:context add' to repopulate."

## Notes

- `context.md` is committed to the project repo — changes show up in git diff and are reviewable in PRs.
- The file is auto-updated whenever a PR is merged via `/specclaw:pr` or `/specclaw-sync:pr-azdo`. Manual edits via this skill are for adding rules discovered outside the normal lifecycle.
- All coding agents spawned by `/specclaw:build` receive the contents of `context.md` in their prompt automatically.
