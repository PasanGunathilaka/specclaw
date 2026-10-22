# Pending Questions

<!--
  Ask-don't-guess buffer for the brownfield analysis pipeline. Any analysis
  agent (bf-domain-analyst, bf-architecture-analyst, bf-rebuild-planner,
  bf-baseline-designer) that would otherwise have to silently assume an
  answer — see the T1-T6 trigger list below — appends a PQ-### entry here
  instead of guessing. /specclaw-bf:bf-clarify ingests every OPEN entry,
  assigns it a real type (DECISION/DEFECT/SCOPE/TARGET-GAP) and a permanent
  CQ-###/SQ-###/UQ-### id, and rewrites that entry's Status line in place to
  PROMOTED → <that id>. clarifications.md/decisions.md remain the single
  source of truth for the question's content and its eventual answer — this
  file is only ever the handoff buffer between "an agent noticed something
  uncertain" and "a human got asked about it."

  APPEND-ONLY, LIKE clarifications.md's own source-of-truth invariant —
  NEVER archive-then-replace. An agent adding a new PQ must append it (e.g.
  via its own Bash tool: `cat >> .specclaw/analysis/pending-questions.md
  <<'PQEOF' ... PQEOF`) — never read the whole file and Write it back,
  which risks silently dropping another run's entry this agent never saw.
  The only in-place edit ever made to an existing entry is
  /specclaw-bf:bf-clarify rewriting its own Status line on promotion — nothing
  else in this file is ever rewritten, reordered, or deleted. PQ-### ids
  are permanent, exactly like DR-NNN/BL-NNN/GM-NNN/CQ-NNN — never
  renumbered or reused, even for a WITHDRAWN entry.

  GATING IS SOFT-BLOCK: an OPEN PQ never stops any command from running. It
  marks whatever it Blocks as PROVISIONAL — a labelled provisional default
  that flows downstream (a rebuild-backlog.md item, a baseline
  scenario/fixture, a replay verdict) until a human answers it under
  ## Decisions in decisions.md. See CONTRACT.md and each analysis agent's
  own instructions for the exact PROVISIONAL marker convention per
  artifact.

  Uncertainty triggers (exhaustive — an agent asks on these, and only
  these; anything else uncited is dropped or flagged as today, never
  asked):
    T1 — Field rendering/widget type not evidenced in code (input type,
         component, file-handling logic all absent or ambiguous).
    T2 — Code behaviour contradicts comments, docs, or naming.
    T3 — Multiple plausible interpretations of a business rule, or of a
         module grouping, with no test, usage site, data constraint, or
         dependency edge disambiguating them. (The module case: an entity,
         rule, service or screen two MOD-###s could each plausibly own, or
         two prior modules that match one proposed module equally well
         during MOD-ID reconciliation. /specclaw-bf:bf-clarify types these
         DECISION — an ownership fork — or SCOPE, when the real question is
         whether that module belongs in the rebuild at all.)
    T4 — Legacy behaviour that appears to be a defect (describe; clarify
         will type it DEFECT).
    T5 — A capability with no one-to-one mapping in the rebuild target
         (describe; clarify will type it TARGET-GAP).
    T6 — Ordering, formatting, or default-value behaviour that is
         observable to users but not pinned by any code path the agent
         can cite.

  Entry format:

  ### PQ-### — <one-line question>

  - **Status:** OPEN | PROMOTED → CQ-### | WITHDRAWN
  - **Source:** <command/agent that raised it>
  - **Trigger:** T1–T6
  - **Blocks:** <artifact item IDs: MOD-###, DR-###, BL-0##, GM-###, field
    path. Name every id the question actually blocks — for a contested
    module boundary that means BOTH candidate MOD-###s plus the item they
    are contesting, since a question naming only one of them reads as
    settled in that one's favour.>
  - **Evidence found:** <cited findings, file:line or quoted passage>
  - **Could not determine:** <the specific gap>
  - **Candidates considered:** <options>
  - **Proposed default (UNCONFIRMED):** <default + one-line reasoning>

  Every PQ needs a real Proposed default with reasoning — a PQ without one
  is malformed, not just incomplete. "No default is reasonable — needs a
  fresh human answer" is a valid one-line reasoning of last resort; leaving
  the field off entirely is not. Before appending a new PQ, check existing
  PQ entries here and CQ entries in clarifications.md (if present) for the
  same artifact item — if one already covers it, add a cross-reference to
  the existing id (e.g. "see PQ-002") in your own finding instead of
  drafting a duplicate.
-->
