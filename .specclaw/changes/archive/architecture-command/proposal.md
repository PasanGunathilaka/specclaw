# Proposal: C4 Architecture Views (`/specclaw:architecture`)

**Created:** 2026-07-22
**Status:** 🟡 Draft

## Problem

_What problem are we solving? Why does it matter?_

`/specclaw:analyze` (shipped, v1) produces one grounded technical report,
`.specclaw/codebase-report.md`, including a prose "Structure/Architecture"
section. We ran it against a real legacy Delphi 7 app (EPANET) and the
verdict was: technically accurate, but not enough. The acceptance test going
forward is explicit — **"The generated docs should be enough for an AI model
to develop a new application just by looking at those docs, without reading
the old code."** A single prose paragraph describing module layout does not
clear that bar. Specifically:

- There is no way to see the system at multiple zoom levels — from "what
  does this system talk to" down to "what does this one component do" —
  without re-reading the codebase at each level.
- Nothing renders as a diagram. A rebuild effort reasoning about container
  boundaries or component responsibilities has to reconstruct that shape
  from prose, which is exactly the kind of re-reading the acceptance test
  rules out.
- v1's collected facts (file tree, manifests, LOC, discovered docs) say
  nothing about how internal files/modules depend on each other — the one
  fact a component-level view actually needs.

This is also the first of a larger, previously-agreed gap: v1's report needs
to grow into a small suite of documents rather than one file (deeper domain
analysis, a functional spec, an honest rebuild-gap list). This proposal is
step 1 of that suite — see **Roadmap Context** below for the full sequence
and why architecture goes first.

## Proposed Solution

_What are we building? High-level approach._

A new **read-only side-command**, `/specclaw:architecture [path]`, that
writes `.specclaw/analysis/architecture.md`: a C4-model view of the analyzed
codebase — **L1 System Context → L2 Containers → L3 Components → L4 Code**
(L4 only where a component is important/complex enough to merit zooming in
further) — with a Mermaid diagram plus grounded prose at every level. Same
evidence discipline as v1: every diagram edge and every prose claim traces to
a collected fact or a file the agent actually opened; nothing is invented
from unread code.

