---
description: Produce a C4-model architecture view (L1 context through L4 code) of an existing or legacy codebase as `.specclaw/analysis/architecture.md`, with Mermaid diagrams and grounded prose per level. Any language or stack. Run in the legacy repo for a visual map of how its pieces connect.
---

# specclaw bf-architecture

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Analyze an existing codebase's architecture and write `.specclaw/analysis/architecture.md`. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `analyze`/`patterns`/`status` pattern.

1. **Resolve and collect:**
   ```bash
   specclaw-bf-analyze-codebase collect .specclaw [path]
   ```
   `[path]` defaults to the repository root when omitted. The script itself validates that `[path]` exists, resolves inside the repository, and is not `.specclaw` itself or nested inside it, and now also emits a `dependency_graph` field alongside its existing fields. **If it exits non-zero, surface its stderr message to the user verbatim and stop** — don't retry, don't guess a different path. This validation already lives inside `collect`; do not reimplement it here.

2. **Archive the prior architecture report, if any**, before writing a new one:
   ```bash
   mkdir -p .specclaw/analysis/archive
   mv .specclaw/analysis/architecture.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-architecture.md
   ```
   Skip this step if `.specclaw/analysis/architecture.md` doesn't exist yet. This is the same shared archive directory `skills/analyze/SKILL.md` uses for `codebase-report.md` — both document types land in `.specclaw/analysis/archive/`, distinguished by filename.

3. **Spawn the analysis agent:** `Agent` tool, `subagent_type: "bf-architecture-analyst"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`). Pass as context:
   - The collected JSON (stdout of Step 1, which now includes `dependency_graph`).
   - The resolved target path.
   - Whether `.specclaw/analysis/pending-questions.md` and `.specclaw/analysis/clarifications.md` exist (simple `[ -f ... ]` checks — this command has no dedicated collector to add the fields to, unlike `bf-domain`) and their resolved paths if so, for the agent's own Ask, Don't Guess de-duplication.

4. The agent writes `.specclaw/analysis/architecture.md` itself, per its own Output section — this skill does not write the file.

5. **Present a short summary** to the user: the path analyzed, which C4 levels were written, and any component the agent flagged "L4 not warranted for this component."

6. **Show what comes next:**
   ```bash
   specclaw-bf-status .specclaw --next
   ```
   Render its output **verbatim**, after the summary above — never instead of it. Read-only, writes nothing, costs a second.

   **Only if this run completed.** Step 1 says to surface `collect`'s stderr and stop; that means stop. A run that did not finish must never print a next step, which would read as though the phase advanced when it did not.

   **Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.
