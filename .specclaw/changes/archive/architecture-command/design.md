# Design: C4 Architecture Views (`/specclaw:architecture`)

**Change:** architecture-command
**Created:** 2026-07-22

## Technical Approach

Five touch points: one extended script, two new files, two mechanically
edited existing files.

1. **`bin/specclaw-analyze-codebase` — extend `collect`, don't duplicate.**
   The existing `cmd_collect` already does file enumeration, scoping, and
   manifest extraction; this change adds one more collection step (step 3.5,
   between manifest detection and LOC counting) that reuses the same scoped
   file list (`tmp_scoped`) already built for every other step — no second
   enumeration pass.

   ```bash
   # New: dependency-graph extraction (additive field, no existing field touched)
   graph_tmp="$(mktemp)"

   # Delphi: uses-clause -> file resolution
   while IFS= read -r pas_file; do
     [ -z "$pas_file" ] && continue
     case "${pas_file##*/}" in *.pas) ;; *) continue ;; esac
     extract_uses_clause_units "$project_root/$pas_file" | while IFS= read -r unit; do
       resolved="$(resolve_unit_to_scoped_file "$unit" "$tmp_scoped")"
       [ -n "$resolved" ] && printf '{"from":"%s","to":"%s","kind":"uses"}\n' \
         "$(json_escape "$pas_file")" "$(json_escape "$resolved")" >> "$graph_tmp"
     done
   done < "$tmp_scoped"

   # Node/JS/TS: relative require()/import resolution — same shape, different
   # extractor + resolver (try literal path + .js/.jsx/.ts/.tsx/index.{js,ts}).

   # .NET: <ProjectReference Include="...csproj"> — grep per scoped .csproj,
   # resolve relative to the referencing file's directory, no case-fold needed.
   ```

   - **`extract_uses_clause_units(file)`** — an `awk` state machine bounded
     by `uses` (case-insensitive keyword, start of a statement) and the next
     `;`, printing one unit name per line, splitting on commas — the same
     bounded-block technique `extract_maven_deps` already uses for
     `<dependency>...</dependency>`.
   - **`resolve_unit_to_scoped_file(unit, files_file)`** — case-insensitive
     match of `<unit>.pas` against the scoped file list's basenames; prints
     the matching scoped-relative path, or nothing if unresolved. Mirrors
     `match_files_by_name`'s existing basename-glob approach, case-folded.
   - **Node extractor** — `grep -oE "require\(['\"]\.\.?/[^'\"]+['\"]\)|from ['\"]\.\.?/[^'\"]+['\"]"` per
     scoped `.js`/`.jsx`/`.ts`/`.tsx` file, then a resolver that joins the
     specifier to the importing file's directory and probes the scoped file
     list for the literal path, then each of `.js`/`.jsx`/`.ts`/`.tsx`/
     `/index.js`/`/index.ts` in turn.
   - **.NET extractor** — `grep -oE '<ProjectReference[[:space:]]+Include="[^"]+\.csproj"'`
     per scoped `.csproj`, resolved relative to the referencing project's
     directory (`dirname` + the captured relative path, normalized). A
     distinct extractor from `extract_dotnet_deps` (which only sees
     `<PackageReference>`) — both read the same file, for different
     purposes, and both stay best-effort/`|| true`.
   - **Go/Rust/Python/Java/Maven/Make** — no extractor added. `dependency_graph`
     simply accumulates zero entries for files of these types.
   - Final assembly: `graph_tmp`'s lines become the `dependency_graph` array
     the same way `manifests_tmp`'s lines already become the `manifests`
     array — read line-by-line, comma-joined, wrapped in `[...]`. New field
     inserted into the existing `cat <<ENDJSON` heredoc between
     `test_locations` and `discovered_docs`; every existing field's
     construction is untouched.