**Reuse, not re-derivation.** This command does **not** re-run file
enumeration, manifest parsing, or doc discovery — it consumes
`specclaw-analyze-codebase collect`'s existing JSON payload (`top_level_dirs`,
`manifests`, `loc_by_extension`, `discovered_docs`) exactly as
`codebase-analyst` does today. The **one** genuinely new fact this command
needs that v1 doesn't collect: an **internal dependency graph** — which file
depends on which other file, extracted from `uses`-clauses (Delphi),
`using`-directives (.NET), and import/require statements (Node/Python/etc.)
— because that's the raw signal an L3 Components view actually needs to
cluster files into components and draw edges between them. Per this repo's
own reuse rule ("extend the collect payload or add a sibling collector,
don't duplicate"), this is added as a new field on
`specclaw-analyze-codebase collect`'s existing JSON output
(`dependency_graph`), computed by a new per-stack extractor alongside the
existing manifest extractors — additive only, existing consumers
(`skills/analyze`, `codebase-analyst`) are unaffected by the extra key.

**Establishing `.specclaw/analysis/` as the suite's home.** Every document in
the eventual suite (this one, plus the domain/functional/rebuild-gap
documents from later changes) needs one shared directory rather than one
file living alone at `.specclaw/` root while the rest land elsewhere. This
change introduces `.specclaw/analysis/` and — as a small, purely mechanical
task — relocates v1's already-shipped output there too:
`.specclaw/codebase-report.md` → `.specclaw/analysis/codebase-report.md`,
and its archive convention `.specclaw/codebase-reports/archive/` →
`.specclaw/analysis/archive/`. This is a path edit in
`skills/analyze/SKILL.md` (two lines) — no change to what `/specclaw:analyze`
collects, how `codebase-analyst` reasons, or the report's content/shape.
Flagged explicitly as an **Open Question** below since it touches an
already-shipped, already-verified command's output location.

**New pieces, following `docs/specclaw-architecture-notes.md` §6 exactly:**

- `skills/architecture/SKILL.md` — `/specclaw:architecture [path]`,
  model-invokable, read-only, no `disable-model-invocation`. Same shape as
  `skills/analyze/SKILL.md`: ensure-init → resolve/validate `[path]` (reuses
  the same containment-check logic already proven in
  `specclaw-analyze-codebase`) → collect → archive prior report if any →
  spawn agent → agent writes the file → summarize.
- `bin/specclaw-analyze-codebase` (extend, not duplicate) — new
  `dependency_graph` field on the existing `collect` output: per-file edges
  `{from, to}` derived from best-effort grep/awk extraction of
  language-specific dependency syntax (`uses` clauses for Delphi/Pascal,
  `using` directives for C#, `import`/`require` for JS/TS/Python/Go/Rust
  where cheap). File-level granularity only in v1 — no symbol-level call
  graph. An unrecognized language yields an empty graph, not a guess.
- `templates/architecture.md` — scaffold with header fields plus four body
  sections (L1–L4), each with a fenced ` ```mermaid ` block placeholder and
  a prose placeholder.
- `agents/architecture-analyst.md` — fixed-rubric persona mirroring
  `codebase-analyst.md`'s shape: one rubric row per C4 level, an "Evidence
  Discipline" section (every diagram node/edge and every prose claim
  anchored to a collected fact or an opened file), and explicit guidance on
  when L4 is warranted ("only where it matters" — a component with
  non-obvious internal structure, a suspected god-object, or a component the
  Suggested-First-Changes-equivalent guidance would point someone toward)
  versus when to state "L4 not warranted for this component" and move on.
- Mermaid diagram convention: **`flowchart`/`graph` with subgraphs**, not
  Mermaid's native `C4Context`/`C4Container`/`C4Component` diagram types —
  see Open Questions for why.
- Version bump (`plugin.json` + `marketplace.json`), README Commands-table
  row, new parser-test cases in `tests/run-parser-tests.sh` for the
  dependency-graph extractor (at least Delphi `uses` + one other stack, same
  "Delphi is the differentiating case" reasoning v1 used for manifests).

**Explicitly a side-command, no lifecycle gate** — joins `analyze`/
`patterns`/`status`; no `specclaw-validate-change` case arm.

### Command-shape argument (for the record — see Roadmap Context)

Your lean groups the eventual suite into three commands (`analyze` shipped,
`domain`, `architecture`) plus an umbrella. This proposal argues for keeping
**architecture as its own separate command**, not folded into `analyze` and
not folded into `domain`:

- **Distinct new evidence.** Architecture's one new fact (a file-level
  dependency graph) is unrelated to what domain/functional analysis needs
  (UI-control/menu-handler parsing, business-rule extraction from routine
  bodies). Bundling them would force one command's bin script to grow two
  unrelated collectors and one agent to hold two unrelated rubrics — the
  kind of multi-task surface that strained v1's own verify pass (see
  Roadmap Context).
- **Different reading mode.** C4 views are read by zooming (L1 → L4);
  domain/functional docs are read narratively (rules, workflows). Different
  enough audiences/use-cases that forcing them into one output file would
  make both harder to skim.
- **Independently useful either way** — satisfies the hard requirement.
  Someone onboarding to a legacy repo may want *only* "show me the system
  shape" without waiting on deeper domain/business-rule extraction, or vice
  versa.

## Scope

### In Scope
- `skills/architecture/SKILL.md` (`/specclaw:architecture [path]`)
- `bin/specclaw-analyze-codebase` — additive `dependency_graph` field on the
  existing `collect` output (new per-stack uses/import extractors; existing
  fields/behavior unchanged)
- `templates/architecture.md` (C4 L1–L4 scaffold, Mermaid placeholders)
- `agents/architecture-analyst.md` (fixed C4 rubric, evidence discipline,
  L4-when-warranted guidance)
- Dependency-graph extraction for at least: Delphi/Object Pascal (`uses`
  clauses), .NET (`using` directives). Best-effort for Node/Python/Go/Rust
  where a cheap import/require pattern exists; an unrecognized syntax
  yields an empty graph rather than a guess (mirrors v1's FR4 shallow-depth
  precedent).
- Establish `.specclaw/analysis/` as the shared output directory for the
  eventual suite; relocate `/specclaw:analyze`'s existing output there
  (`skills/analyze/SKILL.md` path edit only — two lines, no logic change)
- `plugin.json` + `marketplace.json` version bump; README Commands-table row
- New parser-test cases in `tests/run-parser-tests.sh` (dependency-graph
  extractor, at least two ecosystems) plus fixture additions

### Out of Scope
- `domain-model.md`, `functional-spec.md`, `rebuild-inputs.md` and the
  commands that produce them — later changes in the roadmap (see below)
- Symbol/call-level dependency graphs — v1 of this graph is file-level only
- L4 Code diagrams beyond a small, evidence-justified sample per component —
  this command does not attempt exhaustive L4 coverage
- Multi-repo / multi-service C4 (e.g. a System Context spanning repos this
  command wasn't pointed at) — single-repo scope only, matching `/specclaw:
  analyze`'s existing subdirectory-only constraint
- Rendering Mermaid to an image/PNG, or any diagramming tool beyond plain
  Mermaid text blocks
- Wiring `architecture.md` into `specclaw-build-context`/
  `specclaw-verify-context` as an injected section (same "integration
  payoff, not now" deferral v1 made for `codebase-report.md`)
- Automated/CI invocation

## Impact

- **Files affected:** ~9 (5 new: `skills/architecture/SKILL.md`,
  `templates/architecture.md`, `agents/architecture-analyst.md`, plus test
  fixtures; 4 modified: `bin/specclaw-analyze-codebase`,
  `skills/analyze/SKILL.md`, `tests/run-parser-tests.sh`, `plugin.json` +
  `marketplace.json`, `README.md`) (estimated)
- **Complexity:** medium — reuses the now-proven skill/bin/template/agent
  shape from `analyze-command`, but the dependency-graph extractor is
  genuinely new per-stack parsing, and the Mermaid-as-C4 convention needs
  its own verification (does it actually render on GitHub) rather than
  reusing an existing pattern
- **Risk:** low — read-only, no gate changes; the one touch to
  already-shipped behavior (v1's output path) is a pure relocation with no
  logic change, verifiable by diffing `skills/analyze/SKILL.md` before/after

## Open Questions

Resolved at approval — carried into `spec.md`/`design.md` as concrete
requirements rather than left open:

- **Relocate v1's output path?** Yes. `.specclaw/codebase-report.md` →
  `.specclaw/analysis/codebase-report.md`, archive convention moves to
  `.specclaw/analysis/archive/`. Mechanical path edit in
  `skills/analyze/SKILL.md` only — `codebase-analyst.md`'s logic, the
  report's content/shape, and `bin/specclaw-analyze-codebase`'s existing
  fields are all untouched. Reasoning: the whole point of this suite is one
  shared home; leaving v1's file behind at the old path while every new
  document lands in `.specclaw/analysis/` would defeat that.
- **Mermaid diagram type: `flowchart`/`graph` + subgraphs, not native
  `C4Context`/`C4Container`/`C4Component`.** Mermaid does support dedicated
  C4 diagram types, but GitHub's and most editors' bundled Mermaid renderer
  versions have historically had inconsistent/limited support for them,
  where `flowchart`/`graph` is universally supported everywhere Mermaid
  renders at all. Given the hard requirement that diagrams "render on GitHub
  and in editors without extra tooling," universal rendering wins over
  native C4 notation icons. Container/component boundaries are represented
  via labeled subgraphs instead.
- **Dependency-graph depth: file-level only, v1.** No symbol/call graph —
  matches v1's own "shallow, no uniform depth promise" precedent for
  manifest version signals. A file-level graph is sufficient to cluster
  files into L3 components and draw L2/L3 edges; anything deeper is a
  candidate for a future v2, not blocking this suite.
- **L4 is agent-judgment, not exhaustive.** The `architecture-analyst` agent
  decides per-component whether L4 is warranted (non-obvious internal
  structure, suspected god-object, or a component worth pointing a rebuild
  effort at first) and states explicitly "L4 not warranted for this
  component" when it isn't — never silently omitted, never forced for every
  component.

## Roadmap Context

_Not part of the standard template — recorded here so the overall sequence
this change belongs to is on record, per the operator's explicit request._

This is change **1 of 3** in a plan to grow `/specclaw:analyze`'s single
technical report into a reverse-engineering documentation suite, driven by
one acceptance test: **the generated docs must be enough for an AI model to
develop a new application from them, without reading the old code.**

1. **`architecture-command`** (this change) — `/specclaw:architecture` →
   `.specclaw/analysis/architecture.md`. Goes first because it has the
   smallest new-evidence surface (one dependency graph, reusing everything
   else already collected) and because its dependency graph becomes
   groundwork change 2 can lean on when anchoring business rules and
   workflow steps to specific files.
2. **`domain-command`** (next) — `/specclaw:domain` →
   `.specclaw/analysis/domain-model.md` + `.specclaw/analysis/
   functional-spec.md`. The deepest, highest-value, highest-risk change —
   business entities/rules in plain language (every rule anchored to the
   file + routine that enforces it) and user-facing capabilities/workflows/
   UI inventory (parsed from `.dfm`/`.xaml`/`.cshtml`/`.jsx` as applicable).
   Bundled into one command because both documents need the same new
   evidence (a UI-control/menu-handler-to-routine catalog) and
   cross-reference each other. Its own task breakdown should split the
   UI-inventory collector work from the business-rule-extraction collector
   work into separate build waves — v1's verify-report already surfaced
   evidence-collection strain from a single script/agent/template doing
   several things at once; a change this large needs that lesson applied
   deliberately, not repeated.
3. **`discover-command`** (last) — an umbrella command, tentatively
   `/specclaw:discover`, that runs analyze + architecture + domain in
   sequence and then writes `.specclaw/analysis/rebuild-inputs.md`: an
   honest, per-project gap list (categorized MISSING vs DECISION) of
   everything a real rebuild needs that static analysis cannot produce
   (runtime behavior, external docs/help files, sample data, stakeholder
   decisions on platform/scale/parity/licensing). This has to come last
   structurally — a gap list can't be honest about what's missing until the
   other three have already reported what they found. Recommending a
   distinct umbrella command over a `/specclaw:analyze --full` flag: analyze
   is already shipped as a fast, single-purpose command with its own
   identity, and `rebuild-inputs.md`'s job (cross-cutting synthesis across
   three other commands' output) reads more naturally as its own
   orchestrator than as a mode bolted onto one of the three it depends on.

Explicitly out of scope for the whole roadmap, not just this change: running
the legacy application, extracting `.hlp` files, collecting sample data, and
stakeholder decisions themselves — `rebuild-inputs.md` names these, it does
not attempt them. Automated E2E test generation for the legacy system is
also out of scope; `functional-spec.md`'s workflows section is written to be
a test charter a later, separate effort could automate, not automated here.

---

**To proceed:** Review this proposal and approve to begin planning.
