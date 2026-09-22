# Tasks: Model-invocation opt-out for the bf-* commands

**Change:** 039-model-invocation-opt-out
**Created:** 2026-09-20
**Total Tasks:** 9

## Summary

Seven tasks in three waves. Wave 1 is the audit that decides what wave 2 is allowed to switch off,
plus the two independent scaffolds (config key, gitignore). Wave 2 is the two real edits — the nine
skill handoffs (L1) and the bf-quality deterministic path (L2). Wave 3 is the test suite and its CI
registration, which gate the whole change.

T1 comes first on purpose: it is the deliverable that answers "which of these could we turn off",
and T4 must not pick its own answer.

## Tasks

### Wave 1 — Audit and scaffolds

- [x] `T1` — Audit and classify every bf spawn site
  - Files: `plugins/specclaw/references/model-invocation-map.md` (new)
  - Estimate: medium
  - Kind: docs
  - Notes: One row per bf spawn site (19: `bf-analyze` 1, `bf-architecture` 1, `bf-baseline` 2,
    `bf-blueprint` 1, `bf-bootstrap` 1, `bf-clarify` 5, `bf-domain` 1, `bf-e2e` 1, `bf-quality` 1,
    `bf-rebuild-plan` 1, `bf-replay` 2, `bf-ui` 2). Each row: skill, `SKILL.md:line`, agent,
    classification (`narration` | `judgement`), the cited line that justifies it, and — for
    `narration` only — the deterministic fallback. Read the agent's charter in `agents/` as well as
    the spawn site; `bf-quality-analyst`'s *"every status, severity, rollup and verdict … is already
    final"* is the model for what `narration` means. **Classify `judgement` when unsure** — a wrong
    `narration` call is a silently missing answer, a wrong `judgement` call costs only a spawn.
    Satisfies AC-3.

- [x] `T2` — Add the `bf:` config block
  - Files: `plugins/specclaw/templates/config.yaml`
  - Estimate: small
  - Kind: config
  - Notes: `bf.narration: true`, with the comment from design.md's Data Model section verbatim —
    including the sentence that this saves tokens/money/wall-clock but **not** main-session context.
    That sentence is the point; do not trim it.

- [x] `T3` — Gitignore the collector handoff directory
  - Files: `plugins/specclaw/bin/specclaw-init`
  - Estimate: small
  - Kind: impl
  - Notes: A second idempotent grep-guarded block in the shape of the existing `timeline.jsonl` one
    at `bin/specclaw-init:57-62` — guard on a fixed string, append once, `|| true`. Ignore
    `.specclaw/analysis/.collect/`. Satisfies AC-10.

### Wave 2 — The two levers

- [x] `T4` — L1: pass the collector path, not its stdout (nine skills)
  - Files: `plugins/specclaw/skills/bf-{analyze,architecture,baseline,blueprint,bootstrap,clarify,domain,rebuild-plan,ui}/SKILL.md`,
    plus the nine matching charters in `plugins/specclaw/agents/`
  - Estimate: large
  - Kind: docs
  - Depends: T1
  - Notes: Fifteen sites. Each becomes: `mkdir -p .specclaw/analysis/.collect`, redirect the
    collector to `.specclaw/analysis/.collect/<phase>.json`, **check the exit status before
    spawning**, then pass that path as the agent's context. `bf-clarify` has five modes and
    `bf-baseline`/`bf-ui` two each — give each mode its own file name, never a shared one, or two
    modes in one session overwrite each other. Copy the wording of `bf-quality/SKILL.md:71`, which
    already does this. Each charter gains one line: its facts arrive as a path it reads itself.
    Satisfies FR-1, FR-2, AC-1, AC-2.

- [x] `T5` — L2: deterministic report rendering for bf-quality
  - Files: `plugins/specclaw/bin/specclaw-bf-quality-render` (new),
    `plugins/specclaw/skills/bf-quality/SKILL.md`
  - Estimate: large
  - Kind: impl
  - Depends: T1, T2
  - Notes: The script reads `quality.json` + the template under `templates/`, copies the three
    `report_blocks.*_md` fields **verbatim** between the existing `<!-- quality-report:… -->`
    anchors, and replaces every narrated section body with
    `_Not narrated — deterministic mode. Facts below are collector output._`. Fail the way the
    existing lint does when a `report_blocks.<field>` is missing — never emit a report with a hole.
    Carry `yaml_val` in byte-identical form per the repo's duplication convention. The skill reads
    `bf.narration` and the `--no-model` ARGUMENTS token, and branches: **only the literal `false`
    (or the token) takes the deterministic path** — every other value leaves today's spawn intact.
    Satisfies FR-4, FR-5, FR-6, AC-4, AC-6, AC-7, AC-8.

