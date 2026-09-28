# The `analyze-command` Change, Explained

What `/specclaw:analyze` actually is, grounded in the change trail at
`.specclaw/changes/analyze-command/` (proposal → spec → design → tasks →
verify-report) and cross-checked against the files that actually shipped in
`plugins/specclaw/`. Merged via `e486300 Merge specclaw/analyze-command`
(waves `4f3c4d2` → `b6bc8b8` → `558e1cb`); version bumped `0.5.3` → `0.5.4`.

Where the trail and the code agreed, this just states the fact. Where they
didn't — or where the trail's own verify-report already flagged a gap —
that's called out explicitly in **§6**.

---

## 1. What Was Added

Nine file changes, exactly matching design.md's File Changes Map, all
verified present on disk as described:

| File | Type | What it is / does |
|---|---|---|
| `plugins/specclaw/skills/analyze/SKILL.md` | **Skill** | Registers `/specclaw:analyze [path]`. Orchestration prose only — no executable logic of its own. Model-invokable (no `disable-model-invocation`). |
| `plugins/specclaw/bin/specclaw-analyze-codebase` | **Bash script** | The `collect` subcommand: deterministic fact-gathering (tracked + untracked-non-ignored file enumeration, manifest/dependency detection across 8 formats, binary-safe LOC-per-extension, binary artifact inventory, legacy/database artifact categories, test-location detection, `discovered_docs` passthrough), emitted as one JSON object to stdout. Zero interpretation — that's the agent's job. |
| `plugins/specclaw/templates/codebase-report.md` | **Template** | The `{{placeholder}}` scaffold for the written report: header fields (title, path, date) + 6 body sections. Not executable — a shape the agent fills in. |
| `plugins/specclaw/agents/codebase-analyst.md` | **Agent** | A subagent persona (`name: codebase-analyst`, `tools: [Read, Write, Bash]`, `model: sonnet`). Takes the collected JSON, **reads real files itself**, and writes the final `.specclaw/codebase-report.md`. This is the piece that does the actual thinking. |
| `plugins/specclaw/tests/run-parser-tests.sh` | **Test** (modified) | Existing regression suite; gained "Case 9" (12 sub-assertions, 9a–9l) exercising the new bash script. |
| `plugins/specclaw/tests/fixtures/analyze/` | **Test fixture** (data, not code) | 7 checked-in files (`package.json`, `go.mod`, `AnalyzeFixture.dproj`, `README.md`, `sample.qux`, `sub/extra.txt`, `tests/sample.txt`) — a minimal multi-ecosystem tree Case 9 runs against. |
| `plugins/specclaw/.claude-plugin/plugin.json` | **Manifest** (modified) | Version bump only: `0.5.3` → `0.5.4`. |
| `.claude-plugin/marketplace.json` | **Manifest** (modified) | Same version bump, kept in sync with the plugin manifest. |
| `README.md` | **Docs** (modified) | One new Commands-table row: `` `/specclaw:analyze [path]` — Analyze an existing/legacy codebase and write `.specclaw/codebase-report.md` (read-only) ``, placed next to `/specclaw:status`. |

**The skill/agent distinction, explicitly:** there is exactly **one skill**
(`skills/analyze/SKILL.md`) and exactly **one agent**
(`agents/codebase-analyst.md`) in this change. The skill is a numbered
procedure Claude follows — it never touches a file directly and contains no
analysis logic. The agent is the subagent that gets spawned partway through
that procedure; it's the only piece that reads source files and writes the
report. The bash script sits between them as a third, distinct kind of
thing — deterministic, non-agentic fact collection — and the template is a
fourth kind again: a static shape neither the skill nor the script executes,
only the agent fills in.

Not part of this table, but also new on disk from the same work: the six
`.specclaw/changes/analyze-command/*.md` files (proposal/spec/design/tasks/
status/verify-report). These are specclaw's own **process trail** for
building this feature — dogfooding, not shipped plugin capability — so they
don't get a skill/agent/script/template label; they're planning documents
that happen to live in the repo.

---

## 2. The Command

