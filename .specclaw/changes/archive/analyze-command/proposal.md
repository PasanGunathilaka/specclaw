# Proposal: Brownfield Codebase Analysis (`/specclaw:analyze`)

**Created:** 2026-07-21
**Status:** 🟡 Draft

## Problem

_What problem are we solving? Why does it matter?_

specclaw's lifecycle (`propose` → `plan` → `build` → `verify` → `pr`) assumes
someone already understands the codebase they're changing. On a legacy or
unfamiliar repo — including non-Node/`.NET`-shaped stacks like Delphi/Object
Pascal that this repo's own tooling has never had to reason about — there is
no fast, grounded way to answer "what is this codebase, technically, before I
propose a change to it?" Today that survey either doesn't happen, or happens
informally inside `/specclaw:plan` Step 3 ("Codebase survey"), scoped to a
single change and never persisted or reused.

This also matters for specclaw's own machinery: `/specclaw:plan` re-derives
the same top-level directory/manifest survey inline, from scratch, every time
it plans a change, instead of reading a standing artifact.

## Proposed Solution

_What are we building? High-level approach._

A new **read-only side-command**, `/specclaw:analyze [path]`, that inspects
an existing codebase and writes one project-level report,
`.specclaw/codebase-report.md`, with every claim grounded in files the agent
actually opened. Five required sections:

1. **Tech stack** — languages, frameworks, runtime/build tooling and
   versions, read from manifests (`package.json`, `*.csproj`/`*.sln`,
   `pom.xml`, `go.mod`, `Cargo.toml`, `requirements.txt`/`pyproject.toml`,
   `*.dpr`/`*.dproj` (Delphi), `Makefile`, etc.).
2. **Dependencies** — third-party libs parsed straight out of those
   manifests, plus internal module dependencies where cheaply derivable.
3. **Structure / architecture** — top-level module map, entry points, where
   tests live, layering (or lack of it).
4. **Domain** — the business domain the code serves, inferred only from
   evidence (folder/entity/table names, comments, existing docs). Every
   domain inference is labeled as an inference; low-confidence guesses are
   flagged; nothing is invented from unread code.
5. **Risks / tech-debt** — dead code, fragile spots, unmaintained
   dependencies, and anything a human must confirm.

Built per this repo's own extension recipe (`docs/specclaw-architecture-notes.md`
§6 — "Where a legacy-codebase analyzer slots in"), reusing existing machinery
instead of reinventing file enumeration/filtering:

- **`skills/analyze/SKILL.md`** — model-invokable, read-only, no
  `disable-model-invocation`. Opens with the same `specclaw-ensure-init
  .specclaw` boilerplate every skill uses.
