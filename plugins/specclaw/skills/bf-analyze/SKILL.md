---
description: Analyze an existing (possibly legacy) codebase and write a grounded `.specclaw/analysis/codebase-report.md` covering tech stack, dependencies, architecture, domain, and risks. Works on any language or stack — Node, .NET, Java, Go, Rust, Python, Delphi/Object Pascal, or none of the above — not just Node/.NET. Read-only: no TTY or credential prompts, no lifecycle gate. Use when onboarding to an unfamiliar or legacy repo, or before proposing a change in one.
---

# specclaw bf-analyze

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Analyze an existing codebase and write `.specclaw/analysis/codebase-report.md`. Read-only side-command — no `specclaw-validate-change` call, no `<change>` involved, matching the `patterns`/`status` pattern.

1. **Resolve and collect:**
   ```bash
   mkdir -p .specclaw/analysis/.collect
   specclaw-bf-analyze-codebase collect .specclaw [path] > .specclaw/analysis/.collect/analyze.json
   ```
   `[path]` defaults to the repository root when omitted. The script itself validates that `[path]` exists, resolves inside the repository, and is not `.specclaw` itself or nested inside it. **Check the exit status before spawning.** If it exits non-zero, surface its stderr message to the user verbatim and stop — don't retry, don't guess a different path, and never hand the agent a path to a half-written file.

2. **Migrate a pre-upgrade report, if present**, before archiving: if `.specclaw/codebase-report.md` (the old path) exists and `.specclaw/analysis/codebase-report.md` (the new path) does not yet exist, move it into the new archive location so it is never orphaned:
   ```bash
   mkdir -p .specclaw/analysis/archive
   mv .specclaw/codebase-report.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md
   ```
   Skip this step once the old path is gone — on every run after the first post-upgrade run for a given project, this is a no-op.

3. **Archive the prior report, if any**, before writing a new one:
   ```bash
   mkdir -p .specclaw/analysis/archive
   mv .specclaw/analysis/codebase-report.md .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-codebase-report.md
   ```
   Skip this step if `.specclaw/analysis/codebase-report.md` doesn't exist yet.

4. **Spawn the analysis agent:** `Agent` tool, `subagent_type: "bf-codebase-analyst"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`). Pass as context:
   - The path `.specclaw/analysis/.collect/analyze.json` — it reads that file directly.
   - The resolved target path.

5. The agent writes `.specclaw/analysis/codebase-report.md` itself, per its own Output section — this skill does not write the file.

6. **Present a short summary** to the user: the path analyzed, which report sections were written, and any low-confidence flags (`Inference (low confidence): ...`) the report surfaced.

7. **Show what comes next:**
   ```bash
   specclaw-bf-status .specclaw --next
   ```
   Render its output **verbatim**, after the summary above — never instead of it. Read-only, writes nothing, costs a second.

   **Only if this run completed.** Step 1 says to surface `collect`'s stderr and stop; that means stop. A run that did not finish must never print a next step, which would read as though the phase advanced when it did not.

   **Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.