**What the user types:** `/specclaw:analyze` or `/specclaw:analyze <path>`.

**What it reads:**
- `.specclaw/config.yaml` — for `models.review` (which model runs the
  analysis agent; same default `/specclaw:verify` uses,
  `anthropic/claude-sonnet-4-5`) and for `context.*` settings that
  `specclaw-discover-context` (called internally) respects.
- The scoped file tree itself — `git ls-files` (or a `find` fallback)
  under the resolved `[path]`, plus the raw content of every manifest file
  it detects (`package.json`, `*.csproj`/`*.sln`, `pom.xml`, `go.mod`,
  `Cargo.toml`, `requirements.txt`/`pyproject.toml`, `*.dpr`/`*.dproj`,
  `Makefile`).
- Whatever additional files the `codebase-analyst` agent decides to `Read`
  during its own investigation (entry points, README/docs, domain-shaped
  files) — the collected JSON is a map, not the full picture.

**What it writes:**
- `.specclaw/codebase-report.md` — the current report, always at this
  stable path.
- `.specclaw/codebase-reports/archive/<YYYY-MM-DD-HHMMSS>-codebase-report.md`
  — the *previous* report, moved here (not deleted) before the new one is
  written, if one existed.

**What it never touches:** no `changes/<name>/` directory, no
`STATUS.md`, no `specclaw-validate-change` call, no source code. It is
read-only over the analyzed codebase with exactly two write targets, both
inside `.specclaw/`.

`[path]`, when given, must be a subdirectory of the current repository;
analyzing an external/different repo is explicitly out of scope for v1 (a
named v2 candidate in both proposal.md and spec.md).

---

## 3. The Flow

One run of `/specclaw:analyze [path]`, step by step:

1. **`skills/analyze/SKILL.md` fires** (model-invoked, or explicit
   `/specclaw:analyze`). Step 0, like every skill: `specclaw-ensure-init
   .specclaw`.
2. **The skill immediately shells out to the bash script:**
   `specclaw-analyze-codebase collect .specclaw [path]`.
   - Inside the script, `cmd_collect` first **resolves and validates**
     `[path]`: physically resolves it (`cd "$dir" && pwd`), confirms it
     exists, confirms it's under `PROJECT_ROOT`, and rejects it if it *is*
     `.specclaw` or nested inside it. Any failure here `die`s with a
     stderr message and a non-zero exit — **before any collection runs.**
   - It then collects five independent groups of facts, in this order (not
     that order matters — none depends on another):
     1. File enumeration — inside a git work tree, tracked files unioned with
        untracked-but-not-ignored files
        (`{ git ls-files; git ls-files --others --exclude-standard; } | sort -u`),
        scoped by prefix to `[path]`, or a `find`-with-prune fallback when
        there's no git work tree. A legacy source drop extracted into a freshly
        `git init`'d repository with no commit is therefore still enumerated;
        ignored files stay out. `.specclaw`, `node_modules`, `vendor`, `dist`,
        `build` are always excluded from the result regardless of which
        enumeration path ran.
     2. Top-two-level directory summary (`cut -d/ -f1-2 | sort -u`).
     3. Manifest detection across all 8 formats, each with its own
        best-effort grep/awk/sed dependency (and where cheap, version)
        extractor — nothing here ever aborts the script on a malformed
        file.
     4. LOC per file extension (one `wc -l` pass, grouped by extension) —
        **binary-safe**: a single deterministic extension→category lookup
        routes each file, and files in a binary category are never passed to
        the `wc -l` pass, so a binary can neither inflate `loc_by_extension`
        nor be read as text. A binary-only repository yields an empty
        `loc_by_extension`.
     4a. Binary artifact inventory — binary-category files are counted per
        extension into `binary_artifacts_by_extension` and totalled in
        `binary_artifact_count` (stable schema: `{}` / `0` when none).
     4b. Artifact categories — every classified file is rolled up by category
        into `artifact_categories` (each with a `count` and a per-extension
        breakdown). Text categories `database_source` (PL/SQL package specs
        and bodies, triggers, views, procedures, functions, types, plain SQL)
        and `loader_control` (`.ctl`) contribute to `loc_by_extension` as
        normal; the `forms_reports_binary` subset (`fmb rdf mmb pll olb`) and
        the generic `binary` category do not. Categories with zero files are
        omitted; the object is `{}` when nothing matches.
     5. Test-location detection (`test`/`tests`/`spec`/`__tests__`
        directories, `*_test.*`/`*.test.*`/`*.spec.*` files) — reported as
        deduplicated directories, not individual files.
     6. `discovered_docs` — shells out to the existing
        `specclaw-discover-context <specclaw_dir> emit` and embeds its
        digest verbatim; no reimplementation.
   - All of that is assembled into **one JSON object** whose top-level
     fields are `path`, `project_root`, `top_level_dirs`, `manifests`,
     `loc_by_extension`, `binary_artifacts_by_extension`,
     `binary_artifact_count`, `artifact_categories`, `test_locations`,
     `dependency_graph`, and `discovered_docs`, and printed to stdout. The
     three artifact keys are additive; every pre-existing key keeps its name,
     type, and meaning. If it exits non-zero instead, the skill surfaces the
     stderr message verbatim and **stops** — no retry, no guessed path.
