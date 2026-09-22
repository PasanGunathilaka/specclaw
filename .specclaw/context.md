# Project Context

_Last updated: 2026-09-20 — codex-plugin-packaging_

## Architecture Overview

specclaw is a Claude Code plugin with a native Codex package that drives the spec-first lifecycle:
`propose` → `plan` → `build` → `verify` → `pr` → _(context auto-updated)_.

- `plugins/specclaw/bin/` — executable Bash lifecycle rules; skills call these helpers rather
  than reimplementing mechanics.
- `plugins/specclaw/skills/` — canonical lifecycle `SKILL.md` tree shared by Claude and installed
  Codex users.
- `plugins/specclaw/.claude-plugin/plugin.json` — Claude package metadata.
- `plugins/specclaw/.codex-plugin/plugin.json` — native Codex manifest; its `skills` field exposes
  `./skills/` directly, with no copied lifecycle implementation.
- `.agents/plugins/marketplace.json` — repository-root Codex marketplace catalog. Its
  `./plugins/specclaw` source is resolved from the checkout root for `codex plugin marketplace add`
  and `codex plugin add` installation.
- `.agents/skills/specclaw/SKILL.md` — checkout-local Codex adapter. It dynamically resolves the
  checkout root and delegates lifecycle verbs to canonical assets; it owns no implementation/state.
- `plugins/specclaw/templates/` — seed files for a project's `.specclaw/`, including `context.md`.
- `plugins/specclaw/tests/` — Bash test suites, all registered in `.github/workflows/ci.yml`.
- `.specclaw/` — per-project durable record: `config.yaml`, `context.md`, `STATUS.md`, and
  `changes/<NNN>-<slug>/` artifacts. Active phase dispatches temporarily use `.lock/meta.json`.
  Completed changes move to `changes/archive/<NNN>-<slug>/`; `party/session-spawns.jsonl` is a
  separate top-level cross-change ledger.

Change folders carry permanent three-digit ordinals assigned by `specclaw-next-change-number` and
preserved through archival. `specclaw-update-status` and `specclaw-reconcile` iterate them in
numeric order, with unnumbered legacy folders after numbered ones.

**Per-change dispatch lock.** `plan`, `build`, `verify`, and `pr` acquire
`changes/<change>/.lock/meta.json` through `specclaw-change-lock` before mutation and release it
on completion. Staleness uses wall-clock age only (`git.lock_stale_minutes`, default 120), not PID
liveness; a dispatch spans separately invoked processes and has no meaningful single PID.

## Coding Style & Conventions

- **Scripts are Bash + coreutils.** `jq` and `python3` may be used in `bin/`; test suites stay
  jq-free (`run-parser-tests.sh` is the exception and shells out to it).
- **Every test suite must be registered in `.github/workflows/ci.yml`.** An unregistered suite
  silently never runs.
- **Native Codex packaging has a focused CI gate.** `tests/run-codex-plugin-tests.sh` validates
  marketplace and manifest JSON, marketplace-root path resolution, Claude/Codex metadata parity,
  declared skill root, canonical skill inventory, and CI registration. It stays offline and never
  mutates global Codex configuration.
- **The checkout-local adapter has a separate focused gate.** `tests/run-codex-skill-tests.sh`
  validates CI registration, root resolution, dynamic routing, and the one-file boundary.
- **`tests/shellcheck-gate.sh` passes with `shellcheck-baseline.txt` unchanged.** Fix new findings
  or add a targeted `# shellcheck disable=SCxxxx` with a written rationale.
- **Force base ten for digit runs read from disk:** `$((10#$n))`; `$((08))` is invalid Bash.
- **Quote every path; never interpolate a change name into a regex.** Change names are opaque and
  are tested against shell/regex metacharacters.
- **Version bump before every PR:** Claude and Codex manifests must remain in sync. `specclaw-pr`
  auto-bumps their patch version when `plugin.version_files` says the base version is unchanged.
- **Hand-written Bash JSON must escape values.** `specclaw-party`'s `json_str` and
  `specclaw-change-lock`'s `json_esc` escape backslashes/quotes before interpolation.
- Where a helper must be duplicated between standalone executables, copies stay byte-identical and
  a test pins that identity.

## Key Patterns

- **Native package metadata, canonical implementation.** The Codex marketplace selects the
  existing `plugins/specclaw` root and its manifest points at `./skills/`; packaging never copies
  skills, binaries, templates, or references.
- **Derived, not stored.** Recompute facts already on disk instead of caching them. For example,
  `specclaw-next-change-number` takes the current maximum ordinal plus one.
- **One writer per state file.** `specclaw-set-phase` alone writes `changes/<change>/state.json`.
  It writes atomically and callers must preserve every carried field when refreshing a record.
