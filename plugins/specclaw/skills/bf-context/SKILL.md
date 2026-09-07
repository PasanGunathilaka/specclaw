---
description: Generate a project context router skill from this project's SpecClaw artifacts — one page naming where each question is answered. Run in either repo after the analysis commands.
---

# specclaw bf-context

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Write a project-specific context router into this repo's own `.claude/skills/`, so anyone working here — human or agent — starts from the same map of where this project's answers live.

1. **Generate it:**
   ```bash
   specclaw-bf-context .specclaw
   ```
   Pure bash, deterministic, spawns no agent. Reads project knowledge only from files under `.specclaw/` and writes exactly one file.

   **If it exits non-zero, surface its stderr message verbatim and stop.** There are three failures and each names its own fix: a missing `.specclaw/` (run `/specclaw:init`), an empty `project.name` in `config.yaml`, and a target file that already exists without this command's generated-by marker. That last one is a **hand-written skill** and is deliberately never overwritten — don't work around it, don't rename it, don't delete it on the user's behalf. Relay the path and let them decide.

2. **Relay what it reported:** the path written, the module count, and which artifacts came back `not present`. The absent ones are the useful half — each is a document some `bf-*` command has not produced yet, and the router says so on its own face rather than pretending the project is more mapped than it is.

3. **Remind the user to `git add` the generated skill.** It is worth committing for the same reason every other analysis output is: a router only helps the team if the team has it, and a file that exists on one machine is a private note.

## What gets generated

One `SKILL.md` at `.claude/skills/<project>-context/`, where `<project>` is the name recorded in `config.yaml`. It contains the project name, a table of the authoritative artifacts with the question each one answers and whether it is present, the `MOD-###` modules with their titles, and the module map's and blueprint's own status lines verbatim.

**It is a router, not a summary.** It carries no business rule, no decision, no id beyond the module list, and no stack name — only where each question is answered. That restraint is the point: a generated file that restated what the artifacts say would be a second copy of them, stale the moment either side moved, and a reader trusting it over the real document would be reading last week's answer. A path cannot go stale that way.

Regeneration is wholesale and needs no archive, because nothing in the file is authored — every line is derived from something else. That reasoning holds only for a file this command wrote, which is what the marker on its first content line establishes.

## What this command does not do

It **spawns no agent and reads no application source.** Everything it knows comes from `.specclaw/`.

It **is invoked by a human, never by another command.** Nothing in the pipeline references it, no `--next` output names it, and no other skill or script reads its output. Delete the generated file and every specclaw command behaves identically — this is additive convenience with no coupling in either direction.

It **hardcodes no framework, language or vendor.** The questions it routes to are the same for every project; the project-specific parts come from that project's own artifacts at generation time.

It **states absence rather than failing on it.** A project with no `module-map.md` still gets a router; the module section says the map is not present and names the command that writes one. The only refusal is an unmarked file it would otherwise overwrite.