3. **The skill archives the prior report, if one exists** — a plain `mv`
   (no script involved): `.specclaw/codebase-report.md` →
   `.specclaw/codebase-reports/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md`.
   Skipped entirely on a repo's first run.
4. **The skill spawns the `codebase-analyst` agent** (`Agent` tool,
   `subagent_type: "codebase-analyst"`, model from `models.review`),
   passing the collected JSON and the resolved target path directly as
   context — no prompt-template extraction step (unlike the Verify Agent,
   this persona is self-contained).
5. **The agent does the actual analysis.** It reads
   `templates/codebase-report.md` to know the required shape, then works
   through six rubric dimensions (Tech Stack, Dependencies, Architecture,
   Domain, Risks, Suggested First Changes) — and for anything beyond a
   direct pass-through of a collected fact, it uses its own `Read` tool to
   open real files (manifests it wants full context on, suspected entry
   points, README/docs, domain-entity-shaped files) before writing a claim.
   Every Domain finding is prefixed `Inference:` (or `Inference (low
   confidence):`); anything it can't anchor to an opened file gets dropped,
   not guessed.
   - **Evidence discipline.** Claims are grounded in the target source tree and
     the collector output. Generated analysis folders, prior AI reports, and
     `.specclaw/` outputs are not evidence for source-code claims unless they
     are primary project documentation inside the analysed path. Files in a
     binary category are evidence only for existence, path, extension, size,
     count, and location — never opened, decompiled, or reasoned about for
     behaviour; where a binary has no readable source, that is stated as a
     limitation. Insufficient evidence is stated as a limitation rather than
     guessed, and credentials, connection strings, private keys, tokens, and
     hostnames are never reproduced in the report.
   - **Suggested First Changes** keeps its exact heading but is limited to
     evidence-grounded investigation / characterization entry points (each with
     a WHY from `analyze.json`). It proposes no target technologies, rewrites,
     migrations, sequencing, or effort estimates — those belong to
     `bf-rebuild-plan`.
6. **The agent writes `.specclaw/codebase-report.md`** itself, once, at
   the end — the skill never touches this file directly.
7. **The skill presents a short summary** to the user: path analyzed,
   sections written, any low-confidence flags the report raised.

```
/specclaw:analyze [path]
  │
  ├─ 1. specclaw-ensure-init .specclaw
  ├─ 2. specclaw-analyze-codebase collect .specclaw [path]   (bash — facts only)
  │        → resolve/validate [path]  → die on failure, stop
  │        → file enum → manifests → LOC → test-locations → discover-context digest
  │        → one JSON object to stdout
  ├─ 3. mv codebase-report.md → codebase-reports/archive/<timestamp>-...  (if it existed)
  ├─ 4. Agent(subagent_type: "codebase-analyst", <JSON + path>)
  │        → reads templates/codebase-report.md for shape
  │        → Read tool: opens real files for evidence
  │        → writes .specclaw/codebase-report.md            (agent — interpretation)
  └─ 5. summary to user
```

