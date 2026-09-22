# Design: Package SpecClaw as an Installable Codex Plugin

**Change:** 040-codex-plugin-packaging
**Created:** 2026-09-20

## Technical Approach

Add a small Codex-native packaging layer over the existing canonical plugin.
The repository-root marketplace catalog selects `plugins/specclaw`; that root
gets a `.codex-plugin/plugin.json` manifest whose `skills` field selects the
already-canonical `skills/` directory. The existing `.agents/skills/specclaw`
adapter remains unchanged and continues to serve checkout-local contributor
sessions. One Bash contract test parses the two new JSON documents with Python,
checks path and metadata invariants, and is wired into the existing CI test job.

## Architecture

```text
Codex marketplace source (chan4lk/specclaw)
  └─ .agents/plugins/marketplace.json
       └─ local source: ./plugins/specclaw
            ├─ .codex-plugin/plugin.json
            │    └─ skills: ./skills/
            └─ skills/<verb>/SKILL.md  (existing canonical lifecycle assets)

Checkout-local contributors
  └─ .agents/skills/specclaw/SKILL.md
       └─ delegates to the same plugins/specclaw/{skills,bin,...} root
```

The marketplace contains only the portable entry. The plugin manifest owns
plugin metadata and the canonical skill-root declaration. Canonical lifecycle
behavior, helper binaries, templates, references, and the local adapter stay
owned by their current paths.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `.agents/plugins/marketplace.json` | Create | Native Codex marketplace named `chan4lk`, with a local `specclaw` entry resolving to `./plugins/specclaw`. |
| `plugins/specclaw/.codex-plugin/plugin.json` | Create | Native plugin manifest mirroring shared Claude metadata and declaring `./skills/`. |
| `plugins/specclaw/tests/run-codex-plugin-tests.sh` | Create | Offline package-contract checks for JSON, paths, metadata parity, skill inventory, and CI registration. |
| `.github/workflows/ci.yml` | Modify | Run the package-contract suite and parse the native manifest in the JSON job. |
| `README.md` | Modify | Add installed-Codex marketplace and plugin-add instructions; keep checkout-local and Claude paths distinct. |
| `docs/index.md` | Modify | Document native Codex marketplace architecture and source-root semantics. |
| `CONTRIBUTING.md` | Modify | Add a contributor-safe local package validation path that avoids global configuration writes. |

## Data Model Changes

None. The new JSON files are static package metadata; no lifecycle state,
registry, or user configuration is introduced.

## API Changes

None. The change adds distribution metadata and documentation only. Existing
SpecClaw skills and lifecycle command semantics stay unchanged.

## Key Decisions

- Use `.agents/plugins/marketplace.json`, not the existing
  `.claude-plugin/marketplace.json`, as the Codex-native catalog. This keeps
  source syntax and marketplace behavior explicit for Codex while retaining
  Claude compatibility.
- Point the manifest at `./skills/` rather than copying or wrapping lifecycle
  skills. This preserves one source of truth and lets package validation catch
  an incomplete canonical skill inventory.
- Keep the existing root-level adapter. It solves a different use case:
  running Codex directly from a repository checkout; the new package solves
  marketplace discovery and installation.
- Make static validation the CI gate. An installation smoke test may be run
  manually only with an isolated Codex home, because tests must not alter a
  developer's configured marketplaces or plugin cache.

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Codex resolves `source.path` from the wrong directory | Assert resolution from the repository root and pin the expected `./plugins/specclaw` value. |
| Claude and Codex release metadata drift | Parse both manifests and compare shared fields in the focused test. |
| A future skill is absent from the package | Enumerate canonical skill directories and require `SKILL.md` under the declared skill root. |
| Docs recommend obsolete CLI syntax | Pin the current `marketplace add` + `plugin add` commands in the contract test or documentation assertions. |
| Test mutates global Codex settings | Keep CI static/offline; document optional smoke testing with a temporary isolated home. |

## Grounding Sources

- `CONTRIBUTING.md:33-40` — “The plugin lives in `plugins/specclaw/`” and the
  existing Codex path is explicitly “repository-local”; the design adds a
  distribution wrapper around that canonical root rather than a parallel tree.
- `docs/index.md:122-136` — “The specclaw plugin lives at
  `plugins/specclaw/`” and scripts use `$CLAUDE_PLUGIN_ROOT`; the manifest
  selects that same root.
- `plugins/specclaw/tests/run-codex-skill-tests.sh:18-84` — existing validation
  requires a one-file adapter with no copied `skills`, `bin`, `templates`, or
  `references`; the package does not relax or duplicate that boundary.
- [OpenAI plugin-management documentation](https://developers.openai.com/docs/enterprise/plugin-management)
  — Codex marketplaces use `.agents/plugins/marketplace.json`, and local
  plugin paths are relative to the marketplace root.
