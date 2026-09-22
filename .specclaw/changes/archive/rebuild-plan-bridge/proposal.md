# Proposal: Connect the analysis layer to the delivery lifecycle (rebuild-plan-bridge)

**Created:** 2026-07-24
**Status:** 🟡 Draft

## Problem

`analyze`, `architecture`, and `domain` are three read-only side-commands that
write `.specclaw/analysis/{codebase-report,architecture,domain-model,
functional-spec}.md` — a static understanding of an existing (possibly
legacy) codebase: tech stack, C4 architecture, business entities/rules, and
user-facing capabilities/workflows.

None of this currently reaches the delivery lifecycle. `propose`, `plan`,
`build`, and `verify` have no path to this understanding today:
- `propose` never reads `context.md` or any discovered docs at all (confirmed
  by reading `skills/propose/SKILL.md`) — it's a pure drafting step.
- `plan`/`build`/`verify` read `.specclaw/context.md` directly and pull a
  budget-capped digest from `specclaw-discover-context`, but that script's
  default directory-exclusion list (`DEFAULT_EXCLUDE_DIRS=".specclaw
  node_modules vendor dist build archive deprecated i18n .git"`) excludes
  `.specclaw/` outright — so `.specclaw/analysis/*.md` is invisible to
  discovery today, pinned or not... *unless* pinned (see below).

Practically, this means: rebuilding a legacy app as a faithful
re-implementation currently requires the operator to manually paste analysis
content into every `propose`/`plan` conversation, and there is no ordered list
of what to propose — "rebuild the exact same app" is not one change, it's an
unknown number of undiscovered ones.

## Proposed Solution

Two additive mechanisms, evaluated separately, recommended together (**A + B**).

### Confirmed: existing lifecycle is unchanged

