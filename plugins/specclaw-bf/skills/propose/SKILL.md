---
name: propose
description: Use when proposing a change in a brownfield rebuild repo that has a rebuild backlog.
---

# specclaw-bf propose

Run the gates below first. When they pass, follow `/specclaw:propose`, adding the proposal sections listed at the end.

1. **Target-foundation gate** (brownfield rebuilds only — inert everywhere else). **Run this before creating or renaming anything:**

```bash
specclaw-bf-bootstrap foundation-check .specclaw
```

**If `applicable` is `false`, continue to step 1b** — there is no rebuild backlog, so this project is not a brownfield rebuild target and nothing here applies. Say nothing about it.

**If the command does not run at all** — `command not found`, any non-zero exit, or no JSON on stdout — you cannot read the gate, so fall back to the one signal that does not need it: **if `.specclaw/analysis/rebuild-backlog.md` does not exist, continue to step 1b silently.** No backlog means this is not a rebuild target, so the gate has nothing to protect and stopping an ordinary proposal because a brownfield-only binary is missing from an older install would be a pure false positive. If that file **does** exist, say the foundation gate could not be evaluated, name the command that failed, and stop — a brownfield project is exactly where this gate matters. The fail-closed rule at the bottom of this page governs a manifest this command *read* and distrusted; it does not govern a command that never ran.

**If `applicable` is `true` and `foundation_ready` is `false`, stop.** Do not offer or run the backfill, do not name the change, do not create the change directory, do not draft a proposal, do not run the dependency check. Relay the `reason`, then the `remedy` verbatim:

> Target rebuild foundation has not been created. Run `/specclaw-bf:bf-bootstrap` first.

**Why this gate is absolute.** Without it, the first backlog item proposed inherits responsibility for inventing the application skeleton — and it inherits it *invisibly*, because nothing in the spec, the tasks or the verify report says "this item is also creating the app". That is how a screen-bearing item once shipped as a backend-only slice: the repo had no frontend, so the frontend was never anybody's task. A backlog item adds a capability to an application that already exists. If it does not exist yet, the answer is to create it deliberately, once, not to smuggle it into whichever item happened to be proposed first.

The one legitimate false positive is proposing an ordinary change **inside the legacy repo**, which also carries a `rebuild-backlog.md`. That is recorded once, explicitly, and attributably — never inferred, because there is no honest signal that distinguishes the two repos:

```bash
specclaw-bf-bootstrap not-applicable .specclaw \
  --reason "<why this repo is not the rebuild target>" \
  --declared-by "<name>, <YYYY-MM-DD>"
```

Both flags are required and the declaration is refused without them — same rule as a bypass's `Chosen by`. Ask the user for their name; do not supply one yourself.

When `foundation_ready` is `true`, continue silently. Mention the foundation only if the user asks.

1a. **Prototype-approval gate** (REINTERPRET rebuilds only — inert everywhere else). **Only run this if step 1 reported `applicable: true`.** If step 1 said `applicable: false`, this project is not a brownfield rebuild target, so skip straight to step 1b and say nothing — a greenfield project never runs this command at all.

```bash
specclaw-bf-prototype verify .specclaw
```

**If `applicable` is `false`, continue to step 1b silently** — this rebuild did not answer `SQ-013` as `REINTERPRET`, so there is no prototype stage and nothing here applies.

**If the command does not run at all** — `command not found`, any non-zero exit, or no JSON on stdout — apply the same rule as step 1: if `.specclaw/prototype/prototype-manifest.json` does not exist, continue to step 1b silently (an older install with no prototype stage, and no manifest for it to protect). If that file **does** exist, say the prototype gate could not be evaluated, name the command that failed, and stop.

**If `applicable` is `true` and `ready` is `false`, stop.** Do not name the change, do not create the change directory, do not draft a proposal. Relay the `reason`, then the `remedy` verbatim.

This check is deliberately whole-repo rather than per-item, and it runs for **every** change, not only screen-bearing ones. A repo that was bootstrapped while the prototype was approved, and whose approval was later withdrawn — or which had a `NOT-READY` manifest re-copied over a ready one — has an unapproved design underneath everything now being proposed. Gating only the screen-bearing items would let the rest of the work proceed on that foundation, which is the same mistake the foundation gate above exists to prevent, one level up.

The per-item half of this gate runs in step 2d, once the backlog item is known.

2a. **Backlog check** (brownfield rebuilds only — inert everywhere else). **Run this once, here; steps 2b and 2c both read its output:**

```bash
specclaw-bf-rebuild-collect bypass-check .specclaw <BL-###|--title "<the item title>">
```

