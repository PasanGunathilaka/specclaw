# Design: Domain & Functional Documentation (`/specclaw:domain`)

**Change:** domain-command
**Created:** 2026-07-22

## Technical Approach

One new bin script, two new files, no modification to any existing
script or agent (unlike `architecture-command`, which extended
`specclaw-analyze-codebase` in place, this change adds a sibling instead —
see Key Decision 1).

### 1. `bin/specclaw-domain-collect` — delegate, merge, then extend

```bash
# collect <specclaw_dir> [path]
SPECCLAW_DIR="$1"; TARGET_PATH="${2:-.}"
ANALYZE_BIN="$SCRIPT_DIR/specclaw-analyze-codebase"

# Step 1: delegate — reuses path validation, manifests, dependency_graph,
# discovered_docs. A non-zero exit here (bad [path]) propagates verbatim —
# specclaw-domain-collect does not re-validate the path itself.
delegated="$(bash "$ANALYZE_BIN" collect "$SPECCLAW_DIR" "$TARGET_PATH")" || exit $?

# Step 2: merge, not nest. delegated is known to start with "{" and end
# with "}" (analyze-codebase's own json_escape() guarantees no unescaped
# brace at those exact boundary positions) — strip exactly one char off
# each end to get delegated's body as a splice-able chunk.
delegated_body="${delegated:1:${#delegated}-2}"

# Step 3: re-enumerate the scoped file list ourselves (same git ls-files /
# find fallback + prefix-scope filter every sibling script already uses —
# the delegated JSON has no "every file in scope" field, only summaries
# derived from one, so a consumer that needs to open specific files must
# re-derive the list; the one accepted minimal duplication, per this
# repo's no-shared-lib convention).
# ... (identical enumeration block to specclaw-analyze-codebase's own) ...

# Step 4: new extraction, each independent, each best-effort:
#   forms_json            <- gather_dfm_forms      (over *.dfm)
#   xaml_json              <- gather_xaml_forms      (over *.xaml)
#   other_ui_json          <- gather_other_ui_files   (over *.cshtml etc.)
#   handler_impls_json    <- resolve_handler_implementations (needs forms_json's handler names + scoped .pas/.cs)
#   main_form_hint        <- detect_main_form         (over *.dpr, optional)
#   type_decls_json        <- gather_type_declarations (over *.pas interface sections)
#   const_decls_json       <- gather_const_declarations(over *.pas interface sections)
#   validation_cands_json  <- gather_validation_candidates (over *.pas/*.cs)

# Step 5: assemble. delegated_body's fields plus the new ones, one flat object.
cat <<ENDJSON
{
  ${delegated_body},
  "forms": [${forms_json}],
  "xaml_forms": [${xaml_json}],
  "other_ui_files": [${other_ui_json}],
  "handler_implementations": [${handler_impls_json}],
  "main_form_hint": ${main_form_hint_json},
  "type_declarations": [${type_decls_json}],
  "const_declarations": [${const_decls_json}],
  "validation_routine_candidates": [${validation_cands_json}]
}
ENDJSON
```

### 2. `.dfm` extraction — `gather_dfm_forms`

```awk
# Pseudocode shape, not literal awk — the real implementation is one
# per-file awk script invoked once per scoped .dfm file.
first_nonblank_line ~ /^(object|inherited)\b/  ->  parseable = true, proceed
else                                            ->  parseable = false, reason = "binary DFM format (or unrecognized text structure)", STOP for this file

depth = 0
capturing_props_for_current_object = false
for each line:
  if line ~ /^[[:space:]]*(object|inherited)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)?:?[[:space:]]*[A-Za-z_][A-Za-z0-9_]*/:
    depth += 1
    push (name, class) — parsed from the line
    if depth == 1: root_name, root_class = name, class
    capturing_props_for_current_object = true   # its OWN properties come next, before any child
    continue
  if line ~ /^[[:space:]]*end[[:space:]]*$/:
    depth -= 1
    pop
    capturing_props_for_current_object = false   # a sibling's properties (if any) would follow a new object line, not here
    continue
  if capturing_props_for_current_object:
    if line ~ /^[[:space:]]*(Caption|Text|Hint)[[:space:]]*=/:      record caption for the CURRENT (top-of-stack) object
    if line ~ /^[[:space:]]*On[A-Za-z]+[[:space:]]*=/:              record {object=top-of-stack, event, handler} — ALWAYS, any depth
    # any other property line: ignored (layout/anchors/binary blocks/etc.)
  # a line that is itself an object/inherited/end line already handled above
  # ends capturing_props_for_current_object for the object whose block it opens/closes

at end of file:
  controls[] = every object recorded at depth == 1 (name, class, caption)
  handlers[] = every On<Event> recorded, regardless of depth
```

