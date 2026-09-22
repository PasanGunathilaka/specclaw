# Spec: Domain & Functional Documentation (`/specclaw:domain`)

**Change:** domain-command
**Created:** 2026-07-22
**Status:** 🟡 Draft

## Overview

Add a read-only side-command, `/specclaw:domain [path]`, that writes two
documents into `.specclaw/analysis/`: `domain-model.md` (business entities,
relationships, business rules, enumerations) and `functional-spec.md`
(user-facing capabilities, workflows, UI inventory, named gaps). One new
bin script, `bin/specclaw-domain-collect`, delegates to
`specclaw-analyze-codebase collect` for everything that script already
gathers (manifests, `dependency_graph`, discovered docs) and adds the new
facts this command needs: UI-definition parsing (`.dfm` first-class,
`.xaml` shallower, other formats detection-only), menu/event-handler-to-
routine mapping, Pascal type/enum/const declarations, and business-rule
candidate extraction from routine bodies. One agent, `domain-analyst`,
produces both documents from one eight-row rubric. Same archive-on-rerun
convention as `analyze`/`architecture`, same shared `.specclaw/analysis/
archive/` directory, no lifecycle gate.

This is change 2 of 3 in the roadmap recorded in
`.specclaw/changes/architecture-command/proposal.md`.

## Requirements

### Functional Requirements

- **FR1 — New skill.** `skills/domain/SKILL.md` registers `/specclaw:domain
  [path]`. Model-invokable (no `disable-model-invocation`) — read-only, no
  TTY/credential handling. Opens with the `specclaw-ensure-init .specclaw`
  boilerplate every skill uses.
- **FR2 — Path scoping, reused not reimplemented.** `[path]` semantics are
  identical to `/specclaw:analyze`/`/specclaw:architecture`'s (default:
  repository root; must resolve inside the repo; rejected if `.specclaw`
  itself or nested inside it). Neither the skill nor the new bin script
  reimplements this validation — `specclaw-domain-collect` delegates to
  `specclaw-analyze-codebase collect`, which already dies with a clear
  stderr message and non-zero exit on a bad path before any work happens.
