# Proposal: Session-start bootstrap and intent router — make specclaw skills fire without being typed

**Created:** 2026-09-19
**Status:** 🟡 Draft
**Source of the idea:** `obra/superpowers` v6.3.0 (`hooks/hooks.json`, `hooks/session-start`, `skills/using-superpowers/SKILL.md`). Learning adapted, not copied.

## Problem

specclaw's lifecycle only starts when someone types `/specclaw:<verb>` or the model happens to match a
skill description. The README promises conversational routing (*"i have a proposal" fires
`/specclaw:propose`*) but nothing in the plugin makes that reliable:

- **No hook exists.** `plugins/specclaw/` has `agents/ bin/ lib/ references/ skills/ templates/ tests/` and
  no `hooks/` directory. At session start Claude knows nothing about specclaw beyond ~30 skill
  descriptions competing with every other installed plugin's descriptions.
- **The model does not know the project state.** `.specclaw/STATUS.md` says there is a build in progress
  on `032-party-mode` and two pending proposals, but that is on disk, not in context. "The tests are
  failing" said mid-build should route to the loop / a debug protocol; said on a clean tree it is a new
  change. Without state in context the model cannot tell.
- **Descriptions are doing the routing job alone, and they do it badly.** `skills/propose/SKILL.md`'s
  description is five sentences of lifecycle prose. superpowers measured that a description which
  summarises the workflow gets *followed instead of the skill* (`skills/writing-skills/SKILL.md:150-158`).
- **Context is lost at `/compact` and `/clear`.** Even when the user has said "we're doing specclaw",
  compaction drops it.

superpowers' entire auto-trigger mechanism is one `SessionStart` hook (`matcher: startup|clear|compact`)
that injects the full `using-superpowers` skill as `hookSpecificOutput.additionalContext`. Their
contributor guide is blunt about it: *"The bootstrap is what causes skills to auto-trigger at the
right moments. Without it, the skills are dead weight — present on disk but never invoked."*
specclaw is currently dead weight in exactly that sense.

superpowers' routing doctrine — *"if there is even a 1% chance a skill might apply you ABSOLUTELY MUST
invoke it"* — is persuasion-heavy and non-deterministic, and applying it to every verb would make the
router a mood, not a table. But it exists because the one moment an agent reliably rationalises its way
past a process is **the moment before it starts writing code for something new**. That is exactly the
moment specclaw's paper trail is created or lost forever: a change that starts without `propose` never
gets a change dir, and no later verb can recover it. So the forcing language is worth taking for
**that one route and no other**: new work in the codebase MUST go through `/specclaw:propose`; every
other verb is routed by a deterministic table and may be declined.

## Proposed Solution

**1. `SessionStart` hook — inert outside specclaw projects.**

