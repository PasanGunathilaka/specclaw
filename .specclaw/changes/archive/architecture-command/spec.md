# Spec: C4 Architecture Views (`/specclaw:architecture`)

**Change:** architecture-command
**Created:** 2026-07-22
**Status:** 🟡 Draft

## Overview

Add a read-only side-command, `/specclaw:architecture [path]`, that writes
`.specclaw/analysis/architecture.md`: a C4-model view of the analyzed
codebase (L1 System Context → L2 Containers → L3 Components → L4 Code, L4
only where warranted) with a Mermaid diagram plus grounded prose per level.
It reuses `bin/specclaw-analyze-codebase collect`'s existing JSON payload
(`top_level_dirs`, `manifests`, `loc_by_extension`, `discovered_docs`)
unchanged, and adds exactly one new fact that payload doesn't have: an
internal file/project dependency graph, needed to cluster files into
components and draw edges between them. As part of establishing
`.specclaw/analysis/` as the shared home for the whole eventual document
suite, this change also relocates `/specclaw:analyze`'s already-shipped
output there (a mechanical path edit, no behavior change to what it
collects or how it reasons). No lifecycle gate: matches the `analyze`/
`patterns`/`status` side-command pattern.

**Refinement from the approved proposal, made during codebase analysis:**
the proposal described the new dependency signal loosely as "`uses`-clauses
(Delphi), `using`-directives (.NET), and import/require statements
(Node/Python/etc.)." Reading `bin/specclaw-analyze-codebase`'s existing
`.csproj` handling (`extract_dotnet_deps` — grep `<PackageReference
Include="...">`) surfaced that C# `using` directives reference **namespaces**,
not files — there is no cheap, reliable way to map a `using X.Y;` line to a
specific file in the repo without much deeper parsing. The cheap, reliable
.NET signal is `<ProjectReference Include="....csproj">` in the same
`.csproj` files already being read — a genuine project-to-project edge,
distinct from the `<PackageReference>` (NuGet) entries already extracted as
manifest dependencies. FR3/FR4 below reflect this refinement; Go, Rust,
Python, Java/Maven, and Make get no dependency-graph contribution in v1 for
the same reason (no cheap, reliable file-level signal) — named explicitly as
a v2 candidate, mirroring the shallow-depth precedent `analyze-command`'s
own FR4 already set for manifest version signals.

## Requirements

### Functional Requirements

- **FR1 — New skill.** `skills/architecture/SKILL.md` registers
  `/specclaw:architecture [path]`. Model-invokable (no
  `disable-model-invocation`) — read-only, no TTY or credential handling.
  Opens with the `specclaw-ensure-init .specclaw` boilerplate every skill
  uses.
- **FR2 — Path scoping, reused not reimplemented.** `[path]` semantics are
  identical to `/specclaw:analyze`'s (default: repository root; must resolve
  to an existing directory inside the repo; rejected if it's `.specclaw`
  itself or nested inside it). This command does not reimplement that
  validation — it calls the same `specclaw-analyze-codebase collect`
  subcommand analyze already uses, which already dies with a clear stderr
  message and non-zero exit before any collection runs on a bad path.