- **FR3 — `bin/specclaw-domain-collect collect <specclaw_dir> [path]`.**
  New script, same subcommand-dispatch shape as its two siblings
  (`-h|--help`, `case "$1" in collect) ... esac`). Internally:
  1. Calls `specclaw-analyze-codebase collect "$specclaw_dir" "$target_path"`
     as a subprocess and captures its JSON verbatim.
  2. **Merges, not nests**, that JSON's top-level fields (`path`,
     `project_root`, `top_level_dirs`, `manifests`, `loc_by_extension`,
     `test_locations`, `dependency_graph`, `discovered_docs`) into this
     script's own output object, by stripping the delegated JSON's
     outer `{`/`}` (safe: the string is known to start with `{` and end
     with `}`, and analyze-codebase's own `json_escape()` guarantees no
     unescaped brace can appear at those exact boundary positions) and
     splicing its body in as one comma-joined chunk alongside the new
     fields below — a flat object, not `{"delegated_collect": {...}}`, so
     `domain-analyst` reads one payload, not two.
  3. Re-enumerates the scoped file list itself (same `git ls-files`/`find`
     fallback every sibling script uses — the delegated JSON has no field
     that is itself "every file path in scope," only summaries derived from
     it, so a consumer that needs to open specific files must re-derive the
     list; this is the one accepted, minimal duplication, consistent with
     this repo's no-shared-lib convention) to locate `.dfm`, `.xaml`,
     `.cshtml`(+ other UI-shaped extensions, detection only), `.pas`, `.cs`,
     and `.dpr` files within scope, feeding FR4–FR10 below.
  4. Emits one JSON object to stdout, jq-validated when present, printed
     either way (same tolerant pattern every sibling `collect` uses).
- **FR4 — `.dfm` parsing (Delphi, first-class).** For every scoped `.dfm`
  file:
  - **Text-format files** (the file's first non-blank line matches
    `^(object|inherited)\b`, allowing an optional UTF-8 BOM before it):
    parsed via a depth-counted scan (`object`/`inherited` lines increment
    depth, a bare `end` line decrements it). Produces:
    - `root_name`, `root_class`, `root_caption` (the form's own
      `Caption`/`Text`/`Hint`-shaped property, if present).
    - `controls[]` — one entry per object at depth 1 (direct children of
      the form root only — **not** deeper): `{name, class, caption}`.
    - `handlers[]` — one entry per `On<Event> = <HandlerName>` property
      found **at any depth in the tree**, not capped at depth 1 (menus
      nest 2–3 levels deep and are exactly the evidence this command
      needs): `{object_name, object_class, event, handler_name}`. A
      property belongs to the most recently opened, not-yet-closed
      `object`/`inherited` block — property lines are read as the
      contiguous span immediately following an `object`/`inherited` line,
      before its first nested child or its own closing `end` (Delphi's
      form designer always serializes an object's own properties before
      its children, so this span is reliable without a full per-object
      property stack).
  - **Non-text (binary-format) or unrecognized-structure files** — the
    same first-non-blank-line check failing marks the entry
    `"parseable": false, "reason": "binary DFM format (or unrecognized
    text structure)"`. Never attempted, never a crash, never silently
    dropped from the output — the entry still appears, just without
    `controls`/`handlers`.
  - **Explicitly not parsed for any `.dfm` file:** layout/anchor/size
    properties, non-visual component internals beyond name/class, control
    hierarchy beyond depth 1 (except handlers, per above), and binary
    property blocks (`{...}`-delimited hex data, e.g. glyphs/pictures) —
    skipped over, not decoded.
- **FR5 — `.xaml` parsing (.NET, real but shallower).** For every scoped
  `.xaml` file: plain XML tag/attribute extraction (same cheap-and-reliable
  approach `.csproj`'s `<ProjectReference>` already uses) of element name,
  `x:Name` attribute, and `Content`/`Header`/`Text`-shaped attribute values,
  one level of nesting. No binding/trigger/style/layout interpretation.
- **FR6 — Other UI formats (`.cshtml`, and any UI-shaped file not covered
  by FR4/FR5) — detection only.** Path recorded, `"parseable": false,
  "reason": "not deep-parsed in v1 — detection only"`. Never attempted at
  FR4/FR5's depth. Explicit v1.1 candidate, not silently absent.
- **FR7 — Handler-to-implementation mapping.** For every `handler_name`
  captured in FR4/FR5, search scoped `.pas`/`.cs` files for its
  implementation: a `procedure T<Class>.<HandlerName>(...)` signature
  (Delphi) or an analogous method signature (C#). Record
  `{handler_name, file, line}` when found; omit the entry (not a fabricated
  guess) when no matching implementation is found in scope.
- **FR8 — Main-form hint (optional, never required).** Best-effort: if a
  `.dpr` file is in scope, parse its first `Application.CreateForm(T<X>,
  ...)` call and record `main_form_hint: "<X>"`. If no `.dpr` is in scope
  (e.g. `[path]` scoped to a subdirectory) or the pattern doesn't match,
  `main_form_hint` is simply absent (`null`) — **every detected form still
  appears in `forms[]` regardless of whether this hint resolves.**
- **FR9 — Type/enum/const declaration extraction (Pascal `interface`
  sections).** Bounded-block scan between `interface` and `implementation`
  (same in-section idiom as `extract_maven_deps`/`extract_uses_clause_units`),
  multi-line-tolerant (an enum's identifier list may span lines, accumulated
  until its closing `);`, same technique the `uses`-clause extractor
  already uses):
  - **Enum type declarations** (`<Name> = (<id1>, <id2>, ...);`) — full
    capture: `{name, kind: "enum", values: [...], file, line}`.
  - **`record`/`class` type declarations** (`<Name> = record|class ...`) —
    name/kind/location only: `{name, kind: "record"|"class", file, line}`.
    Field lists are **not** parsed in bash — the agent opens the file
    itself to read them (same "read the real file before asserting
    structure" discipline `codebase-analyst`/`architecture-analyst` already
    follow).
  - **`const` declarations** with a simple scalar value (a bare number or a
    single quoted string — not a computed expression) — `{name, value,
    file, line}`.
- **FR10 — Business-rule candidate extraction (bash surfaces candidates
  only; the agent decides what's a real rule).** Scan scoped `.pas`/`.cs`
  files for routine signatures whose name matches, case-insensitively,
  `Valid*`, `Validate*`, `Check*`, or `Can*`. For each match, capture the
  full routine body via a depth-counted `begin`/`end` scan (increment on
  `begin`, decrement on a matching `end;`, stop at depth 0), size-capped at
  100 lines (truncation labeled `"... (truncated, N total lines)"`, same
  labeling convention `specclaw-verify collect` already uses at its own
  200-line cap). **Known, accepted limitation, stated explicitly, not
  silently risked:** the depth counter has no concept of comments or string
  literals — a comment or string containing the literal word `begin`/`end`
  can misalign it. This is the same "no real parser, best-effort text scan"
  tolerance every extractor in this script already accepts.
- **FR11 — `agents/domain-analyst.md`.** One persona (mirrors
  `architecture-analyst.md`'s shape: `tools: [Read, Write, Bash]`, `model:
  sonnet`), an eight-row rubric — **Entities / Relationships / Business
  Rules / Enumerations** (→ `domain-model.md`) and **Capabilities /
  Workflows / UI Inventory / Named Gaps** (→ `functional-spec.md`) — an
  Evidence Discipline section (every entity/rule/capability/control
  anchored to a collected fact or a file the agent opened itself), an
  explicit **Domain Inference Rule** (every entity/rule/enum-value meaning
  is prefixed `Inference:`, low-confidence ones `Inference (low
  confidence):`, mirroring `codebase-analyst.md`'s existing rule verbatim),
  and an explicit **Mechanical Recording Rule**: when a rule's intent is
  unclear from the code (a magic number, an unexplained guard), record it
  mechanically ("rejects values > 100 — reason not evident") rather than
  inventing a plausible-sounding rationale.
- **FR12 — `templates/domain-model.md` + `templates/functional-spec.md`.**
  `{{placeholder}}` scaffolds, same convention as every other template.
  `domain-model.md`: header + Entities / Relationships (with a fenced
  ` ```mermaid ` `erDiagram` placeholder) / Business Rules / Enumerations.
  `functional-spec.md`: header + Capabilities / Workflows (with fenced
  ` ```mermaid ` `flowchart` placeholders where a workflow branches) / UI
  Inventory / Named Gaps.
- **FR13 — Skill orchestration.** `skills/domain/SKILL.md` steps: (1)
  `specclaw-ensure-init .specclaw`; (2) run `specclaw-domain-collect
  collect .specclaw [path]` — non-zero exit surfaces stderr verbatim and
  stops; (3) archive **both** prior documents if they exist (two `mv`s,
  same shared `.specclaw/analysis/archive/` directory `analyze`/
  `architecture` already use, distinguished by filename); (4) spawn `Agent`
  (`subagent_type: "domain-analyst"`, model from `config.yaml`
  `models.review`) with the collected JSON and resolved path; (5) the agent
  writes both files itself; (6) present a short summary — path analyzed,
  entity/rule/capability counts, any Named Gaps flagged.
- **FR14 — Versioned output, shared archive directory.** Both
  `domain-model.md` and `functional-spec.md` follow the exact
  archive-on-rerun convention `analyze`/`architecture` already established
  — same directory, filename-distinguished, no new versioning scheme.
- **FR15 — Release plumbing.** Bump `plugin.json` + `marketplace.json`
  (patch increment, synced); add a `/specclaw:domain [path]` row to
  `README.md`'s Commands table.
- **FR16 — Parser tests.** Extend `tests/fixtures/analyze/` (not a parallel
  fixture) with: one well-formed text-format `.dfm` (a form with at least
  one top-level control with a `Caption`, and a nested menu with at least
  one `TMenuItem` whose `OnClick` names a handler that has a matching
  procedure implementation added to an existing `.pas` fixture file); one
  malformed/binary-format `.dfm` (a file whose first bytes are not
  `object`/`inherited` text — a synthetic stub sufficient to exercise the
  detection path, not required to be byte-authentic Delphi output); an
  enum + a `record` type + a `const` block added to an existing `.pas`
  fixture file; a `Valid*`-named routine with a guard clause added to an
  existing `.pas` fixture file. New test case(s) in `tests/run-parser-tests.sh`
  asserting FR3–FR10.

### Non-Functional Requirements

- **NFR1 — Language-agnostic-safe.** A scope with zero `.dfm`/`.xaml`/
  `.pas`/`.cs`/`.dpr` files produces valid JSON with empty arrays for every
  new field — not a crash, not an omitted field.
- **NFR2 — Grounded, not invented.** Every entity, relationship, rule,
  capability, workflow step, and control in the written documents must
  trace to either the collected JSON (facts) or a file the agent read
  directly (interpretation). No claim may be asserted from a file that was
  neither collected nor opened.
- **NFR3 — Portability.** Plain bash + coreutils, matching every sibling
  script; `jq` optional with a grep/awk fallback; no new external
  dependency.
- **NFR4 — No lifecycle coupling.** `/specclaw:domain` must not call
  `specclaw-validate-change`, must not require or read any
  `changes/<name>/` directory, and must not alter `STATUS.md` or any
  change's `status.md`.
- **NFR5 — Safe re-run.** Re-running `/specclaw:domain` must never
  silently discard either prior document — both are archived before either
  is overwritten.
- **NFR6 — Malformed input never crashes the collector.** A binary-format
  `.dfm`, an unreadable file, or a truncated/malformed `.pas` file must
  never abort `specclaw-domain-collect` — every extractor is best-effort
  (`|| true` style), matching every sibling script's existing tolerance.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- [ ] **AC1** — `specclaw-domain-collect collect .specclaw` (no path)
  defaults to the repository root; output is valid JSON containing every
  field `specclaw-analyze-codebase collect` produces (merged, not nested)
  plus the new domain-specific fields.
- [ ] **AC2** — Against a fixture with one well-formed text-format `.dfm`,
  `forms[]` contains one entry with `parseable: true`, the correct
  `root_name`/`root_class`, at least one `controls[]` entry with a
  `caption`, and at least one `handlers[]` entry naming a menu item's
  `OnClick` handler.
- [ ] **AC3** — Against the malformed/binary-format `.dfm` fixture,
  `forms[]` contains an entry with `"parseable": false` and a reason string
  — no crash, no attempted parse, no silent omission from the array.
- [ ] **AC4** — A `handlers[]` entry whose `handler_name` has a matching
  procedure implementation in a scoped `.pas` file produces a corresponding
  `handler_implementations[]` (or equivalent) entry with the correct file;
  a handler with no matching implementation in scope produces no such
  entry (not a guess).
- [ ] **AC5** — Against a fixture `.pas` file containing an enum type
  declaration, `type_declarations[]` contains an entry with `kind: "enum"`
  and the full, correctly-ordered `values[]` list.
- [ ] **AC6** — Against the same fixture's `record`/`class` type
  declaration, `type_declarations[]` contains an entry with the correct
  `kind` and no fabricated field list (fields are not attempted in bash).
- [ ] **AC7** — Against the fixture's `const` block, `const_declarations[]`
  contains the correct name/value pairs for simple scalar values.
- [ ] **AC8** — Against a fixture `Valid*`-named routine with a guard
  clause, `validation_routine_candidates[]` contains an entry whose
  captured body includes the guard clause's text, correctly bounded (does
  not include the following routine's code).
- [ ] **AC9** — A `.dpr` fixture's first `Application.CreateForm` call
  produces the correct `main_form_hint`; scoping `[path]` to exclude the
  `.dpr` file leaves `main_form_hint` absent while `forms[]` still contains
  every detected form.
- [ ] **AC10** — A fixture `.xaml` file's element/`x:Name`/`Content`-shaped
  attributes are captured in an `xaml_forms[]`-equivalent field at the
  depth FR5 specifies (no binding/trigger/style content asserted).
- [ ] **AC11** — A fixture `.cshtml` (or other non-`.dfm`/`.xaml` UI-shaped)
  file appears in the output marked detection-only
  (`"parseable": false, "reason": "not deep-parsed in v1 — detection only"`),
  never silently absent, never deep-parsed.
- [ ] **AC12** — A scope with zero `.dfm`/`.xaml`/`.pas`/`.cs`/`.dpr` files
  yields empty arrays for every new field — no crash.
- [ ] **AC13** — `collect .specclaw <subdir>` scopes every new field the
  same way `manifests`/`dependency_graph` are already scoped — an entity
  whose source file falls outside `<subdir>` never appears.
- [ ] **AC14** — `/specclaw:domain <bad-path>` stops with a clear error
  before collection or agent spawn (same die-before-work guarantee
  `collect` already provides via its delegated call).
- [ ] **AC15** — On a repo with no prior `domain-model.md`/
  `functional-spec.md`, running `/specclaw:domain` creates both files under
  `.specclaw/analysis/` with all eight rubric sections present (or
  explicitly "No findings — insufficient evidence" where a dimension has
  nothing to anchor), every entity/rule/capability traceable to a quoted
  file, and every domain-meaning claim prefixed `Inference:` (or
  `Inference (low confidence):`).
- [ ] **AC16** — Running `/specclaw:domain` a second time archives **both**
  prior documents (byte-identical) into `.specclaw/analysis/archive/`
  before writing new ones.
- [ ] **AC17** — `agents/domain-analyst.md` frontmatter declares `tools:
  [Read, Write, Bash]` and documents the eight-row rubric, the Domain
  Inference Rule, and the Mechanical Recording Rule.
- [ ] **AC18** — `plugin.json` and `marketplace.json` versions match each
  other, one patch increment above pre-change values.
- [ ] **AC19** — `tests/run-parser-tests.sh` includes the new case(s) and
  the full suite passes.
- [ ] **AC20** — `README.md`'s Commands table includes a `/specclaw:domain
  [path]` row describing it as a read-only domain/functional documentation
  command.

## Edge Cases

- A `.dfm` file with a menu nested three levels deep (File → Recent Files →
  item) → every `OnClick` handler at every depth still appears in
  `handlers[]` (handler capture is not depth-capped, only `controls[]` is).
- A `.dfm` object with a binary property block (`{...}`-delimited hex data,
  e.g. a `Glyph.Data`) → the block is skipped over (not decoded, not
  mistaken for a nested `object`/`end`), and depth tracking is unaffected
  by its contents.
- An enum declaration whose identifier list spans multiple lines before its
  closing `);` → parsed as one accumulated statement, same technique the
  `uses`-clause extractor already uses for multi-line clauses.
- A routine name matching the `Valid*`/`Check*`/`Can*` heuristic that is
  NOT actually a validation routine (a false positive, e.g. `CanRedo`) →
  still surfaced as a candidate; the agent's own judgment (not the bash
  heuristic) decides whether it becomes a documented business rule.
- A comment or string literal inside a candidate routine's body containing
  the literal word `begin` or `end` → accepted, named limitation (FR10);
  not treated as a defect to fix in this change.
- A `.pas` file with no `interface`/`implementation` section markers at all
  (malformed or non-standard) → yields no type/const/routine entries for
  that file, not a crash.
- `[path]` scoped to a subdirectory containing forms but no `.dpr` →
  `main_form_hint` absent, every form still surfaced (FR8's core guarantee).
- Multiple `.dfm` files with no way to determine which is "the" main
  form (no `.dpr` in scope, no naming convention match) → all are
  surfaced as peers in `forms[]`; the agent may still reason about which
  is most central using its own judgment (e.g. most menu items, most
  incoming `dependency_graph` edges), explicitly labeled as inference.

## Dependencies

- `bin/specclaw-analyze-codebase` (existing, unmodified) — delegated to via
  subprocess for path validation, manifests, `dependency_graph`,
  `discovered_docs`. Not re-derived.
- `skills/analyze/SKILL.md`, `skills/architecture/SKILL.md`,
  `agents/codebase-analyst.md`, `agents/architecture-analyst.md` (existing,
  unmodified) — shape/convention reference only; no behavior dependency.
- No new external runtime dependency.

## Notes

Deferred to v1.1/v2 (per this spec's decisions, not part of this change):
deep `.cshtml`/Razor parsing and any UI framework beyond `.dfm`/`.xaml`;
symbol-level or call-graph-level business-rule tracing beyond "anchored to
the routine that directly enforces it"; automated E2E test generation from
`functional-spec.md`'s workflows section (written to be a test charter a
later effort could automate, not automated here). `rebuild-inputs.md` and
the `discover-command` umbrella that produces it are a separate, later
change — not part of this one.