- `plugins/specclaw/hooks/hooks.json` registering `startup|clear|compact` → `hooks/session-start`.
- `hooks/session-start` (bash, shellcheck-clean, `set -euo pipefail`, always `exit 0`):
  - **Exit silently unless `./.specclaw/config.yaml` exists.** superpowers injects unconditionally;
    specclaw must not tax sessions in unrelated repos.
  - Read `bootstrap.enabled` (default `true`) via a small bash reader with the same
    column-0-anchored discipline as `specclaw-party get`; `false` → emit nothing.
  - Emit one JSON object with `hookSpecificOutput.additionalContext` built with `printf`, not a
    heredoc (superpowers hit a bash 5.3 heredoc hang, their issue #571). Escape with parameter
    substitution.
  - Any failure → emit nothing and exit 0. A broken hook must never break a session.

**2. `skills/using-specclaw/SKILL.md` — the router, ~120 lines, injected verbatim.**

Content, in this order:

- **What specclaw is, in three lines**, and where the change dirs live.
- **The hard gate — new work MUST be proposed.** One block, in superpowers' own register, scoped to
  one route:

  > If the user asks to add, build, create, implement, change, extend, remove or "just quickly" alter
  > anything in this codebase — a feature, a flag, a file, a config value, a one-line fix — and there is
  > even a 1% chance it is new work rather than a question, you MUST invoke `/specclaw:propose` before
  > reading, editing or creating any source file. This is not negotiable. You cannot rationalise your way
  > out of it. "It's too small", "I'll propose it after", "they seem in a hurry", "I'm just looking
  > first" — all of these mean STOP and invoke `/specclaw:propose`. The skill sizes the ceremony
  > (change 036); the gate does not scale.

  The gate is forcing because this is the only route with no recovery path: a change that begins
  without a proposal has no change dir, and nothing downstream can create one retroactively. It
  applies to **new work in the codebase only** — questions about the code, debugging an existing
  change, planning, building, verifying and shipping are routed by the table below and are advisory.

- **The routing table** — deterministic, intent → verb, for everything that is not new work:

  | The user… | Route | Never route when… |
  |---|---|---|
  | wants to add / build / change / implement something | `/specclaw:propose` — **the hard gate above applies; this row is not optional** | it is a question about the code, not a request to change it |
  | says a proposal is approved / asks for spec, design, tasks | `/specclaw:plan` | no proposal dir exists — propose first |
  | says go / build / implement the tasks | `/specclaw:build` | tasks.md is absent |
  | reports a bug, failing test, unexpected behaviour, broken build | `/specclaw:debug` (see change 034) | — |
  | asks "are we done", "does it pass", "ship it", "open the PR" | `/specclaw:verify` then `/specclaw:pr` | verify-report.md already says PASS for HEAD — go straight to pr |
  | asks where things stand | `/specclaw:status` | — |
  | mentions a lesson, gotcha, "remember that…" | `/specclaw:learn` | — |

- **Explicit non-routes**: `auth-azdo`, `auth-jira` (credentials, `disable-model-invocation` already),
  pure read-only questions, and anything the user asks for by a different tool's name.
- **The announce line**: `Using /specclaw:<verb> — <the trigger phrase that matched>` before the
  first tool call. This is the one superpowers habit worth keeping verbatim: the operator can veto
  a bad route in one message instead of discovering it three files later.
- **A short Red-Flags table** (≤ 8 rows) for the rationalisations that skip the lifecycle: "this is
  too small for a proposal", "I'll just fix it and propose after", "the user seems in a hurry",
  "let me explore the codebase first". Recognition tables at decision time are the phrasing superpowers
  measured to work (`docs/superpowers/specs/2026-06-10-positive-instruction-redesign-design.md`); they
  back up the hard gate for propose and are the *only* enforcement for the advisory rows.
- **Coexistence rule**: if the session also has superpowers, `brainstorming` may run *inside*
  propose's elicitation, but the artifact is `proposal.md`, and `writing-plans` is replaced by
  `/specclaw:plan`. Two frameworks, one paper trail.

**3. State snapshot appended by the hook.** After the router text the hook appends a ≤ 15-line block:

```
## specclaw state (live, 2026-09-19 10:41 UTC)
- 032-party-mode — build in-progress, 8/8 tasks, 0 failed  → "tests fail" = /specclaw:loop or /specclaw:debug, not propose
- 028-phase-time-accounting — proposal awaiting approval
- 029-staged-files-auditor — proposal awaiting approval
```

Produced by a new `specclaw-bootstrap-snapshot .specclaw` (bash, reads the same rows
`specclaw-update-status` writes; never spawns a model). This is the part superpowers does not have
and the part that makes routing *controlled*: the route depends on recorded phase, not on vibes.

**4. Config.** `bootstrap:` block seeded by `specclaw-init` (`templates/config.yaml`):
`enabled: true`, `snapshot: true`, `max_lines: 15`. Existing projects without the block get the defaults.

**5. Tests.** bats suite `tests/run-bootstrap-hook-tests.sh`: no `.specclaw/` → empty stdout, exit 0;
`enabled: false` → empty; valid project → parses as JSON, contains the router heading and the
snapshot; corrupted STATUS.md → router still emitted, snapshot omitted, exit 0. Registered in CI.

## Scope

### In Scope
- `hooks/hooks.json`, `hooks/session-start`, `bin/specclaw-bootstrap-snapshot`.
- `skills/using-specclaw/SKILL.md` (router content as specified above; frontmatter description is
  trigger-only: "Use when a session starts in a repo that has `.specclaw/` — establishes how specclaw
  verbs are chosen").
- `bootstrap:` block in `templates/config.yaml`; `specclaw-init` seeds it.
- Plugin `CLAUDE.md` section explaining the hook and how to disable it.
- bats suite + CI registration; shellcheck gate passes.

### Out of Scope
- Cross-harness output formats (Cursor `additional_context`, Copilot top-level `additionalContext`).
  specclaw targets Claude Code; add the branch when a second harness is actually supported.
- Rewriting the other ~30 skill descriptions to trigger-only form — that is change **037** with a lint
  and an eval to prove it helped.
- A `/specclaw:debug` skill — change **034**. The router table references it; until 034 lands the row
  routes to `/specclaw:loop` when a build is in progress and to plain investigation otherwise.
- Any `PreToolUse`/`Stop` hooks that *block* actions. This change gates in prose (propose only); it
  does not gate in the harness.

## Impact

- **Files affected:** ~7 (estimated) — 2 new hook files, 1 new bin script, 1 new SKILL.md,
  `templates/config.yaml`, `bin/specclaw-init`, plugin `CLAUDE.md`, 1 new bats suite.
- **Complexity:** medium — the mechanism is small; the work is in the router text (behaviour-shaping
  prose needs iteration) and in keeping the injected block short.
- **Risk:** low — additive, fail-open (`exit 0` always), off-switch in config, inert in non-specclaw repos.
  The real risk is *token cost per session*: superpowers' bootstrap is ~1.2k tokens; budget ≤ 1.5k
  including the snapshot and enforce it in the bats suite (line/byte cap).

## Open Questions

1. **Should the snapshot fire on `compact` too?** It is cheap and keeps state after compaction, but
   a stale "live" timestamp could mislead. Lean: yes, always regenerate at emit time.
2. **Strict vs advisory routing.** The propose gate is already strict in prose. Should a
   `bootstrap.mode: strict` add a `PreToolUse` block on `Edit`/`Write` to source files when no change is
   active (explicitly out of scope here), or is the forcing language enough? Lean: prose only in this
   change; measure the propose row's hit rate with 037's evals — including its negative rows, since a
   MUST gate is exactly what over-triggers on read-only questions — before adding teeth.
2b. **Does the propose gate fire inside an active build?** "Add a retry to T5" mid-build is a scope
   change to an existing change, not new work. Lean: the snapshot tells the router a build is active,
   and the gate yields to *"is this part of `<change>`, or new?"* — one question, then route.
3. **Plugin cache lag.** The installed plugin (`~/.claude/plugins/cache/chan4lk/specclaw/0.4.2`) is
   several versions behind the repo. Hooks only load from the installed plugin — document that the
   hook needs a plugin update, and have `specclaw-check-update` mention it.
4. **What does the router say when two active changes are building?** Snapshot lists both; the router
   should ask which change rather than guess. Confirm that ask-don't-guess phrasing.
5. **Does the `using-specclaw` skill also need to be listed for the `Skill` tool** (so it can be
   re-read after compaction if the hook did not fire), or is hook-only sufficient?

---

**To proceed:** Review this proposal and approve to begin planning.
