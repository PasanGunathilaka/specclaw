# Rebuild Backlog: {{title}}

**Path analyzed:** {{path}}
**Date generated:** {{date}}
**Source documents:** codebase-report.md, architecture.md, domain-model.md, functional-spec.md, module-map.md

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder
  token inside this comment's own prose (not even to describe it) — the
  render step's template substitution is a dumb global string replace, and
  a token mentioned here would get overwritten by that token's rendered
  value along with the real placeholder below, corrupting this comment.
  Refer to placeholders by section name instead (e.g. "the status block
  below", "the Backlog section").

  The status block right after this comment is bash-computed, never
  agent-drafted — date, which optional inputs (decisions.md,
  clarifications.md, baseline/manifest.json, baseline/scenarios.md) were
  consumed vs. missing (with the command that produces each),
  Gate/Verification counts, and the single recommended next item to
  propose. This block, and every item's Gate:/Verification: field below,
  is recomputed from scratch on every run — never hand-maintained.

  MODULE GROUPING. The Backlog section below is two levels deep: one
  "## MOD-### — <Module Name>" heading per module from module-map.md, with
  that module's "### BL-0##" items beneath it. Modules are ordered by their
  own dependency rank from the map (foundations first), computed in bash by
  the same fixed-point pass that ranks items; a declared cycle is reported
  and no rank number is printed, because the number would be an artifact of
  the iteration cap rather than a dependency depth.

  A module is a MIGRATION/ACCEPTANCE unit — the "one flow at a time" slice a
  large legacy system is rebuilt and signed off in. BL items remain the
  BUILD units: the hierarchy is MOD-### -> BL-0## -> DR-### -> GM-###, and a
  module is NEVER collapsed into one giant BL item. Item granularity rules
  are exactly as they were — a module only groups items that already exist
  at capability-bullet granularity.

  Item order WITHIN a module is unchanged from before modules existed
  (dependency rank first — a hard constraint — then within the same rank:
  CLEAR+VERIFIABLE, then CLEAR+PENDING CAPTURE/NO BASELINE DATA/
  UNVERIFIABLE, then OPEN QUESTIONS, then BLOCKED). Two further top-level
  groups may appear after the modules: "## Unassigned — no module declared"
  (items with no **Module:** field, or one naming a MOD-### the map does not
  define — never folded into a real module by guesswork) and "## Struck"
  (tombstones, which belong to no module).

  Expected per-item sub-structure inside each module group — one entry per
  backlog item:

  ### BL-NNN — <Feature Title>

  **Module:** <the MOD-### from module-map.md this item belongs to. Declared
    by the planner agent, read mechanically by bash, and NEVER derived from
    the item's DR-### rules — deriving one would be a silent assignment, and
    a disagreement between this field and the map's own rule ownership is
    exactly what /specclaw:bf-baseline record reports as a WARN at record
    time. An item with no such field is rendered under "## Unassigned",
    never guessed into a module.>
  **Maps to capability:** <functional-spec.md capability name/quote. DESCRIPTIVE
    METADATA, never part of the acceptance basis: it is skipped entirely when
    the basis is computed, so a CAP-### written here selects nothing. Cite the
    id in the Acceptance basis field below if this item is to be accepted on
    that capability. The two are kept separate deliberately — counting this
    field as basis would give every item an acceptance criterion nobody
    authored, and then require a NOT-REPLAYABLE classification for it before
    the item could ever pass with zero fixtures.>
  **Depends on:** <earlier items' BL-NNN IDs, or "None">
  **Acceptance basis (domain-model.md, functional-spec.md):**
  - <entity/business-rule/enumeration reference, quoted — cite a business
    rule's DR-NNN ID (from domain-model.md) directly wherever the
    acceptance basis rests on a numbered rule, e.g. "DR-007: ..."; this is
    the join key /specclaw:bf-clarify and /specclaw:bf-baseline key their own
    CQ-NNN/GM-NNN citations against, so the ID itself must be textually
    present, not just implied by the quoted prose>
  - <AND cite a CAP-NNN ID (from functional-spec.md) wherever the basis rests
    on a capability rather than a numbered rule — a form's field set, a
    composite flow, a default. The basis is the UNION of the two families,
    and this field is the ONLY place either is read from: "Maps to
    capability:" above is skipped, and so are Gate:/Verification:/UI
    fidelity:/status notes. An item whose behaviour is a form and a
    persistence write cites only CAP-NNN ids here, and that is a complete
    and acceptable basis — before capabilities were citable, such an item
    could never be mechanically accepted at all.>

  **Verification inputs needed:**
  - <golden-master capture, external-format/DLL/COM semantics, or other
    human-supplied input this item's fidelity check will need — never
    leave this field blank; if genuinely nothing beyond the acceptance
    criteria above applies, say so explicitly rather than omitting it>

  **Gate:** <bash-computed: BLOCKED — blocked by <CQ-NNN + one-line title,
    ...> | OPEN QUESTIONS — risk from unanswered, non-blocking: <CQ-NNN,
    ...> | CLEAR>
  **Verification:** <bash-computed: VERIFIABLE — fixtures: <GM-NNN (legacy
    commit sha), ...> | PENDING CAPTURE — scenarios designed, no recorded
    fixture yet: <GM-NNN, ...> | UNVERIFIABLE — acceptance must come from a
    stakeholder decision, not fixture comparison (see CQ-NNN) | NO BASELINE
    DATA — baseline not run (or not designed) for these rules>
  **UI fidelity:** <bash-computed, and present ONLY when this item renders a
    screen AND the UI fidelity policy (SQ-013, read mechanically from
    decisions.md) is decided FAITHFUL/THEME-ONLY or is undecided. Renders as:
    FAITHFUL — reproduce the layout structure and token values of: <SCR-###,
    ...>; token groups: <TK-###, ...> | THEME-ONLY — reproduce the token
    values of: <TK-###, ...>; screens for reference only: <SCR-###, ...> |
    ⚠ UI GROUNDING MISSING — <the decided policy, plus which .specclaw/ui/
    artifacts are absent, or the fact that this item cites no SCR-### at all>
    | UNDECIDED — <SQ-013 has no recorded decision>. The last two also
    contribute an OPEN QUESTIONS state to the Gate line above, naming SQ-013.
    Under a decided REINTERPRET policy this field never appears on any item
    and no warning is emitted anywhere — the zero-extra-work path for a
    project that does not need visual fidelity. Which items render a screen
    is the planner agent's judgment, delivered as a SCREEN-BEARING: directive
    and applied mechanically here; SCR-###/TK-### content itself belongs to
    /specclaw:bf-ui, never to this document. A cited SCR-### never implies
    visual equivalence has been proven — that is established by a named human
    signing ui-review.md against recorded screenshots, never by this backlog
    and never by fixture replay.>
  **Settled constraints (from decisions):** <optional — only present when a
    mechanical-adopt decision applies to this item; omit the field entirely
    otherwise, never render it empty>

  **Status notes (human-added):** <optional — anything a human types under
    this exact heading (e.g. "built and merged, PR #12") survives every
    future /specclaw:bf-rebuild-plan --refresh verbatim, byte for byte. Nothing
    else in this document offers that guarantee — this is the one place a
    human note is safe to leave.>

  If two or more functional-spec capabilities are merged into a single
  backlog item, the item must state why in a "Merge rationale:" line —
  merging is a judgment call, never silent. A revised item (its acceptance
  basis rewritten because a decision changed its shape) states so inline,
  e.g. a line reading "⟲ revised per CQ-005, 2026-08-01" placed right after
  the heading.

  PROVISIONAL marker: an item touched by an open pending question — either
  a direct DR-NNN/BL-NNN join to a CQ-NNN promoted from a PQ-NNN (bash-
  computed), or a prose-level match the planner agent found and directed
  via a PROVISIONAL: line (agent-judged, mechanically re-verified by bash
  the same way an UNVERIFIABLE: directive is) — carries its own line right
  after the heading: "⚠ PROVISIONAL — pending PQ-NNN/CQ-NNN (proposed
  default: <x>)". This is soft-block: the item is still fully drafted,
  sequenced, and gated/verified exactly as any other; the marker rides
  alongside Gate/Verification, not instead of them, and both this line and
  Gate/Verification are recomputed from scratch on every run — it clears
  automatically once decisions.md answers the underlying question, no
  manual cleanup.

  STUB-BACKED marker: an item built against a dependency-bypass stub (see
  templates/CONTRACT.md (m) and .specclaw/analysis/module-stubs.md) carries
  its own line right after the heading, alongside any PROVISIONAL marker:
  "⚠ STUB-BACKED — built against ST-001 (stub-interface, faking BL-014
  (MOD-005)). Any replay verdict for this item says so until the stub is
  retired."

  It is deliberately NOT folded into the Verification: line. Verification
  answers "is there a fixture for this?"; taint answers "was the thing under
  test real?" — orthogonal axes, and collapsing them would let a
  VERIFIABLE item read as fully proven when part of what it was checked
  against was a placeholder. Like PROVISIONAL, it is recomputed from the
  registry on every run and never persisted, so retiring a stub clears every
  consuming item's marker automatically with no manual cleanup.

  A stub is only ever created by a human choosing one at /specclaw:propose
  time. Nothing in this document creates, edits, or retires one.

  QUALITY REMEDIATION ITEMS. When /specclaw:bf-quality has measured the legacy
  tree, each module with at least one open hotspot at or above the configured
  severity floor also carries ONE bash-written item — never one per hotspot —
  headed "### BL-NNN — MOD-### quality remediation" and declaring
  "**Item type:** QUALITY-REMEDIATION". Absent that measurement the whole
  mechanism is inert and this document is exactly what it would have been
  before the mechanism existed, down to the byte.

  ONE PER MODULE. A large legacy tree registers hundreds of QI-###; an item
  each would bury the functional backlog. The module is already the migration
  and acceptance unit here, and it is also the finest grain the target-side
  measurement can be taken at.

  ITS ACCEPTANCE IS A MEASUREMENT, NEVER A LITERAL INSTRUCTION. The item's
  criterion is that the REBUILT module measures within the thresholds in
  config.yaml's `quality:` section and regresses on no dimension, evidenced by
  .specclaw/analysis/quality-delta.json (from /specclaw:bf-quality --target
  followed by --compare). It never asks anyone to change a named legacy source
  file: that file is not part of the target and will not exist there. The
  QI-### ids it lists are the evidence for WHY the item exists; the delta is
  the proof that it is done.

  A hotspot counts as retired at the grain the delta can actually carry —
  module × metric. A hotspot's identity names a legacy file and function, and
  neither survives into the rebuilt tree to be measured a second time, so a
  per-hotspot claim of retirement would be a claim nothing could check.

  ITS OWN VERIFICATION CHANNEL. "**Verification:** QUALITY-MEASURED" is a fifth
  value alongside VERIFIABLE / PENDING CAPTURE / UNVERIFIABLE / NO BASELINE
  DATA, and it is not one of them: those four all answer "is there a recorded
  legacy output to compare against?", and here that question does not apply.
  The item cites no DR-### and maps to no GM-###. /specclaw:bf-replay --item on
  one refuses cleanly, names the item type, and points at
  /specclaw:bf-quality --compare — it never reports NO BASELINE DATA, which
  would read as "somebody forgot to record a fixture".

  ITS OWN COMPLETION AXIS. "**Quality state:** BLOCKED | OPEN | DONE" is
  bash-computed from the delta and is a THIRD question, not a restatement of
  the two fields above it: Gate answers "can this start?", Verification "how
  would it ever be checked?", and this one "has it been checked, and did it
  pass?". It is recomputed every run, so it clears by regeneration alone.

  MECHANICALLY GATED BEHIND ITS OWN MODULE. A remediation item is BLOCKED
  until every functional item in its module carries a declared "BUILT:" line in
  its Status-notes block — the same narrow declared trigger stub retirement and
  item splits use, never a prose reading. You cannot measure the health of code
  that does not exist yet.

  WHAT PERSISTS. The body is regenerated in full on every run, so the ONE thing
  that could not be recomputed is kept: a dated "⊕ Added"/"⊖ Retired" ledger
  recording hotspots that appeared or stopped qualifying after the item was
  created. A re-measured quality.json APPENDS a new hotspot to the module's
  existing item and never creates a second one. Human Status notes survive
  verbatim, exactly as on every other item.

  A hotspot BELOW the severity floor generates no item. It is reported as an
  advisory count on its module's line in the Module Coverage Rollup below, so
  it stays visible without becoming something the rebuild must clear.

  THE LEVER FOR "WE ACCEPT THIS DEBT" IS THE FLOOR, NOT A STRIKE. Deferring a
  remediation item works normally and holds its id forever, like any other item.
  STRIKING one does not stick: a tombstone keeps only the id and the reason, so
  the module it belonged to is no longer recoverable from the document, and the
  next --refresh sees a measured module with no item and generates one (once —
  the new item is then permanent like any other). If a module's measured state
  is genuinely acceptable, raise `quality.remediation_severity_floor` or resolve
  the hotspots at source; both are re-measured facts rather than an edit to a
  generated document.

  BL-NNN IDs are permanent identifiers, not position — assigned once in
  dependency order on the first-ever run and never renumbered afterward.
  A later /specclaw:bf-rebuild-plan --refresh may append a genuinely new item
  (next free BL-NNN, dependency-placed correctly) or strike/defer an
  existing one, but an already-assigned ID is never reused, renumbered, or
  silently deleted — a struck item stays in the Backlog section as a
  one-line tombstone ("### BL-NNN — STRUCK — <reason>, <date>"); a deferred
  item moves in full to the Deferred section, out of the ready ordering.
  "Depends on:" always cites BL-NNN IDs, never bare position, for exactly
  this reason.
