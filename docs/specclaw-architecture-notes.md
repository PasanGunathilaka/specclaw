# SpecClaw Architecture Notes

Investigation notes on `plugins/specclaw/` — the real source tree behind the
`chan4lk` marketplace wrapper at the repo root. Written for someone about to
extend the plugin, not just use it.

One fact worth keeping in mind throughout: **this repo dogfoods itself.**
`.specclaw/changes/` at the repo root contains ~20 real proposal→spec→design→
tasks→verify trails (`loop-engineering`, `grounded-context`, `build-engine`,
`code-reviewer-agent`, `smart-base-branch`, ...) — every feature described
below was itself built by running `/specclaw:propose` → `/specclaw:plan` →
`/specclaw:build` → `/specclaw:verify` → `/specclaw:pr` against this codebase.
That's the strongest evidence for how the tool is meant to be used, and it's
the recommended path for the legacy-codebase-analysis feature discussed in
§6.

---

## 1. Packaging

Two manifests, read together:

**`.claude-plugin/marketplace.json`** (repo root) — the marketplace
definition. It's owned by `chan4lk`, not by specclaw, and lists specclaw as
its first (currently only) plugin entry:

```json
{
  "name": "chan4lk",
  "plugins": [
    {
      "name": "specclaw",
      "source": "./plugins/specclaw",
      "version": "0.5.3",
      "homepage": "https://github.com/chan4lk/specclaw"
    }
  ]
}
```

`source` is the load-bearing field — it tells Claude Code's plugin loader
where the installable plugin actually lives relative to the marketplace repo
root. Everything under `plugins/specclaw/` is the unit that gets installed;
the rest of the repo (`.github/`, `docs/`, root `README.md`) is marketplace
/ project scaffolding that never ships to a consumer.

**`plugins/specclaw/.claude-plugin/plugin.json`** — the plugin's own
manifest: name, version, description, author, license, keywords. Notice what
it *doesn't* contain: no explicit `"commands"`, `"agents"`, or `"skills"`
path list. Claude Code discovers those by **directory convention** —
anything under `skills/<verb>/SKILL.md` becomes `/specclaw:<verb>`, and
anything under `agents/*.md` becomes a spawnable subagent — so adding a new
command is a filesystem operation, not a manifest edit (see §6).

**Install flow** (from the root `README.md`):

```
/plugin marketplace add chan4lk/specclaw     # registers the marketplace.json above
/plugin install specclaw@chan4lk             # installs plugins/specclaw/ as a plugin
/specclaw:init                               # plugin's own first-run command
```

**`$CLAUDE_PLUGIN_ROOT`** — every `bin/specclaw-*` script and every
`SKILL.md` that references a template does so via
`$CLAUDE_PLUGIN_ROOT/templates/...` or `$CLAUDE_PLUGIN_ROOT/references/...`.
At runtime, Claude Code sets this environment variable to the **absolute
path of the installed plugin directory** (i.e. `plugins/specclaw/` after
install, wherever the harness actually unpacked it) — this is what lets a
script say "read the spec template" without knowing where on disk the plugin
was installed. Scripts that might run standalone (outside the plugin
harness, e.g. under `tests/`) fall back to computing it from their own
location:

```bash
# bin/specclaw-init
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
```

That fallback (`script's own dir / ..`) is why `plugins/specclaw/tests/run-parser-tests.sh`
can invoke `bin/specclaw-*` directly with plain `bash`, with no plugin
runtime involved at all.

Everything specclaw *writes* — `.specclaw/config.yaml`, `changes/`, `STATUS.md`
— lives in the **host project's working directory**, never inside the
plugin install. The plugin is stateless; state lives in the repo you run it
against.

---

## 2. Commands (skills)

19 skills under `skills/<verb>/SKILL.md`. Each is a Markdown file with YAML
frontmatter — the `description:` field is what Claude Code's model-invocation
router matches against user intent (e.g. "I have a proposal" routes to
`propose`). `disable-model-invocation: true` opts a skill out of that routing
so it's reachable only by explicit `/specclaw:<verb>` — used exactly twice,
for the two commands that block on an interactive TTY prompt for a secret.

