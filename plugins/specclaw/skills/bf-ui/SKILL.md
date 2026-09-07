---
description: Optional UI-fidelity workstream — extract the legacy app's screen inventory (SCR-###) and design tokens, record human-captured screenshots into a hashed manifest (`--record`), and generate a per-change sign-off table (`--checklist`). Run in the legacy repo after /specclaw:bf-domain.
---

# specclaw bf-ui

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Extract, capture, and review the UI-fidelity dimension of a rebuild. Read-only side-command — no `specclaw-validate-change` call, no `<change>` gate, matching the `analyze`/`architecture`/`domain`/`clarify`/`baseline`/`rebuild-plan` pattern.

**This command is optional and never required.** The whole brownfield pipeline works without it. `/specclaw:bf-clarify` asks the UI fidelity policy question (`SQ-013`) whether or not this command was ever run, and `/specclaw:bf-rebuild-plan` only requires UI grounding when that policy is decided `FAITHFUL` or `THEME-ONLY`. A project on `REINTERPRET` answers one question and is done.

**UI is never a golden-master seam.** `templates/seams.md`'s `## Excluded: UI Automation` class stands unchanged, and `/specclaw:bf-replay` is untouched by this command except for one informational footer line. Nothing this command produces is replayable, diffable, or a proof of pixel-identity — visual fidelity is established by a **human** reviewing recorded evidence (Mode C's `ui-review.md`), and this command must never be described as doing more than that.

Determine the mode from the user's message:

| If the message contains | Mode |
|---|---|
| `--record` | **Mode B** — record the human's captures |
| `--checklist <change-name>` | **Mode C** — generate the review table (run in the NEW repo) |
| neither | **Mode A** — design/extract (default) |

## Mode A — design / extract (default: no flag)

Run this in the **legacy repo**, after `/specclaw:bf-domain` (its `domain-model.md` and `functional-spec.md` are what the widget cross-reference keys against) and before `/specclaw:bf-clarify` (so any pending question this run raises is ingested in the same clarify sweep).

1. **Collect:**
   ```bash
   specclaw-bf-ui collect .specclaw [path]
   ```
   `[path]` defaults to the repository root when omitted. This parses the prior `ui-inventory.md`/`design-tokens.json` for their permanent `SCR-###`/`TK-###` assignments **before** archiving all three prior Mode A outputs into `.specclaw/ui/archive/`, then emits one JSON object: resolved paths, those prior id assignments, the next free ids, which analysis documents are present, the legacy repo's HEAD sha, and a stack-agnostic extension histogram of every file in scope. **If it exits non-zero, surface its stderr message to the user verbatim and stop** — don't retry, don't guess a different path.

   Note what this collector deliberately does **not** do: it names no view framework, no markup/style/resource file type, and no toolchain. It reports which file extensions exist and a few samples of each; identifying which of those are views and what technology that implies is the agent's job, per run, by reading the repo.

2. **Spawn the extraction agent:** `Agent` tool, `subagent_type: "bf-ui-analyst"`, on the model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`) — same routing as the sibling read-only analysis agents. Pass as context:
   - The collected JSON (stdout of Step 1), including `archived_this_run[]` so the agent can read a prior version's prose if it needs to.
   - The resolved target path.
   - **Tell the agent explicitly it is running in extract mode.**

3. The agent writes `.specclaw/ui/ui-inventory.md`, `.specclaw/ui/design-tokens.json`, and `.specclaw/ui/screenshot-checklist.md` itself, per its own Output section — this skill writes none of them.

4. **Present a short summary:** the view technology the agent identified (and any disagreement it flagged between the extension histogram and `codebase-report.md`), the screen count with their `SCR-###` ids, the token-group count with their `TK-` ids, how many tokens landed in `omitted[]` and why, every widget cross-reference finding, and every pending question raised this run (by `PQ-NNN`, with what it blocks).