- **Anchor dispatch locks at a true dispatch boundary.** Do not add lock acquisition to a `bin/`
  subcommand that may also be a standalone read-only inspection; acquire in the phase `SKILL.md`
  boundary and keep only idempotent release in the helper when necessary.
- **Append-only, sum-on-read ledgers for cross-run counts.** `specclaw-timer`'s timeline and
  `specclaw-party`'s session-spawn ledger write one JSON event per line and compute totals on read.
- **Shared counter formats are caller contracts.** When `specclaw-parse-tasks --count` gained its
  deferred fourth field, every caller and its zero fallback changed together; `read` otherwise
  silently appends surplus fields to the last variable.
- **Plan → validate → execute destructive work.** Refuse before the first mutation; destructive
  tools such as `specclaw-renumber-changes` are dry-run by default and need `--apply`.
- **Self-clearing hints, not “already asked” flags.** Condition prompts on the live condition so
  they disappear when resolved without extra state.
- **Document fallback precedence** for incomplete data and use deterministic name tiebreakers.
- **`git mv` inside a working tree, plain `mv` outside it.**
- **Mixed old/new states are supported steady states.** No lifecycle command fails merely because
  a folder predates a convention.

## Technology Decisions

- **Bash + coreutils** ship directly as runnable lifecycle helpers, with no build step/runtime.
- **Codex uses `.agents/plugins/marketplace.json` and `.codex-plugin/plugin.json`.** They provide
  portable Codex discovery metadata over the canonical plugin root while the Claude manifest
  remains its own packaging contract.
- **Offline contract tests, not installation tests, are the CI package gate.** Static validation
  is deterministic and avoids configured marketplaces/plugin caches; any install smoke test must
  use an isolated temporary Codex home.
- **Three-digit change ordinals** (`NNN-<slug>`) preserve lexical chronological order past 99;
  `printf '%03d'` widens above 999 rather than colliding.
- **`^[0-9]+-`, excluding `^[0-9]{4}-[0-9]{2}-[0-9]{2}`, defines numbered folders.** This avoids
  mistaking legacy date-prefixed archives for ordinals.
- **Archive folders retain their ordinal and drop their old archive-date prefix.** The archive date
  belongs in `state.json`.
- **No config key controls numbering format.** It is one fixed rule.
- **Concurrency uses wall-clock staleness, unlike browser-slot PID semaphores.** Their ownership
  models differ even though both use atomic `mkdir` claims.

## Constraints

- **Never write `state.json` directly.** Use `specclaw-set-phase`; omitting a field can delete it.
- **Never add an index/cache for filesystem-derived state.** Append-only event ledgers are distinct.
- **Never silence ShellCheck by appending to `shellcheck-baseline.txt`.**
- **Never add an unregistered test suite.**
- **Never copy canonical assets for Codex.** The installed package points at
  `plugins/specclaw/skills/`; the single checkout-local adapter delegates to that same root.
- **Never let package validation mutate global Codex configuration.** Installation tests, if
  needed, must use an isolated temporary Codex home; CI remains offline.
- **Never rename/migrate a user's change folders automatically.** Require explicit `--apply` and
  confirmation; never rename one mid-build.
- **Never assume a change name starts with a letter or has a number.** Do not lexical-sort changes
  where chronology matters or place unnumbered folders first.
- **A `--force` safety override only overrides its documented failure mode.** For example,
  `specclaw-change-lock acquire --force` clears stale locks but still refuses live ones.

## Recent Decisions

<!-- Last 5 significant decisions from merged changes. Updated automatically on each PR merge. -->

1. **2026-09-20 — codex-plugin-packaging:** SpecClaw now ships as a native Codex marketplace
   package: `.agents/plugins/marketplace.json` selects `./plugins/specclaw`, whose
   `.codex-plugin/plugin.json` exposes the existing `./skills/` tree. Metadata stays in parity
   with the Claude manifest, and offline CI validates it without touching global Codex config.
2. **2026-09-20 — change-concurrency-lock-and-review-budget:** `specclaw-change-lock` guards
   `plan`/`build`/`verify`/`pr` at each phase's real dispatch boundary, using wall-clock age.
3. **2026-09-20 — codex-skill-packaging:** The checkout-local adapter at
   `.agents/skills/specclaw/SKILL.md` dynamically resolves the checkout root and delegates to
   canonical `plugins/specclaw/` assets, leaving Claude packaging untouched.
4. **2026-09-20 — codex-skill-packaging:** The adapter remains exactly one file, with CI pinning
   root resolution, dynamic routing, and its no-duplication boundary.
5. **2026-09-20 — change-concurrency-lock-and-review-budget:** `specclaw-parse-tasks` gained
   deferred `[>]` tasks and a fourth `--count` field; every caller changed together to avoid
   `read` silently corrupting its failed-count variable.
