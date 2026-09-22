# Proposal: Domain & Functional Documentation (`/specclaw:domain`)

**Created:** 2026-07-22
**Status:** 🟡 Draft

## Problem

_What problem are we solving? Why does it matter?_

Two of the four planned analysis documents are shipped: `/specclaw:analyze`
(technical layer — stack, dependencies, structure, prose) and
`/specclaw:architecture` (structural layer — C4 System Context through Code,
as Mermaid diagrams). Neither answers the question the manager's acceptance
test actually turns on: **what does the system do, for whom, and under what
rules?** `codebase-report.md`'s "Domain" section is a few inference-labeled
sentences by design (v1's own scope note); `architecture.md` is explicitly
domain-free (its own spec's Overview: "No — architecture is purely
structural... deferred to the next change"). Neither document names a single
business rule, walks a user workflow, or inventories a screen. Without that,
an AI model reading the suite would know the shape of the house but nothing
about what the people living in it actually do — which is exactly the gap
the acceptance test rules out.

This is change **2 of 3** in the roadmap recorded in
`.specclaw/changes/architecture-command/proposal.md`'s Roadmap Context,
confirmed there almost word-for-word: "The deepest, highest-value,
highest-risk change — business entities/rules in plain language (every rule
anchored to the file + routine that enforces it) and user-facing
capabilities/workflows/UI inventory... Bundled into one command because both
documents need the same new evidence (a UI-control/menu-handler-to-routine
catalog) and cross-reference each other." This proposal delivers exactly
that, plus the two scope refinements design-level analysis surfaced (below).

## Proposed Solution

_What are we building? High-level approach._

A new **read-only side-command**, `/specclaw:domain [path]`, that writes
**two** documents into the now-established `.specclaw/analysis/` suite
directory, both versioned via the same archive-on-rerun convention the prior
two commands use (same shared `.specclaw/analysis/archive/`, one `mv` per
document on rerun):

1. **`domain-model.md`** — business entities (attributes + meaning), their
   relationships as a Mermaid `erDiagram`, **business rules in plain
   language** (the heart of the document — every rule anchored to the file
   + routine that enforces it), and enumerations with each value's inferred
   domain meaning.
2. **`functional-spec.md`** — capabilities ("the user can X", grouped by
   functional area), end-to-end workflows as ordered sequences (Mermaid
   flowcharts where a sequence branches), a screen-by-screen UI inventory,
   and a **Named Gaps** section listing what would require running the
   legacy app to determine (explicitly not attempted here — this is raw
   material the roadmap's final change, `rebuild-inputs.md`, will later
   aggregate across all three analysis commands).

**One command, one agent, two documents** — per the roadmap's own reasoning:
both documents need the identical new evidence (which UI control triggers
which routine), so splitting collection across two commands would either
duplicate that catalog or force an artificial dependency between two
supposedly-independent side-commands. `agents/domain-analyst.md` is one
persona with an eight-row rubric (four per document), not two personas.

### The one thing that makes this change different: source-structure parsing, not manifest parsing

`analyze` and `architecture`'s bin collector
(`specclaw-analyze-codebase`) only ever reads **declarations and manifests**
— dependency names, `uses` clauses, project references. This command needs
to read **inside** source files: type/enum/const declarations, UI-control
trees, and routine bodies (to find validation logic). That's a different
kind of parsing job, which is why it gets its own script rather than a
further-extended `specclaw-analyze-codebase` — see Key Decision 1 below.

### Fact collection: `bin/specclaw-domain-collect` (new sibling script)

**Recommendation: new sibling script, not a further extension of
`specclaw-analyze-codebase`.** Reasoning:
- **Different kind of work.** The existing collector's job is "detect a
  known manifest/declaration format and extract a known field from it"
  (dependency names, a `uses` clause, a `ProjectReference`). This command's
  job is "read inside a routine body to find validation logic," "walk an
  indented `.dfm` property tree," and "map a UI event handler name to its
  implementation" — structurally different parsing, not one more format in
  the same family.
- **The existing script is already large** (grew again in
  `architecture-command`; three ecosystems' worth of extractors plus the
  new dependency-graph work). Domain adds at least three more extraction
  concerns (UI trees, type/enum/const declarations, validation-routine
  bodies) across two stacks. Bundling risks the same "one script, several
  unrelated jobs" strain the roadmap already flagged as a lesson from v1's
  verify pass — better paid down by a second script than by growing the
  first past the point either stays readable.
- **Reuse without duplication is still fully honored.** `specclaw-domain-
  collect collect <specclaw_dir> [path]` shells out to
  `specclaw-analyze-codebase collect <specclaw_dir> [path]` as its **first
  step** — the exact subprocess-reuse pattern `specclaw-analyze-codebase`
  itself already uses for `specclaw-discover-context`. This reuses path
  validation, manifests, `dependency_graph`, and `discovered_docs` with zero
  re-derivation. The only unavoidable duplication is re-enumerating the
  scoped file list (~15–20 lines: `git ls-files`/`find` fallback, same as
  every sibling script) — because none of `collect`'s existing JSON fields
  is itself "every file path in scope," only summaries derived from it, so
  a second consumer that needs to actually open specific files must
  re-enumerate. This matches the repo's own established convention (every
  script keeps its own `yaml_val()`/`json_escape()` rather than sharing a
  lib) rather than fighting it.

New deterministic facts this script collects (bash gathers, never
interprets — same split as every sibling script):

- **UI definition parsing (`.dfm` first-class, `.xaml` real-but-shallower,
  everything else named-not-parsed in v1):**
  - **`.dfm` (Delphi)** — full first-class treatment. Extracted per form:
    root object name + class, `Caption`/`Text`-shaped properties, one level
    of child-control hierarchy (name, class, caption), and every `OnClick`
    (or other `On<Event>`) property value (the handler procedure name it
    names). **Explicitly not parsed:** pixel/anchor/layout properties,
    non-visual component internals beyond name/class, deeply nested
    (2+ levels) runtime-generated control trees. **Malformed/binary-format
    `.dfm` files (pre-Delphi-5 binary resource format) are detected by their
    non-text-leading byte signature and reported as
    `"parseable": false, "reason": "binary DFM format"` — never silently
    skipped, never a parse attempt that could crash or fabricate content.**
  - **`.xaml` (.NET/WPF)** — real but shallower: XAML is well-formed XML, so
    element name, `x:Name`, and `Content`/`Header`/`Text`-shaped attribute
    values are cheap and reliable to extract the same way `.csproj`'s
    `<ProjectReference>` already is (a plain XML tag/attribute grep, no
    layout/binding/trigger interpretation).
  - **`.cshtml`/other UI formats** — **detected and counted only** in v1
    (file exists, path recorded) — not deep-parsed. Named explicitly as a
    v1.1 candidate rather than attempted at the same depth as `.dfm`/`.xaml`
    in this change. Mirrors the exact "shallow where cheap, honest where
    not" precedent `analyze-command`'s FR4 and `architecture-command`'s Key
    Decision 3 already set.
- **Menu-handler enumeration.** For every `On<Event>` property captured
  above, search scoped `.pas`/`.cs` files for the matching procedure/method
  implementation (`procedure T<Class>.<HandlerName>(...)` for Delphi,
  analogous method signature for C#) and record its file — completing the
  "menu command → routine" link `functional-spec.md`'s Capabilities and
  Workflows sections need.
- **Main-form detection (a hint, never required).** Best-effort: parse a
  `.dpr` file's first `Application.CreateForm(T<X>, ...)` call to name the
  probable main form. If no `.dpr` is in scope (e.g. `[path]` scoped to a
  subdirectory) or the pattern doesn't match, this field is simply absent
  — **every detected form is still surfaced regardless**, so a missing hint
  never hides a form.
- **Type/enum/const declaration extraction** from `.pas` `interface`
  sections (bounded-block `awk`, same idiom as every existing extractor):
  enum type declarations (`TWaterQuality = (wqNone, wqChem, ...);`) captured
  fully as name + value list; `record`/`class` type declarations captured as
  name + kind + file/line only (the collector does **not** attempt to parse
  Pascal field-declaration syntax — the agent opens the file itself to read
  fields, same "read the real file before asserting structure" discipline
  `codebase-analyst`/`architecture-analyst` already follow); `const` blocks
  captured as name + literal value where the value is a simple scalar.
- **Business-rule candidate extraction (the collector's most novel job, and
  purely a candidate list — the agent decides what's a real rule).**
  Heuristic name-pattern match against routine names
  (`Valid*`/`Validate*`/`Check*`/`Can*`, case-insensitive) plus a depth-
  counted `begin`/`end` scan (increment on `begin`, decrement on a matching
  `end;`, stop at depth 0) to capture each candidate routine's full body as
  raw text, size-capped like `specclaw-verify collect`'s 200-line file cap.
  **Known, accepted limitation:** the depth counter has no concept of
  comments or string literals, so a comment or string containing the literal
  word `begin`/`end` could misalign it — the same "no real parser, grep/awk
  best-effort" tolerance every extractor in this codebase already accepts,
  named explicitly rather than silently risked.

### `agents/domain-analyst.md` — one persona, eight-row rubric

Mirrors `architecture-analyst.md`'s shape (`tools: [Read, Write, Bash]`,
`model: sonnet`, Evidence Discipline section, explicit inference-labeling
rule). Rubric: **Entities / Relationships / Business Rules / Enumerations**
(→ `domain-model.md`) and **Capabilities / Workflows / UI Inventory / Named
Gaps** (→ `functional-spec.md`). Two hard rules carried over verbatim from
the manager's brief, not softened:
- **Domain semantics are inference, always labeled** — the same
  `Inference:` / `Inference (low confidence):` prefixing rule
  `codebase-analyst.md` already uses for its Domain section, applied to
  every entity/rule/enum-value meaning in this document.
- **A rule with unclear intent is recorded mechanically, never
  rationalized** — e.g. "rejects values > 100 — reason not evident" instead
  of inventing a plausible-sounding explanation for a magic number. A
  confidently-wrong business rule is worse than a gap, because a rebuild
  effort would silently build the wrong rule into the new system.

### Templates

`templates/domain-model.md` (header + Entities/Relationships/Business
Rules/Enumerations sections, `erDiagram` Mermaid placeholder) and
`templates/functional-spec.md` (header + Capabilities/Workflows/UI
Inventory/Named Gaps sections, `flowchart` Mermaid placeholders where
workflows branch) — same `{{placeholder}}` scaffold convention as every
other template.

### Skill orchestration

`skills/domain/SKILL.md` mirrors `skills/architecture/SKILL.md` exactly:
ensure-init → `specclaw-domain-collect collect .specclaw [path]` (die-and-
stop on non-zero exit, validation lives inside the collector via its
subprocess call to `specclaw-analyze-codebase collect`, not reimplemented)
→ archive **both** prior documents if they exist (two `mv`s into the same
shared `.specclaw/analysis/archive/`) → spawn `Agent`
(`subagent_type: "domain-analyst"`, model from `models.review`) → agent
writes both files itself → summarize (capabilities/rules/entities counted,
any Named Gaps flagged).

## Scope

### In Scope
- `skills/domain/SKILL.md` (`/specclaw:domain [path]`)
- `bin/specclaw-domain-collect` (`collect <specclaw_dir> [path]` subcommand)
  — wraps `specclaw-analyze-codebase collect`, adds `.dfm`/`.xaml` UI
  parsing, menu-handler mapping, main-form hint, type/enum/const
  declarations, business-rule candidate extraction
- `agents/domain-analyst.md` (8-row rubric, both documents)
- `templates/domain-model.md` + `templates/functional-spec.md`
- `.dfm` first-class parsing (valid text-format + malformed/binary-format
  detection); `.xaml` real-but-shallower parsing; `.cshtml`/other UI formats
  detected-and-counted only
- Delphi (`.pas`) type/enum/const declaration extraction and validation-
  routine candidate extraction; a comparable but likely shallower first cut
  for C# (`.cs`) method-body candidate extraction, matched to whatever depth
  design.md finds is cheap and reliable — **not** promised at the same
  literal depth as the Delphi/EPANET-driven examples in this proposal
- Parser tests: at least one well-formed `.dfm` fixture, one malformed/
  binary-format `.dfm` fixture, one enum + one validation-routine-shaped
  `.pas` fixture — extending the existing `tests/fixtures/analyze/` tree
  where it fits the coherent-project narrative already established there,
  per design.md's exact layout call
- Version bump (`plugin.json` + `marketplace.json`) + README Commands rows

### Out of Scope
- `rebuild-inputs.md` and the `discover-command` umbrella that produces it
  — change 3 of 3, cannot honestly be written before this change's gaps are
  known
- Running the legacy application, `.hlp` file extraction, screenshots,
  sample data collection, or any other evidence that requires the app to
  actually execute — `functional-spec.md`'s Named Gaps section **names**
  these, it does not attempt them
- Cross-repo/external-repo `[path]` — same v2 deferral every prior command
  in this suite carries
- Deep `.cshtml`/Razor UI parsing, and any UI framework beyond
  `.dfm`/`.xaml` — named as v1.1 candidates, not attempted here
- Symbol-level or call-graph-level business-rule tracing (e.g. "this UI
  field's value flows through 3 functions before the actual validation") —
  v1 anchors a rule to the routine that directly enforces it, not a full
  data-flow trace
- Automated E2E test generation from `functional-spec.md`'s workflows — the
  workflows section is written to be a test charter a **later, separate**
  effort could automate, not automated as part of this change

## Impact

- **Files affected:** ~9 (6 new: `skills/domain/SKILL.md`,
  `bin/specclaw-domain-collect`, `agents/domain-analyst.md`,
  `templates/domain-model.md`, `templates/functional-spec.md`, new fixture
  files; 3 modified: `tests/run-parser-tests.sh`, `plugin.json` +
  `marketplace.json`, `README.md`) (estimated)
- **Complexity:** large — this is the roadmap's own "deepest,
  highest-value, highest-risk change" by design; genuinely new parsing
  (indented `.dfm` trees, depth-counted routine-body extraction, Pascal
  type/enum/const declarations) across two documents and (at meaningfully
  different depths) two language stacks
- **Risk:** medium — read-only and no gate changes, so the usual "worst
  case is an inaccurate report, not data loss" floor still holds, but the
  business-rule-extraction heuristic (name/pattern matching, no real
  parser) has more room to miss a real rule or mis-bound a routine body than
  anything the two prior commands attempted; mitigated by the mandatory
  malformed-fixture requirement and by treating collected candidates as
  "evidence to read," never "facts to assert," in the agent's rubric

## Open Questions

Resolved at approval — carried into `spec.md`/`design.md` as concrete
requirements rather than left open:

- **Sibling script, not an extension.** `bin/specclaw-domain-collect` is a
  new script that wraps `specclaw-analyze-codebase collect` via subprocess
  call — reasoning above (different kind of parsing, existing script
  already large, reuse still fully honored via the subprocess call rather
  than re-derivation).
- **One agent, two documents.** `agents/domain-analyst.md` — matches the
  roadmap's own recorded reasoning (shared UI-control/handler evidence,
  cross-referencing documents) rather than splitting into two personas or
  two commands.
- **`.dfm` gets full first-class treatment; `.xaml` gets real-but-shallower;
  everything else gets detection-only in v1.** Not a uniform promise across
  every UI format — the same "shallow where cheap, honest where not"
  pattern this suite has used from `analyze-command`'s FR4 onward.
- **Malformed/binary-format `.dfm` files are detected and reported, never
  silently skipped or crashed on.** A dedicated fixture is mandatory, per
  the operator's explicit instruction — this is new, real parsing, not a
  known-safe format extension.
- **Main-form detection is a hint, never a requirement.** Every detected
  form is surfaced regardless of whether the `.dpr`-based main-form guess
  succeeds.
- **Business-rule extraction is candidate-surfacing, not rule-asserting.**
  The bash collector's job stops at "here is a routine whose name and shape
  suggest a validation rule, here is its raw body text" — the agent decides
  whether it's a real rule, states it in plain language, and anchors it to
  file + routine. A rule the agent cannot anchor to an opened file is
  dropped, never asserted from the candidate list alone.
- **Task-wave discipline, set now so it isn't forgotten at plan time.** Per
  this change's own entry in `architecture-command/proposal.md`'s Roadmap
  Context: the UI-inventory collector work and the business-rule-extraction
  collector work are split into separate build waves — the two are
  different-enough parsing concerns that verifying them together risks the
  same evidence-collection strain the roadmap already flagged as a lesson
  from v1.

## Roadmap Context

_Confirming this change's place in the sequence recorded in
`.specclaw/changes/architecture-command/proposal.md`'s Roadmap Context —
not re-deciding it._

This is change **2 of 3**: `architecture-command` (shipped) →
**`domain-command`** (this proposal) → `discover-command` (last — an
umbrella running all three and writing `rebuild-inputs.md`, which cannot be
honest about what's missing until this change's gaps, particularly its
Named Gaps section, actually exist to synthesize from). No change to that
recorded sequence or to `discover-command`'s scope is made here.

---

**To proceed:** Review this proposal and approve to begin planning.