2. **`agents/architecture-analyst.md`** — persona file, structured like
   `codebase-analyst.md`: frontmatter (`name`, `description`, `tools: [Read,
   Write, Bash]`, `model: sonnet`), an Inputs section (collected JSON
   including `dependency_graph`, target path; reads
   `templates/architecture.md` before writing, same "don't invent new
   sections" instruction `codebase-analyst.md` already carries), a
   four-row rubric (System Context / Containers / Components / Code), an
   Evidence Discipline section adapted from `codebase-analyst.md`'s, an
   explicit **L4 rule** ("produce L4 only for a component whose internal
   structure is non-obvious, is a suspected god-object, or is where you'd
   point a rebuild effort first; for every other component, write exactly
   'L4 not warranted for this component' — never omit the line silently"),
   and a **Mermaid convention** with a literal example in the Output
   section:
   ```mermaid
   flowchart TD
     user([User]):::person
     subgraph sys["Analyzed System"]
       subgraph containerA["Container: <name>"]
         compA["Component: <name>"]
         compB["Component: <name>"]
       end
     end
     user --> sys
     compA --> compB
   ```
   L1 uses `person`-styled nodes for external actors and one box for the
   system boundary; L2 nests one `subgraph` per container; L3 nests one
   `subgraph` per container with one node per component inside it, edges
   drawn from `dependency_graph`; L4 (where warranted) is a smaller
   `flowchart` of the functions/classes inside one component, grounded in
   files the agent opened directly (not from `dependency_graph`, which is
   file-level only).

3. **`templates/architecture.md`** — header (`{{title}}`, `{{path}}`,
   `{{date}}`) plus four sections, each pairing a fenced ` ```mermaid `
   placeholder with a prose placeholder: `{{l1_diagram}}`/`{{l1_narrative}}`
   … `{{l4_diagram}}`/`{{l4_narrative}}`.

4. **`skills/architecture/SKILL.md`** — orchestration prose, same shape as
   `skills/analyze/SKILL.md`: ensure-init → `specclaw-analyze-codebase
   collect .specclaw [path]` (die-and-stop on non-zero exit, no
   reimplemented validation) → archive prior `.specclaw/analysis/
   architecture.md` if present (`mkdir -p .specclaw/analysis/archive && mv
   ...`) → spawn `Agent` (`subagent_type: "architecture-analyst"`, model
   from `config.yaml` `models.review`) with the collected JSON + resolved
   path → agent writes the file → summarize.

5. **Relocation (mechanical, two files + one migration check):**
   - `skills/analyze/SKILL.md` — frontmatter description and the archive
     step's two path strings change from `.specclaw/codebase-report.md` /
     `.specclaw/codebase-reports/archive/` to
     `.specclaw/analysis/codebase-report.md` /
     `.specclaw/analysis/archive/`. **New sub-step added before the normal
     archive check:** if `.specclaw/codebase-report.md` (the OLD path)
     exists and `.specclaw/analysis/codebase-report.md` does not yet exist,
     `mv` the old-path file into `.specclaw/analysis/archive/
     $(date +%Y-%m-%d-%H%M%S)-codebase-report.md` first — a one-time
     migration, not a new steady-state behavior; on every subsequent run
     the old path is simply absent and this check is a no-op `[ -f ... ]`
     test.
   - `agents/codebase-analyst.md` — description line, Identity line, and
     Output section's file path updated to
     `.specclaw/analysis/codebase-report.md`. No change to its rubric,
     evidence discipline, or report shape.

No `specclaw-validate-change` case arm is added — same as `analyze`, this
command doesn't validate a `<change>`, it doesn't have one.

## Architecture

```
User: /specclaw:architecture [path]
        │
        ▼
skills/architecture/SKILL.md  (orchestration prose, not executable)
        │
        ├─ specclaw-ensure-init .specclaw
        ├─ bin/specclaw-analyze-codebase collect .specclaw [path]
        │     ├─ (unchanged) file enum / manifests / LOC / test-locations / discovered_docs
        │     └─ (NEW) dependency_graph: uses-clauses (Delphi) + relative imports (Node)
        │               + ProjectReference (.NET) — scoped, additive field
        │        → one JSON object to stdout (die-before-work on bad [path])
        ├─ archive prior .specclaw/analysis/architecture.md (if any)
        ├─ Agent(subagent_type: "architecture-analyst", <JSON payload incl. dependency_graph>)
        │     ├─ reads templates/architecture.md for shape
        │     ├─ Read tool: opens files for L1–L4 evidence
        │     └─ writes .specclaw/analysis/architecture.md   (L1→L4, Mermaid flowchart+subgraphs)
        └─ summary to user

Separately, this change also edits (mechanical relocation, FR9):
skills/analyze/SKILL.md            → .specclaw/analysis/codebase-report.md
agents/codebase-analyst.md         → .specclaw/analysis/codebase-report.md
  (+ one-time migration of a pre-existing OLD-path report into the archive)
```

Data flow is one-directional and read-only end to end: nothing under
`PROJECT_ROOT` other than `.specclaw/analysis/` contents is ever written.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/skills/architecture/SKILL.md` | create | `/specclaw:architecture [path]` orchestration (FR1, FR2, FR7, FR8) |
| `plugins/specclaw/bin/specclaw-analyze-codebase` | modify | Additive `dependency_graph` field on `collect`'s output (FR3, FR4, FR11) |
| `plugins/specclaw/templates/architecture.md` | create | C4 L1–L4 scaffold, Mermaid placeholders (FR6) |
| `plugins/specclaw/agents/architecture-analyst.md` | create | Fixed C4 rubric persona (FR5) |
| `plugins/specclaw/skills/analyze/SKILL.md` | modify | Output-path relocation + one-time old-path migration (FR9.1, FR9.3) |
| `plugins/specclaw/agents/codebase-analyst.md` | modify | Output-path relocation only, no logic change (FR9.2) |
| `plugins/specclaw/tests/run-parser-tests.sh` | modify | New case: `dependency_graph` extraction (FR11, AC1–AC7) |
| `plugins/specclaw/tests/fixtures/analyze/` | modify | Extend (not duplicate) the existing fixture: `.pas` pair with `uses`, `.js` pair with relative `require`, second `.csproj` with `ProjectReference` |
| `plugins/specclaw/.claude-plugin/plugin.json` | modify | Version bump (FR10) |
| `.claude-plugin/marketplace.json` | modify | Version bump, kept in sync (FR10) |
| `README.md` | modify | New `/specclaw:architecture` row + existing `/specclaw:analyze` row's path text updated (FR9, FR10, AC16) |

## Data Model Changes

New on-disk artifacts:
- `.specclaw/analysis/architecture.md` — current C4 report (stable path).
- `.specclaw/analysis/archive/<YYYY-MM-DD-HHMMSS>-architecture.md` — prior
  architecture reports.

Relocated (not new) artifacts:
- `.specclaw/analysis/codebase-report.md` — was `.specclaw/codebase-report.md`.
- `.specclaw/analysis/archive/<YYYY-MM-DD-HHMMSS>-codebase-report.md` — was
  under `.specclaw/codebase-reports/archive/`; also receives any pre-upgrade
  report found at the old path (one-time migration, FR9.3).

`dependency_graph` is a new field on `specclaw-analyze-codebase collect`'s
JSON output — additive, no schema change to the six existing fields.
`STATUS.md` and every `changes/<name>/` artifact remain untouched (NFR4).

## API Changes

New CLI surface:
- `/specclaw:architecture [path]` (skill/slash command).
- `bin/specclaw-analyze-codebase collect` — same signature, one new field
  in its JSON output (`dependency_graph`). No new subcommand; no existing
  field's shape changes.

## Key Decisions

1. **Extend the existing `collect`, don't add a second script or
   subcommand.** Per the hard requirement to reuse rather than re-derive:
   `dependency_graph` needs the exact same scoped file list `collect`
   already builds for manifests/LOC/test-locations, so it's a new step
   inside the same function, not a second pass or a sibling script that
   would have to re-enumerate and re-scope from scratch.
2. **Refine the proposal's ".NET `using`-directives" into
   `<ProjectReference>` extraction.** `using` directives reference
   namespaces, not files — there's no cheap, reliable namespace-to-file
   mapping. `<ProjectReference>` in `.csproj` is a genuine, cheap,
   file-adjacent (project-level) dependency edge already sitting in a file
   `extract_dotnet_deps` already reads for an unrelated purpose
   (`<PackageReference>`). This is the same kind of proposal→design
   refinement `analyze-command`'s own design.md made for Delphi version
   signals (Key Decision 5 there) — stated explicitly here per Rule 1
   (Think Before Coding): don't silently pick between interpretations,
   state the reasoning.
3. **Go/Rust/Python/Java/Maven/Make get no `dependency_graph` contribution
   in v1.** No cheap, reliable file-level signal exists for these the way
   `uses`/relative-`import`/`ProjectReference` do for Delphi/Node/.NET.
   Mirrors `analyze-command`'s own FR4 precedent: shallow coverage stated
   honestly beats guessed coverage. Named as a v2 candidate.
4. **Mermaid `flowchart`/`graph` + `subgraph`, not native C4 diagram
   types.** Universal renderer support (GitHub, VS Code, plain mermaid.js)
   outweighs native C4 notation icons — a proposal-level decision, restated
   here because it drives `agents/architecture-analyst.md`'s concrete
   Output-section example.
5. **L4 is agent judgment, stated explicitly either way.** Exhaustive L4
   for every component would bloat the report and re-introduce the "prose
   nobody reads" problem this change exists to fix. The agent must still
   *say* "L4 not warranted" rather than silently skip a component, so a
   reader never has to wonder whether L4 was forgotten or deliberately
   skipped.
6. **Relocate v1's output path as part of this change, including a
   one-time migration check — not a silent new default.** Established in
   the approved proposal's Open Questions. The migration check (FR9.3) is
   the one piece of genuinely new logic in an otherwise mechanical edit: a
   real user (the operator's own manager, on EPANET) has already run
   `/specclaw:analyze` under v1's old path, so "just change the path
   in the skill" would orphan their existing report the next time they
   upgrade and re-run. Handled as a `[ -f <old_path> ]` check that becomes
   a permanent no-op after the first post-upgrade run on any given project.
7. **Archive directory is shared, not per-document-type.** Both
   `<timestamp>-architecture.md` and `<timestamp>-codebase-report.md` land
   in the same `.specclaw/analysis/archive/`, distinguished by filename —
   avoids proliferating one archive subdirectory per document type as the
   suite grows to five documents across three more changes.

## Grounding sources

- `docs/specclaw-architecture-notes.md` §6 — the extension recipe this
  change follows for the third time (skill/bin/template/agent shape,
  JSON-facts-only bin script, side-command classification).
- `.specclaw/changes/architecture-command/proposal.md` — the roadmap
  context, the command-shape argument, and the two Open Questions this
  design implements (relocation, Mermaid convention).
- `plugins/specclaw/bin/specclaw-analyze-codebase` — the exact `cmd_collect`
  function this change extends; `extract_maven_deps`'s bounded-block `awk`
  idiom reused for `uses`-clause extraction; `match_files_by_name`'s
  basename-glob approach reused (case-folded) for unit-name resolution.
- `plugins/specclaw/agents/codebase-analyst.md` — the fixed-rubric persona
  shape (`tools:`/`model:` frontmatter, Evidence Discipline section,
  quote-or-drop finding rule) `architecture-analyst.md` mirrors.
- `plugins/specclaw/skills/analyze/SKILL.md` L17–L22 — the exact archive
  step (`mkdir -p .../archive && mv ...`) whose two path strings this
  change edits, and whose pattern the new architecture skill's own archive
  step copies verbatim in shape.
- `.specclaw/changes/analyze-command/design.md` Key Decision 5 — the
  precedent for "state a proposal→design refinement explicitly, with
  reasoning" that this design's Key Decision 2 follows for the .NET signal.

## Risks & Mitigations

- **Case-insensitive Delphi unit-name resolution could false-match an
  unrelated file that happens to share a basename** (e.g. two `Utils.pas`
  files in different subdirectories, one out of scope) → mitigated by
  resolving only against the already-scoped file list (never the full
  repo), same containment discipline every other field already applies.
- **The one-time old-path migration (FR9.3) is new logic in what's
  otherwise a mechanical relocation, and is the one piece of this change
  most likely to be under-tested** → mitigated by AC13's dedicated test
  (pre-existing old-path file, confirm it's archived not orphaned) and by
  the check's own no-op-after-first-run design limiting its exposure window
  to exactly one run per project.
- **`.csproj` files can contain both `<PackageReference>` and
  `<ProjectReference>` — a hasty regex could conflate them** → mitigated by
  AC5's explicit assertion that a `ProjectReference` path must NOT appear in
  the manifest's own `dependencies` list, and by using an anchored tag-name
  match (`<ProjectReference` vs the existing `<PackageReference` extractor)
  rather than a shared/looser pattern.
- **Node relative-import resolution (trying five suffix variants per
  specifier) is the most guess-prone extractor in this change** → mitigated
  by requiring a literal filesystem match against the already-scoped file
  list for every variant (never assume a match — probe and drop if none
  resolves), same "resolve-or-drop" discipline as the Delphi extractor.
- **Mermaid `flowchart`/`subgraph` C4 approximation could look wrong or
  inconsistent across runs without a concrete example to anchor to** →
  mitigated by `agents/architecture-analyst.md`'s Output section carrying a
  literal Mermaid example (this design's §"Technical Approach" item 2), not
  just a prose description of the convention.