| Skill | What it does | Invocation |
|---|---|---|
| `init` | Creates `.specclaw/` (`config.yaml`, `STATUS.md`, `changes/archive/`) | Model-invokable; effectively a one-time explicit bootstrap |
| `propose` | Drafts `proposal.md` (problem/solution/scope/impact) for a new change | Model-invokable — explicitly told to fire on *any* mention of a feature idea, no clarifying turn first |
| `author-spec` | Interactively co-authors `spec.md` via the `spec-author` subagent (5 Whys, JTBD, Inversion, MoSCoW, ...) | Model-invokable; standalone alternative to `plan --author-spec` |
| `plan` | Generates `spec.md` + `design.md` + `tasks.md` from an approved proposal | Model-invokable |
| `build` | Executes `tasks.md` wave-by-wave, spawning a coding agent per task, committing each | Model-invokable |
| `learn` | Appends a spec-gap/design-gap/pattern/best-practice/agent-issue entry to `learnings.md` | Model-invokable; used mid-build |
| `patterns` | Scans/lists/promotes the cross-change pattern registry (`patterns.md`) | Model-invokable, read-heavy |
| `verify` | Runs test/lint/build, evaluates acceptance criteria, writes `verify-report.md`; optional code review | Model-invokable |
| `pr` | Opens a GitHub PR via `gh`, enforces test policy, bumps plugin version, updates `context.md` | Model-invokable |
| `pr-azdo` | Same as `pr` but targets Azure DevOps Repos via REST | Model-invokable |
| `issue` | Creates a Jira issue from `proposal.md` + `spec.md` | Model-invokable |
| `azdo-issue` | Creates/updates/comments/closes an Azure Boards Work Item; links PRs | Model-invokable |
| `auth-azdo` | Interactive Azure DevOps PAT setup, writes `.specclaw/.env` | **`disable-model-invocation: true`** — refuses to run without `/dev/tty` |
| `auth-jira` | Interactive Jira API-token setup, writes `.specclaw/.env` | **`disable-model-invocation: true`** — same reason |
| `status` | Refreshes and prints `STATUS.md`; per-change snapshot; plugin-update hint | Model-invokable, read-only |
| `archive` | Moves a completed change to `changes/archive/YYYY-MM-DD-<name>/`, closes tracker issues | Model-invokable |
| `auto` | Advances the whole active-changes queue one phase each, autonomously | Model-invokable but "advanced" — needs `automation.*` config |
| `loop` | Drives autonomous build→verify→review remediation until all gates are green or a guardrail halts | Model-invokable; default-on wrapper around build/verify |
| `context` | `show`/`add`/`edit`/`reset` for the living `.specclaw/context.md` architecture doc | Model-invokable |

Every skill's first line of substance is identical: `**First, run**
specclaw-ensure-init .specclaw` — an idempotent self-heal so a user can type
`/specclaw:propose "..."` on a brand-new repo without running `/specclaw:init`
first.

---

## 3. The Engine

### Language and dependency model

All 26 executables under `bin/` are **plain POSIX-ish Bash**
(`#!/usr/bin/env bash`, `set -euo pipefail`). There is no Node/Python/Go
runtime anywhere in the execution path. `jq` is used opportunistically for
JSON handling but every script that touches JSON carries a **grep/awk/sed
fallback** so it degrades gracefully without it (search each script for
`command -v jq`). This is a deliberate constraint, not an accident — it means
the plugin has zero install step beyond `bash`, `git`, and coreutils, which
matters because these scripts run inside whatever the *host project's*
environment happens to be, not a controlled plugin sandbox.

