---
description: Show where a brownfield rebuild stands — one row per bf-* phase, what each produced, every open item holding a phase back, and the single next command to run. Read-only. Use when picking a rebuild back up, or when unsure which bf-* command comes next.
---

# specclaw bf-status

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Show where the brownfield workstream stands. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `status`/`patterns`/`bf-analyze` pattern.

1. **Compute and render:**
   ```bash
   specclaw-bf-status .specclaw
   ```
   Deterministic, read-only, cheap. Everything it reports is recomputed from each phase's own declared artifacts on every run.

   **If it exits non-zero, surface its stderr message verbatim and stop** — the only failures are a missing `<specclaw_dir>` (run `/specclaw:init`) and a missing argument. Don't retry, don't guess a different path.

2. **Relay its output to the user.** It is already a finished markdown report — a phase table, a **Needs attention** list, and a **Next** line. Present it as-is rather than paraphrasing it into prose. The attention list in particular is a work list someone can act on today; summarising it away is exactly the failure this command exists to fix.

3. **Lead with the `Next` line**, then name anything in **Needs attention** the user should know is *human* work no command can do for them: answering a blocking question, capturing a fixture or a screenshot, confirming the module map. Those are the items that silently stall a rebuild, because no command ever fails on account of them.

4. **If the user asked about one specific module rather than the workstream as a whole**, run the per-module view instead — it answers a different question and this command deliberately does not duplicate it:
   ```bash
   specclaw-bf-rebuild-collect module-status .specclaw
   ```
   That writes `.specclaw/analysis/module-status.md`: one row per `MOD-###` with backlog items planned/total, scenarios captured/designed, the latest module-scoped replay verdict, stub-tainted item counts, and open questions naming that module.

## What each phase row reads

Every row is derived from that phase's **own** declared artifact and nothing else. A phase whose document is absent reads `—` (not run) — never "probably fine", and never inferred from a sibling document that happens to mention it.

| Row | Reads |
|---|---|
| Codebase report | `analysis/codebase-report.md` |
| Architecture (C4) | `analysis/architecture.md` |
| Domain + module map | `analysis/domain-model.md`, `functional-spec.md`, `module-map.md` + its `**Status:**` line |
| Clarifications | `analysis/clarifications.md` (per-question `**Answer:**`/`**Blocking:**`), `decisions.md`, `pending-questions.md` |
| UI fidelity | `ui/ui-inventory.md`, `ui/ui-manifest.json` |
| Golden-master baseline | `baseline/seams.md`, `scenarios.md`, `error-map.md`, `harness/`, `manifest.json` |
| Rebuild backlog | `analysis/rebuild-backlog.md` (per-item `**Gate:**`/`**Verification:**`/`**Status:**`) |
| Target blueprint | `analysis/target-architecture.md`'s `**Blueprint status:**` line |
| Target foundation | `bootstrap/bootstrap-manifest.json` (`foundation_ready`, `not_applicable`) |
| Replay acceptance | every retained `run-metadata.json`, in both evidence pools |

**The replay row reports the latest verdict PER TARGET, not the latest run overall.** Two runs covering two different targets are two independent answers, and the newer does not supersede the older — reporting only the newest would hide a change whose own most recent verdict is `FAIL` behind an unrelated module that passed yesterday. A verdict earned while an `ACTIVE` dependency-bypass stub stood in for an unbuilt module is counted separately and reads `PASS*`, never `PASS`.

**`jq` is optional.** Without it the UI, baseline, bootstrap and replay rows report a file count instead of parsed detail, and say so on their own face. Every markdown-derived count stays exact.

## What this command does not do

`/specclaw:bf-status` **writes nothing** — not a status file, not a cache, not an archive entry. It is a status view, not evidence: it records no finding of its own, every number is recomputed from documents whose own history is already archived under `.specclaw/analysis/archive/`, and nothing reads its output. Re-running it costs a second and can never destroy or stale anything.

It never runs an agent, never reads application source, and never invokes another bf-* command. It reports what the artifacts say and stops.

It never says a phase, a module, or an item is **done**. specclaw records no built state for a backlog item beyond a status note a human typed, so every number here is a statement about planning, capture and comparison coverage — not about completion. A `DONE` row means that phase's command has run and its output has no open item, not that the work it describes is finished or signed off.

The **Next** line is the earliest unstarted phase, not a judgement about priority. When every phase has started it says so and points at **Needs attention** — most of what stalls a real rebuild is human work (answering a blocking question, running the harness, confirming the module map), and no command can clear it for you.

It does not duplicate `.specclaw/analysis/module-status.md`. That is the per-**module** view and it is a written artifact, regenerated by `/specclaw:bf-rebuild-plan` at the moment its inputs are freshest. This is the per-**phase** view. Neither is derivable from the other.