Pass the `BL-###` if the user named one; otherwise pass the title — always behind the `--title` flag, never as a bare positional, which is refused. **If the JSON says `"applicable": false`, skip straight to step 3** — there is no backlog, or this change isn't a backlog item, and neither 2b nor 2c applies. Relay the `reason` only when it reports an *ambiguous* title (the user has to name the id); the other reasons are just "this isn't a brownfield backlog item" and need no comment.

**If the command does not run at all** — `command not found`, any non-zero exit, or no JSON on stdout — apply the same fallback as the step 1 gate: **if `.specclaw/analysis/rebuild-backlog.md` does not exist, skip straight to step 3 silently.** If it does exist, say the dependency check could not be evaluated, name the command that failed, and stop rather than proposing a backlog item with its dependencies unread.

The check is read-only and idempotent — it writes nothing — so re-running it costs nothing if you lose its output.

2b. **Item-split resume check.** Step 2a's output carries a `splits` array — every non-`COMPLETE` `IS-###` split on this backlog item. **If it is empty (the normal case), skip to 2c.**

Otherwise this item has already been partly built, and this proposal is a **resume, not a fresh start**. Before anything else, present:

- **What was already implemented** — the entry's `implemented_now`, and the rules it covers (`rules_implemented`).
- **The evidence that implemented it** — `change`, `evidence` (PR/merge), `replay_evidence` (the run id). Cite these, don't paraphrase them; they are what makes "already built" checkable rather than asserted.
- **What remains deferred** — `deferred`, plus `rules_deferred` and `layers_deferred`.
- **Which blockers are now satisfied** — `blocked_until_built` vs `blocked_until_unbuilt`.

Then, by the split's `status`:

| `status` | What to do |
|---|---|
| `READY-TO-RESUME` | Every blocker is built. **Propose only the deferred scope**, citing the `IS-###`. |
| `ACTIVE` with `resume_ready: true` | Every blocker now carries a `BUILT:` note but no `--refresh` has run since. Say so, and offer to run `/specclaw-bf:bf-rebuild-plan --refresh` (which flips the state mechanically) before resuming. |
| `ACTIVE` with `resume_ready: false` | Blockers named in `blocked_until_unbuilt` are still unbuilt. Say which, and that the deferred scope genuinely cannot resume yet. Offer: propose some *other* remaining scope if any exists, wait, or — if the user says those blockers **are** built — write the `BUILT:` note into their status notes so the question isn't asked again. |

**Never re-propose completed scope.** The proposal's scope section covers the remainder only, and `proposal.md` carries `## Resumes Split` citing the `IS-###`. Rebuilding the finished slice from scratch is the failure this record exists to prevent — the whole point of `IS-###` is that choosing item-split must never make implementation history disappear.

2c. **Dependency check.** Act on each dependency in step 2a's `dependencies` array, by its `action`:

| `action` | What it means | What to do |
|---|---|---|
| `ok-built` | The dependency carries a declared `BUILT:` note | Nothing. Mention it in passing. |
| `covered-by-active-stub` | An `ST-###` already fakes it *for this item* | Nothing new to choose. Name the `ST-###` in the proposal's bypass section. |
| `same-module-prerequisite` | Unmet, and in **this item's own module** | **Refuse.** Not bypassable — see below. |
| `stub-exists-not-consumed` | A stub fakes this dependency, but for other items | Offer to add this item to that entry (`stub-update --consumed-by-add`) rather than mint a second stub for the same thing. Still the human's call. |
| `needs-bypass` | Unmet, cross-module, no stub | **Elicit** — see below. |
| `dependency-struck` | The dependency was struck from the backlog | Not a dependency any more. Say so; the backlog's `Depends on:` is stale. |
| `dependency-unknown` | The id isn't in the backlog at all | Report it as a backlog integrity problem. Do **not** treat it as either met or unmet. |
| `deferred-by-split` | A non-`COMPLETE` `IS-###` already defers the scope needing it | **Nothing to choose.** Name the `IS-###`. **Do not offer the strategies again** — the human already decided this, and accepting a second answer would produce two records of one deferral. |

**If any `same-module-prerequisite` exists, stop.** Name the prerequisite and say plainly that a same-module dependency is the item's own groundwork, not a cross-boundary wait — stubbing it would mean stubbing part of the very thing being built. The options are to build the prerequisite first, or to propose a smaller slice of this item that doesn't need it. Do not offer the four strategies for it, and do not create a registry entry.

