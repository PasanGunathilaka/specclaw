# Design: Model-invocation opt-out for the bf-* commands

**Change:** 039-model-invocation-opt-out
**Created:** 2026-09-20

## Technical Approach

Three pieces, deliberately unequal in risk.

**L1 (markdown only).** Nine `SKILL.md` files change one instruction each. Where a skill today says

> Run `specclaw-bf-<x> collect .specclaw` … pass **the collected JSON (stdout of Step 1)**

it will say

> ```bash
> mkdir -p .specclaw/analysis/.collect
> specclaw-bf-<x> collect .specclaw > .specclaw/analysis/.collect/<phase>.json
> ```
> Check the exit status. Pass the agent **the path** `.specclaw/analysis/.collect/<phase>.json`;
> it reads the file itself.

No `bin/` change, no config, no new behaviour — the agent receives the same bytes by a different
route. The matching agent charter in `agents/` gains one line saying its facts arrive as a path.

**L2 (one new script + one config key).** `bf-quality`'s skill reads `bf.narration` with the
existing `yaml_val` helper and, when it is the literal `false` (or `--no-model` is in ARGUMENTS),
skips the spawn and calls `specclaw-bf-quality-render` instead. The renderer reads `quality.json`,
copies the three `report_blocks.*_md` fields verbatim between the report template's existing
`<!-- quality-report:… -->` anchors, and replaces every narrated section body with a fixed marker
line. Its own output is then checkable by the `lint` subcommand that already exists.

**The audit (one new reference doc).** Every bf spawn site gets a row: `narration` or `judgement`,
the line that justifies the call, and the fallback. This is the artifact that answers "which of
these could we turn off", and it is what a later change reads before extending L2.

## Architecture

```
bf skill (SKILL.md)
  │
  ├─ 1. collect ──────────► .specclaw/analysis/.collect/<phase>.json   [L1: bytes land on disk,
  │                                                                     not in the orchestrator]
  ├─ 2. read bf.narration (yaml_val) + --no-model token
  │
  ├─ narration ON (default) ──► Agent(subagent_type: …, context = the PATH)
  │                                └─ agent reads the file, writes the report
  │
  └─ narration OFF ───────────► specclaw-bf-quality-render
                                   └─ template + report_blocks.*_md + markers → report
                                        └─ verified by `… collect lint` (already exists)
```

L1 applies to all nine skills unconditionally. L2 applies to `bf-quality` only in this change; the
other narration candidates are named in the reference doc and left alone.

## File Changes Map

| File | Action | Description |
|------|--------|-------------|
| `plugins/specclaw/skills/bf-analyze/SKILL.md` | modify | redirect collector → `.collect/analyze.json`; pass path |
| `plugins/specclaw/skills/bf-architecture/SKILL.md` | modify | same, `.collect/architecture.json` |
| `plugins/specclaw/skills/bf-baseline/SKILL.md` | modify | same, two sites (design + harness modes) |
| `plugins/specclaw/skills/bf-blueprint/SKILL.md` | modify | same, `.collect/blueprint.json` |
| `plugins/specclaw/skills/bf-bootstrap/SKILL.md` | modify | same, `.collect/bootstrap.json` |
| `plugins/specclaw/skills/bf-clarify/SKILL.md` | modify | same, five sites, one file per mode |
| `plugins/specclaw/skills/bf-domain/SKILL.md` | modify | same, `.collect/domain.json` |
| `plugins/specclaw/skills/bf-rebuild-plan/SKILL.md` | modify | same, `.collect/rebuild-plan.json` |
| `plugins/specclaw/skills/bf-ui/SKILL.md` | modify | same, two sites |
| `plugins/specclaw/agents/*.md` (9 charters) | modify | one line: facts arrive as a path, read it |
| `plugins/specclaw/references/model-invocation-map.md` | **create** | the 19-row audit table |
| `plugins/specclaw/skills/bf-quality/SKILL.md` | modify | read `bf.narration` / `--no-model`; branch to render |
| `plugins/specclaw/bin/specclaw-bf-quality-render` | **create** | deterministic report renderer |
| `plugins/specclaw/templates/config.yaml` | modify | new `bf:` block, documented, shipped `true` |
| `plugins/specclaw/bin/specclaw-init` | modify | idempotent `.gitignore` block for `.collect/` |
| `plugins/specclaw/tests/run-narration-gate-tests.sh` | **create** | AC-4…AC-8, AC-10 |
| `.github/workflows/ci.yml` | modify | register the new suite (NFR-3) |
| `plugins/specclaw/.claude-plugin/plugin.json` | modify | version bump |
| `.claude-plugin/marketplace.json` | modify | version bump, in sync |

## Data Model Changes

One new config block, shipped in the ON position:

```yaml
# Brownfield (bf-*) command settings
bf:
  # Narration agents — the bf spawns whose artifact is ALREADY FINAL before the
  # agent runs (see references/model-invocation-map.md for which ones those are).
  # false = skip the spawn; the report is rendered deterministically from the
  # collector's own output, with every un-narrated section marked as such.
  #
  # This saves tokens, money and wall clock. It does NOT save main-session
  # context: a subagent's prompt never enters the orchestrator's window. The
  # context saving comes from the collector handoff, which needs no switch.
  #
  # Anything other than the literal `false` means narration stays on.
  narration: true
```

New on-disk artifact: `.specclaw/analysis/.collect/<phase>.json` — per-run handoff, truncated on
every write, gitignored, read once by the agent it was written for.

## Key Decisions

1. **The skill redirects; the collectors are not touched.** A `--out` flag on nine collectors would
   be nine bash changes to buy what `>` already does. L1 stays a markdown change, which is why it
   can ship unconditionally with no switch.
2. **A dot-prefixed directory under `analysis/`.** `git add .specclaw/analysis/*.md` — the command
   `docs/rebuild-workflow.md` tells users to run — will not sweep it, and `specclaw-discover-context`
   enumerates via `git ls-files`, so an ignored file is invisible to discovery. Both properties come
   free from the name.
3. **`bf.narration`, not `models.narration`.** The `models:` block is a model-routing map
   (`planning`/`coding`/`review`); a boolean does not belong in it. A `bf:` block also gives the
   next bf-wide setting somewhere obvious to live.
4. **The opt-out tightens per run but never loosens.** `--no-model` can force narration off against
   a `true` config; nothing forces it on against a `false` config. This mirrors the repo's rule that
   *"a `--force` flag on a safety check may only override the specific failure mode it documents"* —
   a per-run token that could re-enable spend the project disabled is a switch that does not hold.
5. **Only the literal `false` disables.** `off`, `no`, `0`, empty and typos all leave narration on.
   The failure direction matters: a misread key that silently skips a model produces a report nobody
   knows was unwritten.
6. **`bf-quality` is the pilot because it arrives with its own verifier.** `… collect lint` already
   asserts each anchored region is byte-identical to `report_blocks.<field>`. The deterministic path
   is therefore checkable by machinery that exists, on day one.
7. **`.collect/` is a handoff, not a cache.** It stores no fact that is consulted later, is
   overwritten every run, and has exactly one reader. The repo's "derived, not stored" rule is about
   facts that drift; this file cannot drift because nothing reads it after its one agent does.

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| An agent charter still assumes inline JSON and ignores the path it is given, producing a report from nothing | FR-2 updates all nine charters in the same change; the reference doc records the pairing so the skill/charter mismatch is visible in one table |
| A deterministically rendered report is mistaken for a written one | FR-5's marker is mandatory on every narrated section, and AC-6 gates it |
| Collector fails mid-redirect, agent is handed truncated JSON | The skill checks the collector's exit status before spawning (Edge Cases); the redirect truncates on open, so a stale complete file can never masquerade as fresh |
| `yaml_val` reads the wrong `narration:` from a neighbouring block | `yaml_val` windows on a column-0 section header before matching an indented key (`bin/specclaw-build:83-95`); `bf:` is top-level and the key name is unique. A test pins the read against a config carrying decoy keys — this is the exact failure that made `party` need its own reader |
| Scope drift into "disable every model call" | Out of scope is explicit: `judgement` spawns are named individually in the reference doc and untouched |
| Nine near-identical markdown edits, one silently missed | AC-1 is a repo-wide grep that must return zero — one command proves all nine |

## Grounding sources

- `.specclaw/context.md` — *"Every test suite must be registered in `.github/workflows/ci.yml`. An
  unregistered suite silently never runs — this has happened twice in this repo."* → NFR-3, AC-9.
- `.specclaw/context.md` — *"Never introduce a counter, index, or cache for something the filesystem
  already states."* → Key Decision 7 states why `.collect/` is not one.
- `.specclaw/context.md` — *"A `--force` flag on a safety check may only override the specific
  failure mode it documents, never the check itself."* → Key Decision 4.
- `.specclaw/context.md` — *"Where a helper function is deliberately duplicated between two
  standalone executables … the copies are kept byte-identical and a test pins that identity."* →
  the `yaml_val` copy in the new renderer (NFR-4).
- `plugins/specclaw/skills/bf-quality/SKILL.md:71,75,79` — the path-passing precedent and the
  "already final" narration contract → L1's shape and L2's pilot choice.
- `plugins/specclaw/bin/specclaw-bf-quality-collect:91,2438-2440,3266-3286` — collector writes
  `quality.json` *and* emits stdout; `report_blocks.*_md`; the `lint` byte-identity check → FR-5, AC-5.
- `plugins/specclaw/bin/specclaw-init:57-62` — the existing idempotent grep-guarded `.gitignore`
  block → FR-7's shape.
