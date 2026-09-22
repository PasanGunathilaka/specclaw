# Spec: Session-start bootstrap and intent router

**Change:** 033-session-bootstrap-router
**Created:** 2026-09-19
**Status:** 🟢 Approved

## Overview

specclaw's lifecycle only starts when somebody types `/specclaw:<verb>`, or when the model happens to
match one of ~30 skill descriptions competing with every other installed plugin's. The README
promises conversational routing; nothing in the plugin delivers it. `plugins/specclaw/` has no
`hooks/` directory at all.

This change adds one `SessionStart` hook that injects a router — and, unlike the framework it is
learned from, injects the **project's live state** with it, so a route depends on a recorded phase
rather than on a guess.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Snapshot on `compact` too? | **Yes**, regenerated at emit time on every matcher. Stale state after a compaction is worse than the cost of recomputing it, and it is recomputed from disk in milliseconds. |
| 2 | Strict (`PreToolUse` block) or advisory? | **Prose only.** The MUST gate on `propose` is forcing language, not a harness block. Measure the hit rate — including the negative rows — with 037's evals before adding teeth. |
| 2b | Does the propose gate fire inside an active build? | No. The snapshot tells the router a build is active, and the gate yields to one question: *is this part of `<change>`, or new?* |
| 3 | Plugin cache lag | Documented in the plugin `CLAUDE.md`, and `specclaw-check-update` says it: hooks load from the **installed** plugin, so the hook needs a plugin update, not a `git pull`. |
| 4 | Two changes building at once | The router asks which change rather than guessing. Pinned as a snapshot case. |
| 5 | Is the skill also `Skill`-invocable? | **Yes.** Hook-only would mean the router is unrecoverable after a compaction that the hook missed, and unreadable to anyone who wants to see what is routing them. |

## Requirements

### Functional Requirements

- **FR1** — `hooks/hooks.json` registers `SessionStart` for `startup|clear|compact` → `hooks/session-start`.
- **FR2** — `hooks/session-start` **emits nothing and exits 0** unless `./.specclaw/config.yaml`
  exists. specclaw must not tax sessions in unrelated repos.
- **FR3** — `bootstrap.enabled: false` → emits nothing, exit 0. Read with a **block-scoped**
  reader: a whole-file `grep enabled:` finds `build.dynamic_agents.enabled` (false) or
  `loop.enabled`, which is the exact defect `party_val` exists to prevent.
- **FR4** — Output is a single JSON object carrying
  `hookSpecificOutput.additionalContext`, built with `printf` — **not** a heredoc.
- **FR5** — The hook **always exits 0**, on every path including failure. A broken hook must never
  break a session.
- **FR6** — `skills/using-specclaw/SKILL.md` is the router text, injected verbatim: what specclaw is,
  the hard gate on `propose`, the routing table, explicit non-routes, the announce line, and a
  red-flags table.
- **FR7** — The hard gate applies to **new work in the codebase only**, and is the only forcing
  route. Every other row is a deterministic table and may be declined.
- **FR8** — `bin/specclaw-bootstrap-snapshot <specclaw_dir>` prints a ≤ `max_lines` state block from
  `state.json` / `tasks.md` / `proposal.md` on disk. **It never spawns a model** and never writes.
- **FR9** — `bootstrap.snapshot: false` → router only, no state block.
- **FR10** — A corrupted or unreadable project state yields the router **without** the snapshot,
  exit 0 — never a failed hook and never a partial JSON document.
- **FR11** — `templates/config.yaml` seeds `bootstrap:` with `enabled: true`, `snapshot: true`,
  `max_lines: 15`. Projects without the block get those defaults.
- **FR12** — The emitted `additionalContext` is **capped**: ≤ 8000 bytes, enforced by the suite.
  The whole point of a per-session injection is that it is cheap.

### Non-Functional Requirements

- **NFR1** — `set -euo pipefail`, shellcheck-clean, bash + coreutils.
- **NFR2** — Valid JSON on every emitting path, verified by the suite with `python3`/`jq` when
  present and by shape otherwise.

## Acceptance Criteria

- **AC-1** — No `.specclaw/config.yaml` → empty stdout, exit 0.
- **AC-2** — `bootstrap.enabled: false` → empty stdout, exit 0.
- **AC-3** — A valid project → stdout parses as JSON and carries
  `hookSpecificOutput.hookEventName` = `SessionStart` and a non-empty `additionalContext`.
- **AC-4** — That context contains the router heading, the propose gate, and the routing table.
- **AC-5** — It contains the live state block, listing an in-progress build with its task counts.
- **AC-6** — `bootstrap.snapshot: false` → router present, state block absent, exit 0.
- **AC-7** — A `state.json` that is unparseable → router present, snapshot absent, exit 0, and
  stdout still parses as JSON.
- **AC-8** — `bootstrap.enabled` is read from the `bootstrap:` block even when `loop.enabled: true`
  and `build.dynamic_agents.enabled: false` sit above it in the same file.
- **AC-9** — The emitted `additionalContext` is ≤ 8000 bytes on a project with 12 changes.
- **AC-10** — `specclaw-bootstrap-snapshot` writes no file anywhere under `.specclaw/`.
- **AC-11** — The snapshot honours `bootstrap.max_lines`.
- **AC-12** — Two changes at `build` → the snapshot lists both and the router says to ask which.
- **AC-13** — `hooks.json` is valid JSON and names `startup|clear|compact`.
- **AC-14** — The skill's frontmatter description is trigger-only — no workflow narration.

## Edge Cases

- `.specclaw/` exists but `config.yaml` does not → treated as not-a-specclaw-project (FR2 keys on
  the config file, not the directory).
- A change with `state.json` but no `tasks.md` → listed with its phase and no counts.
- `date -u` unavailable → the snapshot header omits the timestamp rather than printing an empty one.

## Dependencies

References `/specclaw:debug` (change 034, in this PR) and change 036's sizes in one Red-Flag row.
Neither is a build-time dependency: the router is prose.
