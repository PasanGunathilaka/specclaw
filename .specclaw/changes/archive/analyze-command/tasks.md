# Tasks: Brownfield Codebase Analysis (`/specclaw:analyze`)

**Change:** analyze-command
**Created:** 2026-07-21
**Total Tasks:** 5

## Summary

The fact-collector script and the report scaffold + analyst persona are
independent of each other and run as Wave 1. The orchestrating skill and the
fixture/test case both need the real `collect` output to build against, so
they're Wave 2. Release plumbing (docs + version bump) closes out Wave 3
once everything else is proven working.

## Tasks

### Wave 1 — Collector script, report scaffold + persona (parallel)

- [x] `T1` — `bin/specclaw-analyze-codebase collect` subcommand
  - Files: plugins/specclaw/bin/specclaw-analyze-codebase
  - Estimate: large
  - Depends: —
  - Notes: Per design.md's Technical Approach. `#!/usr/bin/env bash`,
    `set -euo pipefail`, `-h|--help` usage block, `case "$1" in collect) ...
    esac` dispatch (only `collect` in v1). Signature: `collect
    <specclaw_dir> [path]`. Resolve `PROJECT_ROOT` and physically-resolve
    `[path]` (`cd "$dir" && pwd`, default `.`); reject with a clear stderr
    error + non-zero exit if it doesn't exist, isn't under `PROJECT_ROOT`, or
    is `$SPECCLAW_DIR` or nested inside it (FR2, edge case). File
    enumeration: `git -C "$PROJECT_ROOT" ls-files` when
    `git rev-parse --is-inside-work-tree` succeeds (copy the detection from
    `specclaw-discover-context`), else its `find`-with-prune fallback;
    filter to the scoped path by prefix. Build: top-two-level dir summary
    (`cut -d/ -f1-2 | sort -u`); manifest detection + best-effort dependency
    extraction for all 8 formats listed in spec FR3 (see design.md's
    per-format breakdown — `package.json` jq-with-grep-fallback,
    `*.csproj`/`*.sln` grep, `pom.xml` bounded awk block scan, `go.mod`
    require-block parse, `Cargo.toml`/`pyproject.toml` section-scoped scan
    copying `specclaw-discover-context`'s `yaml_list()` in-section idiom,
    `requirements.txt` line-per-dependency, `*.dpr`/`*.dproj`
    `DCCReference` grep with `version_signal: null` always, `Makefile`
    detected with `dependencies: []`); LOC per extension via one `wc -l`
    pass grouped by extension; test-location detection (dedup'd
    directories, not files, matching `test`/`tests`/`spec`/`__tests__`/
    `*_test.*`/`*.test.*`/`*.spec.*`); `discovered_docs` field from
    `bash "$SCRIPT_DIR/specclaw-discover-context" "$SPECCLAW_DIR" emit`
    (copy the exact subprocess call `specclaw-build-context` uses). Copy
    `json_escape()` verbatim from `specclaw-verify`. Every per-manifest
    extractor is best-effort (`|| true`, never aborts the script on a
    malformed file). jq-validate the final JSON when `jq` is present, print
    either way (copy `specclaw-verify collect`'s Step 8 pattern exactly).

- [x] `T2` — `templates/codebase-report.md` + `agents/codebase-analyst.md`
  - Files: plugins/specclaw/templates/codebase-report.md, plugins/specclaw/agents/codebase-analyst.md
  - Estimate: medium
  - Depends: —
  - Notes: Template first: header fields (`{{title}}`, `{{date}}`,
    `{{path}}`) plus six `{{placeholder}}` body sections — Tech Stack,
    Dependencies, Structure/Architecture, Domain, Risks/Tech-Debt, Suggested
    First Changes — same `{{token}}` convention as every other template.
    Then the agent, shaped exactly like `code-reviewer.md`: frontmatter
    `name: codebase-analyst`, a description sentence, `tools: [Read, Write,
    Bash]`, `model: sonnet`. Inputs section: it's invoked with the collected
    JSON payload + target path, and reads the scaffold at
    `$CLAUDE_PLUGIN_ROOT/templates/codebase-report.md` itself (mirror
    `spec-author.md`'s "read the template, don't invent new sections"
    line). Rubric table: the same six dimensions as the template's sections.
    Evidence Discipline section adapted verbatim in spirit from
    `code-reviewer.md`'s ("a claim you cannot anchor to a file you opened is
    not a finding — drop it, never attribute behavior to code you haven't
    read"). Domain dimension gets an explicit extra rule: every domain
    finding is prefixed `Inference:` and low-confidence guesses are flagged
    as such — never asserted as fact. Output section: write
    `.specclaw/codebase-report.md` once, at the end, using the template's
    exact section shape.

### Wave 2 — Orchestrating skill + regression test

- [x] `T3` — `skills/analyze/SKILL.md`
  - Files: plugins/specclaw/skills/analyze/SKILL.md
  - Estimate: medium
  - Depends: T1, T2
  - Notes: Frontmatter `description:` model-invokable, no
    `disable-model-invocation` (read-only command). Opens with the
    `specclaw-ensure-init .specclaw` line every skill uses. Steps per
    design.md's Architecture diagram: (1) ensure-init; (2) resolve/validate
    `[path]` — if `specclaw-analyze-codebase collect` exits non-zero on a
    bad path, surface its stderr and stop, don't retry or guess; (3) run
    `specclaw-analyze-codebase collect .specclaw [path]`; (4) if
    `.specclaw/codebase-report.md` already exists, `mv` it to
    `.specclaw/codebase-reports/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md`
    (create the `archive/` dir if needed) — plain Bash instruction, no new
    script, mirroring `skills/archive/SKILL.md`'s own "3. Move to..." line;
    (5) spawn `Agent` with `subagent_type: "codebase-analyst"`, model from
    `config.yaml` `models.review` (default `anthropic/claude-sonnet-4-5`),
    passing the collect JSON and the resolved path — no `agent-prompts.md`
    extraction, pass context directly like `/specclaw:verify` Step 3.5 does
    for `code-reviewer`; (6) the agent writes
    `.specclaw/codebase-report.md` itself (per T2); (7) present a short
    summary to the user — path analyzed, sections written, any
    low-confidence flags the agent raised. No `specclaw-validate-change`
    call anywhere in this skill.

- [x] `T4` — Fixture + parser-test case
  - Files: plugins/specclaw/tests/fixtures/analyze/, plugins/specclaw/tests/run-parser-tests.sh
  - Estimate: medium
  - Depends: T1
  - Notes: New fixture tree under `tests/fixtures/analyze/` (checked into
    the repo, mirrors `tests/fixtures/discovery/`'s existing pattern):
    minimal `package.json` with 1-2 real deps, a minimal `go.mod` with a
    `require` block, a minimal `.dproj` with one `DCCReference` entry, a
    `tests/` subdirectory with a trivial file, and a couple of plain source
    files with a known, hand-countable line count for the LOC assertion.
    Add a new "Case N" block to `run-parser-tests.sh` (follow the file's
    existing numbering/style — see the header comment listing B2/B3/B4/NFR2/
    grounded-context/update-check/smart-base-branch cases) that runs
    `specclaw-analyze-codebase collect <fixture-specclaw-dir>` against a
    temp copy of the fixture and asserts (AC1–AC6): valid JSON; scoping to a
    subdir excludes files outside it; the three manifest entries have the
    right `type` and non-empty (or explicitly empty, for `.dproj`)
    dependency lists; `loc_by_extension` matches a hand-computed `wc -l`
    count for one extension; `test_locations` includes the fixture's
    `tests/` dir; `discovered_docs` matches a direct
    `specclaw-discover-context ... emit` call on the same fixture dir.

### Wave 3 — Release plumbing

- [x] `T5` — README row + version bump
  - Files: README.md, plugins/specclaw/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
  - Estimate: small
  - Depends: T3, T4
  - Notes: Add `| /specclaw:analyze [path] | Analyze an existing/legacy
    codebase and write .specclaw/codebase-report.md (read-only) |` to
    README's Commands table (placed near `/specclaw:status`/`/specclaw:
    patterns`, the other read-only side-commands). Patch-increment
    `version` in both `plugin.json` and `marketplace.json`'s `specclaw`
    entry, keep them in sync, per this repo's `CLAUDE.md` version-bump
    rule.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:** see the tasks above for the live shape — checkbox, ID, title, then `Files / Estimate / Depends / Notes` sub-bullets.
