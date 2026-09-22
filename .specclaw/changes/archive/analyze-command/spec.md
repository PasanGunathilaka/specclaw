# Spec: Brownfield Codebase Analysis (`/specclaw:analyze`)

**Change:** analyze-command
**Created:** 2026-07-21
**Status:** 🟡 Draft

## Overview

Add a read-only side-command, `/specclaw:analyze [path]`, that inspects an
existing (possibly legacy, possibly non-Node/.NET-shaped) codebase and writes
a grounded, five-section report to `.specclaw/codebase-report.md`. It reuses
`specclaw-discover-context` for doc discovery and promotes `/specclaw:plan`
Step 3's inline "codebase survey" (top-two-level directory summary, manifest
detection, test-location detection) into a standalone, reusable
`bin/specclaw-analyze-codebase` script, per
`docs/specclaw-architecture-notes.md` §6. No lifecycle gate: it does not call
`specclaw-validate-change` and has no interaction with
`propose`/`plan`/`build`/`verify`/`pr` prerequisites, matching the
`patterns`/`status` side-command pattern.

## Requirements

### Functional Requirements

- **FR1 — New skill.** `skills/analyze/SKILL.md` registers `/specclaw:analyze
  [path]`. Model-invokable (no `disable-model-invocation`) — read-only, no TTY
  or credential handling. Opens with the `specclaw-ensure-init .specclaw`
  boilerplate every skill uses.
- **FR2 — Path scoping.** `[path]`, when given, must resolve to an existing
  directory inside the current repository (relative to CWD). Default (no
  argument) is the repository root. If the resolved path does not exist, or
  resolves outside the repository root, the skill reports a clear error and
  stops before any collection or agent step runs.