A consequence worth knowing before you add a script: there's **no shared
bash library**. Nearly every script that reads `config.yaml` carries its own
copy of a `yaml_val()` function (a hand-rolled section/field YAML scalar
reader) and its own `sed_i()` GNU/BSD `sed -i` shim. This is copy-paste, not
DRY — it's what "each script is self-contained/portable" costs. Match this
style rather than introducing a `bin/_lib.sh` unless you're prepared to
update every caller.

### How a skill calls a script

**A SKILL.md file is not executed** — it's a Markdown procedure that Claude
(the agent running the skill) reads and follows turn-by-turn, issuing `Bash`
tool calls for each `specclaw-*` invocation the file specifies, and `Agent`
tool calls wherever the file says "spawn a coding agent" / "invoke the
`spec-author` subagent". The bin scripts are the only part of the system
that's actually deterministic; the skill text is the orchestration prompt
around them.

### The core lifecycle scripts

| Script | Subcommands | Job |
|---|---|---|
| `specclaw-init` | — | Scaffolds `.specclaw/{config.yaml,STATUS.md,changes/archive/}` from `templates/config.yaml`. Refuses to run if `.specclaw/` exists. |
| `specclaw-ensure-init` | — | Idempotent guard: no-ops if `.specclaw/` exists, else shells out to `specclaw-init` with the CWD's basename as project name. Called by every other skill's Step 0. |
| `specclaw-validate-change` | `<phase>` \| `status` | Central gate. Checks phase prerequisites (`propose/plan/build/verify/archive/pr/github-create`) against files on disk; reads `workflow.strict` to decide error-vs-warning. `status` mode prints a per-change artifact checklist. |
| `specclaw-build` | `setup`/`commit`/`finalize`/`worktree-path` | The git-strategy engine. `setup` creates/resumes the change's branch or worktree (from a **detected base branch** — `git.base_branch` config → `origin/HEAD` → `gh` default → `main`/`master` — never just current HEAD) and emits a JSON config blob. `commit` stages+commits one task's files. `finalize` runs test/lint/build commands and merges (`--no-ff`) back to base, aborting cleanly on conflict. |
| `specclaw-parse-tasks` | `--wave N`, `--status S`, `--validate` | An `awk` state machine that turns `tasks.md`'s `### Wave N` / `- [ ] \`T1\`` / `- Files:` markdown into a JSON task array. This is the one piece of the engine with real parsing logic — see `tests/run-parser-tests.sh` for its regression cases (fenced-code-block exclusion, mixed AC formats, etc). |
| `specclaw-update-task-status` | single or `--batch T1:complete T2:failed` | Flips a task's `[ ]/[~]/[x]/[!]` marker in-place via `sed`, optionally appending a `## Status Log` trail. |
| `specclaw-build-context` | `<task_id>` `[--failure-record F] [--reflection F]` | **The single most important script.** Assembles the entire coding-agent prompt: guardrails → repo knowledge base → project `context.md` → discovered docs → spec → design → existing file contents (capped at 500 lines/file) → error history → task + constraints, in that deliberate order (static/cacheable content first, the task itself last — see §4). The `--failure-record`/`--reflection` flags append a "Remediation Context" block used by `/specclaw-extras:loop`; omitting both keeps the payload byte-identical to pre-loop behavior. |
| `specclaw-verify` | `collect`/`report`/`update-status` | `collect` extracts ACs from `spec.md`, reads every file named in `tasks.md`'s `Files:` fields, and runs the configured test/lint/build commands, all as one JSON evidence blob (capped at 100–200 lines per output). `update-status` writes the PASS/FAIL/PARTIAL verdict into `status.md`, self-healing the file from `templates/status.md` if it's missing. |
| `specclaw-verify-context` | — | Builds the Verify Agent's full prompt by running `specclaw-verify collect`, then **extracting the "## Verify Agent" section directly out of `references/agent-prompts.md`** with an `awk` fence-aware scanner, and template-substituting the evidence into its `{{placeholders}}`. The prompt template lives in one file; nothing is duplicated in Bash. |
| `specclaw-update-status` | — | Regenerates `.specclaw/STATUS.md` by scanning every `changes/*/tasks.md` for progress and every `changes/archive/*/` for completions. |
| `specclaw-update-context` | — | Reads `proposal.md`/`design.md`/`verify-report.md` for a merged change and **outputs an LLM prompt to stdout** instructing a rewrite of `.specclaw/context.md` — the calling skill (`pr`/`pr-azdo`) is the one that actually feeds this to an agent and writes the result. The script itself never rewrites `context.md`; it only prepares the instruction. Always exits 0 (non-blocking). |
| `specclaw-pr` | — | Enforces `verify-report.md` exists + test policy met, force-commits the entire `.specclaw/changes/<name>/` planning trail into the branch (refuses to open a PR if any of it is uncommitted), auto-bumps `plugin.version_files` if unchanged since base, then `gh pr create --base <detected-base>`. |