Per `docs/specclaw-architecture-notes.md` §6 ("Where a legacy-codebase
analyzer slots in") and direct inspection of `specclaw-discover-context`,
`specclaw-build-context`, and `specclaw-verify-context`: the grounding pipe
(`context.md` + discovered-docs digest) that `plan`/`build`/`verify` already
consume is generic — it doesn't know or care *what* doc it's showing an
agent. Making `.specclaw/analysis/*.md` visible to it is a **config and
docs change only**. No line of `skills/propose`, `skills/plan`,
`skills/build`, `skills/verify`, `skills/pr`, their `bin/specclaw-*`
scripts, or their `agents/*.md` needs to change.

Files this change touches:
- `.specclaw/config.yaml` (this repo's own, or any host project's) —
  `context.pin` list, optionally `context.max_lines`. **Config, not code.**
- New, additive-only: `skills/rebuild-plan/SKILL.md`, a small
  `bin/specclaw-rebuild-collect` fact-collector, `templates/rebuild-backlog.md`,
  `agents/rebuild-planner.md`.
- `plugin.json` + `marketplace.json` version bump, root `README.md` commands
  table row (mechanical, per this repo's own version-bump rule).
- A short new doc section (proposed: append to
  `docs/specclaw-architecture-notes.md` or a new `docs/rebuild-workflow.md`)
  documenting the operational steps below — no behavioral doc changes to the
  five lifecycle skills.

Nothing under `skills/propose/`, `skills/plan/`, `skills/build/`,
`skills/verify/`, `skills/pr/`, or their scripts/agents is modified.

### Option A — Grounding only (pin, no new command)

Use the mechanism SpecClaw already has: `context.pin` in `config.yaml`.

```yaml
context:
  pin:
    - .specclaw/analysis/codebase-report.md
    - .specclaw/analysis/architecture.md
    - .specclaw/analysis/domain-model.md
    - .specclaw/analysis/functional-spec.md
  max_lines: 8000   # raise from the 3000 default — see caveat below
```

**Why this works, precisely:** in `specclaw-discover-context`, the pin check
(`is_pinned`) runs *before* `config_excluded`/`default_dir_excluded`/
`outside_folders` — a pinned path bypasses the `.specclaw` directory
exclusion and is force-ranked `0` (highest priority, emitted first). That
digest is what `/specclaw:plan` Step 3 reads via `discover-context list`/
`emit`, and what `specclaw-build-context` / `specclaw-verify-context` both
already inject as "Discovered Project Docs" into every coding- and
verify-agent payload. No script change needed — this is exactly the
"Integration payoff" §6 already anticipates.

**Two caveats to spell out, not paper over:**

1. **Git-tracking requirement.** `discover-context` enumerates via
   `git ls-files -- '*.md' ...` against the project root — it does not walk
   the filesystem when in a git repo. A pinned file that was only *written*
   by `analyze`/`architecture`/`domain` but never `git add`-ed is invisible
   to discovery regardless of the pin. Operationally: after running the
   three analysis commands, `git add .specclaw/analysis/*.md` (stage is
   enough — doesn't need to be committed) before `plan`/`build`/`verify`.
2. **Shared budget.** All four docs are pinned rank-0 and emitted *first*
   within `context.max_lines` (default 3000) — at typical sizes (a
   multi-hundred-line functional spec + domain model is plausible for a
   real legacy app) they alone could consume the whole budget, silently
   crowding out README/CLAUDE.md/docs discovery for that same call. Raise
   `max_lines` accordingly (the script never drops silently — it names
   every dropped/truncated file in a footer comment — but "correct, not
   silent" isn't the same as "not lossy"). Recommend starting around 8000
   and adjusting from what the footer reports.

**Explicitly NOT recommended:** seeding `.specclaw/context.md` from the
analysis docs instead of/as well as pinning. `context.md` is a *curated,
rewritten-per-merge* doc (`specclaw-update-context` regenerates it from
`proposal.md`/`design.md`/`verify-report.md` after every merged change —
"not an append log," per `plugins/specclaw/CLAUDE.md`). Dumping structured
entity/rule/capability tables into it both breaks its intended shape and
risks silent erosion: the next PR's automatic rewrite has no reason to
preserve content it didn't put there. Pin is the mechanism actually meant
for durable reference docs; `context.md` is for living project decisions.

**Known gap Option A does not close:** `propose` still doesn't read
anything — grounding starts at `plan`. That's not a regression (propose
reads nothing today either) but it means each `/specclaw:propose "<feature>"`
call is still just a drafted problem statement until `/specclaw:plan` pulls
the pinned docs in.

### Option B — `/specclaw:rebuild-plan` (additive bridge command)

A new read-only side-command, mirroring `analyze`/`architecture`/`domain`'s
own shape (`patterns`/`status` pattern — no `specclaw-validate-change` gate,
no `<change>` involved):

- **`skills/rebuild-plan/SKILL.md`** → `/specclaw:rebuild-plan`. Reads all
  four `.specclaw/analysis/*.md` files; if any is missing, tells the user
  exactly which analysis command to run first and stops (no partial
  backlog from partial input).
- **`bin/specclaw-rebuild-collect`** — deterministic fact collection only
  (mirrors `specclaw-analyze-codebase collect`'s shape): parses
  `functional-spec.md`'s Capabilities/Workflows sections into candidate
  feature units, cross-references `domain-model.md`'s Entities/Business
  Rules/Enumerations against each candidate, and pulls `architecture.md`'s
  dependency graph to infer a rough build order (leaf components before
  the things that depend on them). Emits one JSON payload to stdout — no
  interpretation happens in bash.
- **`agents/rebuild-planner.md`** — takes that payload and writes
  `.specclaw/analysis/rebuild-backlog.md` from a new
  `templates/rebuild-backlog.md`: an ordered list, each entry naming the
  functional-spec capability it covers, the domain rules/entities that are
  its acceptance basis, its dependencies on earlier entries, and an
  explicit **"Verification inputs needed"** field (see Fidelity
  requirement below) — never left blank; defaults to naming what a human
  must still supply if nothing else applies.
- Creates **nothing** in `changes/`, calls **no** lifecycle command. The
  operator still runs `/specclaw:propose "<item>"` themselves for each
  backlog entry, same as today.

**Why B is needed, not just A:** "rebuild the same app" is a decomposition
problem, not a context problem — pin makes each feature's `plan` well
grounded, it doesn't tell you what the features *are* or what order to
build them in. Nothing in the pin/discovery mechanism can produce an
ordered backlog; that requires synthesis across all four docs, which is
exactly what a dedicated read-only agent step is for.

### Recommendation

**A + B.** They compose exactly as framed in the ask: B produces the
ordered backlog once (or re-run after re-analyzing), A ensures every item
proposed off that backlog is grounded when it reaches `plan`/`build`/
`verify`. A alone leaves "what are the features" unanswered; B alone leaves
every proposed feature under-grounded once `plan` starts writing spec/design
from scratch. Build both in this same change — B's design already assumes
A's pin config exists so the backlog-generation agent itself is grounded in
the same pinned docs, not a fifth ad hoc context path.

## Fidelity requirement — explicit limitation, not a promise

This connection carries the functional spec's capabilities and the domain
model's rules through as the **acceptance basis** for each rebuilt feature —
that's what pinning + the backlog's per-item rule/entity references gives
you. It does **not**, and cannot, give you proof that the new
implementation behaves identically to the old one. True "same app"
verification additionally needs:

- **Golden-master outputs** — recorded input/output pairs from the running
  legacy system, captured by a human, to diff the new implementation
  against. Static analysis of source code cannot produce these; nothing
  in `analyze`/`architecture`/`domain`/`rebuild-plan` claims to.
- **External-format and DLL/COM semantics** — where the legacy app depends
  on an external file format, a proprietary/undocumented DLL, or COM
  component whose behavior isn't fully recoverable from static analysis
  (e.g. `.dfm`/`.xaml` parsing gets you the declared UI shape, not runtime
  behavior of an opaque control), a human with domain knowledge of that
  dependency must supply the semantics.

`rebuild-backlog.md`'s "Verification inputs needed" field exists specifically
to surface these gaps per-item rather than let the plan imply they're
already covered. Neither this proposal nor its build should claim otherwise.

## Scope

### In Scope
- `context.pin` (+ `context.max_lines` guidance) wiring for
  `.specclaw/analysis/*.md`, documented as an operational recipe.
- New skill `skills/rebuild-plan/SKILL.md`, bin script
  `bin/specclaw-rebuild-collect`, template `templates/rebuild-backlog.md`,
  agent `agents/rebuild-planner.md`.
- `rebuild-backlog.md` output: ordered feature list, functional-spec/
  domain-model cross-references, dependency ordering, per-item
  verification-inputs-needed callouts.
- Doc note (README/architecture-notes/new doc) covering the `git add`
  requirement and the pin/budget recipe.
- Version bump (`plugin.json` + `marketplace.json`) and README commands
  table row, per this repo's standing rule.

### Out of Scope
- Any edit to `skills/propose`, `skills/plan`, `skills/build`,
  `skills/verify`, `skills/pr`, their `bin/specclaw-*` scripts, or their
  `agents/*.md`.
- Any change to `specclaw-validate-change` (rebuild-plan needs no gate —
  confirmed per §6, it's a side-command).
- Actually running `/specclaw:propose` for backlog items — `rebuild-plan`
  only writes the backlog; the operator drives propose themselves per item.
- Golden-master capture tooling, DLL/format reverse-engineering, or any
  other human-supplied verification input named above — explicitly not
  synthesizable by this feature.

## Impact

- **Files affected:** ~7 new files (skill, bin script, template, agent,
  doc note, version bump ×2, README row); 0 existing lifecycle files
  modified. (estimated)
- **Complexity:** medium (small) — the new command mirrors an established
  pattern (`analyze`/`architecture`/`domain`) exactly; the pin config is a
  few lines.
- **Risk:** low — nothing existing is touched; worst case if the pin
  budget is misjudged is a verbose/truncated discovery digest, never a
  broken lifecycle phase (discover-context always degrades gracefully and
  names every drop).

## Open Questions

1. **Where should the doc note live?** Append to
   `docs/specclaw-architecture-notes.md` (extends the existing §6
   analysis) vs. a new standalone `docs/rebuild-workflow.md`. Leaning
   toward a new doc since it's an operator recipe, not architecture
   documentation — but no strong opinion either way.
2. **Default `context.max_lines` guidance** — should the doc recommend a
   fixed number (8000, as drafted above), or a formula tied to the actual
   line counts `specclaw analyze/architecture/domain` just produced
   (e.g. "set max_lines to pinned-doc-total + 3000")? The latter is more
   correct but harder to state simply in a doc.
3. **Should `rebuild-backlog.md` items map 1:1 to functional-spec
   Capabilities**, or can/should the planner agent merge trivially small
   capabilities into one backlog item to avoid over-decomposition (Rule 2,
   Simplicity First, applies here too)? Proposing: agent's judgment call,
   documented in the item's rationale, not a fixed 1:1 rule.
4. Should `rebuild-plan` support a `--focus <area>` argument to backlog
   only part of a large legacy app, or always produce the full backlog in
   one pass? Proposing: full backlog only for v1 — `--focus` can be a
   follow-up if the backlog turns out unwieldy in practice.

---

**To proceed:** Review this proposal and approve to begin planning.
