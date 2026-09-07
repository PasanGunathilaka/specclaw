---
description: Scaffold the target application foundation in the NEW rebuild repo — app shell, routing, API client, persistence, DI, config, test structure — from the stack decisions.md records. Implements no backlog capability. Run once per rebuild repo, before the first /specclaw:propose.
---

# specclaw bf-bootstrap

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Create the target application's foundation in the **new (rebuild) repo**. This is the stage that used to be missing, and its absence is what let the first backlog item proposed accidentally inherit responsibility for inventing half the application skeleton — a screen-bearing item quietly shipping as a backend-only slice because nothing else owned the frontend's existence.

**The boundary that defines this command:** it creates the things every backlog item will stand on, and **not one thing any backlog item is for**. See **The foundation-only boundary** below; it is enforced by a gate, not by good intentions.

Read-only side-command with respect to `.specclaw/analysis/` and `.specclaw/baseline/` — it never writes into either, never touches the legacy repo, and calls no lifecycle skill or script. It is the one brownfield command that writes application source, and it does so exactly once per repo.

Invocation:
```
/specclaw:bf-bootstrap                          # scaffold the foundation
/specclaw:bf-bootstrap --adopt                  # a foundation already exists by hand: smoke + record it, scaffold nothing
/specclaw:bf-bootstrap --not-applicable "<why>"  # this repo is not the rebuild target; record that once
```

## Step 0 — `--not-applicable` (early exit)

**Only when the user invoked `--not-applicable`.** This repo is not the rebuild target — record the declaration and stop. Nothing else on this page runs: no collect, no agent, no scaffold, no smoke.

```bash
specclaw-bf-bootstrap not-applicable .specclaw \
  --reason "<why — the user's own words>" \
  --declared-by "<name>, <YYYY-MM-DD>"
```

Both flags are required and the subcommand refuses the declaration without them. That is deliberate: this declaration switches off `/specclaw:propose`'s target-foundation gate, and an unexplained or unattributable one is indistinguishable from having skipped the foundation by accident — the exact failure the gate exists to catch. Ask the user for their name, and for the reason if the invocation didn't carry one; never supply either yourself.

If a real foundation manifest already exists, the subcommand refuses to overwrite it with a not-applicable declaration and says so — relay that verbatim rather than moving the manifest aside on your own initiative. If the declaration was already made, it reports that and leaves it unchanged.

Then run **Step 7** to show what comes next, and stop.

## Step 1 — Collect (Phase 0 validate + Phase 1 resolve the stack)

```bash
specclaw-bf-bootstrap collect .specclaw
```

**If it exits non-zero, surface its stderr message to the user verbatim and stop.** There are three refusals, and each one names its own fix:

