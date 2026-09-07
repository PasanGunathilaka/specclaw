---
description: Golden-master comparison — replay captured legacy fixtures against the rebuilt app and report MATCH/DIVERGES/ERROR per fixture, scoped to a change, `--item BL-###`, `--module MOD-###`, or `--all`. Run in the rebuild repo after /specclaw:verify and before /specclaw:pr.
---

# specclaw bf-replay

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized).

Compares the new app's actual behaviour against `.specclaw/baseline/`'s captured golden-master fixtures. This is **not** `/specclaw:verify` — verify checks a change against its own spec/tasks; replay checks the rebuild against the *legacy app's own recorded behaviour*. Neither command modifies the other; do not merge this flow into `verify`.

Invocation:
```
/specclaw:bf-replay <change-name>                    # fixtures behind this change's cited BL item; retains evidence
/specclaw:bf-replay --item BL-###                    # fixtures behind ONE backlog item; no change directory needed
/specclaw:bf-replay --module MOD-###                 # every fixture tagged with that module; retains evidence
/specclaw:bf-replay --all                            # full regression: every fixture in the manifest; retains evidence
/specclaw:bf-replay <change-name> --keep              # accepted for compatibility — identical to the default
/specclaw:bf-replay <change-name> --discard           # opt this one run out of evidence retention (never for an acceptance run)
/specclaw:bf-replay <change-name> --prune-evidence <n> # keep only the newest n evidence runs for this change; no new replay run
```

**Four selection scopes, smallest to largest: `--item BL-###` → `<change-name>` → `--module MOD-###` → `--all`.** `--item` is the single-item acceptance gate — accept one backlog item's behaviour on its own, before any change exists for it and without inventing one. `--module` is the module-at-a-time gate: it replays every fixture the manifest tags with that module, so a large legacy system can be migrated and behaviourally signed off one flow at a time instead of all-or-one-change. **All four are selection only** — verdict logic, the four-step verdict order, PROVISIONAL semantics, ST-### taint mechanics, and every exit code are identical across every one of them.

**The four scopes are mutually exclusive.** A positional `<change-name>` combines with no scope flag, and the flags combine with nothing. Retention qualifiers (`--keep`, `--discard`, `--prune-evidence <n>`) qualify a run rather than selecting one, and combine with any scope.

**Never decide the scope by reading the invocation yourself — resolve it mechanically first:**
```bash
target="$(specclaw-bf-replay parse-target <the user's flags and arguments, verbatim>)"
```
It prints the one canonical target token (`<change-name>` | `BL-###` | `MOD-###` | `--all`) or fails loudly naming the conflict. **If it exits non-zero, surface its stderr verbatim and stop.** Pass `$target` as the target argument to `resolve`, `render`, and `finalize` — every subcommand accepts all four forms in the same argument position, so no separate flag is threaded through five call sites.

## Evidence Retention

Retention is the default, not an opt-in. A verdict alone ("PASS") is a claim; the generated tests and their actual results are the proof — that the rebuilt application was mechanically compared against recorded behaviour of the original application, not just asserted to be. Deleting them after the run, as this command used to do by default, threw the proof away and kept only the claim.

**Where evidence lives** — a per-change run:
```
.specclaw/changes/<name>/replay-evidence/
├── evidence-summary.md        # the ONE mutable file — regenerated in full every run
└── run-<timestamp>/
    ├── report.md               # identical content to replay-report.md for this run
    ├── run-metadata.json        # legacy SHA, new-repo SHA, the plugin version that
    │                            # ran AND the one that recorded the manifest, the
    │                            # manifest schema, stack, date, fixture counts by
    │                            # class, overall verdict
    ├── tests/                   # the generated test project — SOURCE ONLY (never
    │                            # this stack's own build/dependency output, per
    │                            # run-config.json's evidence_exclusions — an
    │                            # explicit exclusion list in the copy step, not a
    │                            # hoped-for clean)
    ├── actual-results/          # actual-output JSON per fixture, from this run
    ├── expected/                # manifest excerpt: fixture IDs + hashes replayed
    │                            # against (never a copy of the fixture files
    │                            # themselves — those stay the single source of
    │                            # truth in .specclaw/baseline/fixtures/)
    └── pipeline/                # how the verdict was reached: run-config.json,
                                 # selection.json, mapping.json, compare.json,
                                 # sanction.json, sanction-verified.json, and the
                                 # build/test logs
```

**Why `pipeline/` is part of the package.** A report states a verdict; these files are how a reviewer checks its working — what the mapper decided and at which seam layer, what `compare` computed field by field and how it classified each difference, what the auditor claimed, what `sanction-check` independently confirmed, and the raw output of the test run. Without them the package asserts a conclusion nobody outside the run can audit. `sanction.json`/`sanction-verified.json` are legitimately absent from a run with no behavioural divergence, and `build.log` from a stack with no separate build step — a missing file there is a normal state, not a gap.

For `--all`, `MOD-###` **and `BL-###`** runs, the same `run-<timestamp>/` structure lives under `.specclaw/replay/evidence/` instead (no `evidence-summary.md` there — that index is change-scoped by design). A module or item run shares that corpus-wide pool rather than getting a parallel tree of its own, and records what it covered in its own `run-metadata.json` (`"module": "MOD-###"`, or `"bl_item": "BL-###"` with `bl_items_covered` naming exactly that one id). A module and an item are each a property of the run, not a new place to keep runs — and neither has a `.specclaw/changes/<name>/` to live under.

