# Item Splits: {{title}}

**Registry created:** {{date}}

<!--
  THE ITEM-SPLIT REGISTRY. One ### IS-### entry per explicit human decision to
  implement PART of a backlog item now and defer the rest until the items it
  depends on exist.

  ── WHY THIS IS NOT module-stubs.md ──────────────────────────────────────
  item-split is a dependency-bypass strategy, but it is fundamentally a
  different KIND of thing from the other three, and mixing them cost a real
  project a whole layer of a real feature.

    stub-interface / mock-data / feature-flag
      -> FAKE a dependency -> ST-### in module-stubs.md -> taint possible
      -> RETIRED when the real module lands

    item-split
      -> FAKES NOTHING; it defers real scope -> IS-### here
      -> NEVER taints (there is no unreal thing anything stood on)
      -> COMPLETE when the deferred scope is actually built

  A stub raises the question "was the thing under test real?". A split raises
  an entirely different question: "is this item even finished?". Those need
  different records, different states and different vocabulary — so the two
  registries are kept strictly separate, and `stub-append --strategy
  item-split` is refused, naming `split-append` instead.

  Entries recorded before this registry existed stay in module-stubs.md
  forever with Strategy: item-split. ST-### ids are permanent and entries are
  never deleted (CONTRACT.md (c)), so nothing migrates them. They are excluded
  from taint and from the retirement block, and /specclaw-bf:bf-rebuild-plan
  names them once with the manual step, rather than pretending a migration
  happened.

  ── APPEND / UPDATE-IN-PLACE — archive-then-replace does NOT apply ────────
  Exactly like module-stubs.md, pending-questions.md and clarifications.md,
  and unlike every generated analysis document in .specclaw/analysis/. No
  command ever archives, regenerates, or rewrites this file wholesale. New
  entries are APPENDED; an existing entry is only ever edited field by field.
  IS-### ids are permanent under CONTRACT.md (c) — never renumbered, never
  reused, never deleted. Reaching COMPLETE UPDATES an entry's Status; it never
  removes the entry.

  THE WHOLE POINT: choosing item-split must never make implementation history
  disappear. If specclaw deliberately splits a backlog item today, it must
  know exactly what was completed and what remains when that item is resumed
  weeks or months later.

  ── A SPLIT IS ALWAYS A HUMAN CHOICE, AND NEVER WIDER THAN THE ONE CHOSEN ─
  No agent ever appends an entry on its own judgment. /specclaw:propose
  DETECTS the unmet dependency, PRESENTS the strategies, and writes the entry
  the human picked — with their name in Chosen by.

  And the split the human chooses is the split that happens. Two mechanical
  guards enforce that:

    1. THE DR PARTITION. Rules implemented and Rules deferred must together
       account for EVERY DR-### in the item's own acceptance basis, with no
       overlap. An unaccounted rule is scope that quietly belongs to neither
       half — which is exactly how a split silently widens.

    2. LAYER-REMOVAL CONFIRMATION. If the split removes a whole layer, and in
       particular the UI layer from a SCREEN-BEARING item, split-append
       refuses unless "Layer removal confirmed by" names a human. A
       user-visible, screen-bearing backlog item must never become a
       backend-only implementation because nobody was asked.

  Prefer a VERTICAL slice — a thin end-to-end capability, UI through to
  persistence — over a horizontal stack cut. A horizontal cut is what produces
  an item that looks 80% done and delivers nothing a user can see.

  ── Entry format ─────────────────────────────────────────────────────────

  ### IS-### — <one line: which item was split, and what waits>

  - **Status:** ACTIVE | READY-TO-RESUME <YYYY-MM-DD> | COMPLETE <YYYY-MM-DD>, cleared by run <run_id>
  - **Item:** <BL-0## — the backlog item being split>
  - **Module:** <MOD-### — the item's own module>
  - **Reason:** <why the split was required at all>
  - **Unmet dependencies:** <BL-0##, ... — the dependencies that forced it>
  - **Implemented now:** <the scope shipping in this change, in the project's
    own language>
  - **Deferred:** <the scope explicitly NOT shipping. Everything not named
    here ships; everything named here waits. This field is the record that
    settles a later argument about what was agreed.>
  - **Rules implemented:** <DR-###, ... — the acceptance-basis rules the now
    slice covers>
  - **Rules deferred:** <DR-###, ... — the acceptance-basis rules the deferred
    scope covers. THE PARTITION: these two fields together must equal the
    item's own acceptance basis exactly, with no overlap and nothing left out.
    This is also what lets /specclaw-bf:bf-replay --item say WHICH of the item's
    fixtures cover built vs deferred scope, rather than an agent judging prose
    at read time.>
  - **Layers implemented:** <closed vocabulary: ui, api, domain, persistence,
    integration, auth-integration, reporting, background-jobs>
  - **Layers deferred:** <same vocabulary. A whole layer named here is a
    layer the item does not have yet.>
  - **Blocked until:** <BL-0## BUILT, ... — the conditions required before the
    deferred part can resume. Each id must carry a declared "BUILT:" line in
    its own Status-notes block before this entry can become READY-TO-RESUME.>
  - **Chosen by:** <human name>, <YYYY-MM-DD>
  - **Layer removal confirmed by:** <human name>, <YYYY-MM-DD — PRESENT ONLY
    when this split removes a whole layer. Omit the field entirely otherwise.>
  - **Change:** <change-name that implemented the now slice>
  - **Evidence:** <PR/merge evidence once available; "not yet merged" until
    then>
  - **Replay evidence:** <the /specclaw-bf:bf-replay --item run id covering the
    implemented slice; "not yet replayed" until then>
  - **Resumed by:** <change-name of the change that implements the deferred
    scope; blank until one exists>
  - **Completion:** <blank until COMPLETE. On completion: the date, the clean
    --item run id, and what was implemented to finish it.>

  ── STATE MODEL — three states, and who flips each ────────────────────────

    ACTIVE           — deferred scope exists and its Blocked-until items are
                       not all built. The item is NOT fully built, and
                       rebuild-backlog.md says so on its face.
    READY-TO-RESUME  — every Blocked-until item now carries a declared
                       "BUILT:" note. The deferred work can proceed.
    COMPLETE         — the deferred scope has been implemented and the FULL
                       item passed /specclaw-bf:bf-replay --item BL-### cleanly.

  WHO FLIPS WHAT, and why the split is where it is:

    -> ACTIVE            /specclaw:propose, from the human's choice
    ACTIVE -> READY-TO-RESUME
                         BASH, during /specclaw-bf:bf-rebuild-plan --refresh.
                         Never agent-asserted — same trust model as ST-###
                         taint. This transition is a PURE FUNCTION of declared
                         data (the Blocked-until ids x their BUILT: notes), so
                         there is no human judgement to defer to, and leaving
                         it to a manual flip would make a stale ACTIVE
                         indistinguishable from "nobody got round to it".
                         Only the Status line is rewritten, one direction only,
                         never back — the same surgical single-line rewrite
                         /specclaw-bf:bf-clarify already performs on a promoted
                         pending question.
    READY-TO-RESUME -> COMPLETE
                         CLAUDE, and ONLY on a clean --item run, citing that
                         run id. This one is a handoff rather than a
                         computation because it requires an act in the world
                         (the deferred work actually being built and proven),
                         exactly like flipping a stub to RETIRED.

  The governing rule: BASH WRITES WHAT BASH CAN PROVE; A NAMED ACTOR WRITES
  WHAT REQUIRES AN ACT IN THE WORLD.

  It is deliberately NOT called "retired" — nothing fake ever existed here.

  A split whose deferred scope is WITHDRAWN from the product (the feature was
  dropped, not built) is handled manually and deliberately: strike the deferred
  scope in rebuild-backlog.md and record the withdrawal in this entry's
  Completion field. split-update refuses COMPLETE from ACTIVE, so there is no
  path that quietly marks unbuilt scope as done.

  ── WHAT BASH DOES, AND DOES NOT DO, WITH THIS FILE ──────────────────────

  Does:
    - /specclaw:propose  reads it before creating a proposal, so a re-proposed
      item RESUMES rather than starting over; and appends the entry a human
      chose. A dependency already deferred by an active split is classified
      deferred-by-split and is NOT re-elicited.
    - /specclaw-bf:bf-rebuild-plan  renders the per-item "PARTIALLY BUILT"
      marker, computes READY-TO-RESUME, and writes that one Status line.
    - /specclaw-bf:bf-replay --item  reports the run as PARTIAL while a split is
      ACTIVE or READY-TO-RESUME, naming which of the item's fixtures cover
      built vs deferred scope, so the run can never present as the item's
      final acceptance.
    - module-status  counts each module's partially-built items.

  Does not:
    - Decide that a split is warranted, or what belongs in which half. Ever.
    - Infer that a Blocked-until item is built from anything but a declared
      "BUILT:" line on that item.
    - Taint anything. A split fakes nothing, so no fixture's standing is in
      question and no verdict, divergence class or exit code changes. What a
      split puts in question is whether the ITEM is finished — reported as
      PARTIAL, alongside an unchanged verdict.
    - Remove an entry, renumber an id, or archive this file.

  ── The file's absence is a normal state ─────────────────────────────────
  Most projects never split an item. A project with no item-splits.md has no
  splits: every reader treats it as an empty registry, silently. Nothing
  warns, nothing degrades, and no verdict changes. This file is created by the
  first /specclaw:propose that records a split — in the REBUILD repo, where
  changes live. It is not part of the Phase A copy set and does not travel
  from the legacy repo.
-->

## Splits

{{split_entries}}