5. **Hand the human their work order — this is the point of Mode A.** State plainly, in the summary:
   - the number of screenshots to capture and where the checklist is (`.specclaw/ui/screenshot-checklist.md`);
   - that **they** run the legacy application and take the screenshots — no specclaw command does, ever;
   - that captures go under `.specclaw/ui/screens/` using the exact filenames the checklist gives;
   - that `/specclaw:bf-ui --record` is what turns those files into recorded, hashed evidence, and that it is safe to run partway through (missing captures are reported, not errors).

6. **Note the `/specclaw:bf-clarify` cross-reference:** if this run raised any pending question, remind the user that `/specclaw:bf-clarify` ingests every OPEN `PQ-NNN` into a real `CQ-NNN`, and that until then the affected `SCR`/`TK` entries carry a `PROVISIONAL` marker that flows into `rebuild-backlog.md`. This command never writes into `clarifications.md` itself.

## Mode B — record the capture (`--record`)

Fully deterministic — **no agent involved.** Run after a human has captured screenshots into `.specclaw/ui/screens/`; it is also safe to run before any capture exists (every row is correctly reported as missing rather than failing).

1. **Run:**
   ```bash
   specclaw-bf-ui record .specclaw
   ```
   Requires `.specclaw/ui/screenshot-checklist.md` (Mode A must have run). **If it exits non-zero, surface its stderr message verbatim and stop.** For every checklist row it looks for the target file under `screens/`; a file that is there is sha256-hashed and stamped with its mtime; a row with no file goes in `missing[]`; a file under `screens/` matching no row — or violating the `SCR-###[-state].png` naming convention — goes in `extra[]` with which of those two reasons applies. Archives any prior `ui-manifest.json` into `.specclaw/ui/archive/`, then writes the new one per `templates/CONTRACT.md` (f).

2. **Present a short summary:** how many rows are captured out of the total, which are still missing (name them), and every `extra[]` file with its reason — a typo'd filename shows up as an extra, not a capture, and the human needs to know that directly rather than discovering it later.

**`screens/` is never written to, moved, archived, or deleted — by this mode or any other specclaw command.** Human-captured evidence is append-only, and the hash in the manifest is what makes it tamper-evident, exactly as with golden-master fixtures. If `sha256sum`/`shasum` is unavailable on the machine, `record` says so loudly and records without a hash rather than pretending the evidence is sealed.

## Mode C — per-change review checklist (`--checklist <change-name>`)