### Everything else in `bin/`

- **`specclaw-discover-context`** (`list`/`emit`) — ranks and budget-caps
  project docs (`llms.txt` entries, root `CLAUDE.md`/`README.md`, `docs/`,
  nested READMEs, other `*.md`) for injection into plan/build/verify
  payloads. Config-driven `pin`/`exclude`/`folders`, default-excludes
  changelogs/licenses/`node_modules`/`.specclaw`. Never drops a file
  silently — every truncated/dropped doc is named in a footer comment.
- **`specclaw-detect-patterns`** (`scan`/`list`/`promote`) — keyword-overlap
  matching (stop-word-stripped) across `errors.md`/`learnings.md` entries to
  find recurring failure patterns in `.specclaw/patterns.md`; promotes
  3+-occurrence patterns into `.specclaw/knowledge/agent-hints.md`.
- **`specclaw-log-error`** / **`specclaw-log-learning`** — structured
  appenders for `errors.md` / `learnings.md`, with `--resolve` / `--promote`
  modes. Promotion always writes to `.specclaw/knowledge/` (repo-local),
  **never** back into the plugin's own `templates/`/`references/`.
- **`specclaw-loop`** (`init`/`gates`/`signature`/`decide`/`guard-tests`/
  `log-turn`/`escalate`/`ci-poll`/`done`) — the autonomous
  build→verify→review controller (1,359 lines, by far the largest script).
  Owns every mechanical decision the `loop` skill isn't allowed to
  second-guess: gate evaluation, no-progress/regression/oscillation
  detection, the reward-hack guard (reverts any fix-agent edit that touches
  a configured test-file glob), and CI polling via `gh pr checks` / `az
  pipelines runs`.
- **`specclaw-check-update`** — fail-silent plugin update notifier, at most
  one network call per 24h, cached in `.specclaw/.update-check`.
- **`specclaw-gh-sync`**, **`specclaw-azdo-issue`**, **`specclaw-azdo-pr`**,
  **`specclaw-auth-azdo`**, **`specclaw-auth-jira`**, **`specclaw-jira-issue`**
  — external-tracker integrations, each mirroring the GitHub-native path
  (`gh` CLI or curl) for Azure Boards/Repos and Jira respectively. Credentials
  live in `.specclaw/.env` (gitignored); tracker config lives in
  `config.yaml`.

### State layout on disk (host project, not the plugin)

```
.specclaw/
├── config.yaml              # project config: models, git strategy, workflow, loop, pr policy, integrations
├── STATUS.md                # cross-change dashboard (regenerated, not hand-edited)
├── context.md                # living architecture doc (optional; rewritten each PR merge)
├── patterns.md               # cross-change pattern registry
├── .env                       # gitignored — azdo/jira tokens
├── .update-check              # gitignored — plugin-version check cache
├── knowledge/
│   ├── spec-guidelines.md    # promoted spec_gap/design_gap learnings
│   └── agent-hints.md         # promoted pattern/best_practice/agent_issue learnings
├── worktrees/<change>/         # only if git.strategy: worktree-per-change
└── changes/
    ├── <change-name>/
    │   ├── proposal.md
    │   ├── spec.md
    │   ├── design.md
    │   ├── tasks.md
    │   ├── status.md
    │   ├── errors.md           # created on first build failure
    │   ├── learnings.md        # created on first /specclaw-extras:learn or post-build finding
    │   ├── verify-report.md
    │   ├── review-report.md    # only if workflow.code_review: true
    │   ├── loop-state.json     # only if /specclaw-extras:loop has run
    │   └── loop-log.md
    └── archive/
        └── YYYY-MM-DD-<change-name>/   # same shape, moved wholesale
```