-->

{{status_header}}

## Backlog

{{backlog_items}}

## Deferred

{{deferred_items}}

## Sequencing Rationale

{{sequencing_rationale}}

## Coverage Check

<!--
  Capability-bullet coverage, authored by the planner agent (bash never
  writes prose it cannot verify against the source documents) and carried
  by bash: this run's draft wins, otherwise the prior file's section is
  preserved verbatim, otherwise a line saying plainly that it is absent.

  Each bullet is accounted for on its own line, in this countable form so
  that the per-module rollup below can be computed mechanically rather than
  asserted:

    - **MOD-002** — "<capability bullet, quoted>" -> BL-014
    - **MOD-002** — "<capability bullet, quoted>" -> EXCLUDED: <reason>
    - **MOD-002** — "<capability bullet, quoted>" -> ORPHAN

  Granularity is unchanged — this is still one line per individual
  capability bullet (and per distinct clause of a compound bullet), never
  one line per module. The "### Module Coverage Rollup" subsection is
  bash-computed by counting these lines per module and is re-derived from
  scratch every run; a prior run's copy is dropped before the new one is
  appended, exactly as the UI Screen Coverage subsection is. When no line
  matches the countable form, the rollup says it is not computable rather
  than reporting 0/0 — which would read as "nothing to cover."

  Under a --module scoped run, only the scoped module's lines are replaced;
  every other module's accounting is preserved by line-level surgery.