- **FR3 — `bin/specclaw-analyze-codebase collect` subcommand.** Signature:
  `specclaw-analyze-codebase collect <specclaw_dir> [path]`, mirroring
  `specclaw-verify collect <specclaw_dir> <change_name>`'s dispatch shape
  (`case "$1" in collect) ... esac`, `-h|--help` block). Deterministic
  fact-collection only — gathers, does not interpret:
  - Repo-relative file enumeration scoped to `[path]`: `git ls-files` when
    inside a git work tree, `find` fallback otherwise (mirrors
    `specclaw-discover-context`'s existing git/find fallback, not
    reimplemented from scratch).
  - Top-two-level directory summary scoped to `[path]` (same shape as
    `/specclaw:plan` Step 3's `git ls-files | cut -d/ -f1-2 | sort -u`).
  - Manifest detection + best-effort parsing for: `package.json`,
    `*.csproj`/`*.sln`, `pom.xml`, `go.mod`, `Cargo.toml`,
    `requirements.txt`/`pyproject.toml`, `*.dpr`/`*.dproj` (Delphi/Object
    Pascal), `Makefile`. Every detected manifest yields one entry: its path,
    ecosystem type, raw content (small files — no line cap needed for typical
    manifest sizes), and a dependency-name list extracted with
    grep/sed/awk (no real JSON/XML/TOML parser — same fallback philosophy as
    every sibling script). A single cheap version field is captured where one
    exists (see FR4); this is not attempted uniformly.
  - LOC per language: `wc -l` totals grouped by file extension across the
    scoped file list.
  - Test-location detection: directories/files matching common conventions
    (`test`, `tests`, `spec`, `__tests__`, `*_test.*`, `*.test.*`,
    `*.spec.*`) found under `[path]`.
  - Discovered project docs: shells out to `specclaw-discover-context
    <specclaw_dir> emit` and embeds its digest verbatim — no reimplementation
    of ranking/filtering/budget logic.
  - Emits one JSON object to stdout (jq-validated when `jq` is present,
    printed best-effort otherwise — matching `specclaw-verify collect`'s
    validate-then-print pattern). Malformed/empty manifest files do not abort
    the script (`|| true` / best-effort extraction, consistent with existing
    scripts' error tolerance).
- **FR4 — Shallow version extraction (v1).** Every manifest format in FR3
  gets ecosystem detection and a dependency-name list. A version signal
  (e.g. `package.json`'s `engines` field, a `.csproj`'s
  `<TargetFramework>`) is captured only where a single cheap field already
  carries it — no uniform per-ecosystem version depth is promised or
  required.
- **FR5 — `agents/codebase-analyst.md`.** A fixed-rubric persona (mirrors
  `code-reviewer.md`'s shape): `tools: [Read, Write, Bash]`, six-dimension
  rubric — Tech Stack / Dependencies / Architecture / Domain / Risks /
  Suggested First Changes. Every finding must be anchored to a quoted line
  from a file the agent actually opened via `Read` during the run — the
  collected JSON payload from FR3 is a starting map, not a substitute for
  reading real files. Domain findings are explicitly labeled as inferences
  (e.g. prefixed "Inference:") and low-confidence guesses are flagged as
  such; the agent must never assert domain behavior from a file it has not
  opened.
- **FR6 — `templates/codebase-report.md`.** Scaffold with `{{placeholder}}`
  tokens for the five proposal sections (Tech Stack, Dependencies,
  Structure/Architecture, Domain, Risks/Tech-Debt) plus a Suggested First
  Changes section mirroring the agent's sixth rubric dimension, and header
  fields (title, date, path analyzed).
- **FR7 — Skill orchestration.** `skills/analyze/SKILL.md` steps: (1)
  `specclaw-ensure-init .specclaw`; (2) resolve/validate `[path]` per FR2;
  (3) run `specclaw-analyze-codebase collect`; (4) spawn the
  `codebase-analyst` agent (`subagent_type: "codebase-analyst"`) with the
  collected JSON as context, using the model from `config.yaml`
  `models.review` (default `anthropic/claude-sonnet-4-5`, same default
  `/specclaw:verify` uses) — mirrors how `/specclaw:verify` Step 3.5 spawns
  `code-reviewer` directly with context blocks, no `agent-prompts.md`
  extraction needed since the persona file is self-contained; (5) write the
  report per FR8; (6) present a short summary to the user (sections written,
  path analyzed, any low-confidence flags).
- **FR8 — Versioned output, not overwritten in place.** Before writing a new
  `.specclaw/codebase-report.md`, if one already exists, move it to
  `.specclaw/codebase-reports/archive/<YYYY-MM-DD-HHMMSS>-codebase-report.md`
  — mirrors the existing `changes/archive/YYYY-MM-DD-<name>/` dated-archive
  convention (`skills/archive/SKILL.md` step 3) rather than inventing a new
  scheme. The current run's report always lands at the stable path
  `.specclaw/codebase-report.md` so humans and any future integration always
  know where to look.
- **FR9 — Release plumbing.** Bump `plugin.json` + `marketplace.json`
  (patch increment, kept in sync); add a `/specclaw:analyze [path]` row to
  the root `README.md` Commands table.
- **FR10 — Parser tests.** Add at least one case to
  `tests/run-parser-tests.sh` exercising `specclaw-analyze-codebase collect`
  against a fixture directory covering at least two ecosystems (Node +
  Delphi, since Delphi is the differentiating case for language-agnosticism)
  plus LOC and test-location detection.

### Non-Functional Requirements

- **NFR1 — Language-agnostic.** The collect script must run cleanly (empty
  `manifests: []`, not a crash) against a repo with none of the recognized
  manifest formats, and must correctly detect a Delphi-shaped repo
  (`.dpr`/`.dproj`) as well as it detects Node/.NET/Java/Go/Rust/Python.
- **NFR2 — Grounded, not invented.** Every claim in the written report must
  trace to either the collected JSON (facts) or a file the agent read
  directly (interpretation). No domain or architecture claim may be asserted
  from a file that was neither collected nor opened.
- **NFR3 — Portability.** Plain bash + coreutils, matching every sibling
  script; `jq` optional with a grep/awk fallback; no new external
  dependency; runs standalone (no plugin harness) the same way
  `tests/run-parser-tests.sh` already invokes sibling `bin/specclaw-*`
  scripts directly.
- **NFR4 — No lifecycle coupling.** `/specclaw:analyze` must not call
  `specclaw-validate-change`, must not require or read any
  `changes/<name>/` directory, and must not alter `STATUS.md` or any
  change's `status.md`.
- **NFR5 — Safe re-run.** Re-running `/specclaw:analyze` must never silently
  discard a prior report (FR8) and must never partially write
  `codebase-report.md` (write to a temp path and move into place, or
  equivalent atomicity, consistent with how `specclaw-verify update-status`
  already writes via a tmpfile-then-`mv`).

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- [ ] **AC1** — `specclaw-analyze-codebase collect .specclaw` (no path arg)
  defaults to the repository root; output is valid JSON (`jq -e '.'`
  succeeds when `jq` is present).
- [ ] **AC2** — `specclaw-analyze-codebase collect .specclaw <subdir>` scopes
  `top_level_dirs`, manifest search, LOC counts, and test-location detection
  to files under `<subdir>` only — files outside it never appear in the
  output.
- [ ] **AC3** — Against a fixture directory containing `package.json`,
  `go.mod`, and a Delphi `.dproj` file, the `manifests[]` array contains one
  entry per format with the correct `type`, non-empty dependency lists for
  `package.json` and `go.mod`, and a present (possibly dependency-empty)
  entry for the `.dproj` file.
- [ ] **AC4** — `loc_by_extension` in the output matches real `wc -l` counts
  for the fixture's files (spot-checked against a known extension).
- [ ] **AC5** — `test_locations` includes a fixture's `tests/`-or-`spec/`-style
  directory when present, and is an empty list when no test-like directory
  exists in the fixture.
- [ ] **AC6** — The `discovered_docs` field's content is identical to what
  `specclaw-discover-context <dir> emit` produces standalone against the same
  directory (no reimplementation, same script invoked).
- [ ] **AC7** — `/specclaw:analyze <bad-path>` (nonexistent, or outside the
  repository) stops with a clear error before running `collect` or spawning
  the agent.
- [ ] **AC8** — On a repo with no prior `codebase-report.md`, running
  `/specclaw:analyze` creates `.specclaw/codebase-report.md` with all five
  proposal sections plus Suggested First Changes populated (or explicitly
  marked "insufficient evidence" with a reason, never silently blank), and
  every Tech Stack/Dependencies/Domain claim traceable to a quoted file path.
- [ ] **AC9** — Running `/specclaw:analyze` a second time moves the prior
  `.specclaw/codebase-report.md` to
  `.specclaw/codebase-reports/archive/<timestamp>-codebase-report.md`
  (content byte-identical to the pre-move file) before writing the new
  report at the stable path.
- [ ] **AC10** — `agents/codebase-analyst.md` frontmatter declares `tools:
  [Read, Write, Bash]` and documents the six-dimension rubric (Tech Stack /
  Dependencies / Architecture / Domain / Risks / Suggested First Changes);
  domain findings are labeled as inferences in its output-format
  instructions.
- [ ] **AC11** — `plugin.json` and `marketplace.json` versions match each
  other and are exactly one patch increment above their pre-change values.
- [ ] **AC12** — `tests/run-parser-tests.sh` includes the new
  `specclaw-analyze-codebase` case and the full suite passes
  (`bash plugins/specclaw/tests/run-parser-tests.sh` exits 0).
- [ ] **AC13** — `README.md`'s Commands table includes a `/specclaw:analyze
  [path]` row describing it as a read-only codebase-analysis command.

## Edge Cases

- A repo with zero recognized manifest formats (e.g. a pure-docs repo) →
  `manifests: []`, not a crash; the report's Tech Stack section says so
  explicitly rather than fabricating a stack.
- `[path]` is not a git work tree itself but the parent repo is (e.g.
  analyzing a vendored subdirectory) → file enumeration still scopes
  correctly via the git fallback path used for the whole repo, filtered to
  the subdirectory prefix.
- No git repository at all → `find`-based enumeration fallback (mirrors
  `specclaw-discover-context`'s existing non-git path), same manifest/LOC/
  test-location logic applied to the `find` result.
- Multiple manifests of the same ecosystem at different levels (e.g. a
  monorepo with two `package.json` files) → each is its own `manifests[]`
  entry with its own path; no merging or dependency deduplication across
  entries.
- A detected manifest file that is empty or malformed (invalid JSON/XML) →
  entry still included (path + type + raw content), dependency list empty,
  script does not abort.
- `[path]` targets `.specclaw/` itself or a path nested inside it → rejected
  with a clear error (FR2) — that directory is specclaw's own state, not
  application code, mirroring `specclaw-discover-context`'s existing
  default-exclude of `.specclaw`.
- Very large repositories → LOC counting and file enumeration operate on
  whatever `git ls-files`/`find` returns; no artificial cap is introduced in
  v1 beyond what FR3's per-manifest content size already implies (small
  manifest files only — no full source-tree dump).

## Dependencies

- `specclaw-discover-context` (existing, unmodified) — doc-discovery half,
  invoked as a subprocess by `specclaw-analyze-codebase collect`.
- `/specclaw:plan` Step 3's inline codebase-survey logic — the shape being
  promoted into `bin/specclaw-analyze-codebase`, not duplicated by hand.
  `/specclaw:plan` itself is not modified by this change (the proposal's
  integration payoff — `/specclaw:plan` calling the new script instead of
  re-deriving the survey inline — is explicitly deferred; see proposal Out
  of Scope).
- Existing bash conventions: self-contained `yaml_val()`/`json_escape()`
  idioms (copied, not shared, per repo convention), `jq`-with-fallback
  pattern.
- No new external runtime dependency.

## Notes

Deferred to v2 (per approved proposal decisions, not part of this change):
analyzing a path/repo outside the current working repository; wiring
`codebase-report.md` into `specclaw-build-context`/`specclaw-verify-context`
as an injected section; uniform deep version extraction across all manifest
formats; exhaustive manifest-format coverage beyond the FR3 list (Gradle,
Ruby Gemfile, PHP composer.json, etc.); automated/CI invocation.