`config.yaml` is read by every script via the same hand-rolled `yaml_val`
scanner — it supports one level of section nesting (`git.strategy`,
`build.test_command`, `azdo.boards.sync`, ...) plus inline comment/quote
stripping. There is no real YAML parser anywhere in the codebase.

---

## 4. Agents & Prompts

### `agents/` — subagent personas (auto-discovered, no manifest entry needed)

| Agent | Model | Tools | Purpose |
|---|---|---|---|
| `code-reviewer.md` | sonnet | Read, Write, Bash | Reviews changed files across 10 fixed dimensions (correctness, security, YAGNI, one-liners, naming, complexity, test quality, design adherence, scope creep, dead code). Every finding must quote the exact flagged line — "a finding you cannot anchor to quoted code is not a finding." Writes `review-report.md` with an APPROVED / CHANGES_REQUESTED / APPROVED_WITH_NOTES verdict. Invoked from `/specclaw:verify` Step 3.5 when `workflow.code_review: true`. |
| `spec-author.md` | opus | Read, Write, Bash | Interactively co-authors `spec.md` section-by-section (Overview → FR → NFR → AC → Edge Cases → Dependencies → Notes), naming and applying a specific brainstorming technique per section (5 Whys / JTBD / Inversion / Concrete-example probe / Pre-mortem / MoSCoW) and pushing back on vague or untestable requirements. Writes the file exactly once, at the end, only after explicit user approval. Invoked from `/specclaw:plan --author-spec` or standalone `/specclaw-extras:author-spec`. |

Both inherit `references/agent-guardrails.md` explicitly and cite specific
rules from it by number in their own instructions — the guardrails aren't
just injected mechanically into build agents, they're a shared behavioral
contract referenced by name across the whole agent roster.

### `references/` — four docs, two very different roles

- **`agent-guardrails.md`** — Andrej Karpathy's 4-rule CLAUDE.md (Think
  Before Coding / Simplicity First / Surgical Changes / Goal-Driven
  Execution), vendored verbatim (MIT). **Load-bearing at runtime:**
  `specclaw-build-context` `cat`s this file into every single coding-agent
  prompt. It's also the normative source `/specclaw:plan` and
  `/specclaw-extras:loop`'s skill text point to by rule number.
- **`agent-prompts.md`** — the master prompt-template library (Propose /
  Spec / Design / Tasks / Build / Verify / Code-Reviewer agent templates),
  plus "Context Preparation Notes" documenting how to build
  `{{codebase_summary}}` etc. **Load-bearing at runtime** for the Verify
  Agent specifically: `specclaw-verify-context` extracts the `## Verify
  Agent` section out of this exact file via `awk` at request time. The Build
  Agent template here is illustrative/historical — the live version is
  hardcoded in `specclaw-build-context` (with a comment noting the script
  owns final section ordering).
- **`build-engine.md`** — maintainer-facing reference for the build
  pipeline: script APIs, JSON schemas, wave/parallelism model, git-strategy
  comparison, troubleshooting. **Not read by any script** — pure
  documentation, useful as the definitive spec of what §3 above summarizes.
- **`workflow-examples.md`** — narrative walkthroughs (JWT-auth example,
  cron autonomous mode, multi-model routing, Discord approval flow). Also
  **not read by any script** — onboarding material only.

