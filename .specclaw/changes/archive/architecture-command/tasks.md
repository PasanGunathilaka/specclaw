# Tasks: C4 Architecture Views (`/specclaw:architecture`)

**Change:** architecture-command
**Created:** 2026-07-22
**Total Tasks:** 6

## Summary

Three independent pieces of work don't depend on each other and run as
Wave 1: extending the collector with `dependency_graph`, building the new
template + persona, and mechanically relocating `/specclaw:analyze`'s
output path. Wave 2 needs Wave 1's real output to build against: the
orchestrating skill needs the extended collector and the new persona/
template names, and the fixture/test case needs the real extractors to
assert against. Release plumbing closes out Wave 3 once everything else is
proven working — same three-wave shape `analyze-command` used.

## Tasks

### Wave 1 — Collector extension, template + persona, relocation (parallel)

- [x] `T1` — `dependency_graph` field on `specclaw-analyze-codebase collect`
  - Files: plugins/specclaw/bin/specclaw-analyze-codebase
  - Estimate: large
  - Depends: —
  - Notes: Per design.md's Technical Approach item 1. Add a new collection
    step between manifest detection and LOC counting, reusing the existing
    `tmp_scoped` file list — no second enumeration pass. Three extractors,
    each best-effort (`|| true`, never aborts on a malformed file):
    (a) Delphi `uses`-clause extraction via a bounded `awk` state machine
    (start at `uses`, end at the next `;`, split on commas) over every
    scoped `.pas` file, each unit name resolved to a scoped file via
    case-insensitive `<unit>.pas` basename match (mirror
    `match_files_by_name`'s glob approach, case-folded) — no match, no
    edge, `"kind": "uses"`; (b) Node/JS/TS relative `require()`/`import`
    resolution — `grep -oE` for `require\(['\"]\.\.?/...` and
    `from ['\"]\.\.?/...` specifiers, resolved against the importing file's
    directory trying the literal path plus `.js`/`.jsx`/`.ts`/`.tsx`/
    `/index.{js,ts}`, `"kind": "import"`; (c) .NET `<ProjectReference
    Include="...csproj">` grep per scoped `.csproj` (a new, separate
    extractor from the existing `extract_dotnet_deps`, which only reads
    `<PackageReference>`), resolved relative to the referencing project's
    directory, `"kind": "project_reference"`. Go/Rust/Python/Java/Maven/Make
    get no extractor — zero contribution, not a guess. Assemble
    `dependency_graph` the same way `manifests` is already assembled
    (line-by-line JSON objects from a tmpfile, comma-joined), inserted into
    the existing `cat <<ENDJSON` heredoc between `test_locations` and
    `discovered_docs`. No existing field's construction changes — purely
    additive.

- [x] `T2` — `templates/architecture.md` + `agents/architecture-analyst.md`
  - Files: plugins/specclaw/templates/architecture.md, plugins/specclaw/agents/architecture-analyst.md
  - Estimate: medium
  - Depends: —
  - Notes: Template first: header (`{{title}}`, `{{path}}`, `{{date}}`)
    plus four sections (System Context/L1, Containers/L2, Components/L3,
    Code/L4), each with a fenced ` ```mermaid ` diagram placeholder and a
    prose placeholder (`{{l1_diagram}}`/`{{l1_narrative}}` … `{{l4_diagram}}`/
    `{{l4_narrative}}`). Then the agent, shaped like `codebase-analyst.md`:
    frontmatter `name: architecture-analyst`, `tools: [Read, Write, Bash]`,
    `model: sonnet`. Inputs section: collected JSON (incl.
    `dependency_graph`) + target path; reads
    `$CLAUDE_PLUGIN_ROOT/templates/architecture.md` before writing, same
    "don't invent new sections" instruction. Four-row rubric table (System
    Context / Containers / Components / Code) per design.md. Evidence
    Discipline section adapted from `codebase-analyst.md`'s (every node/edge/
    claim anchored to a collected fact or an opened file). Explicit L4 rule:
    produce L4 only for a component with non-obvious structure, a suspected
    god-object, or a component worth pointing a rebuild effort at first;
    every other component gets an explicit "L4 not warranted for this
    component" line, never silent omission. Mermaid convention: `flowchart`/
    `graph` + `subgraph`, never `C4Context`/`C4Container`/`C4Component` —
    include the literal example from design.md's Technical Approach item 2
    in the Output section so the convention is unambiguous, not just
    described in prose.

- [x] `T3` — Relocate `/specclaw:analyze`'s output path
  - Files: plugins/specclaw/skills/analyze/SKILL.md, plugins/specclaw/agents/codebase-analyst.md
  - Estimate: small
  - Depends: —
  - Notes: Per design.md's Technical Approach item 5 and Key Decision 6 —
    mechanical, no logic change beyond the one new migration check.
    `skills/analyze/SKILL.md`: update the frontmatter description and the
    archive step's two path strings (`.specclaw/codebase-report.md` →
    `.specclaw/analysis/codebase-report.md`,
    `.specclaw/codebase-reports/archive/` → `.specclaw/analysis/archive/`).
    Add one new sub-step immediately before the existing archive check: if
    the OLD path (`.specclaw/codebase-report.md`) exists and the NEW path
    doesn't yet, `mv` the old-path file into
    `.specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md`
    first (this becomes a permanent no-op `[ -f ... ]` check after the first
    post-upgrade run on any given project — do not remove it later just
    because it's usually a no-op). `agents/codebase-analyst.md`: update the
    description line, the Identity line, and the Output section's file path
    to the new location — its rubric, evidence discipline, and report shape
    are untouched.

### Wave 2 — Orchestrating skill + regression test

- [x] `T4` — `skills/architecture/SKILL.md`
  - Files: plugins/specclaw/skills/architecture/SKILL.md
  - Estimate: medium
  - Depends: T1, T2, T3
  - Notes: Same shape as `skills/analyze/SKILL.md`. Frontmatter
    `description:` model-invokable, no `disable-model-invocation`. Steps:
    (1) `specclaw-ensure-init .specclaw`; (2) run `specclaw-analyze-codebase
    collect .specclaw [path]` — if it exits non-zero, surface its stderr
    verbatim and stop, no reimplemented path validation (it's already
    inside `collect`); (3) if `.specclaw/analysis/architecture.md` already
    exists, `mv` it to
    `.specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-architecture.md`
    (`mkdir -p` the archive dir first — same shared archive directory T3's
    relocated `analyze` now uses, plain Bash instruction, no new script);
    (4) spawn `Agent` with `subagent_type: "architecture-analyst"`, model
    from `config.yaml` `models.review` (default `anthropic/claude-sonnet-4-5`),
    passing the collected JSON (incl. `dependency_graph`) and the resolved
    target path — no `agent-prompts.md` extraction, direct context like
    `/specclaw:verify` Step 3.5 and `/specclaw:analyze` Step 3 already do;
    (5) the agent writes `.specclaw/analysis/architecture.md` itself (per
    T2); (6) present a short summary — path analyzed, which C4 levels were
    written, any component flagged "L4 not warranted." No
    `specclaw-validate-change` call anywhere in this skill.

- [x] `T5` — Fixture extension + parser-test case
  - Files: plugins/specclaw/tests/fixtures/analyze/, plugins/specclaw/tests/run-parser-tests.sh
  - Estimate: medium
  - Depends: T1
  - Notes: Extend the existing `tests/fixtures/analyze/` tree (do not create
    a parallel fixture) with, placed so they don't disturb Case 9's existing
    assertions (avoid `sub/`, `tests/`, and `sample.qux`): two `.pas` files
    at fixture root — `UnitA.pas` with a `uses` clause referencing `UnitB`
    (resolves) and an RTL-style name like `SysUtils` (does not resolve to
    any scoped file), and `UnitB.pas`; two `.js` files —
    `a.js` doing `require('./b')`, `b.js` existing; a second `.csproj` (e.g.
    `Other.csproj`) plus edit the existing fixture to add one project with a
    `<ProjectReference Include="../Other/Other.csproj">` pointing at it (or
    add both fresh, whichever keeps the existing manifest-count assertions
    in `run-parser-tests.sh`'s Case 9 intact — verify Case 9 still passes
    unmodified before adding new assertions). Add a new case to
    `run-parser-tests.sh` (follow the existing Case-numbering convention)
    asserting AC1–AC7: `dependency_graph` field present and additive (existing
    fields still all present); the `UnitA.pas`→`UnitB.pas` `uses` edge with
    `"kind": "uses"`; the unresolved `SysUtils` reference produces no edge;
    the `a.js`→`b.js` `import` edge; the `ProjectReference` edge with
    `"kind": "project_reference"`, and that its target does NOT appear in
    that manifest's own `dependencies` array; the existing `go.mod` fixture
    (no `.go` source file) demonstrates `dependency_graph` contains no Go
    entries "for free"; and a subdirectory-scoped `collect` call excludes
    any dependency-graph edge whose endpoint falls outside that subdirectory.

### Wave 3 — Release plumbing

- [x] `T6` — README rows + version bump
  - Files: README.md, plugins/specclaw/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
  - Estimate: small
  - Depends: T4, T5
  - Notes: Add a `| /specclaw:architecture [path] | ... (read-only, C4/
    Mermaid) |` row to README's Commands table, placed near
    `/specclaw:analyze`. Update the existing `/specclaw:analyze` row's
    described output path from `.specclaw/codebase-report.md` to
    `.specclaw/analysis/codebase-report.md` (same row, text edit only — no
    behavior in this row changed). Patch-increment `version` in both
    `plugin.json` and `marketplace.json`'s `specclaw` entry, keep them in
    sync, per this repo's `CLAUDE.md` version-bump rule.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:** see the tasks above for the live shape — checkbox, ID, title, then `Files / Estimate / Depends / Notes` sub-bullets.
