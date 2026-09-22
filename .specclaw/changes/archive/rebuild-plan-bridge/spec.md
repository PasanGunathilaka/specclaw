# Spec: Connect the analysis layer to the delivery lifecycle (rebuild-plan-bridge)

**Change:** rebuild-plan-bridge
**Created:** 2026-07-24
**Status:** 🟡 Draft

## Overview

Connect the three read-only analysis commands (`analyze`, `architecture`,
`domain` → `.specclaw/analysis/{codebase-report,architecture,domain-model,
functional-spec}.md`) to the existing `propose → plan → build → verify → pr`
lifecycle, per the approved proposal's **A + B** recommendation:

- **A — Grounding recipe:** document (and demonstrate) that pinning the four
  analysis docs via `context.pin` in `config.yaml` makes `plan`/`build`/
  `verify` treat them as authoritative context, using the mechanism
  `specclaw-discover-context` already has. No lifecycle skill, bin script,
  or agent changes.
- **B — Bridge command:** a new read-only side-command,
  `/specclaw:rebuild-plan`, that reads the four analysis docs and writes
  `.specclaw/analysis/rebuild-backlog.md` — an ordered, dependency-sequenced
  list of individually-proposable features, each carrying its acceptance
  basis and an explicit "what a human still needs to supply" callout.

`propose`, `plan`, `build`, `verify`, `pr` and their bin scripts/agents are
unmodified by this change — see NFR1.

## Requirements

### Functional Requirements

- **FR1 (Grounding recipe):** The `context.pin` + `context.max_lines` recipe
  is documented and demonstrably works: pinning
  `.specclaw/analysis/*.md` causes `specclaw-discover-context list`/`emit`
  to include them at rank `0`, bypassing the default `.specclaw`-directory
  exclusion — verified against the existing (unmodified) script, not a new
  code path.
- **FR2 (Missing-docs guard):** `/specclaw:rebuild-plan` checks for all four
  `.specclaw/analysis/*.md` files before doing anything else. If any is
  missing, it stops and names exactly which file(s) are missing and which
  command (`analyze`, `architecture`, or `domain`) produces each — no vague
  "run the analysis commands first."
- **FR3 (Backlog output):** When all four docs are present,
  `/specclaw:rebuild-plan` writes `.specclaw/analysis/rebuild-backlog.md`:
  an ordered list of backlog items, each naming the `functional-spec.md`
  capability it covers, the `domain-model.md` rules/entities forming its
  acceptance basis, its dependency on earlier items, and a **non-blank**
  "Verification inputs needed" field.
- **FR4 (Coverage check):** The backlog includes a Coverage Check section
  confirming every `functional-spec.md` Capability is either covered by a
  backlog item or explicitly excluded with a stated reason — no silent
  drops.
- **FR5 (No lifecycle coupling):** `/specclaw:rebuild-plan` creates nothing
  under `.specclaw/changes/` and calls no lifecycle skill or script. It is a
  pure side-command, matching `analyze`/`architecture`/`domain`/`patterns`/
  `status` exactly. The operator still runs `/specclaw:propose` per backlog
  item themselves.
- **FR6 (Operator doc):** A new `docs/rebuild-workflow.md` documents the
  full recipe end to end: run the three analysis commands → `git add
  .specclaw/analysis/*.md` (staging is enough — required because
  `discover-context` enumerates via `git ls-files`, so an untracked pinned
  file is invisible regardless of the pin) → set `context.pin` +
  `context.max_lines` (sizing formula below) → run
  `/specclaw:rebuild-plan` → `/specclaw:propose "<item>"` per backlog entry
  manually. It restates the Fidelity limitation (below) explicitly — it
  does not imply the connection alone proves behavioral equivalence.

### Non-Functional Requirements

- **NFR1 (Hard constraint):** Zero modifications to `skills/propose/`,
  `skills/plan/`, `skills/build/`, `skills/verify/`, `skills/pr/`, any
  `bin/specclaw-*` script they invoke, or any `agents/*.md` they invoke.
  Verified at the end of build via `git diff --stat` against those paths
  showing no changes (AC5).
- **NFR2 (Script conventions):** `bin/specclaw-rebuild-collect` follows
  existing script conventions — `#!/usr/bin/env bash`, `set -euo pipefail`,
  self-contained (no shared lib, per this repo's own no-`bin/_lib.sh`
  convention), `-h|--help` usage block, hand-built JSON emission with no
  hard `jq` dependency.