- **FR3 — `dependency_graph` field on the existing `collect` output.**
  `bin/specclaw-analyze-codebase collect` gains one new top-level JSON field,
  additive only (no existing field renamed/removed/changed):
  ```json
  "dependency_graph": [
    {"from": "<rel_path>", "to": "<rel_path>", "kind": "uses|import|project_reference"}
  ]
  ```
  Scoped to `[path]` by the same prefix rule every other field already
  uses — an edge is only included if both `from` and `to` resolve inside the
  scope. Populated by these extractors, each best-effort (`|| true`, never
  aborts the script on a malformed file), matching the manifest extractors'
  existing tolerance:
  - **Delphi/Object Pascal (`kind: "uses"`)** — parse `uses` clauses (both
    `interface` and `implementation` sections) in every scoped `.pas` file,
    a multi-line block bounded by `uses` and the next `;`. Each referenced
    unit name is resolved to a file by case-insensitive match against
    `<UnitName>.pas` in the scoped file list. A unit name that doesn't
    resolve to any scoped file (RTL/external units, or units outside scope)
    produces no edge — never a guessed or dangling edge.
  - **Node/JS/TS (`kind: "import"`)** — parse `require('./x')` and
    `import ... from './x'` / `from "../x"` specifiers with a leading `./`
    or `../` only (bare/package specifiers are the manifest's job, not this
    graph's). Resolve the specifier relative to the importing file's
    directory, trying the literal path plus `.js`/`.jsx`/`.ts`/`.tsx` and
    `/index.{js,ts}` against the scoped file list. An unresolved specifier
    produces no edge.
  - **.NET (`kind: "project_reference"`)** — grep `<ProjectReference
    Include="[^"]+\.csproj"` in every scoped `.csproj` file, resolved
    relative to the referencing project's directory. This is a
    project-to-project edge (coarser than file-level), which is exactly the
    granularity C4's L2/L3 boundary needs from .NET — distinct from the
    `<PackageReference>` entries already captured as manifest dependencies.
  - **Everything else (Go, Rust, Python, Java/Maven, Make)** — no
    contribution to `dependency_graph` in v1. Explicitly empty, not a
    best-effort guess, per the Overview's refinement note.
- **FR4 — Shallow graph depth (v1), stated as a testable constraint.** No
  symbol/call-level graph — file (or, for .NET, project) level only. Any
  ecosystem not listed in FR3's extractors must yield zero
  `dependency_graph` entries for that file, never a fabricated edge.
- **FR5 — `agents/architecture-analyst.md`.** A fixed-rubric persona
  mirroring `codebase-analyst.md`'s shape: `tools: [Read, Write, Bash]`,
  `model: sonnet`, a four-row rubric (System Context / Containers /
  Components / Code), an "Evidence Discipline" section (every diagram node
  and edge, and every prose claim, anchored to a collected fact or a file
  the agent opened itself via `Read`), an explicit **L4 judgment rule**
  (L4 is produced only for a component with non-obvious internal structure,
  a suspected god-object, or a component worth pointing a rebuild effort at
  first — every other component gets an explicit "L4 not warranted for this
  component," never silent omission), and a **Mermaid convention**: diagrams
  use `flowchart`/`graph` with labeled `subgraph` blocks for
  container/component boundaries, never Mermaid's native `C4Context`/
  `C4Container`/`C4Component` diagram types (see NFR6).
- **FR6 — `templates/architecture.md`.** Scaffold with `{{placeholder}}`
  tokens: header fields (title, path, date), then four body sections — System
  Context (L1), Containers (L2), Components (L3), Code (L4) — each with a
  fenced ` ```mermaid ` diagram placeholder and a prose placeholder.
- **FR7 — Skill orchestration.** `skills/architecture/SKILL.md` steps: (1)
  `specclaw-ensure-init .specclaw`; (2) run `specclaw-analyze-codebase
  collect .specclaw [path]` — if it exits non-zero, surface its stderr
  verbatim and stop (same as analyze's FR7); (3) archive the prior
  `.specclaw/analysis/architecture.md`, if any, to
  `.specclaw/analysis/archive/<YYYY-MM-DD-HHMMSS>-architecture.md` (plain
  `mv`, no new script — mirrors analyze's own archive step, same shared
  archive directory per FR9); (4) spawn `Agent` with `subagent_type:
  "architecture-analyst"`, model from `config.yaml` `models.review`, passing
  the collected JSON (including `dependency_graph`) and the resolved target
  path; (5) the agent writes `.specclaw/analysis/architecture.md` itself; (6)
  present a short summary (path analyzed, C4 levels written, any component
  the agent flagged "L4 not warranted").
- **FR8 — Versioned output, shared archive directory.** Same archive-on-rerun
  convention analyze v1 established, reusing the same
  `.specclaw/analysis/archive/` directory (FR9) rather than a second,
  parallel archive location — entries are distinguished by filename
  (`<timestamp>-architecture.md` vs `<timestamp>-codebase-report.md`), not by
  separate subdirectories.
- **FR9 — Relocate `/specclaw:analyze`'s output path.** Three mechanical
  edits, no logic/content change:
  1. `skills/analyze/SKILL.md` — frontmatter description and the archive
     step now reference `.specclaw/analysis/codebase-report.md` and
     `.specclaw/analysis/archive/` instead of `.specclaw/codebase-report.md`
     and `.specclaw/codebase-reports/archive/`.
  2. `agents/codebase-analyst.md` — its description line, Identity line, and
     Output section's file path all updated to the new path. Its rubric,
     evidence discipline, and report shape are untouched.
  3. **Upgrade migration, not just a new default.** A project that ran
     `/specclaw:analyze` before this change has a report sitting at the OLD
     path. The archive step in `skills/analyze/SKILL.md` must check the OLD
     path (`.specclaw/codebase-report.md`) in addition to the new one: if it
     exists (and nothing has yet been written at the new path), move it into
     `.specclaw/analysis/archive/<YYYY-MM-DD-HHMMSS>-codebase-report.md`
     before writing the new report at the new stable path — the same
     archive-not-discard guarantee FR8 already gives a same-path rerun,
     extended across this one-time relocation so a pre-upgrade report is
     never silently orphaned at a path nothing documents anymore.
- **FR10 — Release plumbing.** Bump `plugin.json` + `marketplace.json`
  (patch increment, kept in sync); add a `/specclaw:architecture [path]` row
  to the root `README.md` Commands table; update the existing
  `/specclaw:analyze` row's described output path to
  `.specclaw/analysis/codebase-report.md`.
- **FR11 — Parser tests.** Extend the existing `analyze` fixture (don't
  create a parallel one) with: two `.pas` files whose `uses` clauses
  reference each other (one resolving in-scope, one referencing an
  RTL-style name that does not resolve to any scoped file); two `.js` files
  where one does a relative `require`/`import` of the other; a second
  `.csproj` with a `<ProjectReference>` to a project path within the
  fixture. Add a new case to `tests/run-parser-tests.sh` asserting FR3's
  extractors and FR4's silence for uncovered ecosystems (the existing
  `go.mod` fixture, with no `.go` source file, already demonstrates the
  "no source, no edges" case for free).

### Non-Functional Requirements

- **NFR1 — Language-agnostic.** `dependency_graph` must be `[]` (not a
  crash) on a repo with none of FR3's recognized dependency-eligible file
  types.
- **NFR2 — Grounded, not invented.** Every diagram node and edge, and every
  prose claim, in the written `architecture.md` must trace to either the
  collected JSON (`dependency_graph`, `manifests`, `top_level_dirs`) or a
  file the agent read directly. No C4-level claim may be asserted from a
  file that was neither collected nor opened.
- **NFR3 — Portability.** Plain bash + coreutils, matching every sibling
  script; `jq` optional with a grep/awk fallback; no new external
  dependency.
- **NFR4 — No lifecycle coupling.** `/specclaw:architecture` must not call
  `specclaw-validate-change`, must not require or read any
  `changes/<name>/` directory, and must not alter `STATUS.md` or any
  change's `status.md`.
- **NFR5 — Safe re-run and safe relocation.** Re-running
  `/specclaw:architecture` must never silently discard a prior
  `architecture.md` (FR8). The `/specclaw:analyze` path relocation (FR9)
  must never silently discard *or orphan* a prior `codebase-report.md`,
  whether it was written at the new path (normal archive-on-rerun) or the
  old, pre-upgrade path (one-time migration).
- **NFR6 — Renders without extra tooling.** All diagrams are Mermaid
  `flowchart`/`graph` blocks with `subgraph` boundaries — chosen over
  Mermaid's native `C4Context`/`C4Container`/`C4Component` diagram types
  because GitHub's and most editors' bundled Mermaid renderer versions have
  inconsistent support for the native C4 types, while `flowchart`/`graph` is
  universally supported everywhere Mermaid renders at all.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- [ ] **AC1** — `specclaw-analyze-codebase collect .specclaw` output includes
  a `"dependency_graph":` array field in addition to every pre-existing
  field (`path`, `project_root`, `top_level_dirs`, `manifests`,
  `loc_by_extension`, `test_locations`, `discovered_docs`) — purely
  additive, no regression to the existing fields.
- [ ] **AC2** — Against a fixture with two `.pas` files where `UnitA.pas`'s
  `uses` clause references `UnitB.pas` (present in scope), `dependency_graph`
  contains `{"from": "UnitA.pas", "to": "UnitB.pas", "kind": "uses"}`.
- [ ] **AC3** — A `uses` reference to a unit name with no corresponding file
  in scope produces no edge for that reference.
- [ ] **AC4** — Against a fixture where `a.js` does `require('./b')` and
  `b.js` exists, `dependency_graph` contains an edge `a.js` → `b.js` with
  `"kind": "import"`.
- [ ] **AC5** — Against a fixture `.csproj` containing a `<ProjectReference
  Include="../Other/Other.csproj">`, `dependency_graph` contains an edge
  with `"kind": "project_reference"` to that path, and that same path does
  **not** appear in the referencing manifest's own `dependencies` list
  (`<PackageReference>`-only field, unaffected by this change).
- [ ] **AC6** — A fixture/scope containing only Go, Python, Java, or
  Makefile-detected files yields `dependency_graph: []` — no crash, no
  fabricated edge.
- [ ] **AC7** — `collect .specclaw <subdir>` scopes `dependency_graph` the
  same way it already scopes `manifests`/`loc_by_extension`/
  `test_locations`: an edge is excluded if either endpoint falls outside
  `<subdir>`.
- [ ] **AC8** — `/specclaw:architecture <bad-path>` stops with a clear error
  before collection or agent spawn (same die-before-work guarantee `collect`
  already provides).
- [ ] **AC9** — On a repo with no prior `architecture.md`, running
  `/specclaw:architecture` creates `.specclaw/analysis/architecture.md` with
  all four C4 sections present (L4 either populated or explicitly "L4 not
  warranted for this component"), every diagram fenced as a Mermaid
  `flowchart`/`graph` block (never `C4Context`/`C4Container`/
  `C4Component`), and every node/edge/prose claim traceable to a collected
  fact or an opened file.
- [ ] **AC10** — Running `/specclaw:architecture` a second time archives the
  prior `.specclaw/analysis/architecture.md` (byte-identical) to
  `.specclaw/analysis/archive/<timestamp>-architecture.md` before writing
  the new one.
- [ ] **AC11** — `agents/architecture-analyst.md` frontmatter declares
  `tools: [Read, Write, Bash]`; its body documents the four-level rubric,
  the L4-judgment rule, and the Mermaid flowchart-not-native-C4 convention.
- [ ] **AC12** — Running `/specclaw:analyze` on a fresh repo (no prior report
  anywhere) creates `.specclaw/analysis/codebase-report.md`, not
  `.specclaw/codebase-report.md`; `agents/codebase-analyst.md` and
  `skills/analyze/SKILL.md` contain no remaining reference to the old path.
- [ ] **AC13** — On a repo with a pre-existing `.specclaw/codebase-report.md`
  at the OLD path and nothing yet at the new path, running
  `/specclaw:analyze` moves the old-path file (byte-identical) to
  `.specclaw/analysis/archive/<timestamp>-codebase-report.md` before writing
  the new report at the new stable path.
- [ ] **AC14** — `plugin.json` and `marketplace.json` versions match each
  other and are exactly one patch increment above their pre-change values.
- [ ] **AC15** — `tests/run-parser-tests.sh` includes the new
  dependency-graph case(s) and the full suite passes
  (`bash plugins/specclaw/tests/run-parser-tests.sh` exits 0).
- [ ] **AC16** — `README.md`'s Commands table includes a
  `/specclaw:architecture [path]` row (read-only, C4/Mermaid), and the
  existing `/specclaw:analyze` row's described output path reads
  `.specclaw/analysis/codebase-report.md`.

## Edge Cases

- A Delphi `uses` clause spanning multiple lines before its terminating `;`
  → the multi-line block is parsed as one unit list, same as the existing
  manifest extractors' bounded-block technique.
- Circular `uses`/`import`/`ProjectReference` (A → B and B → A) → both edges
  recorded independently; `dependency_graph` is a flat edge list, not a
  traversal, so a cycle is never a hang or an infinite loop.
- A Delphi unit referenced with different casing than its file (Pascal
  identifiers are case-insensitive) → resolved via case-insensitive filename
  match.
- Multiple `.csproj` files with `ProjectReference` edges to each other, and
  to a project path outside the scoped `[path]` → the outside-scope edge is
  excluded per AC7's scoping rule, same discipline as every other field.
- A repo with zero dependency-graph-eligible files → `dependency_graph: []`;
  the L3 Components section states "insufficient evidence for a
  component-level dependency view" rather than fabricating clusters from
  directory names alone.
- A project with reports at **both** the old and new `codebase-report.md`
  paths simultaneously (shouldn't normally arise, but not prevented) → the
  new-path file is archived per the normal rerun rule (FR8-equivalent for
  analyze); the old-path file is also migrated to the archive (FR9.3); both
  end up archived, distinguishable by timestamp, no data loss either way.
- A monorepo with independent Delphi/.NET/Node subprojects at different
  subdirectories, analyzed with a `[path]` scoped to just one of them →
  `dependency_graph` only includes edges where both endpoints resolve
  within the scoped subtree, same as manifests/LOC/test-locations already
  behave.

## Dependencies

- `bin/specclaw-analyze-codebase` (existing, extended not replaced) — the
  `collect` subcommand this change adds `dependency_graph` to; every
  existing field/behavior (manifests, LOC, test-locations, discovered_docs,
  path validation) is reused unchanged.
- `skills/analyze/SKILL.md`, `agents/codebase-analyst.md`, `README.md`
  (existing, modified) — path-relocation edits only (FR9), no change to
  what `/specclaw:analyze` collects or how `codebase-analyst` reasons.
- `specclaw-discover-context` (existing, unmodified) — already reused by
  `specclaw-analyze-codebase collect`'s `discovered_docs` field; unaffected
  by this change.
- No new external runtime dependency.

## Notes

Deferred to v2 (per this spec's decisions, not part of this change):
symbol/call-level dependency graphs; `dependency_graph` coverage for Go,
Rust, Python, Java/Maven, and Make; exhaustive L4 coverage (this change
produces L4 only where the agent judges it warranted); multi-repo/
multi-service C4 views; wiring `architecture.md` into
`specclaw-build-context`/`specclaw-verify-context` as an injected section
(same "integration payoff, not now" deferral `analyze-command` made for
`codebase-report.md`). `domain-model.md`, `functional-spec.md`, and
`rebuild-inputs.md` are separate, later changes in the roadmap recorded in
this change's `proposal.md`.