Binary property blocks (`{...}`-delimited hex, e.g. `Glyph.Data = {...}`)
are never mistaken for `object`/`end` lines (their own regex doesn't match
either pattern) and are simply skipped as ordinary "any other property
line" — no special-casing needed, confirmed against a fixture containing
one (see Risks & Mitigations).

### 3. Pascal type/const/enum extraction — bounded `interface` section scan

Same in-section idiom as `extract_maven_deps`/`extract_uses_clause_units`
(already in `specclaw-analyze-codebase`, copied here per this repo's
no-shared-lib convention, not imported):

```awk
/^interface[[:space:]]*$/       { insection = 1; next }
/^implementation[[:space:]]*$/  { insection = 0 }
insection && /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*\(/ {
  # accumulate until the line's "); " closes — same multi-line technique
  # extract_uses_clause_units already uses for uses-clause statements —
  # then split the parenthesized list on commas -> enum values[]
}
insection && /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*=[[:space:]]*(record|class)\b/ {
  # capture name + kind + file + line only — do not parse further
}
# const block: a separate top-level `const` keyword flips a second
# in-const-block flag (same insection-style idiom); each `<Name> = <scalar>;`
# line inside it is captured directly.
```

### 4. Business-rule candidate extraction — depth-counted routine body

```awk
/^[[:space:]]*(procedure|function)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*\.)?([A-Za-z_][A-Za-z0-9_]*)/ {
  name = <last captured group>
  if (tolower(name) does not start with one of "valid","validate","check","can") { skip_this_routine = 1; next }
  skip_this_routine = 0
  in_signature = 1
  next
}
skip_this_routine { next }
in_signature && /^[[:space:]]*begin[[:space:]]*$/ { in_signature = 0; depth = 1; body = ""; next }
depth > 0 {
  body = body line
  if (line ~ /^[[:space:]]*begin\b/)      depth += 1
  if (line ~ /^[[:space:]]*end;[[:space:]]*$/) depth -= 1
  if (depth == 0) { emit {name, file, line_start, body (capped at 100 lines)}; }
}
```

Known limitation (spec FR10, restated here because it drives this exact
scan): no comment/string awareness — a literal `begin`/`end` inside a
comment or string throws off `depth`. Accepted, matches this repo's
existing no-real-parser tolerance everywhere else.

### 5. `.xaml` extraction — plain XML tag/attribute grep

Same cheap approach `.csproj`'s `<ProjectReference>` extraction already
uses (`grep -oE` for a tag pattern, `sed` to pull the attribute value) —
element name, `x:Name=`, and `Content=`/`Header=`/`Text=` attribute values,
one level of nesting (direct children of the XAML root element only). No
new technique introduced.

### 6. Handler-to-implementation resolution

For each `handlers[].handler_name`, grep scoped `.pas` files for
`procedure T<any class>\.<handler_name>\s*\(` and scoped `.cs` files for an
analogous method-name match; record the first match's file/line. No match
→ omitted from `handler_implementations[]`, never guessed.

### 7. Main-form hint

`grep -oE 'Application\.CreateForm\([[:space:]]*T[A-Za-z0-9_]+' <dpr file>
| head -1` on the (at most one, if in scope) `.dpr` file — extracts the
class name from the first `CreateForm` call. Absent field if no `.dpr` is
scoped or the pattern doesn't match; never blocks `forms[]` from being
fully populated regardless.

### 8. `agents/domain-analyst.md`

