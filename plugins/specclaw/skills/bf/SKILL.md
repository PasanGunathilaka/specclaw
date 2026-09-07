---
description: Run the next brownfield preparation phase — ask specclaw-bf-status what comes next, run exactly one bf-* phase with your approval, stop. Use when unsure which bf-* command to run.
---

# specclaw bf

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

A thin runner over `specclaw-bf-status`. It asks that script what comes next, runs **at most one** phase, and ends. It knows no ordering of its own: every command it prints comes out of the JSON below, never out of this file.

1. **Ask what comes next:**
   ```bash
   specclaw-bf-status .specclaw --next --json
   ```
   Read-only, writes nothing, costs a second. It prints one JSON object on stdout and nothing else.

   **If it exits non-zero, surface its stderr message verbatim and stop** — the only failures are a missing `<specclaw_dir>` (run `/specclaw:init`) and a malformed invocation. Don't retry, don't guess a different path, and print no guidance of your own: a run that did not complete must never print a next step.

2. **Read the document.** Every field below is computed in bash. Relay them; decide none of them yourself.

   | Field | What it is |
   |---|---|
   | `repo_role` | `legacy`, `rebuild`, or `unknown` — `unknown` means the artifacts genuinely cannot tell, not that nobody looked |
   | `degraded` | `true` when `jq` is absent, so several signals are reading optimistically |
   | `complete` | every phase this dashboard sequences has run, and nothing is outstanding |
   | `next` | `{command, runnable, reason, why, after}`, or `null` |
   | `blocked_by` | work no command clears — each `{kind, text, command}` |
   | `advisories` | pointers to a command that is not a blocker |

3. **If `degraded` is `true`,** say so in one line before anything else: `jq` is not installed, so fixture counts, foundation readiness and replay verdicts are being read at their most optimistic and `complete` cannot be trusted. Then carry on.

4. **If any `blocked_by` entry has `kind: "repo-boundary"`, stop.** Render every `blocked_by` and `advisories` entry's `text` as a list under **Needs attention**, each followed by its `command` where it has one. Say plainly that the next step happens in the *other* repository, so nothing here can advance it. If `next` is non-null, print its `command` too, as something to consider once you are in the right repo — but **do not run it**, and do not ask to.

5. **If `complete` is `true`, stop.** Say every phase has run and nothing is outstanding, and point at `/specclaw:bf-status` for the full phase table. Run nothing.

6. **If `next` is `null`, stop.** Render `blocked_by` and `advisories` exactly as in step 4 under **Needs attention**. Say plainly that this is human work no command can clear — answering a question, capturing a fixture or a screenshot, confirming a document — because that is what silently stalls a rebuild: no command ever fails on account of it. Run nothing.

7. **If `next.runnable` is `false`, stop** — and which of the two sentences you say depends on `next.reason`, never on reading the command string:

   - `lifecycle-boundary` — **brownfield preparation is complete.** Print `next.command` verbatim as the command to run next. Do not execute it, do not describe what it does, do not offer to run it. If `next.after` is non-null, print that too as what follows. This runner covers preparation only; everything past this point is the ordinary lifecycle and is the user's to start.
   - `needs-human-flags` — the next step is a phase invoked with a flag, and every flag this pipeline recommends encodes a decision a person makes. Print `next.command` verbatim as the command for the user to run themselves, and say that the flag is why you are not running it. Preparation is **not** complete; do not say that it is.

   Render any `blocked_by` and `advisories` first, as in step 4.

8. **Otherwise `next.runnable` is `true`.** Render any `blocked_by` and `advisories` first under **Needs attention**, so nothing outstanding is hidden behind the thing you are about to run. Then print `next.command` exactly as the JSON gives it, and `next.why` as the one sentence saying why it is next. **Ask for explicit approval.** On anything other than approval, stop.

9. **On approval, invoke `next.command` exactly** — the bare command, no arguments, no flags, no substitutions. When it returns, **end the turn.**

   **Do not run `specclaw-bf-status` again.** The phase you just ran ends by rendering the guidance block itself, so a second call would print the same thing twice and read as two separate recommendations.

   **Do not summarise what the phase produced.** It already reported its own result, in its own words, with detail this runner does not have.

   **Do not continue to the next phase.** One invocation, one phase. If the user wants the next one, they run `/specclaw:bf` again.

## What this command does not do

It **spawns no agent, reads no application source, reads no `.specclaw/` document, and writes nothing** — not a file, not a cache, not a status entry. Its only input is the JSON from step 1.

It **decides no ordering.** `specclaw-bf-status` owns the lifecycle sequence for every `bf-*` command: which phase follows which, which open items are human work, and which command clears them. This file names no phase at all, deliberately — a list of phases here would be a second copy of that ordering, diverging the moment either side changed.

It **never passes a flag.** `--resolve`, `--record`, `--harness`, `--refresh`, `--options-pack`, `--not-applicable`, `--target`, `--compare` and `--adopt` each encode a decision a human makes, and a runner that supplied one would be answering a question on their behalf. When the recommended step carries a flag, it is printed for the user to run, never executed.

It **never loops and never auto-approves.** Running the whole pipeline unattended would defeat the reason this exists: each phase is a decision point, and the context saved by not re-reading the dashboard between phases is spent immediately if the runner chains them.

It **is entirely optional.** Nothing reads it, nothing depends on it, and every `bf-*` command behaves identically whether or not this file exists. Anyone who prefers to type the phases themselves loses nothing by ignoring it — `/specclaw:bf-status` is still the source of truth, and this is only a shortcut to acting on what that already says.