**If any `needs-bypass` exists, stop and ask.** Present *each* unmet dependency separately with these six options, and **ground every strategy sketch in what that dependency actually is** — read its backlog entry and its module's row in `module-map.md` first. Generic sketches ("stub the interface") are useless to someone deciding; a sketch for an auth module reads like *"dev-only auth stub issuing a fixed seeded user + role"*, for a ledger module like *"seeded ledger rows so posting has something to read"*.

1. **`stub-interface`** — <sketch grounded in this dependency>
2. **`mock-data`** — <sketch>
3. **`feature-flag`** — <sketch>
4. **`item-split`** — **propose a specific vertical slice**, not a layer cut. Name exactly what ships now and exactly what waits: *"the grid renders, calls a real endpoint, runs a real query against real persisted data — and only the auth integration waits for BL-001/BL-003."* Say when this looks like the best fit: nothing is faked, so nothing is tainted and nothing needs retiring.
   - **Prefer a thin end-to-end capability over a horizontal stack cut, and say so in the offer.** A vertical slice delivers something a user can open. A horizontal cut — every layer below the UI ships and the UI waits, or the reverse — produces an item that looks nearly finished and delivers nothing anyone can use, with its acceptance basis unmet and no fixture able to notice. The dependency that is actually missing is usually one seam, not one layer.
5. **The dependency is actually built** — specclaw records no built state, so it genuinely cannot tell. If the user says it is, offer to write `BUILT: <their evidence>` into that item's `**Status notes (human-added):**` block in `rebuild-backlog.md`, so the question isn't asked again.
6. **Abort and follow the recommended order** — build the dependency first. Always a legitimate answer, and often the right one.

**Never pick for the user, never default, and never proceed on silence.** A bypass is an explicit human choice (`templates/CONTRACT.md` (m.2)); this is the ask-don't-guess rule applied to dependencies. If the user answers only some of the dependencies, ask about the rest — don't infer the same strategy carries across.

For each chosen **stub** bypass (options 1–3), append the registry entry:

```bash
specclaw-bf-rebuild-collect stub-append .specclaw \
  --substitutes "BL-014 (MOD-005)" --strategy stub-interface \
  --consumed-by "<this item's BL-###>" --chosen-by "<user's name>, <YYYY-MM-DD>" \
  --summary "<the one-line sketch they chose>" [--mock-seed <path>]
```

It prints the new `ST-###`. `Fakes` and `Implementation` stay `not yet implemented` — those are the build step's to fill in with a real `file:line`, and writing them now would be inventing a citation. Ask the user for their name if you don't have it; the entry is refused without one.

### If the user chooses `item-split`

**A split is not a stub and does not go in `module-stubs.md`.** `stub-append --strategy item-split` is refused by name. Read `$CLAUDE_PLUGIN_ROOT/references/split-discipline.md`, then:

**First, state the split back and get it confirmed — itemised, not summarised.** Two lists, from the item's own acceptance basis (`bypass-check` reports it as `item.acceptance_basis_rules`):

- **Implemented now:** the scope, and the `DR-###` rules it covers.
- **Deferred:** the scope, and the `DR-###` rules it covers.

Every rule in the item's acceptance basis must appear in exactly one list. `split-append` refuses a partition with a rule in both halves, a rule in neither, or a rule the item doesn't cite — and the refusal is not a formality: a rule in neither half is scope nobody owns, so nothing can later tell whether it shipped.

**If the split removes an entire major layer, say so as a consequence and require explicit confirmation before recording it.** For a screen-bearing item losing its UI (`bypass-check` reports `item.screen_bearing`), the sentence to put in front of the user names what goes unmet:

> This split defers the entire UI layer. BL-010 renders SCR-004, so it would ship with nothing a user can see, and its UI acceptance basis (SCR-004, TK-001) would go unmet. Confirm explicitly if that is what you want.

`split-append` **refuses** that split without `--layer-removal-confirmed-by "<name>, <date>"`, so this is enforced, not merely advised. Do not supply that flag on your own initiative or reuse the chooser's name to satisfy it — it is a second, separate attestation, and the whole reason the field exists is that somebody was asked.

Then record it:

```bash
specclaw-bf-rebuild-collect split-append .specclaw \
  --item BL-010 --module MOD-002 \
  --reason "BL-001/BL-003 authentication and route guards are not built" \
  --unmet-deps "BL-001, BL-003" \
  --implemented-now "patient listing · search/filter · active-prescription query · paging · backend API · React Patient Grid" \
  --deferred "BL-001 authentication integration · BL-003 route-guard integration" \
  --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
  --layers-implemented "ui, api, domain, persistence" --layers-deferred "auth-integration" \
  --blocked-until "BL-001, BL-003" \
  --chosen-by "<user's name>, <YYYY-MM-DD>" --change "<change-name>" \
  --summary "<one line: which item was split, and what waits>"
```

