# Tasks: Domain & Functional Documentation (`/specclaw:domain`)

**Change:** domain-command
**Created:** 2026-07-22
**Total Tasks:** 6

## Summary

Per the roadmap's own commitment (recorded in `architecture-command/
proposal.md`) and this change's design.md Risks section: the new
collector's two extraction concerns — UI-inventory evidence
(`.dfm`/`.xaml`/handler mapping) and source-structure evidence
(type/const/enum declarations, business-rule candidates) — are split into
separate tasks rather than one large "everything the new script does"
task, so each can be verified on its own evidence. They target the same new
file, so they're sequenced (T2 depends on T1), not parallel — a genuine
verify-scoping split, not a build-time parallelism claim. The template+
persona work only needs the JSON *shape* (already fully specified in
spec.md/design.md), not the collector's actual implementation, so it runs
in parallel with T1. The skill and the fixture/tests both need the
complete, two-halves-merged collector to build against, so they're a later
wave. Release plumbing closes out last, once everything else is proven.

## Tasks

### Wave 1 — Collector skeleton + UI-inventory half; template + persona (parallel)

- [x] `T1` — `specclaw-domain-collect` skeleton + delegation/merge + UI-inventory extraction
  - Files: plugins/specclaw/bin/specclaw-domain-collect
  - Estimate: large
  - Depends: —
  - Notes: Per design.md's Technical Approach items 1–2 and 5–7. New
    script, `#!/usr/bin/env bash`, `set -euo pipefail`, `-h|--help` block,
    `case "$1" in collect) ... esac` dispatch (only `collect` in v1,
    signature `collect <specclaw_dir> [path]`, mirroring both siblings'
    shape). Step 1: shell out to `specclaw-analyze-codebase collect
    "$specclaw_dir" "$target_path"`, propagate its exit code and stderr
    verbatim on failure (no re-validation of `[path]`). Step 2: merge (not
    nest) its JSON body — strip exactly the first and last character of the
    captured string (`"${delegated:1:${#delegated}-2}"`) since it's
    guaranteed to start with `{`/end with `}`, splice as one chunk. Step 3:
    re-enumerate the scoped file list (copy the git-ls-files/find-fallback +
    prefix-scope-filter block from `specclaw-analyze-codebase` verbatim, per
    this repo's no-shared-lib convention) to locate `.dfm`/`.xaml`/
    `.cshtml`/`.dpr` files. Step 4, this task's real content — implement
    `gather_dfm_forms` (depth-counted `object`/`inherited`/`end` scan per
    design.md's pseudocode: depth-1 objects → `controls[]` with name/class/
    caption; `On<Event>` properties captured at ANY depth → `handlers[]`,
    per Key Decision 3 — do not accidentally cap handler capture at depth 1
    too; non-`object`/`inherited`-leading files → `"parseable": false`
    entries, never a crash, never silently dropped from `forms[]`);
    `gather_xaml_forms` (plain XML tag/`x:Name`/`Content|Header|Text`-
    attribute grep, one level of nesting, same cheap technique
    `extract_dotnet_project_refs` already uses for `.csproj`);
    `gather_other_ui_files` (`.cshtml` and similar → detection-only entries,
    `"parseable": false, "reason": "not deep-parsed in v1 — detection
    only"`); `resolve_handler_implementations` (grep scoped `.pas`/`.cs`
    files for each captured `handler_name`'s implementation, omit — never
    guess — when none found); `detect_main_form` (grep a scoped `.dpr`
    file's first `Application.CreateForm(T<X>` call; absent field, not an
    error, when no `.dpr` is in scope or the pattern doesn't match — every
    form in `forms[]` still appears regardless). Emit the assembled JSON
    (delegated fields + `forms`/`xaml_forms`/`other_ui_files`/
    `handler_implementations`/`main_form_hint` — the type/const/validation
    fields land in T2) as valid JSON (jq-validated when present, printed
    either way).

- [x] `T2` — `templates/domain-model.md` + `templates/functional-spec.md` + `agents/domain-analyst.md`
  - Files: plugins/specclaw/templates/domain-model.md, plugins/specclaw/templates/functional-spec.md, plugins/specclaw/agents/domain-analyst.md
  - Estimate: medium
  - Depends: —
  - Notes: Templates first, same `{{placeholder}}` convention as
    `templates/architecture.md`: `domain-model.md` gets header + Entities /
    Relationships (fenced ` ```mermaid ` `erDiagram` placeholder) /
    Business Rules / Enumerations; `functional-spec.md` gets header +
    Capabilities / Workflows (fenced ` ```mermaid ` `flowchart`
    placeholders) / UI Inventory / Named Gaps. Then the agent, shaped like
    `architecture-analyst.md`: frontmatter `name: domain-analyst`, `tools:
    [Read, Write, Bash]`, `model: sonnet`. Inputs section: documents the
    full merged JSON shape from spec.md (delegated fields plus `forms`,
    `xaml_forms`, `other_ui_files`, `handler_implementations`,
    `main_form_hint`, `type_declarations`, `const_declarations`,
    `validation_routine_candidates` — even though T1/T2's bash isn't
    finished yet, the shape is already fully specified in spec.md/design.md,
    so this task doesn't need to wait on it); reads both templates before
    writing either, invents no new sections. Eight-row rubric table:
    Entities / Relationships / Business Rules / Enumerations / Capabilities
    / Workflows / UI Inventory / Named Gaps. Evidence Discipline section
    adapted from `architecture-analyst.md`'s. **Domain Inference Rule**
    (verbatim in spirit from `codebase-analyst.md`'s: every entity/rule/
    enum-value meaning prefixed `Inference:`, low-confidence ones
    `Inference (low confidence):`). **Mechanical Recording Rule** (new,
    per design.md Key Decision 4): when a candidate rule's intent isn't
    evident, record it mechanically ("rejects values > 100 — reason not
    evident") rather than inventing a rationale. Output section: write both
    `.specclaw/analysis/domain-model.md` and `.specclaw/analysis/
    functional-spec.md`, once each, at the end, after completing all eight
    rubric dimensions.

### Wave 2 — Collector: source-structure half (extends T1's file)

- [x] `T3` — Type/const/enum extraction + business-rule candidate extraction
  - Files: plugins/specclaw/bin/specclaw-domain-collect
  - Estimate: large
  - Depends: T1
  - Notes: Per design.md's Technical Approach items 3–4. Extends the file
    T1 created — do not restructure T1's delegation/merge/UI-inventory code,
    only add new gather functions and wire their output into the final
    JSON heredoc. `gather_type_declarations`: bounded `interface`-section
    scan (same in-section idiom as `extract_maven_deps`); enum
    declarations (`<Name> = (<ids>);`) captured fully with multi-line
    accumulation (same technique `extract_uses_clause_units` already uses
    for multi-line `uses` statements) into `{name, kind: "enum", values:
    [...], file, line}`; `record`/`class` declarations captured as
    `{name, kind, file, line}` only — do not attempt to parse field lists.
    `gather_const_declarations`: simple-scalar `<Name> = <value>;` lines in
    the same interface-section scope (a separate `const`-block flag, not
    the `type`-block flag). `gather_validation_candidates`: name-heuristic
    match (case-insensitive `Valid*`/`Validate*`/`Check*`/`Can*`) on
    `procedure`/`function` signatures in scoped `.pas`/`.cs` files, followed
    by a depth-counted `begin`/`end` scan (increment on `begin`, decrement
    on `end;`, stop at depth 0) to capture the full body, capped at 100
    lines with the `"... (truncated, N total lines)"` label
    `specclaw-verify collect` already uses at its own cap. State the
    known comment/string-literal limitation in a code comment (not just
    the spec) so a future reader isn't surprised by it. Wire
    `type_declarations`/`const_declarations`/`validation_routine_candidates`
    into the final JSON assembly alongside T1's fields.

### Wave 3 — Orchestrating skill; fixture + parser tests (parallel)

- [x] `T4` — `skills/domain/SKILL.md`
  - Files: plugins/specclaw/skills/domain/SKILL.md
  - Estimate: medium
  - Depends: T2, T3
  - Notes: Same shape as `skills/architecture/SKILL.md`. Frontmatter
    `description:` model-invokable, no `disable-model-invocation`. Steps:
    (1) `specclaw-ensure-init .specclaw`; (2) run `specclaw-domain-collect
    collect .specclaw [path]` — non-zero exit surfaces stderr verbatim and
    stops, no reimplemented validation; (3) archive **both** prior
    documents if they exist — two `mkdir -p .specclaw/analysis/archive &&
    mv` pairs (one for `domain-model.md`, one for `functional-spec.md`),
    same shared archive directory `analyze`/`architecture` already use;
    (4) spawn `Agent` (`subagent_type: "domain-analyst"`, model from
    `config.yaml` `models.review`), passing the collected JSON and resolved
    target path; (5) the agent writes both files itself, per T2's Output
    section — this skill does not write either file; (6) present a short
    summary — path analyzed, entity/rule/capability counts, any Named Gaps
    the agent flagged. No `specclaw-validate-change` call anywhere in this
    skill.

- [x] `T5` — Fixture extension + parser-test case(s)
  - Files: plugins/specclaw/tests/fixtures/analyze/, plugins/specclaw/tests/run-parser-tests.sh
  - Estimate: large
  - Depends: T3
  - Notes: Extend the existing `tests/fixtures/analyze/` tree (do not
    create a parallel fixture), adding: one well-formed text-format `.dfm`
    (a form with at least one top-level control bearing a `Caption`, a
    nested menu at least two levels deep with a `TMenuItem` whose
    `OnClick` names a handler, and one binary-encoded property block
    (`{...}`-delimited hex) to confirm depth tracking isn't disturbed by it
    per design.md's Risks note); a matching `.pas` file implementing that
    handler procedure (for `handler_implementations[]` to resolve against);
    one malformed/binary-format `.dfm` (a synthetic stub whose first bytes
    are not `object`/`inherited` text — sufficient to exercise the
    detection path, not required to be byte-authentic Delphi output); an
    enum type declaration, a `record` type declaration, and a `const` block
    added to an existing `.pas` fixture file; a `Valid*`-named routine with
    a guard clause (and, per spec Edge Cases, a `Can*`-named routine that
    is NOT a real validation routine, to confirm the heuristic still
    surfaces it as a candidate without the bash layer making a judgment
    call); a minimal `.dpr` file whose first `Application.CreateForm` call
    names the fixture's main form, for `main_form_hint`; a minimal `.xaml`
    file with one element bearing `x:Name` and a `Content`/`Header`-shaped
    attribute; a minimal `.cshtml` file (detection-only, no deep parsing
    expected). Add new case(s) to `run-parser-tests.sh` (continue the
    existing Case-numbering convention) asserting AC1–AC13: merged output
    includes every delegated field plus the new ones; valid `.dfm` parsing
    (`root_name`/`root_class`/`controls[]`/`handlers[]` correct, handler at
    depth 2+ still captured); malformed `.dfm` marked unparseable with a
    reason, no crash; handler-to-implementation resolution succeeds for the
    matching pair and is absent for an unmatched handler; enum captured
    fully with correct `values[]`; record/class captured name-only; const
    captured correctly; validation candidate's body correctly bounded
    (does not bleed into the next routine); main-form hint correct, and
    absent (with `forms[]` still fully populated) when scoped to exclude
    the `.dpr`; `.xaml` element/attribute capture at the specified depth;
    `.cshtml` marked detection-only; a zero-eligible-file scope yields
    empty arrays, not a crash; subdirectory scoping excludes out-of-scope
    entities from every new field, same discipline as `manifests`/
    `dependency_graph`.

### Wave 4 — Release plumbing

- [x] `T6` — README row + version bump
  - Files: README.md, plugins/specclaw/.claude-plugin/plugin.json, .claude-plugin/marketplace.json
  - Estimate: small
  - Depends: T4, T5
  - Notes: Add a `| /specclaw:domain [path] | ... (read-only,
    domain/functional documentation) |` row to README's Commands table,
    placed near `/specclaw:analyze`/`/specclaw:architecture`. Patch-
    increment `version` in both `plugin.json` and `marketplace.json`'s
    `specclaw` entry, keep them in sync, per this repo's `CLAUDE.md`
    version-bump rule.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:** see the tasks above for the live shape — checkbox, ID, title, then `Files / Estimate / Depends / Notes` sub-bullets.