**Re-run behavior (archive-on-rerun):** the *n*-th run always leaves
exactly one live report at the stable path and accumulates one more dated
file under `.specclaw/codebase-reports/archive/` per prior run — nothing is
ever silently overwritten, and nothing is pruned (an accepted, explicitly
named unbounded-growth tradeoff, same as `changes/archive/` already has).

---

## 4. How the Pieces Relate

```
   ORCHESTRATES                  COLLECTS FACTS                INTERPRETS            OUTPUT SHAPE
 ┌────────────────┐    calls    ┌───────────────────────┐              ┌──────────────────────┐   fills   ┌────────────────────────┐
 │ skills/analyze/ │ ─────────► │ bin/specclaw-analyze- │              │ agents/codebase-      │ ────────► │ templates/codebase-    │
 │ SKILL.md        │            │ codebase (collect)    │─── JSON ───► │ analyst.md            │           │ report.md              │
 │ (prose only)    │ ◄───────── │ (deterministic bash)  │   payload    │ (Read/Write/Bash,      │           │ ({{placeholder}} shape) │
 └────────────────┘   spawns   └───────────────────────┘              │  model: sonnet)        │           └────────────────────────┘
        │                                                              └──────────────────────┘                       ▲
        │                                                                        │                                    │
        └────────────────────────── archives prior report ─────────────────────  └── writes .specclaw/codebase-report.md, using this shape
```

- **The skill orchestrates** — it's the only piece aware of the whole
  sequence (ensure-init → collect → archive → spawn agent → summarize). It
  contains no analysis logic itself.
- **The bash script collects** — pure fact-gathering, no judgment calls. It
  would produce the same JSON for the same repo state regardless of which
  LLM or model runs afterward.
- **The agent interprets** — the only piece that reads live source files
  and forms conclusions (tech stack, domain inferences, risk judgment).
  Everything it asserts must trace to either a collected fact or a file it
  opened itself.
- **The template defines the output shape** — a static contract both the
  proposal/spec (five sections) and the agent's actual output (those five
  plus Suggested First Changes) agree on. Nothing executes it; the agent
  reads it once for structure and writes matching prose.

This is a deliberately different shape from `/specclaw:verify`, which
extracts its agent's prompt at runtime from `references/agent-prompts.md`.
Here, `codebase-analyst.md` is self-contained enough that the skill just
passes the JSON straight into the `Agent` call — the design explicitly
chose this to mirror how `/specclaw:verify` Step 3.5 hands context blocks
straight to `code-reviewer` (Key Decision 3 in design.md).

---

## 5. Decisions Locked In

From the proposal's "Open Questions" (all resolved at approval) and
design.md's "Key Decisions," confirmed against the shipped code:

- **Path scoping: subdirectory only, external repos deferred to v2.**
  `[path]` must resolve inside the current repository or the script `die`s
  (confirmed: the `case "$scope_dir" in "$project_root"|"$project_root"/*`
  containment check in `specclaw-analyze-codebase`). Analyzing a different
  filesystem location entirely is explicitly out of scope for v1 in both
  proposal.md and spec.md's Notes.
- **Archive-on-rerun, not overwrite-in-place.** Reverses the architecture
  notes' original suggestion (treat the report like `context.md`, always
  current) in favor of reusing the existing `changes/archive/
  YYYY-MM-DD-<name>/` dated-archive convention from
  `skills/archive/SKILL.md`. Confirmed shipped exactly this way — a plain
  `mv` in the skill, not a new bin script (design's Key Decision 7:
  "a one-line filesystem operation doesn't earn a dedicated script").