Mirrors `architecture-analyst.md`'s shape exactly: frontmatter
(`name: domain-analyst`, `tools: [Read, Write, Bash]`, `model: sonnet`), an
Inputs section (the merged JSON — spec's full field list — plus target
path; reads both `templates/domain-model.md` and
`templates/functional-spec.md` before writing either), an eight-row rubric
table, an Evidence Discipline section (adapted verbatim in spirit from
`codebase-analyst.md`), the **Domain Inference Rule** (same `Inference:`/
`Inference (low confidence):` prefixing `codebase-analyst.md`'s Domain
section already uses, applied here to entities/rules/enum-value meanings),
and the **Mechanical Recording Rule** (a new rule, not present in either
sibling agent, because neither sibling asserts business rules — see Key
Decision 4): when a `validation_routine_candidates[]` entry's *intent*
isn't evident from its body/context, record it as "rejects values > 100 —
reason not evident" rather than inventing a rationale.

### 9. `templates/domain-model.md` + `templates/functional-spec.md`

Same `{{placeholder}}` scaffold convention. `domain-model.md`: header +
four sections (Entities, Relationships with a fenced `erDiagram`
placeholder, Business Rules, Enumerations). `functional-spec.md`: header +
four sections (Capabilities, Workflows with fenced `flowchart` placeholders
where a workflow branches, UI Inventory, Named Gaps).

### 10. `skills/domain/SKILL.md`

Same shape as `skills/architecture/SKILL.md`: ensure-init → `collect` (die
on non-zero, no reimplemented validation) → archive both prior documents
(two `mkdir -p .specclaw/analysis/archive && mv` pairs, same shared
directory) → spawn `Agent` (`subagent_type: "domain-analyst"`) → agent
writes both files → summarize.

No `specclaw-validate-change` case arm — same side-command classification
as its two siblings.

## Architecture

```
User: /specclaw:domain [path]
        │
        ▼
skills/domain/SKILL.md  (orchestration prose, not executable)
        │
        ├─ specclaw-ensure-init .specclaw
        ├─ bin/specclaw-domain-collect collect .specclaw [path]
        │     ├─ delegates to: specclaw-analyze-codebase collect .specclaw [path]
        │     │     └─ (unchanged) manifests / dependency_graph / discovered_docs / path validation
        │     ├─ merges delegated JSON's body into its own output (flat, not nested)
        │     ├─ re-enumerates scoped files (for its own extraction targets)
        │     ├─ gather_dfm_forms (.dfm)          — first-class
        │     ├─ gather_xaml_forms (.xaml)         — shallower
        │     ├─ gather_other_ui_files (.cshtml…)  — detection only
        │     ├─ resolve_handler_implementations   — cross-references forms[] + scoped .pas/.cs
        │     ├─ detect_main_form (.dpr)           — optional hint
        │     ├─ gather_type_declarations (.pas)   — enum full, record/class name-only
        │     ├─ gather_const_declarations (.pas)
        │     └─ gather_validation_candidates (.pas/.cs) — name heuristic + depth-counted body
        │        → one JSON object to stdout (die-before-work propagated from the delegated call)
        ├─ archive prior .specclaw/analysis/domain-model.md (if any)
        ├─ archive prior .specclaw/analysis/functional-spec.md (if any)
        ├─ Agent(subagent_type: "domain-analyst", <merged JSON payload>)
        │     ├─ reads templates/domain-model.md + templates/functional-spec.md for shape
        │     ├─ Read tool: opens real files for evidence (fields, intent, workflow steps)
        │     ├─ writes .specclaw/analysis/domain-model.md
        │     └─ writes .specclaw/analysis/functional-spec.md
        └─ summary to user
```

Data flow is one-directional and read-only end to end: nothing under
`PROJECT_ROOT` other than the two new files (and their archive copies) is
ever written.

## File Changes Map