- **`bin/specclaw-analyze-codebase`** — deterministic fact-collection only
  (mirrors `specclaw-build-context`/`specclaw-verify collect`'s shape): file
  tree, manifest contents, LOC per language, dependency lists, and the
  existing `specclaw-discover-context emit` digest, emitted as one
  structured payload to stdout. Exposes a `collect <path>` subcommand
  mirroring `specclaw-verify collect`'s dispatch shape. Same bash
  conventions as every sibling script: `#!/usr/bin/env bash`, `set -euo
  pipefail`, a self-contained `yaml_val()`, jq-with-grep/awk fallback,
  subcommand dispatch, `-h` help. The script only collects facts; the agent
  does the interpreting.
- **`templates/codebase-report.md`** — scaffold with `{{placeholder}}`
  tokens for the five sections above.
- **`agents/codebase-analyst.md`** — a fixed-rubric persona (mirroring
  `code-reviewer.md`'s 10 dimensions): Tech Stack / Dependencies /
  Architecture / Domain / Risks / Suggested First Changes, each finding
  anchored to quoted evidence from an actually-opened file.
- Reuse **`specclaw-discover-context`** for the doc-discovery half and the
  **`/specclaw:plan` Step 3 "Codebase survey"** logic (directory summary,
  manifest detection, test-location detection) for the structure half — the
  new bin script promotes that inline survey to a standalone, reusable tool
  rather than duplicating it.
- Bump `plugin.json` + `marketplace.json` versions and add a Commands-table
  row to the root `README.md`, per this repo's `CLAUDE.md` rule.
- Add cases to `tests/run-parser-tests.sh` for any real parsing logic added
  (manifest field extraction, LOC counting, etc.).

**Explicitly a side-command, not a lifecycle phase:** no
`specclaw-validate-change` gate, no interaction with `propose`/`plan`/
`build`/`verify`/`pr` prerequisites — it slots in next to `patterns` and
`status` as a read/append utility callable any time, on any repo, in any
language.

## Scope

### In Scope
- `skills/analyze/SKILL.md` (`/specclaw:analyze [path]`)
- `bin/specclaw-analyze-codebase` (fact-collection subcommand(s): file tree,
  manifest parsing, LOC per language, dependency extraction, discover-context
  digest passthrough)
- `templates/codebase-report.md`
- `agents/codebase-analyst.md`
- Manifest support for at least: Node (`package.json`), .NET
  (`*.csproj`/`*.sln`), Java/Maven (`pom.xml`), Go (`go.mod`), Rust
  (`Cargo.toml`), Python (`requirements.txt`/`pyproject.toml`), Delphi/Object
  Pascal (`*.dpr`/`*.dproj`), and generic `Makefile`-based projects. Version
  extraction is **shallow in v1**: ecosystem detection + dependency lists are
  required for every listed format; a version signal is read only where a
  single cheap field already carries it (e.g. `package.json` `engines`, a
  `.csproj` `<TargetFramework>`) — no uniform-depth promise across formats.
- `[path]` argument scopes analysis to a subdirectory of the current repo
  (repo root is the default with no argument). Analyzing a different/external
  repo is **out of scope for v1** — flagged as a v2 candidate.
- Output: `.specclaw/codebase-report.md` — **versioned, not overwritten.**
  Each run preserves the previous report (e.g. timestamped filename or an
  archived copy) rather than replacing it in place, so a human's read of an
  older report survives a re-run.
- `plugin.json` + `marketplace.json` version bump; README Commands-table row
- New parser test cases in `tests/run-parser-tests.sh`

### Out of Scope
- Any mutation of source code — this is strictly read-only/reporting
- A new `specclaw-validate-change` phase or gate
- Per-change (as opposed to project-level) analysis output
- Wiring `codebase-report.md` into `specclaw-build-context` /
  `specclaw-verify-context` as an additional injected section (noted in the
  architecture doc as a natural follow-up "integration payoff," but not part
  of this change — first cut is the standalone command producing a report a
  human reads)
- Exhaustive manifest-format coverage beyond the list above (e.g. Gradle
  `build.gradle`, Ruby `Gemfile`, PHP `composer.json`) — can be added
  incrementally later following the same pattern
- Automated/CI invocation of `/specclaw:analyze`
- Analyzing a repo/path outside the current working repo — `[path]` is a
  subdirectory scope only in v1; targeting an external repo is a v2 candidate
- Deep, uniform version extraction across all manifest formats — v1 reads a
  version signal only where a single cheap field already exposes one

## Impact

- **Files affected:** ~7 new files (`skills/analyze/SKILL.md`,
  `bin/specclaw-analyze-codebase`, `templates/codebase-report.md`,
  `agents/codebase-analyst.md`, `tests/run-parser-tests.sh` additions,
  `plugin.json`, `marketplace.json`) + 1 edited (`README.md`) (estimated)
- **Complexity:** medium (small / medium / large) — no new lifecycle
  wiring, but the bin script needs real per-manifest-format parsing across
  ~8 ecosystems, matching existing bash conventions with no shared lib
- **Risk:** low (low / medium / high) — read-only, no gate gets stricter, no
  existing command's behavior changes; worst case is an inaccurate or
  incomplete report, not data loss or a broken lifecycle

## Open Questions

Resolved at approval — carried into `spec.md`/`design.md` as concrete
requirements rather than left open:

- **`[path]` semantics:** subdirectory of the current repo; root is the
  default when omitted. Analyzing an external/different repo is out of scope
  for v1 — noted as a v2 candidate.
- **Re-run behavior:** `.specclaw/codebase-report.md` is versioned, not
  overwritten — each run preserves the prior report (e.g. a timestamped
  filename or archived copy) instead of replacing it in place.
- **Version-extraction depth:** shallow in v1. Every listed manifest format
  gets ecosystem detection + dependency-list extraction; a version signal is
  read only where a single cheap field already carries it. No uniform-depth
  promise across formats.
- **Bin script shape:** `bin/specclaw-analyze-codebase` exposes a `collect
  <path>` subcommand, mirroring `specclaw-verify collect`'s dispatch shape,
  rather than a single unnamed fact-dump command.

---

**To proceed:** Review this proposal and approve to begin planning.