The distinction matters if you're adding a new reference file: decide
up front whether it's meant to be `cat`/`awk`-extracted into a live prompt
(like the first two) or purely for humans/maintainers (like the last two) —
naming it under `references/` doesn't make it load-bearing by itself.

---

## 5. End-to-End Flow: propose → plan → build → verify → pr

```
 propose                plan                  build                     verify                    pr
 ───────                ────                  ─────                     ──────                    ──
 skill:propose           skill:plan            skill:build               skill:verify              skill:pr
   │                       │                      │                         │                        │
   ├─ ensure-init          ├─ validate-change      ├─ validate-change build  ├─ validate-change verify├─ validate-change pr
   ├─ mkdir changes/<n>    │   plan                ├─ build setup            ├─ verify collect        ├─ pr (script)
   ├─ proposal.md    ◄──── │ discover-context       │  (branch/worktree,     │  (ACs + files +        │   ├─ test-policy gate
   │  from templates/       │  list/emit             │   detected base)      │   test/lint/build)      │   ├─ stage .specclaw/
   │  proposal.md          ├─ [Agent spec-author]   ├─ parse-tasks           ├─ verify-context         │   │  changes/<n>/*
   ├─ status.md      ◄──── │   if --author-spec     │  --status pending      │  (extracts Verify       │   │  (hard-fails if
   │  from templates/       ├─ spec.md        ◄──── ├─ per task, per wave:   │   Agent tmpl from        │   │   uncommitted)
   │  status.md              │  templates/spec.md    │   update-task-status   │   agent-prompts.md)      │   ├─ ensure_version_
   ├─ update-status         ├─ design.md      ◄──── │   in_progress          ├─ [Agent verify]          │   │  bumped()
   ├─ gh-sync create         │  templates/design.md  │   build-context  ◄──── ├─ [Agent code-reviewer]  │   ├─ gh pr create
   │  (if github.sync)      ├─ tasks.md       ◄──── │   (spec+design+code+   │   if workflow.code_      │   │  --base <detected>
   └─ azdo-issue create      │  templates/tasks.md   │    guardrails+context) │   review                 │   ├─ save_pr_url
      (if azdo.boards.sync) ├─ update-status        │   [Agent: coder]       ├─ verify update-status   │   └─ update-context
                            └─ gh-sync/azdo-issue    │   update-task-status   │  → status.md Verify row │      → context.md
                               update                │   complete/failed      ├─ update-status           │      rewrite via agent
                                                      │   build commit         └─ gh-sync/azdo-issue
                                                      │   log-error (on fail)     comment
                                                      ├─ build finalize
                                                      │   (tests/lint/build,
                                                      │    merge to base)
                                                      ├─ detect-patterns scan
                                                      ├─ log-learning
                                                      └─ update-status
```

**Files created/updated per stage:**

| Stage | Skill / script | Template used | Files touched |
|---|---|---|---|
| Propose | `skills/propose`, `specclaw-ensure-init`, `specclaw-update-status` | `templates/proposal.md`, `templates/status.md` | `changes/<n>/proposal.md`, `changes/<n>/status.md`, `STATUS.md` |
| Plan | `skills/plan`, `specclaw-validate-change`, `specclaw-discover-context` | `templates/spec.md`, `templates/design.md`, `templates/tasks.md` (or `spec-author` agent + same spec template as scaffold) | `changes/<n>/{spec,design,tasks}.md` |
| Build | `skills/build`, `specclaw-build`, `specclaw-parse-tasks`, `specclaw-build-context`, `specclaw-update-task-status`, `specclaw-log-error`, `specclaw-detect-patterns`, `specclaw-log-learning` | none (code is the output; `agent-guardrails.md` is injected) | `tasks.md` markers, git commits on `specclaw/<n>`, `errors.md`, `learnings.md`, `patterns.md`, `STATUS.md` |
| Verify | `skills/verify`, `specclaw-verify`, `specclaw-verify-context` | prompt extracted from `references/agent-prompts.md`; output shape mirrors `templates/verify-report.md` | `verify-report.md`, `review-report.md` (optional), `status.md` Verify row |
| PR | `skills/pr`, `specclaw-pr`, `specclaw-update-context` | none (title/body assembled programmatically from `proposal.md` + `spec.md` + `verify-report.md`) | `status.md` PR row, plugin version files (bump commit), `context.md`, a GitHub PR |
| (Archive) | `skills/archive`, `specclaw-validate-change archive` | none | `changes/archive/YYYY-MM-DD-<n>/` |