| File | Action | Description |
|------|--------|--------------|
| `plugins/specclaw/skills/domain/SKILL.md` | create | `/specclaw:domain [path]` orchestration (FR1, FR2, FR13, FR14) |
| `plugins/specclaw/bin/specclaw-domain-collect` | create | `collect` subcommand — delegates + merges + extends (FR3–FR10, FR16) |
| `plugins/specclaw/agents/domain-analyst.md` | create | Eight-row rubric persona, both documents (FR11) |
| `plugins/specclaw/templates/domain-model.md` | create | Entities/Relationships/Business Rules/Enumerations scaffold (FR12) |
| `plugins/specclaw/templates/functional-spec.md` | create | Capabilities/Workflows/UI Inventory/Named Gaps scaffold (FR12) |
| `plugins/specclaw/tests/run-parser-tests.sh` | modify | New case(s): `specclaw-domain-collect` (FR16, AC1–AC13) |
| `plugins/specclaw/tests/fixtures/analyze/` | modify | Extended: valid `.dfm`, malformed/binary `.dfm`, enum/record/const `.pas` additions, `Valid*` routine, `.xaml`, `.cshtml`, `.dpr` |
| `plugins/specclaw/.claude-plugin/plugin.json` | modify | Version bump (FR15) |
| `.claude-plugin/marketplace.json` | modify | Version bump, synced (FR15) |
| `README.md` | modify | Commands table row (FR15, AC20) |

## Data Model Changes

New on-disk artifacts:
- `.specclaw/analysis/domain-model.md`, `.specclaw/analysis/
  functional-spec.md` — current documents (stable paths).
- `.specclaw/analysis/archive/<YYYY-MM-DD-HHMMSS>-domain-model.md`,
  `...-functional-spec.md` — prior versions, same shared archive directory
  `analyze`/`architecture` already use.

`bin/specclaw-domain-collect`'s output is a new JSON shape (not a field
added to an existing script's output, unlike `architecture-command`'s
`dependency_graph`) — it flattens `specclaw-analyze-codebase collect`'s
fields alongside its own new ones. `STATUS.md` and every `changes/<name>/`
artifact remain untouched (NFR4).

## API Changes

New CLI surface:
- `/specclaw:domain [path]` (skill/slash command).
- `bin/specclaw-domain-collect collect <specclaw_dir> [path]` (new script,
  new subcommand — no existing script's interface changes; unlike
  `architecture-command`, this change modifies zero existing bin scripts).

## Key Decisions

1. **New sibling script, not a further extension of
   `specclaw-analyze-codebase`.** Per the approved proposal: this command's
   parsing is a different kind of work (source-code structure, not
   manifest/declaration detection), and the existing script is already
   large. `specclaw-domain-collect` reuses via subprocess delegation
   (zero re-derivation of path validation, manifests, `dependency_graph`,
   `discovered_docs`) rather than growing the existing file further.
2. **Merge the delegated JSON's fields, don't nest them.** A flat output
   object means `domain-analyst` reads one payload with one shape, the same
   way `codebase-analyst`/`architecture-analyst` each read one flat
   payload — nesting would make every existing field-access pattern
   (`manifests`, `dependency_graph`, etc.) inconsistent between the three
   agents for no benefit.
3. **Handler capture is not depth-capped; general control capture is.**
   Restated from the proposal's own precise wording ("one level of
   child-control hierarchy" vs. "every OnClick... property value") because
   it would be easy to accidentally cap both at the same depth during
   implementation — menus nest 2–3 levels deep and are exactly the
   evidence `functional-spec.md`'s Capabilities/Workflows sections need, so
   handler capture must scan the whole tree regardless of the depth-1 cap
   on general controls.