-->

{{coverage_check}}

## Stub Retirement

<!--
  Bash-computed every run from .specclaw/analysis/module-stubs.md, never
  agent-narrated. For every ACTIVE or RETIRING dependency-bypass stub
  (templates/CONTRACT.md (m)): is the thing it substitutes built yet, and if
  so, exactly what does it take to retire it?

  THE TRIGGER IS A DECLARED SIGNAL, NOT PROSE. A stub becomes "ready to
  retire" only when the item it substitutes carries a line beginning "BUILT:"
  inside its own "**Status notes (human-added):**" block — e.g.
  "BUILT: PR #42, merged 2026-08-10". Free text is not parsed: specclaw
  records no built state of its own, and reading "done last week" as a
  completion signal would be exactly the guess the bypass mechanism exists
  to prevent. When a stub substitutes a whole MOD-###, EVERY active item of
  that module must carry the signal — a module is not built because one of
  its items is.

  WHO DOES WHAT. Retirement is a human/Claude handoff, and each step below
  names its actor. In short: a human decides the stub is gone and removes
  the code; Claude re-runs the replays and, only on a clean run, flips the
  registry entry to RETIRED citing that run id; a human decides what to do
  with a FAIL. Claude never removes stub code on its own initiative and
  never retires an entry on an unclean run.

  The three-state flow (ACTIVE -> RETIRING -> RETIRED) exists because with
  only two states the run that PROVES a stub is gone is itself stamped
  tainted, and flipping to RETIRED first leaves a failing re-replay falsely
  marked retired. See CONTRACT.md (m.4).

  This section changes no Gate, no Verification, and no ordering. It is a
  work list.
