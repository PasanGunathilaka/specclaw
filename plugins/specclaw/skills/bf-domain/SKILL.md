---
description: Produce a domain and functional-spec view of an existing/legacy codebase — business entities, relationships, rules, and enumerations (domain-model.md) plus capabilities, workflows, UI inventory, and named gaps (functional-spec.md) — grounded in parsed forms (.dfm/.xaml), type/const declarations, and validation-routine candidates. Also proposes the module map (module-map.md): evidence-grouped MOD-### migration units — owned vs referenced-but-not-owned entities, rules, services, screens, and inter-module dependencies — that /specclaw:bf-rebuild-plan, /specclaw:bf-baseline, and /specclaw:bf-replay later use to migrate and accept a large legacy system one module at a time. The map is agent-proposed and human-confirmed; MOD-### ids are permanent and reconciled across regenerations, never renumbered. Works on any language or stack — Delphi/Object Pascal and .NET get first-class UI/form parsing, other stacks still get entities/rules/enumerations. Read-only: no TTY or credential prompts, no lifecycle gate. Use when you need to understand what a codebase's business domain actually is and what a user can do with it — onboarding, planning a refactor, or before proposing a change in an unfamiliar repo.
---

# specclaw bf-domain

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Analyze an existing codebase's business domain and user-facing functionality, writing `.specclaw/analysis/domain-model.md`, `.specclaw/analysis/functional-spec.md`, and `.specclaw/analysis/module-map.md`. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`architecture`/`patterns`/`status` pattern.

1. **Resolve and collect:**
   ```bash
   specclaw-bf-domain-collect collect .specclaw [path]
   ```
   `[path]` defaults to the repository root when omitted. The script delegates to `specclaw-bf-analyze-codebase collect` for path validation, manifests, `dependency_graph`, and `discovered_docs`, then adds domain-specific facts (`forms`, `xaml_forms`, `other_ui_files`, `handler_implementations`, `main_form_hint`, `type_declarations`, `const_declarations`, `validation_routine_candidates`) plus `architecture_md` presence, the `module_map` block — the prior map's `status`, its `prior_modules[]` roster (id/name/status/owned entities/rules/capabilities, ID-level facts only), and `next_mod_id` — and the `capabilities` block: the prior `functional-spec.md`'s `prior_capabilities[]` roster (id/title/status) and `next_cap_id`. `validation_routine_candidates` is a **hint list only**: a narrow `Valid*`/`Check*`/`Can*` naming heuristic, never an exhaustive inventory of business rules — an empty array means the heuristic matched nothing, never that the codebase has no rules (see the analyst's Candidate-Hint Rule). **If it exits non-zero, surface its stderr message to the user verbatim and stop** — don't retry, don't guess a different path. This validation already lives inside the delegated call to `specclaw-bf-analyze-codebase collect`; do not reimplement it here.

   **Run this step before Step 2's archive, and pass its JSON to the agent verbatim.** The `module_map.prior_modules[]` and `capabilities.prior_capabilities[]` rosters are read from the *live* `module-map.md` and `functional-spec.md`, which Step 2 is about to move — they are the only thing that lets the agent carry surviving `MOD-###` and `CAP-###` ids forward instead of renumbering them, and both families are permanent.

2. **Archive all three prior documents, if they exist**, before writing new ones:
   ```bash
   mkdir -p .specclaw/analysis/archive
   mv .specclaw/analysis/domain-model.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-domain-model.md
   mv .specclaw/analysis/functional-spec.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-functional-spec.md
   mv .specclaw/analysis/module-map.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-module-map.md
   ```
   Skip each `mv` independently if that specific file doesn't exist yet — one may exist without the others on an unusual prior run, and `module-map.md` is absent entirely on any project that predates the module hierarchy. This is the same shared archive directory `analyze`/`architecture` already use — all document types land in `.specclaw/analysis/archive/`, distinguished by filename.

3. **Spawn the analysis agent:** `Agent` tool, `subagent_type: "bf-domain-analyst"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`). Pass as context:
   - The collected JSON (stdout of Step 1) — including `pending_questions`/`clarifications` presence + resolved paths for the agent's own Ask, Don't Guess de-duplication, and the `module_map`/`architecture_md` blocks for rubric row 9.
   - The resolved target path.

4. The agent writes `.specclaw/analysis/domain-model.md`, `.specclaw/analysis/functional-spec.md`, and `.specclaw/analysis/module-map.md` itself, per its own Output section — this skill does not write any of them.

5. **Present a short summary** to the user: the path analyzed, entity/rule/capability counts, and any Named Gaps the agent flagged.

   **Report the capability ids explicitly**, not just a count: how many `CAP-###` were newly assigned, how many carried forward from the prior document, and how many were tombstoned. Name any capability the agent found without an id (a document written before the id family existed — ids arrive on regeneration, never by back-assignment in place), and name any `CAP-###` the agent left under `## Unassigned`. That last one matters more than it looks: a capability no module owns can carry no `Modules` tag, so a fixture pinning it is selectable only by `/specclaw:bf-replay --all` and no module run will ever exercise it.

   `CAP-###` is half the acceptance basis — `MOD-### → BL-0## → {DR-###, CAP-###} → GM-###` — so these ids are what later let a backlog item whose behaviour is a form and a persistence write be accepted at all. Before they existed such an item reported `INCOMPLETE` forever, indistinguishable from one nobody had looked at.

6. **Relay the module map and ask the human to confirm it.** Report the module count with each module's name and owned-entity count, every cross-module reference the map recorded (an entity one module owns and another references — that is where a flow crosses a boundary), anything under `## Unassigned`, and **name every module or placement the agent marked `⚠ PROVISIONAL` together with its `PQ-NNN`**. Then state plainly that the map is **`PROPOSED`** and ask the user to review it and either confirm it — by editing its `**Status:**` line to `CONFIRMED by <name>, <YYYY-MM-DD>` — or tell you what to regroup.

   Say why the confirmation matters, in one sentence: `/specclaw:bf-rebuild-plan` sequences the migration from these boundaries, `/specclaw:bf-baseline` tags scenarios by them, and `/specclaw:bf-replay --module` accepts work by them, so a boundary nobody checked becomes the shape of the whole rebuild. Nothing is blocked by a `PROPOSED` map — every downstream command runs and reports that the map is unconfirmed — so present this as a review request, not a gate.

   If the agent raised any pending question this run, also mention that `/specclaw:bf-clarify` will type and number it (a contested boundary becomes a `DECISION` or `SCOPE` question with a permanent `CQ-###`), so the user knows where that conversation happens rather than answering it in chat where nothing records it.

7. **Show what comes next:**
   ```bash
   specclaw-bf-status .specclaw --next
   ```
   Render its output **verbatim**, after the summary and the confirmation request above — never instead of them. Read-only, writes nothing, costs a second.

   An unconfirmed map surfaces there as a **Next action**, because confirming it is an edit only a human can make. That is a review request, exactly as step 6 states, and never a gate: every downstream command runs against a `PROPOSED` map and reports that it is unconfirmed.

   **Only if this run completed.** Step 1 says to surface `collect`'s stderr and stop; that means stop. A run that did not finish must never print a next step, which would read as though the phase advanced when it did not.

   **Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.
