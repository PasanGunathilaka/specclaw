---
description: Measure the code quality of a legacy or rebuilt codebase into `.specclaw/analysis/quality.json` plus a curatable report — complexity, function length, duplication, file length, per module. Advisory — blocks nothing. `--target` measures a rebuild, `--compare` diffs the two. Requires jq.
---

# specclaw bf-quality

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Measure code quality and write `.specclaw/analysis/quality.json` + `.specclaw/analysis/quality-report.md`. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`architecture`/`domain`/`clarify` pattern.

## What this command is, and what it is not

This is the **only** place quality is judged. `/specclaw:bf-analyze`, `/specclaw:bf-domain` and `/specclaw:bf-architecture` answer *what is this system*; this answers *what shape is the code in*. Those are different questions and the second one is a judgement, so it lives in exactly one command — a reader never has to wonder which document a complexity number came from. Nothing here changes what any other command does.

It is also not `agents/code-reviewer.md`. That reads one change's diff, forms a professional opinion across ten dimensions, and gates a PR. This reads a whole tree, runs measuring tools, and compares numbers to thresholds. The two deliberately disagree on some conventions — the reviewer flags functions over ~30 lines as a matter of taste, this command's default WARN band is 60 — because one is advice to an author and the other is a metric on a legacy corpus nobody is about to hand-tidy.

**Fully optional.** No other command requires anything this one produces. The single exception is `/specclaw:bf-rebuild-plan`, which annotates its per-module rollup with quality status *if* `quality.json` happens to exist and behaves byte-for-byte identically when it does not.

## Tool prerequisites

`jq` is required. The three metric tools are all optional and are probed at every run:

| Tool | Provides | Install |
|------|----------|---------|
| [`scc`](https://github.com/boyter/scc) | LOC, per-file line counts, per-language file counts | `go install github.com/boyter/scc/v3@latest`, or a release binary |
| [`lizard`](https://github.com/terryyin/lizard) | per-function cyclomatic complexity, function length, parameter count | `pip install lizard` |
| [`jscpd`](https://github.com/kucherenko/jscpd) | duplication percentage | `npm install -g jscpd` |

A missing tool never fails the run. Its metrics come back `NOT-MEASURED` with reason `tool_missing`, and the report says so on its face. **Do not install a tool mid-run to "fill in" a gap, and do not estimate a missing value** — a partial measurement that says which parts are missing is worth more than a complete-looking one that isn't.

Note that no tool covers every language. `lizard` does not parse Pascal, for instance, so a Pascal codebase reports size and duplication but no complexity, with reason `language_unsupported`. That is a permanent property of the toolchain, not a run-time failure.

## Determine the mode

Read the user's message:

| Mode | Trigger | Effect |
|------|---------|--------|
| Legacy report | *(default)* | measure the repo (or a given path), write `quality.json` + `quality-report.md`, register/update `QI-###`. Advisory, exit 0. |
| Target report | `--target <path>` | measure the rebuilt tree, write `quality-target.json` + `quality-target-report.md`. Registers no `QI-###`. |
| Compare | `--compare` | requires both snapshots, writes `quality-delta.json` + `quality-delta.md`. Advisory. |
| Gated compare | `--compare --gate` | as compare, plus a bash-computed verdict line and exit code. **The only enforcing mode.** |

A bare path with no flag is the legacy scope for that path.

## Step 1 — Collect

**Legacy or target report:**

```bash
specclaw-bf-quality-collect collect .specclaw [path]            # legacy
specclaw-bf-quality-collect collect .specclaw <path> --target   # target
```

`[path]` defaults to the repository root. The script probes the three tools, enumerates files (`git ls-files` inside a work tree, a pruning `find` otherwise, then the same uniform exclusion of `.specclaw/`, `node_modules/`, `vendor/`, `dist/`, `build/` every other collector applies), runs whichever tools are present, parses **only their machine-readable output**, joins each measured file to its `MOD-###`, applies the thresholds, computes every per-function, per-file and per-module status and rollup, registers or updates the `QI-###` registry, snapshots any prior artifact into `.specclaw/analysis/archive/`, and emits the finished JSON on stdout with a human-readable summary on stderr.

**If it exits non-zero, surface its stderr message to the user verbatim and stop** — don't retry, don't guess a different path, don't try to work around a missing tool. A non-zero exit here means infrastructure (no `jq`, a path outside the repo, no `.specclaw/`), never a quality finding.

**Compare:**

```bash
specclaw-bf-quality-collect compare .specclaw [--gate]
```

Requires both `quality.json` and `quality-target.json`; it fails fast naming whichever is missing and the command that produces it. Pass `--gate` only if the user asked for it.

## Step 2 — Spawn the narration agent

`Agent` tool, `subagent_type: "bf-quality-analyst"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`) — same tier as its sibling analysis agents, since this is read-only narration of an already-computed artifact. Pass as context:

- The resolved path of the JSON artifact it is to narrate (`quality.json`, `quality-target.json` or `quality-delta.json`) — it reads that file directly.
- Which report file to write (`quality-report.md`, `quality-target-report.md` or `quality-delta.md`) and the matching template path under `$CLAUDE_PLUGIN_ROOT/templates/`.
- The resolved measured path, and the mode.

**Tell the agent explicitly that every status, severity, rollup and verdict in the JSON is already final.** Its job is to say what the numbers mean, in prose a non-engineer can act on — not to check them. See `agents/bf-quality-analyst.md` for the constraints it operates under.

The agent writes the report itself. This skill writes no document.

Three of the report's sections are not narration at all. `report_blocks.scan_funnel_md`, `report_blocks.module_rollup_md` and `report_blocks.coverage_sentence_md` are markdown the collector rendered, and the agent pastes each one verbatim between the `<!-- quality-report:… -->` anchors the template puts them in. Tell it so explicitly when you spawn it.

## Step 3 — Lint the report against the artifact

```bash
specclaw-bf-quality-collect lint-report .specclaw <report.md> <artifact.json>
```

Run this every time, on the report that was just written, before saying anything to the user. It is part of the normal flow, not a test.

It checks four things mechanically: that every `MOD-###` in the document exists in the measurement, that every `QI-###` exists in the registry, and that each of the three anchored blocks is byte-identical to the field it was copied from.

**If it exits non-zero, do not report the findings to the user.** Show the lint's output, which names exactly what disagreed, and re-run the narration step telling the agent what to fix. A report that fails this is not a report with a small error in it — it is a document making claims the measurement does not support, and those are the claims most likely to be forwarded to a client.

This exists because a previous report invented a module row that appeared nowhere in the JSON, mis-summed its own status tally, and collapsed a five-stage scan funnel into a single figure that matched none of its stages. Every correct number was already in the artifact. Nothing compared the two.

For a compare run there is nothing to lint: `quality-delta.md` narrates deltas and carries no computed blocks. Skip this step and say so.

## Step 4 — Report to the user

State plainly, in this order:

1. **The measurement coverage first, before any finding.** How many files were measured, and which metrics were not measured for which languages and why. A reader who takes a rollup at face value without knowing that complexity was unmeasurable for a third of the tree has been misled, and putting coverage after the findings is how that happens.
2. Per-module rollup statuses, and the count of modules at `HIGH`.
3. New / open / resolved `QI-###` counts.
4. **How many files landed under `MOD-UNASSIGNED`, and why.** Nothing in `.specclaw/` maps a source file to a module — `module-map.md` maps modules to entities, rules, services and screens. The join therefore uses only the file paths each module actually cites in its own `**Evidence:**` bullets, and Evidence is a sample of a boundary rather than an inventory of one. A large unassigned bucket is the expected result on a map nobody has enriched, and it means the per-module numbers describe the cited slice rather than the whole module. Say that rather than letting the rollup read as complete. The fix is to cite more paths in `module-map.md`; guessing from directory layout is exactly the silent assignment that document raises a pending question for.
5. If `module-map.md` is `PROPOSED` rather than `CONFIRMED`, or absent, say so — the modules these numbers are grouped by are a proposal.
6. In gated compare, the verdict line verbatim.

Then say, in one sentence, that the default mode is advisory and blocked nothing.

## Configuration

Thresholds live in `.specclaw/config.yaml` under `quality:` and nowhere else. Defaults:

```yaml
quality:
  complexity_warn: 10          # cyclomatic complexity per function
  complexity_high: 20
  function_length_warn: 60     # lines per function
  function_length_high: 120
  duplication_warn: 5          # percent, per module
  duplication_high: 15
  file_length_warn: 500        # lines per file
  file_length_high: 1000
  register_severity: HIGH      # which band earns a permanent QI-### id
```

`register_severity` defaults to `HIGH` deliberately. `QI-###` ids are permanent and entries are never deleted, so a registry admitting every `WARN` on a large legacy tree would accumulate thousands of rows that outlive the code they describe. `WARN` findings are still counted in every module rollup — they are simply not individually immortalised. Set it to `WARN` if you want them tracked by id, and expect the registry to grow accordingly.

## QI-### permanence

Hotspots are registered in `.specclaw/analysis/quality-issues.md`, which joins `ST-###` and `IS-###` under `templates/CONTRACT.md` (c): ids are assigned once, sequentially, and never renumbered, reused or deleted. It carries their carve-out too — the registry is **append/update-in-place and is never archived**, because a registry that gets archived and regenerated is precisely the silent re-pointing (c) exists to prevent.

A hotspot's identity is the tuple `metric|file|scope|module|start_line`, never its value. Re-running on unchanged code therefore produces byte-identical id assignments. A hotspot that no longer exceeds its threshold has its `Status` flipped to `resolved` and keeps its id and `First seen` date forever — it is never removed, because "this used to be a hotspot" is itself the finding. A renamed file yields a new `QI-###` plus a resolved old one; inferring the rename would carry an id onto code nobody measured.

`scope` and `start_line` are what make two hotspots in one file distinguishable. The measuring tool reports the short function name, so two overloads share one string, and every unnamed function is reported under one name — so the four-field key that preceded this collapsed several hotspots onto one id and, on the following run, deleted all but one of them. `scope` is the function name, `<anonymous>` where the tool could not name it, or `*global*` where the metric has no function; `start_line` is 1 for a file-level metric and 0 for a module-level one. The collector asserts key uniqueness before it writes anything.

A registry still holding four-field keys is **migrated, never renumbered**: an id whose old key named one hotspot keeps its number and records the new key, and an id whose old key turned out to name several is assigned by the `Value` each entry recorded. The losers become `superseded-duplicate`, a terminal status naming the id that now owns their hotspot; nothing is deleted. Where the recorded values do not decide it, the run **stops** with `QUALITY-MIGRATION-AMBIGUOUS` rather than guessing. Each migration is recorded, dated, in the registry's `## Migration record` section, and a second run is a no-op.

`quality.json`'s `quality_issues[]` is a regenerated **projection** of that registry, not the registry itself. One direction per fact.

## Evidence retention

`quality.json` is the current snapshot. A re-run archives the prior one to `.specclaw/analysis/archive/<timestamp>-quality.json` — the same shared archive directory `analyze`/`architecture`/`domain`/`clarify` use — and stamps it `superseded: true` so a reader who finds it cannot mistake it for current. Its measurements are never altered.