Two threads run underneath this without being a "stage" of their own:

- **Loop** (`skills/loop` + `specclaw-loop`) wraps build→verify→review into
  an iterate-until-green cycle when `loop.enabled: true` (default). It
  doesn't replace build/verify — build still produces the first
  implementation, verify still writes the reports; the loop just
  automates the "read the FAIL, fix it, re-verify" cycle a human would
  otherwise do by hand, with hard caps (iteration/no-progress/regression/
  oscillation) enforced in the controller script, not in prompt text.
- **Context** (`.specclaw/context.md`) is rewritten once per merged change,
  at the tail of `pr`/`pr-azdo`, and is read at the top of `plan`/`build`/
  `verify` — it's the one piece of state that survives *across* changes
  rather than living inside a single change's directory.

---

## 6. Extension Points — Adding a New Command

### The general recipe (inferred from all 19 existing skills)

1. **`skills/<verb>/SKILL.md`** — YAML frontmatter with a `description:`
   written for the model-router (this is what makes `/specclaw:<verb>`
   auto-invoke on the right phrasing — see `propose`'s deliberately
   aggressive description as the strongest example). Add
   `disable-model-invocation: true` only if the command needs a real TTY or
   handles secrets, per `auth-azdo`/`auth-jira`. Body: start with the
   `specclaw-ensure-init .specclaw` boilerplate line every skill opens
   with, then numbered steps that shell out to `bin/specclaw-*` and/or
   spawn `Agent` calls, referencing `$CLAUDE_PLUGIN_ROOT/templates/*.md`
   for any file the agent should generate from a scaffold.

2. **`bin/specclaw-<verb>`** (only if the command needs deterministic
   parsing/state-mutation logic bash can own outright) — `#!/usr/bin/env
   bash`, `set -euo pipefail`, a self-contained `yaml_val()` (copy from any
   sibling script — there's no shared lib), subcommand dispatch via `case
   "$1" in`, hand-built JSON via `json_str`/`json_bool` helpers with a
   grep/awk fallback whenever `jq` is used, a `-h|--help` usage block. If
   the command's true logic is "have an LLM read some facts and write
   prose," keep the script to fact-collection only (mirror
   `specclaw-verify collect` or `specclaw-build-context`'s shape: gather
   deterministic data in bash, hand it to an `Agent` call for the
   judgment/writing part).

3. **`templates/<artifact>.md`** — only if the command produces a new
   Markdown artifact type, with `{{placeholder}}` tokens the skill or an
   agent fills in. Consider whether it needs a row in
   `templates/status.md`/`STATUS-dashboard.md` to surface on the dashboard.

4. **`agents/<name>.md`** — only if the command needs a dedicated,
   reusable persona with its own rubric (like `code-reviewer`'s 10 fixed
   dimensions) rather than an ad hoc one-off `Agent` prompt written inline
   in the skill. Frontmatter: `name`, `description`, `tools: [...]`,
   `model:`. No registration step — `agents/*.md` is auto-discovered the
   same way `skills/*/SKILL.md` is.

5. **`references/agent-prompts.md`** — only if a bin script needs to
   extract a live prompt template at runtime (the `## Verify Agent`
   pattern). Otherwise keep the prompt inline in the skill or the agent
   file; don't add to this file just for documentation's sake (that's what
   `build-engine.md`/`workflow-examples.md` are for).