### Wave 3 — Gates

- [x] `T8` — Fix the silent lint abort on a zero-entry QI registry
  - Files: `plugins/specclaw/bin/specclaw-bf-quality-collect`
  - Estimate: small
  - Kind: impl
  - Notes: Added to scope by operator decision after T5's verification hit it. `:3250` reads the QI
    registry through a grep with no `|| true`; its neighbour at `:3256` has one. A registry with zero
    `### QI-` entries — the normal state of a clean repo, or any machine without the complexity
    tooling — makes the grep exit 1 and `set -euo pipefail` abort `lint-report` silently: rc=1, no
    message, no verdict. Pre-existing on `main`; this change is simply the first thing to lint a
    report on a zero-hotspot repo. Satisfies AC-11, and unblocks AC-5 on any repo.

- [x] `T6` — Test suite for the narration gate
  - Files: `plugins/specclaw/tests/run-narration-gate-tests.sh` (new)
  - Estimate: medium
  - Kind: test
  - Depends: T3, T4, T5
  - Notes: jq-free. Cover: rendered report passes `specclaw-bf-quality-collect lint` unmodified
    (AC-5); markers present on every narrated section (AC-6); `bf.narration` absent/`true`/`off`/
    `no`/empty all leave narration **on** (AC-7); `--no-model` forces off, and no token forces on
    against `false` (AC-8); `yaml_val` reads `bf.narration` correctly from a config carrying decoy
    `narration:` keys in other blocks **and** with an inline trailing comment; `specclaw-init` twice
    appends the ignore block once (AC-10); the repo-wide grep of AC-1 returns zero.

- [x] `T9` — Restore yaml_val byte-identity and pin it
  - Files: `plugins/specclaw/bin/specclaw-bf-quality-render`,
    `plugins/specclaw/tests/run-narration-gate-tests.sh`
  - Estimate: small
  - Kind: refactor
  - Depends: T5, T6
  - Notes: Found by T6. T5's renderer claimed in a comment that its `yaml_val` was copied verbatim
    from `specclaw-build`, but had tidied it — comments dropped, `echo` → `printf '%s'`, quote
    stripping collapsed, one expansion quoted. `substitute()` was correctly identical. Restore the
    canonical body byte-for-byte and add Group G to the suite to pin both helpers. The canonical
    body trips SC2295, which is baselined for all seven existing copies but not for a new file;
    resolved with a targeted `# shellcheck disable=SC2295` **above** the definition (so it stays
    outside the compared body) carrying the rationale, rather than by editing this copy alone or
    by touching the baseline.

- [x] `T7` — Register the suite and bump the version
  - Files: `.github/workflows/ci.yml`, `plugins/specclaw/.claude-plugin/plugin.json`,
    `.claude-plugin/marketplace.json`
  - Estimate: small
  - Kind: config
  - Depends: T6
  - Notes: An unregistered suite silently never runs — this repo has been bitten twice. Patch bump,
    both version files in sync. Confirm `tests/shellcheck-gate.sh` passes with
    `shellcheck-baseline.txt` unmodified (NFR-2); fix any new finding or add a targeted
    `# shellcheck disable=` with a written rationale. Satisfies AC-9, NFR-3.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed
- `[>]` Deferred — correctly blocked on a sibling change, not incomplete through any fault of its own; excluded from the incomplete-task count that gates `verify`

**Task format:**
```
- [ ] `T<n>` — <title>
  - Files: <files to create/modify>
  - Estimate: small | medium | large
  - Kind: docs | test | config | refactor | impl | migration   (optional; hints the build subagent's role, tools, and model)
  - Depends: <task ids> (if any)
  - Notes: <additional context>
  - Deferred-Reason: <why this can't be built yet>            (required when marker is `[>]`)
  - Deferred-Blocked-On: <sibling change name, if known>      (optional; free text, not a structured link)
```

The optional `Kind` hint is consumed by `build.dynamic_agents` (when enabled) to
synthesize a specialized subagent per task. Omit it and build classifies
heuristically, defaulting to `impl`.