-->

{{stub_retirement}}

## Item Splits

<!--
  Bash-computed every run from .specclaw/analysis/item-splits.md, never
  agent-narrated (templates/CONTRACT.md (o)). Which backlog items are
  PARTIALLY BUILT, what each is still missing, and — once every blocked-until
  item carries a declared "BUILT:" note — the exact steps to resume.

  A SPLIT IS NOT A STUB. Nothing was faked, so nothing is tainted and there is
  nothing to retire. What a split puts in question is whether the ITEM IS
  FINISHED, which is why it gets its own section rather than a row in Stub
  Retirement.

  THE SAME DECLARED TRIGGER as stub retirement: an entry becomes
  READY-TO-RESUME only when every id in its "Blocked until" list carries a
  literal "BUILT:" line in that item's own Status-notes block. Prose is never
  parsed. Unlike stub retirement, that transition is WRITTEN by bash here (a
  single Status-line rewrite, one direction only) — it is a pure function of
  declared data, so there is no human judgement to defer to, and a stale
  ACTIVE would be indistinguishable from "nobody got round to it".

  COMPLETE is a handoff, not a computation: it needs a clean
  /specclaw:bf-replay --item BL-### run to cite, and split-update refuses it
  straight from ACTIVE.

  This section changes no Gate, no Verification, and no ordering. It is a
  work list.
-->

{{item_splits}}

## Change Report

<!--
  Populated only by /specclaw:bf-rebuild-plan --refresh — bash-computed by
  diffing this run's fresh Gate/Verification against the prior file's own
  stored Gate:/Verification: lines, never agent-narrated. On a first-ever
  run this section reads "Not applicable."
-->

{{change_report}}
