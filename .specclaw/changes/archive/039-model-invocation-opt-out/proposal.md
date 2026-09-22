# Proposal: Model-invocation opt-out for the bf-* commands

**Created:** 2026-09-20
**Status:** 🟡 Draft

## Problem

Every `bf-*` command has the same shape: a deterministic bash collector produces facts, then an
analyst subagent turns those facts into markdown. Two things about that shape cost context, and
neither is controllable today.

**1. Collector payloads are routed *through* the main session.** Nine bf skills, at fifteen spawn
sites, instruct the orchestrator to pass **"the collected JSON (stdout of Step 1)"** as context to
the agent — `bf-analyze:32`, `bf-architecture:25`, `bf-baseline:38,77`, `bf-blueprint:38`,
`bf-bootstrap:65`, `bf-clarify:32,37,42,63,94`, `bf-domain:29`, `bf-rebuild-plan:30`,
`bf-ui:36,79`. To pass it, the orchestrator must first hold it. Measured on *this* repo — small,
mostly bash and markdown:

```
specclaw-bf-analyze-codebase collect .specclaw .   →  229,770 bytes  (~57k tokens)
```

That is ~57k tokens of main-session context for one `bf-analyze` run, on a repo far smaller than
the legacy Delphi/.NET systems the bf pipeline was built for. `bf-quality` already shows the fix:
it passes **"the resolved path of the JSON artifact it is to narrate… it reads that file
directly"** (`bf-quality:71`). The other nine do not.

**2. Some of those model calls cannot change any fact.** `bf-quality`'s analyst is told that
"every status, severity, rollup and verdict in the JSON is already final" and that three of the
report's sections are collector-rendered markdown it pastes **verbatim** between anchors
(`bf-quality:75,79`). The model is writing prose around numbers it is forbidden to touch. That is
a legitimate thing to want — and a legitimate thing to want to skip when the budget is tight.

**And there is no switch.** specclaw gates every other model spend behind a config key —
`workflow.code_review`, `workflow.staged_files_audit`, `build.dynamic_agents.enabled`,
`build.task_review`, `party.enabled`. The bf analysts are the exception: unconditional, with no
flag anywhere (`grep -roE '--(no|skip|without)-[a-z-]+'` across `skills/ bin/ lib/` returns only
`--no-ff`, `--no-verify`, `--no-gitignore`).

## Proposed Solution

Two independent levers. The first is free and needs no switch; the second is the switch.

**L1 — pass the path, not the payload.** Each bf skill redirects its collector to
`.specclaw/analysis/.collect/<phase>.json` and passes that *path* to the agent, exactly as
`bf-quality` already does. The agent reads the file itself with the tools it already has. No
config, no opt-in, no behaviour change — the agent sees the same bytes; the orchestrator no longer
does. This is where the ~57k tokens/run go away.

**L2 — `--no-model` / `models.narration: off`.** A documented opt-out for the spawn sites that
*narrate an already-final artifact*. When set, the skill skips the spawn and a deterministic
renderer fills the report template from the collector's own `report_blocks.*_md`, stamping every
section the model would have written with an explicit marker:

> `_Not narrated — deterministic mode. Facts below are collector output._`

so a rendered report is never mistaken for a written one. Shipped **off**, same one-release
rollout `code_review_block`, `staged_files_block` and `party.default` took.

**The audit is part of the deliverable, not a preamble to it.** Each of the fifteen spawn sites is
classified in a reference doc as *narration* (skippable — the artifact is final before the agent
runs) or *judgement* (never skippable — the agent decides something bash cannot), with the
evidence for the call. That table is what makes L2 safe to extend later, and it is the honest
answer to "which of these could we turn off".

## Scope

### In Scope
- Audit and classify all 15 bf spawn sites → `references/model-invocation-map.md`.
- **L1** across the 9 bf skills that currently inline collector stdout.
- **L2** implemented for **`bf-quality` only**, as the pilot — its collector already emits the
  pre-rendered `report_blocks.*_md`, so the deterministic path needs no new rendering logic.
- New config key + `templates/config.yaml` documentation, shipped off.
- Deterministic renderer bin + tests for the L2 path (report renders, markers present, lint step
  still passes against the artifact).

### Out of Scope
- Disabling any **judgement** spawn: `bf-domain`, `bf-clarify`, `bf-replay-auditor`,
  `bf-replay-mapper`, `bf-bootstrap`, `bf-rebuild-planner`, the party seats, `code-reviewer`.
  Those agents decide things; skipping them is not a saving, it is a missing answer.
- Extending L2 past `bf-quality` — the audit names the next candidates; a later change takes them.
- Shrinking the SKILL.md files themselves (`bf-replay` alone is 53 KB of prompt). Real context
  cost, genuinely separate change.
- Non-bf skills (`propose`, `plan`, `build`, `verify`).
- Any change to a collector's output schema.

## Impact

- **Size:** architectural (see note below — overridable to `bounded` if L1 ships alone)
- **Files affected:** ~14 (9 bf `SKILL.md`, `bf-quality/SKILL.md`, `templates/config.yaml`,
  1 new `bin/` renderer, 1 new `references/` doc, tests)
- **Complexity:** medium
- **Risk:** low — L1 is a mechanical prompt change with identical agent inputs; L2 ships off.

## Open Questions

- Does L1 alone satisfy the goal? It is the entire measured saving and needs no new config. L2 is
  the thing that was literally asked for, but it buys tokens-and-wall-clock, not main-session
  context — a subagent's prompt never enters this session.
- Where does the switch live — `models.narration: off` in `config.yaml`, a `--no-model` flag on the
  command, or both? A per-run flag is what someone tight on budget actually reaches for; a config
  key is what a project sets once.
- Should `.specclaw/analysis/.collect/` be gitignored, or kept as a debugging record of exactly
  what the agent was handed?

---

**To proceed:** Review this proposal and approve to begin planning.
