# Proposal: Package SpecClaw as an Installable Codex Plugin

**Created:** 2026-09-20
**Status:** 🟡 Draft

## Problem

SpecClaw does not provide an installable Codex plugin or marketplace entry, so users cannot add `chan4lk/specclaw` as a Codex plugin and install it outside a repository checkout.

## Proposed Solution

Package the existing canonical `plugins/specclaw/` implementation as a portable, installable Codex plugin. Add the required plugin manifest and a repository marketplace entry under the Codex-supported `.agents/plugins/` layout, reusing the existing skills, binaries, templates, and references without a second implementation. Document the Codex marketplace add/install flow and validate the resulting package locally.

## Scope

### In Scope

- Add a portable plugin manifest and Codex compatibility metadata to the existing SpecClaw plugin root.
- Add a Codex marketplace catalog that exposes the SpecClaw plugin from this repository.
- Reuse the existing `skills/`, `bin/`, templates, and references; do not duplicate them.
- Provide documented `codex plugin marketplace add` and installation steps.
- Add automated package and marketplace validation.

### Out of Scope

- Rewriting the Claude Code marketplace package or lifecycle implementation.
- Publishing to a public OpenAI directory or changing a user's global Codex configuration.
- Adding MCP servers, hooks, or apps that SpecClaw does not already need.

## Impact

- **Size:** architectural (spike / bounded / architectural)
- **Files affected:** 8–12 (estimated)
- **Complexity:** medium (small / medium / large)
- **Risk:** medium (low / medium / high)

## Open Questions

- Which minimum manifest fields and marketplace policy values are required by the installed Codex version for `codex plugin marketplace add chan4lk/specclaw`?

---

**To proceed:** Review this proposal and approve to begin planning.
