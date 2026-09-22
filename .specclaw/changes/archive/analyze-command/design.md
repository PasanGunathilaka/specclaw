# Design: Brownfield Codebase Analysis (`/specclaw:analyze`)

**Change:** analyze-command
**Created:** 2026-07-21

## Technical Approach

Three new files carry the feature; nothing existing is modified except
README/version files:

1. **`bin/specclaw-analyze-codebase`** — a fact-only collector, structured
   like `specclaw-verify` (subcommand dispatch, `collect` mirrors
   `specclaw-verify collect`'s `<specclaw_dir> <arg>` shape). One subcommand
   for v1: `collect <specclaw_dir> [path]`. Internally it's four independent
   collection steps feeding one JSON object — no step depends on another's
   output, so ordering is only for readability:

   ```bash
   # collect <specclaw_dir> [path]
   SPECCLAW_DIR="$1"; TARGET_PATH="${2:-.}"
   PROJECT_ROOT="$(cd "$SPECCLAW_DIR/.." && pwd)"
   SCOPE_DIR="$(cd "$PROJECT_ROOT/$TARGET_PATH" && pwd)"   # resolves + validates existence
   # reject if $SCOPE_DIR is not under $PROJECT_ROOT, or is $SPECCLAW_DIR/*
   ```

   - **File enumeration**: `git -C "$PROJECT_ROOT" ls-files` when inside a
     work tree (same detection `specclaw-discover-context` already does:
     `git rev-parse --is-inside-work-tree`), else the same `find`
     prune-list fallback `specclaw-discover-context` uses (`.git`,
     `node_modules`, `.specclaw`, `vendor`, `dist`, `build`). Result is
     filtered to paths under `$TARGET_PATH` by string prefix.
   - **Top-level summary**: `cut -d/ -f1-2 | sort -u` over the scoped file
     list — byte-for-byte the same transform `/specclaw:plan` Step 3 already
     documents, just now reusable.
   - **Manifest detection**: for each of the 8 formats in spec FR3, `find`/
     glob-match within the scoped file list; for each hit, read raw content
     and run a format-specific best-effort dependency extractor (grep/sed/awk
     — no real parser, matching `yaml_val`'s own philosophy in this repo).
     Per-format extraction (all best-effort, all `|| true`, none abort the
     script on a malformed file):
     - `package.json` — `jq -r '(.dependencies // {}) + (.devDependencies //
       {}) | keys[]'` when `jq` present; grep-based `"name": "version"` line
       scan inside the dependencies/devDependencies blocks otherwise. Version
       signal: `.engines` block if present.
     - `*.csproj`/`*.sln` — grep `<PackageReference Include="([^"]+)"
       Version="([^"]+)"`. Version signal: `<TargetFramework>` value.
     - `pom.xml` — grep `<artifactId>` lines inside `<dependency>` blocks
       (awk state machine bounded by `<dependency>`/`</dependency>`, same
       bounded-block technique `specclaw-verify`'s error-history extractor
       already uses). Version signal: none attempted (deep XML, low value).
     - `go.mod` — parse the `require ( ... )` block plus bare `require x
       v1.2.3` lines via awk/grep. Version signal: the `go 1.NN` directive.
     - `Cargo.toml` — section-scoped scan under `[dependencies]` until the
       next `[section]`, reusing the same in-section state-machine idiom as
       `specclaw-discover-context`'s own `yaml_list()`. Version signal:
       `edition` field if present.
     - `requirements.txt` — every non-comment, non-blank line is a dependency
       spec verbatim. No version signal beyond the pinned spec itself.
     - `pyproject.toml` — `[tool.poetry.dependencies]` or PEP 621
       `dependencies = [...]` array, same section-scoped scan as Cargo.toml.
       Version signal: `requires-python` if present.
     - `*.dpr`/`*.dproj` (Delphi/Object Pascal) — `.dproj` is XML; grep
       `<DCCReference Include="...">` entries as the closest analog to a
       dependency list (unit/package references — Delphi has no third-party
       manifest convention comparable to npm/NuGet). Version signal: none
       attempted — flagged explicitly in the payload as
       `"version_signal": null` rather than guessed. This is the ecosystem
       where FR4's "shallow, no uniform depth" decision matters most.
     - `Makefile` — detected as a tech-stack/build-tooling signal only; no
       dependency list (Makefiles don't enumerate third-party libs in a
       parseable way). `dependencies: []`.
   - **LOC per extension**: `wc -l` summed per file extension over the
     scoped file list (one pass, grouped in an associative array).
   - **Test-location detection**: filter the scoped file list for path
     segments/filenames matching `test`, `tests`, `spec`, `__tests__`,
     `*_test.*`, `*.test.*`, `*.spec.*`; report the matching directories
     (deduplicated), not every individual file.
   - **Discovered docs**: `bash "$SCRIPT_DIR/specclaw-discover-context"
     "$SPECCLAW_DIR" emit` — called exactly as `specclaw-build-context`
     already calls it, output embedded as one JSON-escaped string field. No
     re-implementation of ranking/filtering/budget logic.
   - Output: one `json_escape()`-safe JSON object (helper copied verbatim
     from `specclaw-verify`, per this repo's no-shared-lib convention),
     jq-validated when available, printed either way (same tolerant pattern
     `specclaw-verify collect`'s Step 8 uses).

2. **`agents/codebase-analyst.md`** — persona file, structured exactly like
   `code-reviewer.md`: YAML frontmatter (`name`, `description`, `tools: [Read,
   Write, Bash]`, `model: sonnet`), an "Inputs" section (the collected JSON
   payload + target path), a fixed-rubric table (6 rows this time: Tech
   Stack, Dependencies, Architecture, Domain, Risks, Suggested First
   Changes), an "Evidence Discipline" section adapted from `code-reviewer`'s
   ("every claim you cannot anchor to a file you opened is not a finding —
   drop it"), explicit domain-inference labeling rules, and an "Output"
   section specifying the exact `codebase-report.md` shape (mirrors
   `templates/codebase-report.md`). Unlike `code-reviewer`, this agent is
   handed a JSON facts payload rather than raw file contents up front — the
   agent is instructed to use its own `Read` tool to open specific files
   (manifests it wants full context on, suspected entry points, README/doc
   files, files whose names suggest domain entities) before writing any
   claim that isn't a direct pass-through of a collected fact (dependency
   name, LOC count, path).

3. **`templates/codebase-report.md`** — same `{{placeholder}}` scaffold
   convention as every other template, six body sections (five from the
   proposal plus Suggested First Changes) plus a small header (title, date
   analyzed, path scope).

4. **`skills/analyze/SKILL.md`** — the orchestration prose. Steps: ensure-init
   → resolve/validate `[path]` (Bash: `realpath`/`cd .. && pwd`-style
   containment check, matching FR2's "must resolve inside the repo" rule) →
   run `specclaw-analyze-codebase collect` → archive the existing report if
   present (`mv .specclaw/codebase-report.md
   .specclaw/codebase-reports/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md`,
   directly mirroring `skills/archive/SKILL.md`'s own plain `mv` instruction
   — no new bin script needed for this, matching how `archive` itself never
   got a "move" bin script either) → spawn `Agent` with `subagent_type:
   "codebase-analyst"`, passing the collected JSON + target path + template
   path → write the result to `.specclaw/codebase-report.md` → present a
   short summary.

No `specclaw-validate-change` case arm is added — this command doesn't
validate a `<change>`, it doesn't have one.

## Architecture

```
User: /specclaw:analyze [path]
        │
        ▼
skills/analyze/SKILL.md  (orchestration prose, not executable)
        │
        ├─ specclaw-ensure-init .specclaw
        ├─ resolve/validate [path]                       (FR2)
        ├─ bin/specclaw-analyze-codebase collect .specclaw [path]
        │     ├─ git ls-files / find (scoped)              ─┐
        │     ├─ manifest detection + dependency extraction  │  → one JSON
        │     ├─ wc -l per extension                         │    object
        │     ├─ test-location filter                        │    to stdout
        │     └─ specclaw-discover-context .specclaw emit   ─┘
        ├─ archive prior .specclaw/codebase-report.md (if any)  (FR8)
        ├─ Agent(subagent_type: "codebase-analyst", <JSON payload>)
        │     └─ Read tool: opens specific files for evidence/quotes
        └─ write .specclaw/codebase-report.md               (from templates/codebase-report.md shape)
```

Data flow is one-directional and read-only end to end: nothing under
`PROJECT_ROOT` other than `.specclaw/codebase-report.md` (and its archive
copy) is ever written.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/skills/analyze/SKILL.md` | create | `/specclaw:analyze [path]` orchestration (FR1, FR2, FR7, FR8) |
| `plugins/specclaw/bin/specclaw-analyze-codebase` | create | `collect` subcommand — fact-only JSON payload (FR3, FR4, FR10) |
| `plugins/specclaw/templates/codebase-report.md` | create | Report scaffold (FR6) |
| `plugins/specclaw/agents/codebase-analyst.md` | create | Fixed-rubric analysis persona (FR5) |
| `plugins/specclaw/tests/run-parser-tests.sh` | modify | New case: `specclaw-analyze-codebase collect` against a fixture (FR10, AC3–AC6) |
| `plugins/specclaw/tests/fixtures/analyze/` | create | Fixture tree: `package.json`, `go.mod`, a `.dproj` file, a `tests/` dir, misc source files with known extensions/LOC |
| `plugins/specclaw/.claude-plugin/plugin.json` | modify | Version bump (FR9) |
| `.claude-plugin/marketplace.json` | modify | Version bump, kept in sync (FR9) |
| `README.md` | modify | Commands table row (FR9, AC13) |

## Data Model Changes

New on-disk artifacts only, no schema changes to existing state:
- `.specclaw/codebase-report.md` — current report (stable path).
- `.specclaw/codebase-reports/archive/<YYYY-MM-DD-HHMMSS>-codebase-report.md`
  — prior reports, append-only over time (FR8).

Neither is read by any existing script in this change — `STATUS.md`,
`context.md`, and every `changes/<name>/` artifact are untouched (NFR4).

## API Changes

New CLI surface only:
- `/specclaw:analyze [path]` (skill/slash command).
- `bin/specclaw-analyze-codebase collect <specclaw_dir> [path]` (new script,
  new subcommand — no existing script's interface changes).

## Key Decisions

1. **Side-command, no lifecycle gate** — per the approved proposal and
   `docs/specclaw-architecture-notes.md` §6: this is read-only, whole-repo
   analysis, not a code-mutating phase. It joins `patterns`/`status` as a
   callable-any-time utility; `specclaw-validate-change` gets no new case
   arm.
2. **Promote, don't duplicate, the `/specclaw:plan` Step 3 survey** — the
   top-two-level directory summary and manifest-detection list move into
   `bin/specclaw-analyze-codebase` verbatim in shape. `/specclaw:plan` itself
   is left unmodified in this change (calling the new script from `plan` is
   the architecture notes' named "integration payoff," explicitly deferred).
3. **JSON facts, not a pre-built prompt** — `collect` emits structured facts
   only (mirrors `specclaw-verify collect`), not a formatted LLM prompt
   (unlike `specclaw-build-context`). The persona file (`codebase-analyst.md`)
   is self-contained enough that the skill can pass the JSON directly in the
   `Agent` call, the same way `/specclaw:verify` Step 3.5 passes context
   blocks straight to `code-reviewer` without an `agent-prompts.md`
   extraction step.
4. **Report is versioned, not overwritten** (per approved proposal decision,
   reversing the architecture notes' original "always current, like
   context.md" suggestion) — reuses the existing dated-archive convention
   from `skills/archive/SKILL.md` (`changes/archive/YYYY-MM-DD-<name>/`)
   rather than inventing a new versioning scheme or a symlink/pointer file.
5. **Delphi/`.dproj` gets no version signal** — Delphi's project file format
   has no cheap single-field version indicator comparable to a
   `<TargetFramework>` or `engines` block; rather than guess from compiler
   namespaces or `ProjectGuid` heuristics, the payload explicitly reports
   `version_signal: null` for this format. Consistent with FR4's shallow,
   no-uniform-depth decision.
6. **No new `agent-prompts.md` section** — per extension-recipe step 5, only
   add there if a bin script needs to extract a live template at runtime;
   `codebase-analyst.md` carries its own complete instructions instead.
7. **Archiving is a plain `mv` in the skill, not a new bin script** — mirrors
   `skills/archive/SKILL.md`'s own "3. Move to
   `.specclaw/changes/archive/YYYY-MM-DD-<change>/`" — a one-line
   filesystem operation doesn't earn a dedicated script.

## Grounding sources

- `docs/specclaw-architecture-notes.md` §6 ("Where a legacy-codebase
  analyzer slots in") — the entire recipe followed above: skill/bin
  script/template/agent shape, JSON-facts-only bin script, side-command
  classification, report location next to `context.md`/`patterns.md`.
- `plugins/specclaw/bin/specclaw-verify` — `collect`/`report`/
  `update-status` dispatch shape and the `json_escape()`/tmpfile-then-`mv`
  idioms reused for the new `collect` subcommand.
- `plugins/specclaw/bin/specclaw-discover-context` — git/`find` fallback
  detection (`git rev-parse --is-inside-work-tree`) and the `yaml_list()`
  in-section scanning idiom reused for TOML section-scoped dependency
  extraction (Cargo.toml, pyproject.toml).
- `plugins/specclaw/bin/specclaw-build-context` — the exact
  `specclaw-discover-context ... emit` subprocess call being mirrored
  verbatim for the `discovered_docs` field.
- `plugins/specclaw/agents/code-reviewer.md` — the fixed-rubric persona
  shape (`tools:`/`model:` frontmatter, "Evidence Discipline" section,
  quote-or-drop finding rule) `codebase-analyst.md` mirrors.
- `plugins/specclaw/skills/archive/SKILL.md` L13 ("3. Move to
  `.specclaw/changes/archive/YYYY-MM-DD-<change>/`") — the dated-archive
  convention reused for report versioning (FR8, Key Decision 4).
- `plugins/specclaw/skills/verify/SKILL.md` Step 3.5 — the "spawn an agent
  with context blocks directly, no `agent-prompts.md` extraction" pattern
  reused for the `codebase-analyst` invocation (Key Decision 3).
- `plugins/specclaw/skills/plan/SKILL.md` "Codebase survey" bullet (Step 3)
  — the exact `git ls-files | cut -d/ -f1-2 | sort -u` transform and manifest
  list being promoted into the new script.

## Risks & Mitigations

- **Per-format dependency extraction is inherently fragile (grep/awk, no
  real parser)** → matches this repo's existing risk posture (`yaml_val()`
  has the same limitation); mitigated by making every extractor best-effort
  (`|| true`, never aborts the script) and by the acceptance criteria only
  requiring correctness on the fixture's known-good manifests, not universal
  correctness on arbitrary malformed input.
- **Agent asserts something about the codebase it didn't actually read** →
  NFR2 + FR5's Evidence Discipline; `codebase-analyst.md` explicitly mirrors
  `code-reviewer.md`'s "unanchored finding is not a finding, drop it" rule.
- **Report versioning silently fills the repo with archive files over many
  re-runs** → acceptable for v1 (mirrors `changes/archive/` having the same
  unbounded-growth property today); no pruning is introduced, but the risk
  is named here rather than silently accepted so it can be revisited if it
  becomes a real problem.
- **`[path]` containment check is easy to get subtly wrong (symlinks,
  trailing slashes, `..` segments)** → resolved via `cd "$dir" && pwd`
  (physical path resolution) rather than string matching on the raw
  argument, then a simple prefix check against `PROJECT_ROOT`'s physical
  path — same technique bash scripts in this repo already use for
  `PROJECT_ROOT`/`SPECCLAW_DIR` resolution.
- **Delphi/`.dproj` XML shape assumptions turn out wrong on real-world
  projects** (single risk explicitly named in the proposal's problem
  statement) → mitigated by the fixture test (AC3) pinning at least one
  concrete `.dproj` shape, and by FR4/Key Decision 5 explicitly not
  promising version-signal depth for this format — a v1 that says "we don't
  know" is safer than one that guesses wrong.