- **NFR3 (Read-only, no gate):** No TTY/credential prompts. No
  `specclaw-validate-change` case arm added — this command needs no phase
  prerequisite, per `docs/specclaw-architecture-notes.md` §6.
- **NFR4 (Repo hygiene):** Plugin version bumped in both
  `plugins/specclaw/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` (`0.5.6` → `0.5.7`), and a commands-table
  row added to root `README.md`, per this repo's standing version-bump rule.

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

- **AC1 (pin bypasses exclusion):** Given `.specclaw/analysis/{codebase-
   report,architecture,domain-model,functional-spec}.md` exist, are `git
   add`-ed, and are listed in `context.pin`, running
   `specclaw-discover-context .specclaw list` shows all four at rank `0`,
   and `specclaw-discover-context .specclaw emit` includes their content in
   the digest.
- **AC2 (missing-docs guard):** Given a project where none of the four
   analysis docs exist, running `/specclaw:rebuild-plan` stops without
   writing `rebuild-backlog.md`, and its output names all four missing
   files plus the specific command that produces each.
- **AC3 (backlog shape):** Given all four docs present, running
   `/specclaw:rebuild-plan` writes `.specclaw/analysis/rebuild-backlog.md`
   where every backlog item has a non-empty "Verification inputs needed"
   field (grep-verifiable: no item's field is blank or the literal
   placeholder token).
- **AC4 (coverage check):** `rebuild-backlog.md`'s Coverage Check section
   accounts for every Capability named in `functional-spec.md` — each
   appears either inside a backlog item or in an explicit exclusion list
   with a reason.
- **AC5 (lifecycle untouched):** `git diff --stat` against
   `skills/propose/`, `skills/plan/`, `skills/build/`, `skills/verify/`,
   `skills/pr/`, and every bin script/agent they reference shows zero
   changes.
- **AC6 (tests pass):** `bash plugins/specclaw/tests/run-parser-tests.sh`
   passes, including the new `specclaw-rebuild-collect` test case.
- **AC7 (version bump):** `plugin.json` and `marketplace.json` versions
   match and read `0.5.7`.
- **AC8 (archive-before-overwrite):** Given a prior
   `.specclaw/analysis/rebuild-backlog.md` exists, re-running
   `/specclaw:rebuild-plan` moves it to
   `.specclaw/analysis/archive/<timestamp>-rebuild-backlog.md` before
   writing the new one — mirroring `analyze`/`architecture`/`domain`'s own
   archive step exactly.

## Edge Cases

- **Partial analysis docs** (e.g. `functional-spec.md` present but
  `domain-model.md` missing): FR2's guard must name the specific missing
  file(s), not fail generically.
- **Zero capabilities found** (`functional-spec.md`'s Capabilities section
  is empty or says "No findings"): `rebuild-planner` must write "No
  capabilities found — insufficient evidence to build a backlog" rather
  than fabricating items, mirroring `codebase-analyst`'s own "no findings"
  convention.
- **Re-run with an existing backlog:** archived per AC8, never silently
  overwritten and never appended to.
- **Stale analysis docs** (written before recent source changes): out of
  scope for this change to detect. `rebuild-plan` trusts each doc's own
  "Date analyzed" field and does not attempt a freshness check against git
  history — a named limitation, stated in `docs/rebuild-workflow.md`, not a
  silent gap.
- **Pinned docs exceeding `context.max_lines`:** handled entirely by
  `specclaw-discover-context`'s existing truncate-and-footer behavior; this
  change relies on that, it does not add new budget logic.

## Dependencies

- Requires `analyze`, `architecture`, and `domain` skills (already shipped
  in this repo, per `git log`) to have been run at least once by the
  operator — this change does not build or modify any of the three.
- Requires `specclaw-discover-context`'s existing pin-bypasses-exclusion
  behavior (confirmed present, unmodified, in
  `plugins/specclaw/bin/specclaw-discover-context`).
- No dependency on `github.sync`/`azdo.boards.sync` — `rebuild-plan` never
  touches an external tracker.

## Notes

**Fidelity limitation (carried from the approved proposal, restated here as
the acceptance boundary):** this connection makes the functional spec's
capabilities and the domain model's rules the acceptance basis for each
rebuilt feature. It does **not** prove behavioral equivalence with the
legacy system. True "same app" verification additionally requires
golden-master outputs (recorded input/output pairs from the running legacy
system, captured by a human) and, where relevant, external-format or
DLL/COM semantics no static analysis can recover. `rebuild-backlog.md`'s
per-item "Verification inputs needed" field exists to surface these gaps,
never to imply they're already handled.