Run this in the **new (rebuild) repo**, for a change that is built — alongside `/specclaw:bf-replay`, before `/specclaw:pr`. It requires the UI artifacts to have been copied into the new repo (see `docs/rebuild-workflow.md`'s Phase B copy set — `screens/` and `ui-manifest.json` are always copied together, or the hashes prove nothing).

1. **Collect:**
   ```bash
   specclaw-bf-ui checklist-collect .specclaw <change-name>
   ```
   Deterministic, no agent. Resolves the change to its cited `BL-###` backlog item (the same two-pass resolution `/specclaw:bf-replay` uses: an `"item N"` self-citation first, a literal `BL-###` as fallback, dependency bullets excluded from both), greps that item's block in `rebuild-backlog.md` for `SCR-###` citations, reads the decided fidelity policy from `decisions.md`'s `SQ-013` entry, and joins the SCR ids against `ui-inventory.md`, `design-tokens.json`, and `ui-manifest.json`.

   It fails loudly, with no file written, when: the change directory doesn't exist; the change cites no BL item; the cited item isn't in `rebuild-backlog.md`; the item cites no `SCR-###`; `SQ-013` is undecided; or the policy is `REINTERPRET` (no UI fidelity review applies — that is the whole point of that option). **Surface its stderr message verbatim and stop** in every one of those cases.

2. **Spawn the agent:** `Agent` tool, `subagent_type: "bf-ui-analyst"`, same model routing as Mode A. Pass as context:
   - The collected JSON from Step 1.
   - The project root of the new repo, for the agent to search directly, and the draft path to write: `.specclaw/changes/<change-name>/.ui-review-draft.txt`.
   - **Tell the agent explicitly it is running in checklist mode**, and that it must emit only `TOKEN-CHECK:`/`LAYOUT-POINT:` lines and **no verdict of any kind**.

3. **Render:**
   ```bash
   specclaw-bf-ui checklist-render .specclaw <change-name> .specclaw/changes/<change-name>/.ui-review-draft.txt
   ```
   Archives any prior `ui-review.md`, renders `templates/ui-review.md` into `.specclaw/changes/<change-name>/ui-review.md` — per-screen sign-off tables with the legacy screenshot reference and its sha256, one row per token to verify (expected value + where to check in the new code), and, for `FAITHFUL` only, one row per layout point — then deletes the draft. Every row ends in empty `Verified by` / `Date` / `Notes` cells for a **named human** to fill. **If it exits non-zero, surface its stderr message verbatim and stop.**

4. **Present a short summary:** the policy in force, the screens and token groups in scope, how many rows need a signature, any `NOT FOUND` location the agent reported (a token with no definition in the new repo is a finding worth naming directly), and any SCR in scope whose screenshot is missing from `ui-manifest.json` — a row a reviewer cannot complete because the legacy evidence was never captured.

5. **Tell the user what to do with the file:** a human opens `ui-review.md`, compares the new UI against the referenced legacy screenshots, fills in each row's `Verified by`/`Date`/`Notes`, and **commits the completed file with the PR alongside the replay evidence**. That committed, signed file is the fidelity proof for this change. An unsigned `ui-review.md` proves nothing.

## Show what comes next — after any mode

Once the mode's own summary is delivered, and only then:

```bash
specclaw-bf-status .specclaw --next
```

Render its output **verbatim**, after that summary — never instead of it. Read-only, writes nothing, costs a second. It runs after **all three modes**, unchanged, because it reads `ui-inventory.md` and `ui-manifest.json` rather than the invocation.

**Uncaptured screenshots surface there as a `Next action`, and that is exactly right** — a human runs the legacy app and takes them; no specclaw command ever does. The guidance names the count and points at `--record` as what turns those files into hashed evidence. This is the computed form of Mode A's step 5 work order, not a replacement for it: give the user the checklist path and the filename convention as step 5 requires, then let the guidance state the count.

This command is **optional and never required**, and the guidance reflects that: a project with no `ui-inventory.md` reads `N/A — optional`, and `/specclaw:bf-ui` is never recommended as a next command anywhere. Nothing here turns the UI workstream into a gate.

**Only if this run completed.** Every mode has steps that say to surface stderr and stop — Mode A's `collect`, Mode B's `record`, Mode C's `checklist-collect` and `checklist-render`. Mode C's refusals in particular (`SQ-013` undecided, policy `REINTERPRET`, no `SCR-###` cited) are stops, not warnings. A run that did not finish must never print a next step.

**Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.

## What this command does not do

`/specclaw:bf-ui` never runs the legacy application, never takes a screenshot, never simulates or describes an unobserved screenshot, and never writes, moves, archives, or deletes anything under `.specclaw/ui/screens/` — screenshot capture is a human action, exactly like golden-master fixture capture, and "no captures yet" is a normal reported state, never an error.

It never declares a fidelity verdict. There is no MATCH, PASS, or "visually identical" anywhere in this command's outputs: `ui-review.md` is a table for a named human to sign, and the plugin must never be read as promising pixel-identity. It does not modify `/specclaw:verify`, and it changes nothing in `/specclaw:bf-replay` beyond one informational footer line noting that UI fidelity is verified by human checklist rather than fixture replay — no verdict logic, no exit codes, no fixture selection.

It never guesses a visual fact it cannot cite. Which theme is active at runtime, an effective font after inheritance, a computed colour, a widget type with no evidence in the view definition, a control's visibility under runtime data — each is a pending question under the existing T1–T6 triggers, marked `PROVISIONAL` on the affected `SCR`/`TK` entry, never silently resolved to a plausible default. It never reconciles a widget/domain-model mismatch on its own — both directions are reported as findings for a human.

It never renumbers a `SCR-###` or `TK-###` id, and it never archives or overwrites the human-captured `screens/` folder. Its three Mode A documents are archive-then-replace, like every other analysis document; the captured evidence and its manifest are not.