It prints the new `IS-###`. `Evidence` and `Replay evidence` stay `not yet merged`/`not yet replayed` — the build and replay steps fill those in, and writing them now would be inventing a citation.

**What to tell the user after recording it**, in one breath: the item will render `⚠ PARTIALLY BUILT` in `rebuild-backlog.md`, an `/specclaw-bf:bf-replay --item BL-###` run will report **PARTIAL** and cannot be the item's final acceptance, and the split returns automatically — `--refresh` flips it to `READY-TO-RESUME` as soon as every blocked-until item carries a declared `BUILT:` note. Nothing is tainted: a split fakes nothing.

2d. **Per-item prototype gate** (REINTERPRET rebuilds only — inert everywhere else). **Skip this entirely unless step 1a reported `applicable: true`.** Skip it too when step 2a said `applicable: false` — with no backlog item there is nothing to key on.

```bash
specclaw-bf-prototype verify .specclaw --item <the BL-### from step 2a>
```

**If `item_ready` is `false`, stop.** Relay `item_reason` verbatim — it names each screen and exactly what is wrong with it:

> Prototype screen(s) not approved for BL-0NN: SCR-004 → PS-003 (STALE), SCR-007 → (no prototype screen). Re-approve, re-record, re-copy.

An item that references no screen passes this check on step 1a's whole-repo result alone; nothing extra is required of it.

**Why per-item as well as whole-repo.** Step 1a proves the redesign as a whole was approved. This proves *this* item's screens were — which is a different claim, and the one that matters when the work about to be proposed is the work that builds those screens. A screen reading `STALE` means the prototype changed after the client signed it off, so the approval on file describes something that no longer exists; building from it would produce an interface nobody approved, with a signed approval sitting next to it saying otherwise.

## Extra proposal.md sections

   - **`## Dependency Bypass`:** one bullet per **stubbed** dependency, citing the `ST-###` from step 2c, the strategy, the chooser and date, and the concrete sketch. **Omit the whole section** when there was no stub bypass — which is the normal case.
   - **`## Item Split`:** present only when this proposal recorded an `IS-###` in step 2c. Cite the id, what ships now, what is deferred, the rules each half covers, what unblocks the remainder, and the chooser — plus the layer-removal confirmer when there was one. The scope section's **out** list must name the deferred scope explicitly; a split whose deferral appears nowhere in the scope section is a split the spec will quietly widen.
   - **`## Resumes Split`:** present only when step 2b found a non-`COMPLETE` split. Cite the `IS-###`, what the earlier slice built, its change/PR/replay evidence, and state that this proposal covers the remainder only.

## What the dependency check never does

It never decides that a bypass is warranted, never picks a strategy, and never writes a registry entry the user didn't choose. `bypass-check` classifies; the human decides; bash records. An agent that picks a "sensible default" here has quietly converted a tracked, dated, attributable decision into an untracked one — which is the single failure mode this whole mechanism exists to prevent.

It also never infers that a dependency is built from prose. Only a declared `BUILT:` line in the item's own status notes counts. "Done last week", "shipped in #42", a ✅ — none of these are read, deliberately: a false positive here silently skips the elicitation that would have caught the unmet dependency.

**And a split never widens on its own.** The split the user selected is the split that happens. If drafting the proposal suggests the chosen partition is wrong — a rule sits awkwardly, a layer turns out to be needed — **stop and hand it back**. Moving one more rule into the deferred half without asking is precisely how a screen-bearing item once lost its entire frontend, and it is the reason `split-append` refuses a partition that does not account for the item's acceptance basis exactly.

## What the foundation gate never does

It never creates a foundation, never infers that one exists from the presence of source files, and never decides that a project doesn't need one. It reads a manifest that `/specclaw-bf:bf-bootstrap` wrote, or it reads a `--not-applicable` declaration a named human made. Absent both, it stops and names the command — the same UX pattern as every other precondition gate in the pipeline.

It fails **closed**: a manifest that can't be parsed, carries an unknown schema, or claims readiness while recording a failed smoke check reports not-ready with the reason. Passing a gate on a file nobody could read would defeat the point of having it.

Nothing above applies to a project with no `rebuild-backlog.md`. Both `foundation-check` and `bypass-check` return `applicable: false` and propose behaves exactly as it always has — and if either command cannot run at all, the absence of that same file is the fallback signal, so a greenfield proposal is never blocked by a brownfield-only binary being missing. **A greenfield project is never gated here, on any path.**