4. **A new "Mechanical Recording Rule" for `domain-analyst.md` that neither
   `codebase-analyst.md` nor `architecture-analyst.md` needed.** Neither
   sibling agent asserts a *business rule* — `codebase-analyst`'s Domain
   section infers what problem the code solves (not "what does this
   specific validation check enforce"), and `architecture-analyst` never
   reasons about validation logic at all. This agent is the first one in
   the suite that reads routine bodies for intent, so it's the first one
   that needs an explicit "record mechanically when intent is unclear"
   rule — carried over verbatim from the operator's brief, not softened.
5. **Property-span-not-property-stack for `.dfm` extraction.** A full
   per-object property stack would be more general but unnecessary:
   Delphi's form designer always serializes an object's own properties
   before its children, so "the contiguous non-structural lines
   immediately following an `object`/`inherited` line" reliably captures
   that object's own properties without needing to track which stack frame
   owns which property line.
6. **`.xaml` reuses the exact grep-and-attribute-value technique
   `.csproj`'s `<ProjectReference>` extraction already established** —
   XAML is well-formed XML, so this is genuinely cheap and reliable, unlike
   the indented, non-XML `.dfm` format, which needs the depth-counted scan
   above.
7. **Business-rule extraction never asserts a rule from the candidate list
   alone.** `validation_routine_candidates[]` is explicitly a candidate
   list — the agent's Evidence Discipline section requires it to actually
   read the routine (already handed to it as raw text, but it may `Read`
   the full file for surrounding context) before writing a rule, and to
   drop a candidate it can't turn into a grounded, plain-language rule.

## Grounding sources

- `docs/specclaw-architecture-notes.md` §6 — the extension recipe followed
  a third time.
- `.specclaw/changes/architecture-command/proposal.md`'s Roadmap Context —
  the recorded reasoning for one-command-two-documents and for the
  task-wave-discipline commitment this design's Tasks breakdown honors.
- `plugins/specclaw/bin/specclaw-analyze-codebase` — the exact `collect`
  output this script delegates to and merges; `extract_maven_deps`'s
  bounded-block idiom and `extract_uses_clause_units`'s multi-line
  accumulation technique, both reused for Pascal type/enum/const scanning.
- `plugins/specclaw/agents/codebase-analyst.md` — the Domain Inference Rule
  (`Inference:`/`Inference (low confidence):`) this design's Domain
  Inference Rule mirrors verbatim.
- `plugins/specclaw/agents/architecture-analyst.md` — the fixed-rubric
  persona shape (`tools:`/`model:` frontmatter, Evidence Discipline
  section, "read the real file, don't trust the map alone" instruction)
  `domain-analyst.md` mirrors.
- `plugins/specclaw/skills/architecture/SKILL.md` — the exact orchestration
  shape (`collect` → archive → spawn agent → agent writes → summarize)
  `skills/domain/SKILL.md` mirrors, extended to two archived files instead
  of one.

## Risks & Mitigations

- **`.dfm` depth-counting is the single most complex piece of bash in this
  plugin so far** (more so than `dependency_graph`'s extractors) → mitigated
  by the property-span simplification (Key Decision 5, avoids needing a
  full property-to-object stack), by the mandatory malformed-fixture
  requirement (AC3), and by a fixture that specifically includes a binary
  property block (`{...}`-delimited data) to confirm depth tracking isn't
  thrown off by it (AC2's fixture, per spec Edge Cases).
- **Business-rule name-heuristic (`Valid*`/`Check*`/`Can*`) will both miss
  real rules with other names and flag false positives (e.g. `CanRedo`)** →
  accepted and named explicitly (spec Edge Cases): the heuristic only
  produces *candidates*; the agent's own reading decides what becomes a
  documented rule, and a missed rule is a named gap, not a silent invention
  — matches the operator's explicit "a gap is better than a confidently
  wrong rule" instruction.
- **Depth-counted routine-body extraction can misalign on a comment/string
  containing `begin`/`end`** → named explicitly in spec FR10 and this
  design, not silently risked; accepted at the same tolerance level as
  every other grep/awk extractor in this codebase.
- **Two agent-written files instead of one raises the same "no live
  end-to-end artifact will exist at verify time" gap** `architecture-
  command`'s verify pass already flagged for its own AC9/AC10 → same
  handling: verify will grade the skill/agent's wiring and instructions,
  not an observed run, exactly as precedent already set twice.
- **This change's own task breakdown risks repeating the evidence-
  collection strain the roadmap flagged as a lesson from v1** → directly
  addressed in `tasks.md`'s wave structure: UI-inventory collection
  (`.dfm`/`.xaml`/`.cshtml`, handler mapping, main-form hint) and
  business-rule/type-declaration collection (type/const/enum, validation
  candidates) are split into separate tasks so each can be verified on its
  own evidence, not bundled into one large "everything the new script does"
  task.