- **No `rebuild-backlog.md`** — this repo is not a rebuild target, or the Phase A artifacts have not been copied in yet (`docs/rebuild-workflow.md`'s Phase B copy set).
- **No `decisions.md`** — bootstrap consumes decided architecture and cannot proceed without the decision record.
- **A required target decision is unresolved** — the message names the exact `SQ-###` ids. **Do not work around this, do not infer the answer from the legacy stack, and do not pick "the obvious modern choice".** Ask-don't-guess applies to scaffolding exactly as it applies to analysis: a foundation built on a stack nobody chose is worse than no foundation, because every item built afterwards inherits the guess and the cost of correcting it compounds. Relay the ids, say they are answered with `/specclaw:bf-clarify` (then `--resolve`) and re-copied, and stop.

The required set is `SQ-001` (target platform), `SQ-002` (database engine/hosting), `SQ-003` (hosting model), `SQ-004` (auth approach — it decides whether the shell has an auth *boundary*, never that auth is implemented), `SQ-006` (UI framework), `SQ-013` (UI fidelity policy) and `SQ-014` (target backend stack). A decision declared **not applicable** in `clarifications.md`'s `## Not Applicable` section counts as resolved — a rebuild with no server side genuinely has no backend stack to choose, and that is an answer, not a gap.

On success it emits one JSON object carrying the resolved decisions with their sources, the closed vocabularies the agent must declare against, and a `mode` field. **The mode decides what happens next:**

| `mode` | What it means | What to do |
|---|---|---|
| `fresh` | No manifest, no source outside `.specclaw/` | Scaffold. Go to Step 2. |
| `gap-fill` | A manifest exists but is not ready | Scaffold **only** the pillars recorded `absent`/`failed`. Never touch a pillar recorded `present`. |
| `recorded-ready` | A ready foundation is already recorded | **Do not scaffold anything.** Re-run `gate` and `smoke` to confirm nothing regressed, report the recorded stack and pillars, and stop. Re-running bootstrap on a healthy foundation is a no-op, exactly as `specclaw-ensure-init` is on an initialized project. |
| `adopt-candidate` | No manifest, but source already exists here | **Stop and ask.** Never scaffold over an application somebody already wrote. Report what is there and offer `--adopt`, which runs Steps 4–5 only against the existing foundation. If the user says it is not a foundation (a stray README, a licence file), they can say so and you continue as `fresh`. |

## Step 2 — Spawn the bootstrap agent

`Agent` tool, `subagent_type: "bf-bootstrap-architect"`, on the model from `config.yaml` `models.coding` (default: `anthropic/claude-sonnet-5`) — deliberately **not** `models.review`, which every sibling `bf-` agent uses. Those agents read documents and write findings; this one writes real application source, which is build work. Pass as context:

- The collected JSON from Step 1, including its `mode` and its `vocabulary` block.
- The resolved paths of `.specclaw/analysis/decisions.md`, `rebuild-backlog.md`, `module-map.md`, and — when present — `.specclaw/ui/ui-inventory.md` and `design-tokens.json`, for the agent to `Read` directly.
- The project root, so the agent can read any ADR this repo already carries and can write the scaffold.
- **Tell the agent explicitly which mode it is running**, and — for `gap-fill` — exactly which pillars it may create.

The agent writes three things itself: the scaffold, `.specclaw/bootstrap/bootstrap-plan.md` (Phase 2 — the human-readable record of the structure, boundaries, testing approach and dev setup it chose, and the token-plumbing line it drew), and `.specclaw/bootstrap/.bootstrap-declaration.json` (its own census of what it created). This skill writes none of them. See `agents/bf-bootstrap-architect.md`.

**The declaration is the whole trust model.** The agent declares *what it did* — which pillars, which files with which purpose, which routes, which screens, which token groups, which decisions it consumed and from where. Bash then decides what that means. No agent asserts that the boundary was respected or that the foundation is ready.

## Step 3 — Gate: the foundation-only boundary

```bash
specclaw-bf-bootstrap gate .specclaw
```

**If it exits non-zero, surface every problem it lists verbatim and stop.** Fix the scaffold — or the declaration, if the declaration misdescribes a scaffold that is actually fine — and re-run `gate`. Do not record a manifest around a failing gate; `record` refuses anyway.

Seven checks, all over declared data plus narrow id greps: pillar vocabulary; no file declared with purpose `capability`; every file purpose inside the closed set; route census (at most one `health` route, everything else `shell`/`error`/`layout`); screen census; no `DR-###`/`BL-###`/`SCR-###` id anywhere in a created file; and design-token groups limited to what the declaration says it imported.

**Say the limit out loud when you report a PASS.** This is a declared-census check plus id greps. It cannot prove the absence of capability logic — a rule implemented without citing its `DR-###` passes it. It is worth running because a scaffold naming a specific screen, rule or backlog item is unambiguously over the line, and because the census makes the claim reviewable. Presenting it as proof that no business logic exists would be exactly the overclaim `templates/CONTRACT.md` spends its length avoiding.

## Step 4 — Smoke: prove the foundation actually runs

```bash
specclaw-bf-bootstrap smoke .specclaw [--timeout <seconds>]
```

Runs each smoke check the declaration named, from the project root, capping each log under `.specclaw/bootstrap/smoke/`. The closed check set is `frontend-build`, `frontend-start`, `api-build`, `api-start`, `db-connect`, `migrations-infra`, `frontend-to-api`, `test-frontend`, `test-backend`.

**Every command must terminate on its own.** A start check is expressed as something that starts the process, proves it answered, and stops it — never a bare `serve` that runs forever. A command that does not terminate is recorded as `FAILED (timed out)` rather than hanging the step.

A check that genuinely does not apply is `SKIPPED` **with a stated reason**, which the manifest keeps. A skip with no reason is indistinguishable from never having thought about it, and `record` refuses one.

**If a required check fails, report it and stop.** The remedy is to fix the scaffold, not to record a foundation nobody proved starts. `smoke` exits non-zero when anything failed.

## Step 5 — Record

```bash
specclaw-bf-bootstrap record .specclaw
```

Merges the declaration, the gate result and the smoke results into `.specclaw/bootstrap/bootstrap-manifest.json` (`templates/CONTRACT.md` (n)), archiving any prior manifest first. `foundation_ready` is **computed here, by bash** — every pillar `present` or `absent-by-decision`, every required smoke check `PASS` or `SKIPPED` with a reason, gate `PASS`, and every required decision recorded as consumed with a source path that exists. It is never asserted by the agent.

Like `/specclaw:bf-baseline --record`, this is **fallible by design**: it collects every problem in one pass and, if there are any, writes no manifest and archives nothing. A run that produced an invalid state must not also destroy the last valid one. **If it exits non-zero, relay its problem list verbatim** — every entry names both the problem and the fix.

On success it deletes the declaration (a transient draft, like `.rebuild-plan-draft.md`) and prints the path plus the pillar/file/smoke counts.

## Step 6 — Present a summary

- The identified stack, named from `decisions_consumed` — and **which decision each part came from**, with its source. "React because SQ-006 says React" is the sentence that makes the scaffold reviewable; "React, the modern choice" is the sentence this command exists to prevent.
- Every pillar and its status. Name every `absent-by-decision` pillar **with its reason** — a pillar that is deliberately absent is a design statement someone may want to argue with, and burying it in a JSON file wastes it.
- The gate result **with its stated limit**.
- The smoke results, naming every skipped check and its reason.
- **The token-plumbing line the plan drew**, when the UI fidelity policy is `FAITHFUL` or `THEME-ONLY`: which global `TK-` groups were imported, and the explicit statement that no screen-scoped token group and no screen layout was reproduced — those belong to the screen-bearing backlog items, and `ui-review.md` is where a named human signs them off per change.
- **What happens next, in one line:** `/specclaw:propose "<the backlog's recommended next item>"`. The foundation gate will now pass, and from here on every backlog item is a proper vertical slice through an application that already exists.

Remind the user to `git add` the scaffold and `.specclaw/bootstrap/` — the manifest is the gate's input, and an untracked one is invisible to a fresh clone and to CI.

## Step 7 — Show what comes next

```bash
specclaw-bf-status .specclaw --next
```

Render its output **verbatim**, after the summary above — never instead of it. Read-only, writes nothing, costs a second.

On a ready foundation it names `/specclaw:propose`, the same command Step 6's last bullet does, with `/specclaw:bf-replay <change>` as what follows. **That agreement is deliberate and load-bearing** — the two used to disagree, because the dashboard recommended replaying an application nobody had built yet. If you ever find them saying different things again, `specclaw-bf-status` is the one to fix; do not quietly reword this skill to match a wrong recommendation.

It reads the manifest this run just wrote, so it is right for every mode without being told which one ran: `--not-applicable` reports nothing outstanding (this repo has declared it is not the rebuild target), and `recorded-ready` reports the same state as before, because nothing changed.

**Only if this run completed.** Steps 1, 3, 4 and 5 each say to surface the problem and stop — that means stop. A run that did not finish must never print a next step, which would read as though the foundation were ready when it is not.

**Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.

## The foundation-only boundary

**MAY create:** the app shell · routing shell · API client foundation · frontend→API connectivity · solution/project layout · dependency injection · environment and configuration structure · CORS · error-handling conventions · ORM setup · database connectivity · migrations *infrastructure* (the mechanism, not a domain migration) · test-project structure for both sides · theme plumbing · exactly one health-check endpoint, purely to prove connectivity.

**MUST NOT create:** any backlog capability. No Sign In, no patient grid, no register-patient, no payments, no reporting — not a stub of one, not a placeholder screen with the capability's name on it, not an endpoint that returns fixture data. Every one of those belongs to its own `BL-###`, starting at `/specclaw:propose`. A capability the foundation ships is a capability nobody specced, nobody verified against a fixture, and nobody signed off.

**The token-plumbing line**, decided here rather than assumed:

- Foundation **may** create the theme *mechanism* (provider/registration, the CSS-variable or platform-equivalent declaration structure, the layout shell) and **may** import the values of `TK-` groups whose scope is `global`. `/specclaw:bf-rebuild-plan` already unions the global token groups into *every* screen-bearing item's UI-fidelity line, which makes them a shared prerequisite of all of them — and a shared prerequisite no single item can own is the definition of foundation.
- Foundation **may not** import a `TK-` group scoped to a specific `SCR-###`, and **may not** reproduce any screen's layout structure, even under `FAITHFUL`. Those are precisely what `bf-ui --checklist`'s `ui-review.md` asks a named human to sign, per change, per screen.
- This changes nothing about the UI workstream's own contracts. The foundation *claims* a global token's value; a human still *confirms* it in the first screen-bearing change's review. No `ui-review.md` row is skipped because bootstrap ran.
- Under `REINTERPRET`, an undecided policy, or a decided policy whose `.specclaw/ui/` artifacts are absent, the mechanism is created and **nothing** is imported — with the reason recorded in `ui_tokens_skipped_reason`. A stated degradation, never a silent one.

## What this command does not do

`/specclaw:bf-bootstrap` never decides architecture — it consumes it. It never defaults a stack, a database, a hosting model or a UI policy; an unresolved required decision is a loud stop naming the id. It ships **no per-stack scaffold template**, and there will never be one: the skeleton is generated per run by an agent reading the decisions and the repo, exactly as `bf-baseline --harness` generates harness code and `bf-replay` generates replay tests. `templates/CONTRACT.md` remains the only stack-related artifact in the plugin, and the manifest schema it now documents names no framework.

It runs **only in the new repo**. It never reads or writes anything under the legacy repo's `.specclaw/`, and no legacy-repo command learns that bootstrap state exists. It writes nothing under `.specclaw/changes/` and calls no lifecycle skill — the operator still runs `/specclaw:propose` for each backlog item themselves, exactly as before.

It never scaffolds over an existing application. It never re-creates a pillar already recorded `present`. It never records a manifest whose gate failed, whose required smoke check failed, or whose required decisions it cannot show a source for. And it never claims the foundation-only gate proves more than it does.
