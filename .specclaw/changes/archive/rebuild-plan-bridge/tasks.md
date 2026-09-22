# Tasks: Connect the analysis layer to the delivery lifecycle (rebuild-plan-bridge)

**Change:** rebuild-plan-bridge
**Created:** 2026-07-24
**Total Tasks:** 8

## Summary

8 tasks across 4 waves. Waves 1–2 build the new command (scaffold → agent +
skill). Wave 3 adds test coverage and the operator doc. Wave 4 is repo
hygiene (version bump, README row) — held until everything else is
functionally complete so the bump reflects the finished feature. No task
touches `skills/propose/`, `skills/plan/`, `skills/build/`,
`skills/verify/`, `skills/pr/`, or their bin scripts/agents.

## Tasks

### Wave 1 — Scaffolding

- [x] `T1` — Create `templates/rebuild-backlog.md`
  - Files: `plugins/specclaw/templates/rebuild-backlog.md`
  - Estimate: small
  - Notes: Mirror the shape of `templates/domain-model.md`/`functional-
    spec.md` (title/path/date header, then sections). Sections: `## Backlog`
    (`{{backlog_items}}`), `## Sequencing Rationale`
    (`{{sequencing_rationale}}`), `## Coverage Check`
    (`{{coverage_check}}`). Document, in an HTML comment, the expected
    per-item sub-structure the agent should follow (title, "Maps to
    capability", "Depends on", "Acceptance basis", "Verification inputs
    needed" — matching `design.md`'s Architecture section) so the template
    itself teaches the shape, same as every other template in this repo.

- [x] `T2` — Create `bin/specclaw-rebuild-collect`
  - Files: `plugins/specclaw/bin/specclaw-rebuild-collect`
  - Estimate: medium
  - Notes: `collect <specclaw_dir>` subcommand. Checks existence of
    `.specclaw/analysis/{codebase-report,architecture,domain-model,
    functional-spec}.md` relative to `specclaw_dir`'s parent. If any are
    missing, print (to stderr) exactly which are missing and which command
    produces each (`codebase-report.md` → `analyze`; `architecture.md` →
    `architecture`; `domain-model.md`/`functional-spec.md` → `domain`),
    then exit non-zero. If all present, emit one JSON object to stdout:
    `{"docs": [{"path":..., "lines": N}, ...], "project_root": "..."}` — no
    markdown parsing, existence/line-count facts only (per design.md Key
    Decision #5). Follow existing script conventions: `set -euo pipefail`,
    self-contained `json_escape`/helpers (no shared lib), `-h|--help` usage
    block, no hard `jq` dependency (mirror `specclaw-analyze-codebase`'s
    tolerant style).

- [x] `T3` — Add commented-out `context.pin` example to `templates/config.yaml`
  - Files: `plugins/specclaw/templates/config.yaml`
  - Estimate: small
  - Notes: Under the existing `context:` block's comment header, add a
    commented-out example:
    ```yaml
    #   pin:
    #     - .specclaw/analysis/codebase-report.md
    #     - .specclaw/analysis/architecture.md
    #     - .specclaw/analysis/domain-model.md
    #     - .specclaw/analysis/functional-spec.md
    #   (see docs/rebuild-workflow.md for the full recipe, incl. max_lines sizing)
    ```
    Do not activate the pin by default (design.md Key Decision #8) — this
    task only adds the commented example + doc pointer, no behavior change.

### Wave 2 — Agent + Skill (depends on Wave 1)

- [x] `T4` — Create `agents/rebuild-planner.md`
  - Files: `plugins/specclaw/agents/rebuild-planner.md`
  - Depends: `T1`, `T2`
  - Estimate: medium
  - Notes: Frontmatter matching sibling analysts (`name`, `description`,
    `tools: [Read, Write, Bash]`, `model: sonnet`). Inputs section: the
    collected JSON (existence/line-count map only) plus instruction to
    `Read` all four analysis docs directly for full content — mirror the
    "collected JSON is a starting map, not a substitute" framing used
    verbatim in `codebase-analyst.md`/`domain-analyst.md`. Rubric: (1)
    decompose `functional-spec.md` Capabilities into backlog items,
    merging only with a stated rationale (design.md Key Decision #3); (2)
    for each item, cross-reference `domain-model.md` Entities/Business
    Rules/Enumerations as its acceptance basis; (3) sequence items using
    `architecture.md`'s C4 levels/diagram plus `functional-spec.md`
    Workflows (foundational/depended-upon pieces first); (4) mandatory,
    never-blank "Verification inputs needed" field per item, biased toward
    naming golden-master capture and any external-format/DLL/COM semantics
    the docs flag as not fully recoverable from static analysis (spec.md
    Notes / Fidelity limitation); (5) a Coverage Check pass confirming
    every `functional-spec.md` Capability is covered or explicitly excluded
    with a reason. Evidence Discipline clause identical in spirit to the
    sibling agents: every backlog item claim anchored to a quote from one
    of the four opened files. Zero-capabilities edge case: write "No
    capabilities found — insufficient evidence to build a backlog" (per
    spec.md Edge Cases), never fabricate. Output: fill
    `templates/rebuild-backlog.md`, written once at the end.

- [x] `T5` — Create `skills/rebuild-plan/SKILL.md`
  - Files: `plugins/specclaw/skills/rebuild-plan/SKILL.md`
  - Depends: `T2`, `T4`
  - Estimate: medium
  - Notes: Frontmatter `description` written for the model router, in the
    style of `analyze`/`architecture`/`domain`'s descriptions (read-only,
    no TTY, no lifecycle gate, works on any stack). Body: (1) `specclaw-
    ensure-init .specclaw` boilerplate line, same as every skill; (2) run
    `specclaw-rebuild-collect collect .specclaw` — **if it exits non-zero,
    surface its stderr verbatim and stop** (same convention as `analyze`/
    `architecture`/`domain`'s own missing-input handling); (3) archive
    prior `rebuild-backlog.md` into `.specclaw/analysis/archive/` if one
    exists (design.md Key Decision #7); (4) spawn `Agent` tool,
    `subagent_type: "rebuild-planner"`, model from `config.yaml`
    `models.review` (design.md Key Decision #6), passing the collected
    JSON + the four resolved doc paths; (5) present a short summary
    (backlog item count, any Coverage Check exclusions) **and remind the
    user to `git add .specclaw/analysis/*.md` (+ the new
    `rebuild-backlog.md`) if not already tracked**, since pin-based
    grounding depends on `discover-context`'s `git ls-files` enumeration
    (design.md Risks). Explicitly state in the skill body: creates nothing
    in `changes/`, calls no lifecycle command — the operator runs
    `/specclaw:propose` per item themselves.

### Wave 3 — Tests + Operator Doc (depends on Wave 2)

- [x] `T6` — Add `specclaw-rebuild-collect` test case to `run-parser-tests.sh`
  - Files: `plugins/specclaw/tests/run-parser-tests.sh`
  - Depends: `T2`
  - Estimate: medium
  - Notes: Mirror Case 9/11's structure (fixture setup → run `collect` →
    assert JSON shape). Two scenarios: (a) all four fixture docs present →
    assert the emitted JSON lists all four paths with correct line counts;
    (b) one or more missing → assert non-zero exit and that stderr names
    the specific missing file(s) + producing command. Add fixture files
    under `tests/fixtures/` as needed (small placeholder `.md` files are
    sufficient — this script never parses their content).

- [x] `T7` — Write `docs/rebuild-workflow.md`
  - Files: `docs/rebuild-workflow.md`
  - Depends: `T5`
  - Estimate: medium
  - Notes: Operator-facing runbook, per design.md Key Decision #1. Steps,
    in order: (1) run `/specclaw:analyze`, `/specclaw:architecture`,
    `/specclaw:domain`; (2) `git add .specclaw/analysis/*.md` — explain
    *why* (discover-context's `git ls-files`-based enumeration, stated as
    the first gotcha, in bold, before the config snippet — design.md
    Risks); (3) set `context.pin` to the four paths + `context.max_lines`
    using the `wc -l`-based sizing formula (design.md Key Decision #2),
    with a literal copy-pasteable shell line; (4) run
    `/specclaw:rebuild-plan`; (5) run `/specclaw:propose "<item>"` per
    backlog entry manually — state plainly that this step is not
    automated and never will be by this command. Close with a restated
    **Fidelity limitation** section, verbatim in spirit with spec.md's
    Notes: pin + backlog give you the acceptance basis, not proof of
    behavioral equivalence; golden-master outputs and external-format/DLL
    semantics are inputs a human must still supply.

### Wave 4 — Repo Hygiene (depends on Wave 3)

- [x] `T8` — Version bump + README row
  - Files: `plugins/specclaw/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`
  - Depends: `T6`, `T7`
  - Estimate: small
  - Notes: Bump `"version"` in both manifests from `0.5.6` to `0.5.7`
    (keep them in sync — this repo's own `CLAUDE.md` rule). Add a
    `/specclaw:rebuild-plan` row to root `README.md`'s commands table,
    matching the existing row style for `analyze`/`architecture`/`domain`.

---

## Legend

- `[ ]` Pending
- `[~]` In Progress
- `[x]` Complete
- `[!]` Failed

**Task format:**
```
- [ ] `T<n>` — <title>
  - Files: <files to create/modify>
  - Estimate: small | medium | large
  - Depends: <task ids> (if any)
  - Notes: <additional context>
```