- **Shallow version extraction, no uniform depth promise.** Every one of
  the 8 manifest formats gets ecosystem detection + a dependency list;
  a version signal is captured *only* where one cheap field already
  carries it (`package.json`'s `engines.node`, `.csproj`'s
  `<TargetFramework>`, `go.mod`'s `go` directive, `Cargo.toml`'s
  `edition`, `pyproject.toml`'s `requires-python`). Maven and Delphi get
  no version signal at all — confirmed: `process_manifest`'s `maven` and
  `delphi` cases never call a version-signal extractor, so `version_signal`
  is always `null` for those two formats.
- **The `collect` subcommand shape.** `bin/specclaw-analyze-codebase`
  exposes `collect <specclaw_dir> [path]`, deliberately mirroring
  `specclaw-verify collect <specclaw_dir> <change_name>`'s dispatch shape
  (`case "$1" in collect) ... esac`, `-h|--help`), rather than a single
  unnamed fact-dump command — confirmed exactly this in the shipped
  script's `case "${1:-}" in ... collect) ...` block.
- **Side-command, no lifecycle gate.** No `specclaw-validate-change` case
  arm was added for `analyze` — confirmed by grep: the skill contains no
  reference to `specclaw-validate-change` anywhere. It joins
  `patterns`/`status` as a callable-any-time utility, per the proposal's
  explicit framing and the architecture notes' §6 recipe it was built
  from.

---

## 6. Known Limitations

Carried forward from verify-report.md's "Issues Found" (verdict was still
**PASS**, 13/13 ACs — these are non-blocking notes, not failures), each
re-checked against the current state of the repo:

1. **No live end-to-end run artifact exists yet.** Confirmed still true:
   there is no `.specclaw/codebase-report.md` and no
   `.specclaw/codebase-reports/` directory anywhere in this repo. Every
   claim about AC8/AC9 behavior (report sections populated correctly, the
   archive-on-rerun mechanics) rests on the skill/agent *instructions*
   being correctly wired, not on an observed output file. The verify
   report's own recommended fix — run `/specclaw:analyze` twice against a
   real or fixture repo and inspect both the live and archived output —
   has not yet been done.
2. **NFR5's atomic-write convention isn't actually implemented.** Spec's
   NFR5 calls for the same tmpfile-then-`mv` atomicity
   `specclaw-verify update-status` already uses. Re-reading the shipped
   `agents/codebase-analyst.md` Output section confirms the gap is still
   there: it says only "Write the file once, at the end, after completing
   all six dimensions" — a single `Write` tool call, not a temp-path-then-
   move pattern. This avoids *incremental* partial writes but doesn't
   match NFR5's stated convention literally.
3. **Three edge cases from spec.md are coded for but untested:** a
   zero-manifest repo (pure-docs), a monorepo with duplicate-ecosystem
   manifests at different levels, and a malformed/empty manifest file.
   Confirmed still true — `tests/fixtures/analyze/` contains exactly three
   manifests (`package.json`, `go.mod`, one `.dproj`), no duplicates, and
   nothing malformed; Case 9 in `run-parser-tests.sh` has no assertions
   for any of these three scenarios. The relevant code paths (e.g.
   `[ -s "$manifests_tmp" ]` being false → `manifests: []`) look correct by
   inspection but remain unexercised by any test.
4. **A pre-existing, unrelated bug surfaced during this change's
   verification** (out of scope for `analyze-command` itself, not a
   limitation of what shipped here): `specclaw-verify collect`'s file-path
   extraction has a fallback-array bug that silently drops most tasks'
   `Files:` entries once the first one populates it. Noted in
   verify-report.md purely for operator awareness — it was not touched by
   this change and doesn't affect `/specclaw:analyze`.

**One additional gap found during this reconciliation, not previously
flagged in verify-report.md:** the bash script's post-filter that excludes
`node_modules`/`vendor`/`dist`/`build`/`.specclaw` from the `git ls-files`
enumeration path (needed because, unlike the `find` fallback, `git
ls-files` doesn't prune anything — a committed `vendor/` directory would
otherwise leak into LOC/manifest/top-level-dir results) is real and correct
in the shipped script, but design.md's prose only describes this exclusion
list in the context of the `find` fallback, not as a filter re-applied
uniformly to both enumeration paths. The code is more careful than the
design doc's wording suggests — a good discrepancy, but a discrepancy: read
the script's own inline comment (just above the exclusion `case` block) as
the actual source of truth here, not design.md's Technical Approach
section.