**Rules:**
- Every part of a `run-<timestamp>/` folder, once written, is immutable — a later run never modifies or deletes it. Runs accumulate. `evidence-summary.md` is the sole exception: it's fully regenerated (never appended to) on every run and by `--prune-evidence`.
- `--keep` is accepted and silently treated identically to the default — retention already keeps everything that matters, so there's nothing left for `--keep` to additionally preserve.
- `--discard` is the genuine opt-out, for a throwaway run (mid-debugging iteration, say) — the report is still written, but no evidence folder is created and `evidence-summary.md` is left untouched. **Never use `--discard` for a run whose result is meant to gate an acceptance decision or a PR.**
- `--prune-evidence <n>` keeps only the newest `n` run folders for a change (or the `--all` evidence pool), deleting the rest and regenerating `evidence-summary.md` to match. This never happens automatically — only when explicitly requested.
- Evidence is committable by design — nothing this command writes is gitignored. `finalize` checks whether the target repo's own `.gitignore` would swallow the evidence path anyway and warns loudly if so, rather than letting "proof" silently end up untracked. The expectation is that a change's final passing run's evidence is committed alongside its PR — that's what makes it citable later, to a client or anyone else.
- `replay-report.md` (and the identical `report.md` inside the evidence folder) carries a short evidence-pointer header: the evidence path (or a plain statement that this run's evidence was discarded), a brief run-metadata summary, and — for client consumption — one sentence naming what the package actually contains.

**Full proof chain, in one place:** legacy-side evidence is `.specclaw/baseline/harness/` + `fixtures/` + `manifest.json` — already permanent (harness and manifest are archived-then-replaced on re-record, per `/specclaw:bf-baseline`'s own convention; fixture files are additive and never deleted by any specclaw command). New-side evidence is this command's `replay-evidence/` folders. Together they are the complete, durable record of what was captured from the original application and what the rebuild was actually checked against.

## Step 0 — Setup

Generate a run id: `run_id=$(date +%Y-%m-%d-%H%M%S)`. This ids both the run directory (`.specclaw/replay/run-<run_id>/`) and, for `--all`, the report filename (`.specclaw/replay/report-<run_id>.md`).

**Resolve the target first** with `parse-target` (see **Invocation** above) and use `$target` everywhere below. It is the single point where an illegal scope combination is caught.

**If `--prune-evidence <n>` was passed**, this is the entire job — run `specclaw-bf-replay prune-evidence .specclaw "$target" <n>`, relay its one-line summary, and stop. No new replay happens; nothing below this point runs.

**Archive the prior report, if any, before writing a new one** — for a per-change run only (an `--all`, `MOD-###` or `BL-###` report is already uniquely timestamped in its own filename, so there is nothing to archive):
```bash
mkdir -p .specclaw/analysis/archive
[ -f .specclaw/changes/<change>/replay-report.md ] && mv .specclaw/changes/<change>/replay-report.md \
  .specclaw/analysis/archive/$(date +%Y-%m-%d-%H%M%S)-replay-report-<change>.md
```
Skip the move if that file doesn't exist yet. Same convention the other analysis commands (`/specclaw:bf-analyze`, `/specclaw:bf-baseline`, etc.) use for their own archive step.

## Step 1 — Resolve fixture selection

```bash
specclaw-bf-replay resolve .specclaw "$target" .specclaw/replay/run-<run_id>/selection.json
```

Deterministic, no agent. For a named change: reads `.specclaw/changes/<change>/proposal.md` and `spec.md` and extracts its cited backlog item (`BL-0\d\d\d` literally, or `item N`/`backlog item N` mapped to `BL-0<N>` and cross-checked against `rebuild-backlog.md`'s own `### BL-0NN —` headers). For `--item BL-###`, that step is skipped — the item is named directly, and **no change directory is required or consulted**. For `--all`, selects every fixture in the manifest, ignoring item scoping entirely.

**The BL → GM join, for both the change and item scopes.** The item's own **acceptance basis** in `rebuild-backlog.md` is read for its `DR-###` citations (as textual `DR-###` tokens — the join key that document's format guarantees is present; the bash-recomputed `Gate:`/`Verification:`/`UI fidelity:` lines are excluded first, so a run never joins on ids describing its own prior output). Every manifest entry whose `business_rules_pinned` contains **any** of those DR ids is selected — ANY-of, exactly like the `module_ids` join, because a fixture pinning two rules is the record of a flow resting on both and an item resting on either cannot be accepted without it.

**This is deliberately the same chain `/specclaw:bf-rebuild-plan` walks** to compute each item's `**Verification:** VERIFIABLE — fixtures: …` line. That makes the two testably equal: `--item BL-020`'s selection must equal the backlog's own Verification fixture list for BL-020, and the test suite asserts exactly that against a backlog rendered by that other tool. If they ever disagree, one of them is lying to whoever reads a report.

**`verifies_backlog_item` is a cross-check only, never load-bearing.** When it is populated and disagrees with the join, `resolve` emits a `WARN` naming **both** sets and names the fix (`re-run /specclaw:bf-baseline --record`) — selection is unaffected, because one of the two documents is stale and bash cannot know which. When it holds the `not yet backlog-linked` placeholder, it is ignored **in silence**: the pipeline's own order runs `/specclaw:bf-baseline` (A4) *before* `/specclaw:bf-rebuild-plan` (A5), so a first-recorded manifest necessarily carries that placeholder on every entry and there is no disagreement to report. A join on that field is why change-scoped selection used to fail on every correctly-run project; it is never used for selection again.

**Empty selection is a result, not a failure.** An active item whose rules no captured fixture pins yields a clean 0-fixture `selection.json`, a one-line `NO BASELINE DATA — 0 fixtures mapped to BL-###` summary, and **exit 0** from `resolve`. **When `selected_count` is 0, skip Steps 2–7 entirely** (there is nothing to map, run, compare, or sanction) and go straight to Step 8, which renders `INCOMPLETE` with exit 2 and states the same message on the report's face. Never invent a fixture, never report it as a PASS, and never treat it as a broken precondition — a malformed manifest still fails loudly (below), and the placeholder is neither of these.

For a `MOD-###` target, selects every fixture whose manifest `module_ids` array contains that module — a **pure jq join on declared manifest data**, no agent involved and nothing re-derived from `scenarios.md` prose. **ANY-of semantics:** a fixture whose pinned rules span modules carries several `module_ids` and is selected by *every* one of them, because it is the record of a flow crossing those boundaries and neither module can be accepted without it. The one-line summary reports how many selected fixtures are shared this way.

This subcommand also **is** the preconditions check — it fails loudly (non-zero exit, no report written, **and nothing created on disk at all**, including the run directory) if:
- the change cites no BL item at all ("replay only makes sense for backlog-driven changes")
- the cited `BL-0NN` doesn't exist in `rebuild-backlog.md`
- **(`BL-###` runs only)** `rebuild-backlog.md` doesn't exist at all — that document is the join's left-hand side, and the fix named is to run `/specclaw:bf-rebuild-plan` first
- **(`BL-###` runs only)** the item has no `### BL-0NN —` heading, in which case the message lists the items that *do* exist; or it is a **`STRUCK` tombstone**, which is an id kept claimed so nothing reuses it, not an item with behaviour anyone can accept. Both refuse before creating anything. A struck id is likewise never attributed to a fixture
- **(`BL-###` runs only)** the item is a **`QUALITY-REMEDIATION` item** (`/specclaw:bf-rebuild-plan`'s per-module quality item, whose `**Verification:**` line reads `QUALITY-MEASURED`). It cites no `DR-###` and maps to no `GM-###`, so there is nothing to compare: its acceptance is a *measurement*, not a recorded output. The refusal names the item type and points at `/specclaw:bf-quality --target` then `--compare`, and it fires **before** the fixture join precisely so the run cannot report `NO BASELINE DATA` — which would read as "somebody forgot to record a fixture" rather than "this item is not verified this way"
- `.specclaw/baseline/manifest.json` or the fixtures directory is missing
- any selected fixture's file is missing, or its recomputed sha256 doesn't match the manifest's recorded `content_hash` (fixtures were edited or half-copied — **never compare against a tampered baseline**)
- the manifest has no `manifest_schema`, or predates the current one — it therefore carries no per-fixture `status`, `seam_layer`, or semantic error fields, and replaying against it would silently treat every fixture as `VERIFIABLE` and accept whatever seam layer the mapper chose. The message names the fix verbatim: **re-run `/specclaw:bf-baseline --record`**
- any *selected* fixture entry is missing `status` or `seam_layer` — checked per entry, because a manifest can carry the right schema number and still be incomplete on exactly the fixture this run depends on
- **(`MOD-###` runs only)** the manifest predates the schema that first carried per-fixture `module_ids` — the message names **re-run `/specclaw:bf-baseline --record`** and states that change-scoped and `--all` runs still work against this manifest unchanged; or the manifest is new enough but *no* fixture carries any module at all, in which case the fix is to re-run design mode so scenarios declare their modules, then `--record`. Two separate, separately-worded failures, because they need different fixes.
- **(`MOD-###` runs only)** the module id matches no fixture — the message lists the modules that *do* appear in the manifest, rather than selecting nothing and reporting a clean `INCOMPLETE`, which would read as "this module has no behaviour to check"

**Adopting this version never forces a re-record.** A `<change-name>`, `--item` or `--all` run reads a pre-module manifest exactly as before; only `--module`, which *is* a join on the module field, requires the newer schema. And because the join now reads `rebuild-backlog.md` rather than the manifest's `verifies_backlog_item`, an existing baseline recorded before the backlog existed works unchanged — **no project needs its baseline re-recorded to fix the selection defect**. A re-record is still worth doing eventually: `/specclaw:bf-baseline --record` now fills `verifies_backlog_item` and `module_ids` from the backlog and module map when those documents exist, retiring the placeholder. That is best-effort metadata only — it never overwrites a value a scenario declares itself, and nothing downstream requires it.

**Stub taint stamping.** `resolve` also reads `.specclaw/analysis/module-stubs.md` — the dependency-bypass registry (`templates/CONTRACT.md` (m)) — and stamps `stub_refs: ["ST-###"]` on every selected fixture whose backlog item appears in an `ACTIVE` entry's `Consumed by` field. A pure join on declared data, the same tier as the `module_ids` join: no agent, nothing re-derived, and **nothing that touches a verdict**.

Which item a fixture verifies comes from `bl_items_resolved` — the reverse of the selection join (which items' acceptance bases rest on the rules this fixture pins), a **set**, because two items legitimately share a rule. It is computed in every scope, not just the item ones. Previously this read `verifies_backlog_item`, which meant that on any correctly-run project it resolved to nothing and **taint silently never fired at all** — the same placeholder defect, in the one place whose entire job is honesty about standing. Attribution falls back to the field's own `BL-###` token only for a fixture the join can say nothing about (no backlog on disk, or a backlog carrying no rule citations): for selection an empty answer is a real answer, but for attribution it means an absence of information, and discarding the last remaining signal there is what disabled taint in the first place. It also records the entries this run actually hit (`stubs_in_effect`) and any `RETIRING` entry whose consumers are in this selection (`retirement_candidates`).

A missing registry is an empty registry — silently. Most projects never bypass anything, and a run against no registry behaves exactly as it did before this existed. A `mock-data` entry that is `RETIRING`/`RETIRED` while its declared seed file still exists produces a WARN, never a failure: nothing observes which data a running application loaded, so this can only prompt a human to check.

A manifest recorded by a **different plugin version** than the one running is a WARN, not a failure — but both versions, and the manifest schema, are stamped into `run-metadata.json` and printed in the report header, so a report rendered by one version against a baseline recorded by another says so on its face rather than leaving it to be discovered later.

**If it exits non-zero, surface its stderr message verbatim and stop.** On success it writes `selection.json` (selected fixtures with their seam/DR/hash/anchor metadata, the BL items and DR rules covered, the legacy commit SHA, and the selected count) and prints a one-line summary.

## Step 2 — Scaffold the run directory

```bash
specclaw-bf-replay init-rundir .specclaw .specclaw/replay/run-<run_id>
```

Deterministic. Creates the run directory and writes a `run-config.json` stub (`{stack: null, build_command: null, test_command: null, results_dir: "actual", evidence_exclusions: []}` per `templates/CONTRACT.md`) for the replay-mapper agent to complete in Step 3. Copies nothing — there is no fixed per-stack scaffold to copy.

## Step 3 — Spawn the replay-mapper agent

`Agent` tool, `subagent_type: "bf-replay-mapper"`, model from `config.yaml` `models.review` (default: `anthropic/claude-sonnet-4-5`). Pass as context:
- `selection.json` from Step 1 (the fixtures to map).
- Resolved paths of `.specclaw/baseline/scenarios.md`, `.specclaw/baseline/seams.md`, `.specclaw/analysis/decisions.md`, `.specclaw/analysis/domain-model.md`, `$CLAUDE_PLUGIN_ROOT/templates/CONTRACT.md`.
- The project root, so the agent reads the new repo's actual current source for each selected fixture's seam, and identifies the rebuild's own stack itself (never assumed — it can genuinely differ from the legacy stack).
- The resolved run directory path, containing Step 2's `run-config.json` stub, which the agent must complete.

The agent first identifies the rebuild repo's stack and completes `run-config.json` (`stack`, `build_command`, `test_command`, `evidence_exclusions`, per `CONTRACT.md`). Then, for each selected fixture, it decides **REPLAYABLE** or **NOT REPLAYABLE** (with reason — the three named categories below, or a stated general reason; never a silent skip), and for every REPLAYABLE fixture generates one test, in whichever test runner it identified as the rebuild's own convention, under the run directory — arranging via the rebuild's own real migration path (never a schema-sync shortcut), pinning the clock where the seam has an injectable override, feeding the fixture's `input`, and writing the actual-result JSON itself per `CONTRACT.md`'s field-mirroring rule.

Known NOT REPLAYABLE reasons the agent must recognize explicitly (never invent a sixth silently — if none of these fit, state the real reason in full):
- **Clock dependency**: the seam's behaviour depends on "now" and the new code still has no injectable override for that call site → reason names the exact call site, remediation says "adopt an injectable clock in the affected service" and cites `seams.md`'s CB-1 recommendation (or a newer ADR if one now exists).
- **Shape changed under a decided CQ**: the seam's input/output shape changed because of a `decisions.md` entry under `## Decisions` (not "Outstanding") — replayable only via a documented input translation that cites that CQ's ID.
- **Seam mismatch**: the fixture's captured `seam_layer` has no equivalent in the rebuild — remediation names what would have to exist for a same-layer replay.
- **No-legacy-behaviour scenario**: the fixture is listed under `scenarios.md`'s "No Legacy Behaviour Exists" section — NOT REPLAYABLE by definition; point at the stakeholder-decided acceptance criteria for that behaviour instead of attempting a capture.

**The same-layer rule.** Every fixture carries the `seam_layer` it was captured at (`pure-function` | `service` | `http` | `persistence`). The agent must generate the replay test at **that** layer and record it as `replay_seam_layer`, alongside `legacy_seam_layer` copied through from `selection.json`. Replaying a `service` fixture through the rebuild's HTTP surface is not a weaker proof of the same rule — it is a different measurement, whose differences describe routing, serialization and middleware rather than the business rule the fixture pins. "Test it through HTTP because that's what's reachable" is never a valid resolution; when the layer genuinely doesn't exist in the rebuild, that is the `seam-mismatch` finding above. Step 5 re-checks this mechanically and overrides the agent either way.

**Error mapping.** For a fixture whose seam can reject, the agent maps the rebuild's error into the *existing* vocabulary in `.specclaw/baseline/error-map.md` — judged on the business condition, never on the exception class name — and cites the rebuild `file:line` it read. It never adds, renames, or invents a code. Where it genuinely cannot map one, it emits `error_code: null`, raises a typed `PQ-NNN`, and records that id; Step 5 classifies the result as `unmapped-error-code`, which never fails a run and never quietly passes one either.

The agent writes `.specclaw/replay/run-<run_id>/mapping.json` itself (one entry per selected fixture: verdict REPLAYABLE/NOT REPLAYABLE, `legacy_seam_layer` + `replay_seam_layer`, reason, remediation if applicable, generated test file path if replayable, and any error-code citations or unmapped conditions) — this skill does not write it, and does not write `run-config.json` either (that's the agent's own responsibility, per above).

**The agent never declares MATCH or DIVERGES for anything.** Its only verdicts are REPLAYABLE / NOT REPLAYABLE; the actual behavioural comparison happens mechanically in Step 5.

## Step 4 — Run the generated tests

```bash
specclaw-bf-replay run-tests .specclaw .specclaw/replay/run-<run_id>
```

Deterministic. Reads `run-config.json`; fails loudly if `test_command` is still null (the replay-mapper agent never completed it). Otherwise runs `build_command` (if non-null) then `test_command` verbatim, from the project root — this stack's own build/test tooling, named by the agent, never assumed here — captures output (capped), and reports which fixtures wrote a valid `actual/<GM-ID>.json` and which didn't (a missing/invalid actual-result file after the test run is the ERROR signal — the generated test crashed before completing capture). This command does not itself decide MATCH/DIVERGES.

## Step 5 — Compare (deterministic)

```bash
specclaw-bf-replay compare .specclaw .specclaw/replay/run-<run_id>
```

**First, seam-layer re-verification.** Before diffing anything, every mapping entry's layers are checked against the manifest's own record (via `selection.json` — the agent's copy is checked *against* it, never believed). A missing `replay_seam_layer`, a `replay_seam_layer` differing from the captured layer, or a `legacy_seam_layer` that doesn't match the manifest forces that row to `NOT REPLAYABLE` / `seam-mismatch` **regardless of what the agent claimed** — the same trust model as Step 7 re-verifying the auditor.

Then, for every surviving REPLAYABLE fixture: loads the fixture's expected `output` and the run's actual `output`, walks both field-by-field, skips any path matched by the fixture's own `normalized_fields` (resolved through the canonical path language of `CONTRACT.md` (g) — the same shared implementation `record` validated those paths with, so a path that validated at capture genuinely excludes at compare), and compares the canonical `ExceptionType`/`InnerExceptionType` fields by **short type name only** — the identifier after the last `.`, `::`, or `/` — so a legacy-to-rebuild namespace/package rename never registers at all.

Every surviving difference is then **classified in bash** (`CONTRACT.md` (j)):

| `divergence_class` | Means | Effect on the run |
|---|---|---|
| `behavioural` | `outcome`, `error_code`, `threw`, or any other compared field differs — the rebuild decided something different | Goes to the auditor (Step 6); FAIL unless sanctioned |
| `representation` | **Only** the raw exception type or message differed (`CONTRACT.md` (b.2)) — the business decision was identical | Never fails a run, never reaches the auditor; listed in its own report section with both raw values kept as evidence |
| `unmapped-error-code` | An error nobody could map to a semantic code, so nobody guessed one | Never fails; holds the run at `PASS-PENDING-DECISIONS` |

Row class is the highest-precedence class present, so a row with even one behavioural difference is behavioural.

Writes `compare.json`: `MATCH` / `DIVERGES` (with every differing field path, both values, and each field's own class) / `ERROR` (with the captured test-command failure detail) / `NOT REPLAYABLE` per fixture, each also carrying the fixture's own `fixture_status` (`VERIFIABLE`/`PROVISIONAL`/`SUPERSEDED`, read straight from `selection.json` — itself flowed through unchanged from `manifest.json`'s per-fixture `status`), plus a `summary` block and any **normalization warnings**: a path that resolved against the captured fixture but matches nothing in the rebuild's actual output, which is exactly the signal that the rebuild reshaped the field the path was meant to exclude. A warning never changes a verdict. **Every verdict, every class, the seam-layer override, and the fixture status are computed entirely in this script — never asserted by an agent.**

## Step 6 — Spawn the replay-auditor agent (only if any BEHAVIOURAL divergence)

If `compare.json` has zero entries with `divergence_class == "behavioural"`, skip straight to Step 7 (nothing to sanction). Representation-only rows are deliberately **not** put to the auditor: the same business decision expressed in a different framework's wording is not a product decision anyone should be asked to record, and asking would manufacture pressure to invent a sanctioning CQ for noise. `unmapped-error-code` rows aren't put to it either — those are a question for a human about the error map, not a divergence to sanction.

Otherwise: `Agent` tool, `subagent_type: "bf-replay-auditor"`, same model routing as Step 3. Pass `compare.json`'s behavioural entries, `selection.json` (for each fixture's DR rule), and resolved paths of `.specclaw/analysis/decisions.md` and `.specclaw/analysis/domain-model.md`. For each DIVERGES fixture the agent searches `decisions.md`'s `## Decisions` section for a CQ that explicitly covers the affected rule and explicitly chose to diverge (e.g. a DEFECT question answered "fix in rebuild") — if found, cites the CQ ID and quotes the deciding language; if not, says so plainly rather than inventing a citation. Writes `.specclaw/replay/run-<run_id>/sanction.json` itself.

**"Looks more correct" is never a sanction.** Only a decision that is actually recorded under `## Decisions` counts — an `## Outstanding Questions` entry, however obviously right the new behaviour seems, sanctions nothing.

## Step 7 — Sanction check (mechanical re-verification)

```bash
specclaw-bf-replay sanction-check .specclaw .specclaw/replay/run-<run_id>
```

Deterministic. For every behavioural-divergence fixture where the agent claimed a sanctioning CQ, mechanically confirms that `decisions.md` actually contains a `### CQ-0NN —` (or `SQ-`/`UQ-`) heading for that exact ID — headings only ever appear under `## Decisions` in this document's real structure, never under `## Outstanding Questions`, so this single grep is sufficient proof the citation is real and decided, not proposed. Also greps that decision's own block text for the affected DR rule / seam name the divergence touches; if it's not mentioned, downgrades to a `WARN` in the report rather than silently trusting or silently rejecting. Any fixture the agent could not cite a CQ for is `UNSANCTIONED` outright. Writes `sanction-verified.json`.

## Step 8 — Render the report

```bash
specclaw-bf-replay render .specclaw "$target" .specclaw/replay/run-<run_id> [--discard]
```

Pass `--discard` only if that flag was on the original invocation — it tells `render` to write a plain "evidence discarded" notice instead of a path to a folder that (per Step 9) won't exist. Deterministic. Renders `$CLAUDE_PLUGIN_ROOT/templates/replay-report.md` from `selection.json` + `mapping.json` + `compare.json` + `sanction-verified.json`:

- **Header** — date, stack, legacy SHA, backlog item, selected count, overall verdict, and a provenance line naming **both** the specclaw version that rendered the report and the one that recorded the baseline, plus the manifest schema. A mismatch is visible on the report's face rather than inferred.
- **Evidence-pointer block** — evidence path or discard notice, the identified stack, a brief run-metadata summary, and the one-sentence client explanation of what the package contains.
- **Summary** — eight disjoint counts: exact match, behavioural sanctioned, behavioural unsanctioned, representation-only, unmapped error code, error, not-replayable/seam-mismatch, not-replayable/other.
- **Module Rollup** — one row per module present in this run's selection: its fixture counts by verdict, its own verdict computed by the **same four-step order** over its own subset, and — always, never omitted — **how many of its fixtures are shared with another module, naming them**. Two honesty guards are built in. First, the **cross-module rule**: a fixture whose rules span modules counts toward *every* module it touches, because a shared fixture is exactly the flow that breaks when one module is rebuilt in isolation, and a module verdict that quietly excluded its shared flows would be a false verdict. Second, **partial coverage is marked**: a module pulled into a run only because a shared fixture touches it shows `N of TOTAL — PARTIAL` and its verdict reads `(of the selected subset only)`, so a one-row glimpse of another module can never be mistaken for that module's verdict. This section changes no verdict and no exit code.
- **Stubs In Effect** — the dependency bypasses this run's verdict rests on: each `ACTIVE` entry it hit, what that entry fakes, and which fixtures it tainted; plus any `RETIRING` entry whose consumers are in this run, named so a clean verdict is legible as the run that retires it. Reads `_None_` when the run rests on no stub, which is the normal case.
- **Item Split In Effect** — present when this run's backlog item carries a non-`COMPLETE` `IS-###` split (`templates/CONTRACT.md` (o)). States, in bold, that **this run is not the item's final acceptance**, then names what is still deferred, what unblocks it, and — split out from each other — which selected fixtures cover **built** scope and which cover **deferred** scope. Reads `_None_` when no split applies.
- **Fixtures table** — per row: verdict (with a `-PROVISIONAL` or `-SUPERSEDED` suffix where the fixture carries that status), its **class**, its sanction where one applies, a **Stubs** cell naming any `ST-###` behind it, and the differing field paths.
- **Behavioural Divergences** — per fixture, one line per differing field: `` `threw` — legacy `true`, rebuild `false` ``. Mechanical statement only; no agent interpretation is attached anywhere in this section.
- **Representation-Only Differences** — both raw values retained as evidence, collected from every row (a behavioural row usually carries some too).
- **Seam-Layer Mismatches** — each with the captured and attempted layers and a remediation.
- **Normalization Warnings** — paths that resolved against the fixture but match nothing in the rebuild's output.
- **Not Replayable**, **Open Decisions Blocking PASS**, and every DR rule from `domain-model.md` left uncovered by any exercised fixture in this run.

The overall verdict, evaluated **strictly in this order**:

1. **INCOMPLETE** — the selected set was non-empty but every fixture in it came back NOT REPLAYABLE, seam mismatches included (nothing was actually exercised). Exit 2.
2. **FAIL** — any ERROR, or any **behavioural** divergence that is not SANCTIONED. Exit 1.
3. **PASS-PENDING-DECISIONS** — no failure above, but at least one exercised (MATCH/DIVERGES/ERROR) fixture is `PROVISIONAL` (an open pending question still blocks the rule it pins), or `SUPERSEDED` (its scenario definition changed after capture, so replaying it proves nothing about the scenario as written — recapture it), or a row is `unmapped-error-code`. Soft-block: never a refusal to run, only this run's own verdict once every comparison is already done. Exit 1.
4. **PASS** — everything else: every exercised fixture matched, or diverged behaviourally under a decided CQ. **Representation-only differences never hold a run back from PASS.** Exit 0.

The order is the guarantee: an unsanctioned behavioural divergence is **always** FAIL, and no provisional, superseded, or unmapped state beside it ever downgrades that to PASS-PENDING-DECISIONS.

**An open item split marks that verdict too, and for a different reason.** When the run's item carries an `ACTIVE` or `READY-TO-RESUME` `IS-###`, the verdict line gains a further `(partial — split IS-###: N of M exercised fixture(s) pin deferred rules)` suffix, and the report states plainly that this run **cannot be that item's final acceptance**. Stub taint qualifies a verdict's *standing* — what it was measured against was not real. A split qualifies its *scope* — the comparison was entirely sound, but only half the item exists to compare. Neither enters the four rules above, and neither changes an exit code.

**Deferred-scope fixtures are reported, never excluded.** A fixture pinning a rule the split declared deferred still runs and still counts toward the verdict. Excluding it would change what the run FAILs on — the one thing a completeness marker must never do — and would hide a real regression behind a scope note. So read the two lists deliberately: a **FAIL** among the deferred-scope fixtures is expected and explained by the split; a **PASS** among them is a *surprise worth investigating*, because it means either the deferred scope was quietly built after all, or the split's rule partition is wrong.

Only a clean `--item` run **after** the deferred scope lands can mark the split `COMPLETE`, and the report prints the exact `split-update` command. This command never writes it itself.

**Stub taint is a marker on that verdict, never an input to it.** When any *exercised* fixture is stub-tainted, the verdict line gains a `(with active stubs: ST-###, ...)` suffix — appended **after** the verdict token, so `PASS` still reads as `PASS` to anything parsing the leading word. The four rules above, the counts they read, and every exit code are byte-identical to a run with no registry at all. A stub-tainted FAIL is reported as FAIL, exit 1, with the taint noted alongside: taint never softens a failure and never introduces a verdict or an exit code of its own. Unlike `PROVISIONAL` — which genuinely participates in rule 3, because an open question means nobody has decided what correct is — a stub leaves the comparison itself sound and qualifies only its **standing**.

When `decisions.md` records a UI fidelity policy (`SQ-013`) of `FAITHFUL` or `THEME-ONLY`, the report also carries one **informational footer line**: _"UI fidelity is verified by human checklist (`ui-review.md`), not by fixture replay."_ That is its entire effect — no verdict logic, no fixture status, no exit code, and no fixture selection changes because of it, and the line is absent altogether under `REINTERPRET` or an undecided policy. UI remains excluded from the seam taxonomy (`templates/seams.md`'s "Excluded: UI Automation"); the footer exists so a reader of a PASS report never mistakes it for a statement about how the rebuilt interface looks.

Writes the report to `.specclaw/changes/<change>/replay-report.md` (named change), `.specclaw/replay/report-<run_id>.md` (`--all`), `.specclaw/replay/report-<run_id>-MOD-###.md` (a module run), or `.specclaw/replay/report-<run_id>-BL-###.md` (an item run) — the last two suffixed so several coexist and the filename itself says what it covers — and exits `0`/`1`/`2`/`1` for PASS/FAIL/INCOMPLETE/PASS-PENDING-DECISIONS respectively — **PASS-PENDING-DECISIONS gates CI/PR exactly like FAIL** (same exit code 1), by design: analysis and build keep moving under a soft block, but the proof gate holds the line until a named human decides the question. This computation is untouched by evidence retention; the same inputs produce the same verdict and exit code as before.

## Step 9 — Retain evidence (or discard, if asked)

```bash
specclaw-bf-replay finalize .specclaw "$target" .specclaw/replay/run-<run_id> [--keep|--discard]
```

Pass whichever of `--keep`/`--discard` was on the original invocation (neither, for the default). Unless `--discard`, this curates the run directory into `.specclaw/changes/<change>/replay-evidence/run-<run_id>/` (or `.specclaw/replay/evidence/run-<run_id>/` for `--all`) — see **Evidence Retention** above for the exact structure — regenerates `evidence-summary.md` for a named change, warns if this repo's `.gitignore` would swallow the evidence path, then removes the now-redundant working run directory. `--keep` is accepted and does exactly the same thing as passing nothing. With `--discard`, it just deletes the run directory — no evidence folder, `evidence-summary.md` untouched. The report file itself (written in Step 8, already containing the correct evidence-pointer text either way) is never touched by this step.

## Step 10 — Present a summary

Relay `render`'s one-line summary and the overall verdict to the user, plus the report's path and (unless `--discard`) the evidence folder path from `finalize`'s own summary line. **If `finalize` warned about `.gitignore` swallowing the evidence path, surface that warning directly** — don't let "proof" silently end up untracked without the user knowing.

- **If the item carries an open split, say "PARTIAL" in the same breath as the verdict — never after it.** "PASS, but BL-010 is partially built under IS-001: the auth integration was deferred and 1 of 4 exercised fixtures pins a rule it covers, so this is not BL-010's acceptance" is the honest sentence. "PASS" followed later by a note about a split is not, because the first word is what gets repeated to whoever asked. Name what is still deferred, not just the split id. **Never present a partial run as the item being done** — the deferred scope landing is what finishes it. If a *deferred-scope* fixture came back MATCH, flag it as worth investigating rather than as good news.
- **For an `--item BL-###` run, state the item id and how many fixtures were selected for it**, so the reader can tell a one-item acceptance from a corpus sweep at a glance. If the verdict is `INCOMPLETE` because **nothing was mapped to that item**, say exactly that — "BL-020 has no captured fixtures, so nothing was compared" — and never phrase it as a pass, a failure, or a defect. The remedy is to design and capture scenarios covering that item's rules (`/specclaw:bf-baseline`), and an INCOMPLETE here is the honest report that the proof does not exist yet.
- If **FAIL**, name the unsanctioned **behavioural** divergences and ERRORs directly — field, legacy value, rebuild value — rather than telling the user to open the file.
- If **PASS-PENDING-DECISIONS**, name what is blocking it: the `PQ-NNN`/`CQ-NNN` id(s) and the fixtures they block, any `SUPERSEDED` fixture needing recapture, and any unmapped error condition. These are soft blocks a human can act on, not failures to root-cause.
- **Report representation-only differences and seam mismatches separately from behavioural ones, and say plainly which is which.** Collapsing them back into one "N divergences" number in the chat summary undoes the whole point of the classification: a run with 18 wording differences and zero behavioural ones is a clean run, and describing it as 18 divergences sends someone hunting for defects that aren't there.
- Mention any **normalization warning** — a dead normalization path means a field that was meant to be excluded is now being compared (or vice versa) on every future run, and it will not fix itself.
- **If any exercised fixture is stub-tainted, say so in the same breath as the verdict — never after it.** "PASS, with ST-001 (a dev-only auth stub) standing in for MOD-005 on 3 of 8 fixtures" is the honest sentence; "PASS" followed later by a note about stubs is not, because the first word is what gets repeated to whoever asked. Name what each stub fakes, not just its id. And do not present a tainted PASS as a module being finished — the real module landing is what finishes it. If the run covered a `RETIRING` entry, say that a clean verdict here is what retires it and that the registry entry still needs flipping to `RETIRED` citing this run id.
- **Relay the Module Rollup, and never collapse it.** For a `--module` run, state that module's own verdict **and** how many of its fixtures are shared with other modules, naming them — a module PASS resting partly on shared flows is not the same claim as a module PASS that stands alone, and the whole point of accepting module-by-module is that someone can tell those apart. For any run, if another module appears in the rollup marked `PARTIAL`, say so explicitly: that row is a glimpse of that module through this run's selection, not its verdict. Never report a module as "done" — a PASS is a statement about the fixtures that were exercised, exactly as it is for the overall verdict.

## Step 11 — Show what comes next

```bash
specclaw-bf-status .specclaw --next
```

Render its output **verbatim**, after the verdict and everything Step 10 requires — never instead of any of it, and **never before the verdict**. Read-only, writes nothing, costs a second.

**This step runs on every verdict, including FAIL** — and that is the point. A failing target is exactly when someone needs to know what is outstanding, and the guidance is built so that saying so cannot be mistaken for progress: a target whose latest run is not a `PASS` surfaces as a **Next action** naming that target, its run id and its verdict, and no `Next command:` line is emitted claiming the phase advanced. A `PASS*` earned against an `ACTIVE` bypass stub surfaces the same way. Nothing here re-derives, softens or overrides the verdict `compare` computed — the guidance reads the retained run metadata and reports it.

It reports the **latest verdict per target**, so an older `FAIL` on one change never disappears behind a newer `PASS` on an unrelated module.

**Only if this run completed.** Every step above that says to surface stderr and stop means stop — a `resolve` refusal, a `run-tests` failure with a null `test_command`, a `render` failure. Those are runs that produced no verdict at all, and a next step printed after one would imply a comparison that never happened. A `--prune-evidence` invocation is not a replay run either: it prunes and stops at Step 0, so skip this step.

**Never work the next step out yourself.** `specclaw-bf-status` owns the lifecycle ordering for every `bf-*` command — which phase follows which, which open items are human work, and which command clears them. A next phase decided here would be a second copy of that ordering, diverging the moment either side changes.

## What this command does not do

`/specclaw:bf-replay` never modifies application source, `.specclaw/baseline/fixtures/`, `manifest.json`, or `error-map.md` — it is read-only against all of them. It never lets an agent assert MATCH/DIVERGES/ERROR (Steps 5 and 7 are bash, not agent judgment) — and, exactly the same way, it never lets an agent assert `divergence_class`, the seam-layer verdict, `PROVISIONAL`, or `PASS-PENDING-DECISIONS`; all of them are computed from `manifest.json`'s own fields and `compare.json`'s own verdicts, never from anything an agent claims in `mapping.json` or `sanction.json`. An agent declares *what it did* — which layer it targeted, which code it mapped an error to, which CQ it found — and bash decides what that means. It never accepts a divergence as sanctioned on the agent's word alone (Step 7 re-verifies mechanically). It never silently skips a fixture — every non-compared fixture is NOT REPLAYABLE with a stated reason in the report. It does not modify `/specclaw:verify` or any other command; it is a new sibling that runs after verify, before `/specclaw:pr`. It never modifies or deletes a previously-written evidence run folder — only `--prune-evidence`, run explicitly, ever removes one, and even then only the oldest beyond the requested count. It never prunes evidence automatically as a side effect of a normal run. It never changes how fixtures are selected, how the replay-mapper/replay-auditor agents classify or write tests, how `compare`/`sanction-check` compute their verdicts, or the resulting exit codes — evidence retention is purely what happens to the artifacts *after* that verdict is already final.

It never lets stub taint touch a verdict. `stub_refs` is joined from declared registry data in `resolve`, carried unread through `compare`, and reported by `render`; no verdict expression, divergence class, fixture status, or exit code reads it. It never writes to `module-stubs.md` — creating, completing, or retiring an entry belongs to `/specclaw:propose`, `/specclaw:build`, and a human, never to a replay run. And it never treats a missing registry as a problem: no registry means no stubs, silently.

The same three things hold for item splits. `item_split` is joined from the entry's own declared `Rules deferred` in `resolve`, reported by `render`, and recorded in `run-metadata.json` (`not_final_acceptance`); no verdict, class, status or exit code reads it. It never writes to `item-splits.md` — flipping a split to `COMPLETE` is a step whoever ran the clean replay takes, using the command this report prints. It never excludes a deferred-scope fixture from the comparison. And a missing split registry is silently an empty one.
