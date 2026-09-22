# Design: Connect the analysis layer to the delivery lifecycle (rebuild-plan-bridge)

**Change:** rebuild-plan-bridge
**Created:** 2026-07-24

## Technical Approach

Two independent, additive tracks — neither touches `skills/propose`,
`skills/plan`, `skills/build`, `skills/verify`, `skills/pr`, or their bin
scripts/agents:

1. **Grounding recipe (Option A):** a documented, verified configuration —
   `context.pin` listing the four `.specclaw/analysis/*.md` paths, plus
   `context.max_lines` sizing guidance. No code changes; `is_pinned()` in
   `specclaw-discover-context` already runs before `default_dir_excluded()`,
   so pinning bypasses the `.specclaw`-directory exclusion today. This
   track is proven by directly exercising the existing, unmodified script
   (AC1), not by writing new code.
2. **Bridge command (Option B):** a new side-command,
   `/specclaw:rebuild-plan`, built with the same four-piece shape every
   existing analysis command uses (`skills/analyze`, `skills/architecture`,
   `skills/domain`): skill → bin collector → template → agent. It reads the
   four analysis docs (which the operator has already produced) and writes
   one new artifact, `.specclaw/analysis/rebuild-backlog.md`.

The two tracks compose: `rebuild-planner` (track 2's agent) is grounded in
the same four docs track 1 pins for the lifecycle — there is exactly one
grounding path, not two parallel ones.

## Architecture

`rebuild-plan` is a **side-command**, not a lifecycle phase — same category
as `patterns`/`status`/`analyze`/`architecture`/`domain`. It gets no
`specclaw-validate-change` case arm, no `<change>` argument, and creates
nothing under `.specclaw/changes/`. This mirrors the existing family
exactly, per `docs/specclaw-architecture-notes.md` §6:

```
/specclaw:rebuild-plan
  │
  ├─ specclaw-ensure-init .specclaw            (idempotent, same as every skill)
  ├─ specclaw-rebuild-collect collect .specclaw
  │    → existence-check the 4 analysis docs
  │    → on any missing: print which + which command produces it, exit non-zero
  │    → on all present: emit {path, lines, exists:true} per doc as JSON
  ├─ archive prior rebuild-backlog.md, if any    (mv into analysis/archive/)
  ├─ [Agent rebuild-planner]
  │    reads the 4 docs directly via its own Read tool (JSON above is just
  │    an existence/size map, not a substitute — same convention as
  │    codebase-analyst/domain-analyst/architecture-analyst)
  │    → writes .specclaw/analysis/rebuild-backlog.md
  └─ present summary (item count, waves inferred, any coverage exclusions)
```

Bash collects deterministic facts only (existence + line counts); all
decomposition, cross-referencing, and sequencing judgment happens in the
`rebuild-planner` agent. This is the same "bash gathers, agent interprets"
split used by every other analysis command in this plugin — `bin/specclaw-
rebuild-collect` does **not** attempt to parse capabilities or rules out of
markdown prose in bash; that would be fragile and duplicate work the agent
is already equipped to do with its own `Read` tool.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/templates/rebuild-backlog.md` | Create | Output scaffold: `{{backlog_items}}`, `{{sequencing_rationale}}`, `{{coverage_check}}` placeholders |
| `plugins/specclaw/bin/specclaw-rebuild-collect` | Create | Existence-check + line-count JSON emitter for the 4 analysis docs; clear per-doc missing-file errors |
| `plugins/specclaw/agents/rebuild-planner.md` | Create | Persona: decompose functional-spec capabilities into backlog items, cross-ref domain-model rules/entities, sequence via architecture.md, mandatory "Verification inputs needed" field, coverage check |
| `plugins/specclaw/skills/rebuild-plan/SKILL.md` | Create | `/specclaw:rebuild-plan` orchestration — ensure-init → collect → archive-prior → spawn agent → summarize |
| `docs/rebuild-workflow.md` | Create | Operator recipe: analyze → git add → pin/max_lines → rebuild-plan → propose per item; restates Fidelity limitation |
| `plugins/specclaw/templates/config.yaml` | Modify | Add a **commented-out** example `context.pin` block + pointer to the new doc — no default-behavior change |
| `plugins/specclaw/tests/run-parser-tests.sh` | Modify | Add a case for `specclaw-rebuild-collect`: all-present JSON shape + missing-doc error path |
| `plugins/specclaw/.claude-plugin/plugin.json` | Modify | `version` `0.5.6` → `0.5.7` |
| `.claude-plugin/marketplace.json` | Modify | `plugins[].version` `0.5.6` → `0.5.7` |
| `README.md` | Modify | Commands table row for `/specclaw:rebuild-plan` |

No file under `skills/propose/`, `skills/plan/`, `skills/build/`,
`skills/verify/`, `skills/pr/`, or their referenced scripts/agents appears
in this table — confirmed by re-reading each of those five `SKILL.md`
files and their invoked `bin/specclaw-*` scripts during proposal research.

## Data Model Changes

None. `.specclaw/analysis/rebuild-backlog.md` is a new markdown artifact,
not a new persistent data structure — it follows the same
`.specclaw/analysis/<doc>.md` + `.specclaw/analysis/archive/` convention
`codebase-report.md`/`architecture.md`/`domain-model.md`/`functional-
spec.md` already established.

## API Changes

None. `/specclaw:rebuild-plan` is a new skill entry point, not a change to
any existing script's CLI surface. `bin/specclaw-rebuild-collect` is a new
script with its own `collect` subcommand — it does not modify the
subcommand surface of `specclaw-analyze-codebase` or `specclaw-domain-
collect`.

## Key Decisions

1. **Doc location (resolves proposal Open Question #1):** the operator
   recipe lands in a new `docs/rebuild-workflow.md`, not appended to
   `docs/specclaw-architecture-notes.md`. Rationale: architecture-notes.md
   is investigation/maintainer documentation about how the plugin works;
   this is an operator-facing runbook ("do X, then Y, then Z") — a
   different genre that deserves its own file.
2. **`context.max_lines` sizing (resolves Open Question #2):** the doc
   gives a formula, not a fixed guess: `wc -l .specclaw/analysis/*.md |
   tail -1` for the pinned total, plus headroom (documented default: +3000)
   for other repo docs discovery would otherwise surface. A fixed number
   would be wrong for most real legacy codebases; a formula the operator
   can actually run is simple enough to state in one line.
3. **Capability→item mapping (resolves Open Question #3):** left as the
   `rebuild-planner` agent's judgment call. When it merges small/related
   capabilities into one backlog item, it must say so in that item's
   rationale — never merge silently. No fixed 1:1 rule is imposed (Rule 2,
   Simplicity First: forcing 1:1 would over-decompose trivially small
   capabilities into their own backlog entries).
4. **No `--focus` flag in v1 (resolves Open Question #4):**
   `/specclaw:rebuild-plan` always produces the full backlog. A scoping
   flag is a plausible follow-up but would be speculative to build before
   anyone has hit the "backlog is unwieldy" problem in practice.
5. **`bin/specclaw-rebuild-collect` stays fact-only.** It checks existence
   and reports line counts; it does not parse capabilities/rules/entities
   out of markdown. All synthesis is the agent's job, reading the four
   files directly — consistent with `codebase-analyst`/`domain-analyst`/
   `architecture-analyst`, all of which treat their "collected JSON" as a
   map, not a substitute for opening real files.
6. **`rebuild-planner` model: `models.review`, not `models.planning`.**
   Matches its three sibling analysis agents exactly (`codebase-analyst`,
   `architecture-analyst`, `domain-analyst` all run on `models.review`,
   default `anthropic/claude-sonnet-4-5`). Even though the synthesis is
   judgment-heavy, it is still read-only analysis of already-written docs
   — not spec/design authoring for a change — so it belongs with its
   family, not with `plan`'s `models.planning`.
7. **Archive-before-overwrite**, identical pattern to `analyze`/
   `architecture`/`domain`: `mkdir -p .specclaw/analysis/archive && mv
   .specclaw/analysis/rebuild-backlog.md .specclaw/analysis/archive/
   $(date +%Y-%m-%d-%H%M%S)-rebuild-backlog.md` before writing a new one,
   skipped when no prior file exists.
8. **`templates/config.yaml`'s pin example ships commented out.** An active
   default pin would reference four files that don't exist on a fresh
   project (harmless — `discover-context` skips non-existent pinned paths
   — but noisy). Commented-out documents the recipe without changing any
   project's default discovery behavior.

## Risks & Mitigations

- **Risk:** operator forgets `git add .specclaw/analysis/*.md` before
  relying on the pin — the docs silently stay invisible to discovery even
  though `context.pin` lists them (pin only reaches paths `git ls-files`
  already enumerates).
  **Mitigation:** `docs/rebuild-workflow.md` states this as the very first
  step, in bold, before the pin config itself; `/specclaw:rebuild-plan`'s
  own summary step reminds the user to stage the four docs (and the new
  backlog file) if they aren't already tracked.
- **Risk:** pinning all four (potentially large) docs starves the shared
  `context.max_lines` budget, silently degrading `plan`/`build`/`verify`
  grounding for unrelated changes in the same project.
  **Mitigation:** the sizing formula in Key Decision #2; no code fix is
  attempted since `specclaw-discover-context` already reports every
  truncation/drop in a footer comment — this change relies on that
  existing, correct behavior rather than adding new budget logic.
- **Risk:** `rebuild-planner` overclaims — asserts a dependency order or a
  verification requirement the source docs don't actually support.
  **Mitigation:** same Evidence Discipline convention as the sibling
  analysts (anchor every claim to a quoted capability/rule/entity); the
  "Verification inputs needed" field is mandatory and never blank,
  specifically to force an explicit human-input call-out instead of quiet
  overclaiming that "same app" fidelity is already proven.
- **Risk:** scope creep later wires `rebuild-plan` to auto-invoke
  `/specclaw:propose` per item, silently reintroducing the lifecycle
  coupling this change deliberately avoids.
  **Mitigation:** stated explicitly in `skills/rebuild-plan/SKILL.md` and
  here: this command calls no lifecycle command, full stop; any future
  automation is a separate, separately-proposed change.