6. **Decide if it's a lifecycle phase or a side-command.** `propose` /
   `plan` / `build` / `verify` / `pr` gate on each other via
   `specclaw-validate-change` (add a new `case` arm there if your command
   needs a prerequisite check). `learn` / `patterns` / `status` / `context`
   don't gate anything — they're read/append utilities callable any time.
   A read-only analysis command belongs in the second category.

7. **Bump the plugin version** (`plugin.json` + `marketplace.json`, per
   this repo's own `CLAUDE.md` rule) and add a row to the root
   `README.md`'s Commands table.

8. **If you added real parsing logic**, add cases to
   `tests/run-parser-tests.sh` — the only test harness in the repo, plain
   bash assertions against fixtures in `tests/fixtures/`. There's no other
   CI-enforced correctness net over the bash scripts.

### Where a legacy-codebase analyzer slots in

This is a **read-only, whole-repo analysis** capability, not a code-mutating
lifecycle phase — so it maps most naturally onto the "side-command" pattern
(`patterns`, `status`), not a new link in propose→plan→build→verify→pr. It
shouldn't need a `specclaw-validate-change` case arm at all.

Concretely:

- **New skill:** `skills/analyze/SKILL.md` → `/specclaw:analyze [path]`,
  with a model-invokable description ("analyze a codebase's structure,
  dependencies, and tech stack..."). No `disable-model-invocation` needed —
  it's read-only.

- **Reuse, don't reinvent, the discovery machinery that already exists:**
  `specclaw-discover-context` already does exactly the "structure" half of
  this job — `git ls-files`-based enumeration, ranking, filtering, and a
  budget-capped digest of every doc in the repo. And `/specclaw:plan`
  Step 3 already sketches the "tech stack" half inline in its own skill
  text (a "Codebase survey" step: top-two-level directory summary via
  `git ls-files | cut -d/ -f1-2 | sort -u`, manifest detection —
  `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`, `*.csproj`,
  `pom.xml`, `Makefile` — and where tests live). That survey has never been
  promoted to a standalone, reusable script; a new
  `bin/specclaw-analyze-codebase` is the natural place to do that, and
  `/specclaw:plan` could then call it (or read a cached report) instead of
  re-deriving the same survey inline every time it plans a change.

- **Bin script shape:** follow `specclaw-build-context`'s pattern —
  deterministic fact-collection in bash (file tree, manifest contents, LOC
  per language, dependency lists parsed straight out of the manifests,
  the existing `discover-context emit` digest), emitted as one structured
  payload to stdout. Don't try to make bash *interpret* the architecture —
  that's the agent's job.

- **Output artifact:** since this describes the whole repo rather than one
  change, it belongs at the project level next to `context.md` and
  `patterns.md` — e.g. `.specclaw/codebase-report.md` — not inside a single
  `changes/<name>/` directory. Add `templates/codebase-report.md` as its
  scaffold (sections like Architecture Overview, Dependencies, Tech Stack,
  Notable Risks/Debt — deliberately overlapping `templates/context.md`'s
  shape, since both describe "what this codebase is").

- **Agent step:** the skill spawns a plain `Agent` call with the collected
  payload and a prompt asking for the structural/dependency/tech-stack
  writeup — a dedicated `agents/codebase-analyst.md` persona (mirroring
  `code-reviewer.md`'s fixed-rubric style: e.g. a fixed checklist of
  "Architecture / Dependencies / Tech Stack / Risk Areas / Suggested First
  Changes") is worth the extra file if you want consistent output shape
  across runs; a one-off inline prompt in the skill is enough for a first
  cut.

- **Integration payoff:** once `.specclaw/codebase-report.md` exists,
  `specclaw-build-context` and `specclaw-verify-context` could pick it up
  the same way they already pick up `context.md` and the
  `discover-context` digest — one more section in an already-established
  "these context blocks get appended to every agent payload" pipeline,
  rather than a new integration point.
