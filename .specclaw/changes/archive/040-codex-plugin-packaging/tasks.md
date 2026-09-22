# Tasks: Package SpecClaw as an Installable Codex Plugin

**Change:** 040-codex-plugin-packaging
**Created:** 2026-09-20
**Total Tasks:** 5 across 3 waves

## Summary

Add a native Codex marketplace catalog and manifest that expose the existing
canonical skill tree, prove the packaging contract offline, document the two
Codex usage modes, and register all validation in CI. No task changes lifecycle
behavior or duplicates canonical assets.

## Tasks

### Wave 1 — Package contract first

- [x] `T1` — Add failing native Codex package-contract validation
  - Files: `plugins/specclaw/tests/run-codex-plugin-tests.sh` (create)
  - Estimate: medium
  - Kind: test
  - Notes: Parse JSON with Python; require a root `.agents/plugins/marketplace.json`, marketplace name `chan4lk`, a local `specclaw` source at `./plugins/specclaw`, a native manifest at that resolved path, `skills: ./skills/`, and a `SKILL.md` in every canonical child directory. Compare the shared metadata fields with the Claude manifest and assert the suite's CI registration. Do not invoke Codex or write global configuration.

### Wave 2 — Native marketplace package

- [x] `T2` — Add the Codex marketplace catalog and native SpecClaw manifest
  - Files: `.agents/plugins/marketplace.json` (create), `plugins/specclaw/.codex-plugin/plugin.json` (create)
  - Estimate: small
  - Kind: config
  - Depends: T1
  - Notes: Use the Codex-native local-source object and repository-root-relative path. Mirror Claude package metadata exactly where it is shared, declare the canonical `./skills/` root, and add no copied skills, scripts, templates, or references.

### Wave 3 — Documentation and CI delivery

- [x] `T3` — Document marketplace installation and checkout-local Codex use
  - Files: `README.md` (modify), `docs/index.md` (modify), `CONTRIBUTING.md` (modify)
  - Estimate: medium
  - Kind: docs
  - Depends: T2
  - Notes: Document `codex plugin marketplace add chan4lk/specclaw` (including sparse-marketplace guidance where appropriate) and `codex plugin add specclaw@chan4lk`; retain and distinguish the existing Claude Code commands and the checkout-local adapter. State that isolated testing must not modify global configuration.

- [x] `T4` — Register Codex package checks in continuous integration
  - Files: `.github/workflows/ci.yml` (modify)
  - Estimate: small
  - Kind: test
  - Depends: T1, T2
  - Notes: Add the focused package-contract suite to the existing test job and parse `plugins/specclaw/.codex-plugin/plugin.json` in the JSON validation job. Preserve the existing adapter test and Claude manifest/version-sync checks.

- [x] `T5` — Validate package behavior and regression boundaries
  - Files: `plugins/specclaw/tests/run-codex-plugin-tests.sh`, `plugins/specclaw/tests/run-codex-skill-tests.sh`, `.github/workflows/ci.yml`
  - Estimate: small
  - Kind: test
  - Depends: T3, T4
  - Notes: Run both focused suites, the JSON parsing/version checks, and relevant description/shellcheck gates. If a Codex CLI smoke test is available, run it only against an isolated temporary Codex home and verify listing/install discovery without changing the operator's configured marketplaces or cache.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
- `[>]` Deferred — correctly blocked on a sibling change, not incomplete through any fault of its own; excluded from the incomplete-task count that gates `verify`
