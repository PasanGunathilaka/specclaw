# Spec: Package SpecClaw as an Installable Codex Plugin

**Change:** 040-codex-plugin-packaging
**Created:** 2026-09-20
**Status:** 🟡 Draft

## Overview

Make the existing SpecClaw distribution installable through Codex's native plugin
marketplace while retaining the checkout-local adapter as a complementary use
case.
The package exposes the canonical `plugins/specclaw/skills/` tree directly; it
does not create a second lifecycle implementation or copy any canonical assets.

## Requirements

### Functional Requirements

- **FR1** — Add `.agents/plugins/marketplace.json` with a `chan4lk` marketplace
  and one `specclaw` entry whose local source path resolves from the repository
  root to `plugins/specclaw`.
- **FR2** — Add `plugins/specclaw/.codex-plugin/plugin.json` as the native
  Codex manifest. It SHALL identify the plugin with the same name, version,
  ownership, repository, license, and product description as the existing
  Claude packaging, and expose `./skills/` as its skill root.
- **FR3** — Keep `plugins/specclaw/skills/`, `bin/`, `templates/`, and
  `references/` canonical and shared. The new Codex package SHALL not add a
  copied lifecycle tree or modify the checkout-local adapter's delegation
  contract.
- **FR4** — Document the Git marketplace and local-checkout flows using
  `codex plugin marketplace add` followed by `codex plugin add
  specclaw@chan4lk`, and distinguish them from the existing Claude Code flow.
- **FR5** — Add an offline package-contract test that validates both JSON
  documents, marketplace-to-plugin path resolution, manifest metadata parity,
  the declared skill root, and that every canonical skill directory supplies a
  `SKILL.md`.
- **FR6** — Register the new package-contract test in the existing CI test
  job, and include the Codex manifest in CI JSON validation.

### Non-Functional Requirements

- **NFR1** — No marketplace command or test may modify a user's global Codex
  configuration; installation testing, if performed, uses an isolated temporary
  Codex home or is limited to the offline contract test.
- **NFR2** — The package must remain self-contained, JSON-valid, and
  dependency-free beyond Codex and the repository's existing Bash/coreutils and
  Python JSON checks.
- **NFR3** — Package validation must be deterministic, offline, and complete
  in under five seconds on a normal checkout.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- **AC1** — `.agents/plugins/marketplace.json` is valid JSON, has marketplace
  name `chan4lk`, and its `specclaw` source is a local `./plugins/specclaw`
  path resolved relative to the repository root, not `.agents/plugins/`.
- **AC2** — `plugins/specclaw/.codex-plugin/plugin.json` is valid JSON,
  declares `name: specclaw`, and exposes `./skills/`.
- **AC3** — The Codex and Claude manifests agree on shared distributable
  metadata (at minimum name, version, description, author, homepage,
  repository, license, and keywords), preventing independent package drift.
- **AC4** — Every directory selected by the Codex skill root contains a
  canonical `SKILL.md`; no additional lifecycle copy is introduced for Codex.
- **AC5** — README, docs index, and contributing guidance state the correct
  Codex CLI add/install commands and retain a clear, separate Claude Code
  marketplace path.
- **AC6** — The focused package-contract suite passes locally, runs in CI, and
  CI parses the native Codex manifest with the other package JSON.
- **AC7** — Existing checkout-local use through
  `.agents/skills/specclaw/SKILL.md` remains documented as an alternative for
  contributors and is not presented as global installation.

## Edge Cases

- A marketplace source is added with `--sparse .agents/plugins`: its entry's
  local path still resolves from the repository root, so validation must not
  resolve it from the marketplace file's directory.
- A manifest version changes for a release: the metadata-parity test catches a
  version mismatch before marketplace publication.
- A new canonical skill directory is added: the package test fails until that
  directory has a `SKILL.md`, rather than silently shipping an incomplete
  package.
- A user has not installed Codex or has a different global configuration: the
  repository's static contract test remains runnable and does not touch it.

## Dependencies

- Canonical lifecycle assets: `plugins/specclaw/skills/`, `bin/`, `templates/`,
  and `references/`.
- Existing Codex checkout-local adapter: `.agents/skills/specclaw/SKILL.md`.
- Codex native marketplace convention: `.agents/plugins/marketplace.json`
  points to a plugin root containing `.codex-plugin/plugin.json`.

## Notes

### Grounding sources

- `CONTRIBUTING.md:33-40` says the plugin lives at
  `plugins/specclaw/` and the current Codex path is checkout-local; the native
  manifest therefore lives beside the canonical plugin rather than creating a
  second implementation.
- `docs/index.md:122-136` identifies `plugins/specclaw/` as the single
  canonical plugin location and states that its scripts resolve internal
  resources through `$CLAUDE_PLUGIN_ROOT`; the package exposes that same asset
  root.
- `plugins/specclaw/tests/run-codex-skill-tests.sh:18-84` proves the adapter's
  one-file/no-duplicate boundary and CI registration; package validation
  complements rather than replaces that focused test.
- [OpenAI plugin-management documentation](https://developers.openai.com/docs/enterprise/plugin-management)
  specifies `.agents/plugins/marketplace.json` and local plugin paths relative
  to the marketplace root; [OpenAI plugin packaging documentation](https://developers.openai.com/plugins/build/plugins)
  specifies `codex plugin marketplace add` and `codex plugin add` flows.
