# Module Stubs: {{title}}

**Registry created:** {{date}}

<!--
  THE BYPASS REGISTRY. One ### ST-### entry per explicit human decision to
  build a backlog item before a module it depends on exists.

  Modules keep their dependency graph as the RECOMMENDED order — the backlog
  still sequences foundations first and still names a recommended next module.
  This file is what makes working OUT of that order possible without making it
  INVISIBLE. A bypass that nobody can see afterwards is indistinguishable from
  a rebuild that was never checked against anything.

  ── APPEND / UPDATE-IN-PLACE — archive-then-replace does NOT apply ────────
  Exactly like pending-questions.md and clarifications.md, and unlike every
  generated analysis document in .specclaw/analysis/. No command ever
  archives, regenerates, or rewrites this file wholesale. New entries are
  APPENDED; an existing entry is only ever edited field by field (a Status
  flip, a filled-in Implementation citation, a Retirement line). An agent
  adding an entry appends it (e.g. `cat >> .specclaw/analysis/module-stubs.md
  <<'STEOF' ... STEOF`) — never reads the whole file and Writes it back, which
  risks silently dropping an entry another run added and this one never saw.

  ST-### ids are permanent under templates/CONTRACT.md (c) — never
  renumbered, never reused, never deleted. RETIREMENT UPDATES AN ENTRY'S
  STATUS; IT NEVER REMOVES THE ENTRY. The record that an item was once built
  out of order is the whole point, and it outlives the stub.

  ── A BYPASS IS ALWAYS A HUMAN CHOICE ────────────────────────────────────
  No agent ever appends an entry on its own judgment, and no strategy is ever
  a default. /specclaw:propose DETECTS the unmet dependency, PRESENTS the
  strategies, and writes the entry the human picked — with their name in
  Chosen by. An entry with no named chooser is malformed, not merely
  incomplete. This is the ask-don't-guess mechanism (pending-questions.md)
  applied to dependencies: the difference is that a pending question records
  what an agent could not determine, and this records what a human decided.

  ── THE FOUR STRATEGIES ──────────────────────────────────────────────────
    stub-interface — the dependency's contract exists; a dev/test-only
      implementation answers it with fixed, obviously-fake responses.
    mock-data      — the dependency's DATA is faked (a seeded table, a
      fixture file); real code paths run against unreal content.
    feature-flag   — the consuming code path is written in full but disabled
      behind a flag that is off until the real module lands.
    item-split     — the item is split so the part not needing the dependency
      ships now; the remainder becomes a new BL-### that genuinely waits.
      The honest non-stub option. It still gets an entry, so the split is on
      the record — but there is no stub code, so there is nothing to retire
      beyond building the remainder.

  NOTHING IN THIS PLUGIN CONTAINS STUB IMPLEMENTATION CODE. The strategies
  above are shapes, not snippets. What a stub actually looks like is designed
  by the build agent in the REBUILD'S OWN STACK, at build time, by reading
  that repo — the same discipline templates/CONTRACT.md holds for harness
  code, replay tests, and error vocabularies. If you are tempted to add a
  framework name or a code sample to this file, that is the signal you are
  writing the wrong artifact.

  ── HARD RULE: DEV/TEST SCOPE ONLY ───────────────────────────────────────
  A stub is never reachable from a production code path. Not "unlikely to be
  hit" — structurally unreachable: a test-only module, a dev-profile-only
  registration, a flag that is off in every non-dev configuration. The
  change's spec.md must assert this as a checkable acceptance criterion, and
  the build agent must enforce it (see references/stub-discipline.md). A stub
  that can serve a real user is not a bypass, it is a defect.

  ── Entry format ─────────────────────────────────────────────────────────

  ### ST-### — <one line: what is faked, for whom>

  - **Status:** ACTIVE | RETIRING <YYYY-MM-DD> | RETIRED <YYYY-MM-DD>, cleared by run <run_id>
  - **Substitutes:** <BL-0## (MOD-###) — the specific unmet dependency; or
    MOD-### alone when the whole module is stood in for>
  - **Strategy:** stub-interface | mock-data | feature-flag | item-split
  - **Consumed by:** <BL-0##, ... — the items built against this stub. THIS
    IS THE JOIN KEY everything downstream keys off: a fixture that verifies
    one of these items is stamped stub_refs: [ST-###] by
    /specclaw-bf:bf-replay, and its verdict says so. Which item a fixture
    verifies is derived from that item's own acceptance-basis DR-### rules
    against the fixture's business_rules_pinned — never from the manifest's
    verifies_backlog_item field, which on a first-recorded baseline holds a
    placeholder and left this join matching nothing at all. An entry
    consumed by nothing taints nothing — which is correct, and visible.>
  - **Chosen by:** <human name>, <YYYY-MM-DD>
  - **Fakes:** <what it concretely does instead of the real thing, in the
    project's own language. Agent-written AT BUILD TIME, once the stub
    actually exists — at propose time this reads "not yet implemented".>
  - **Implementation:** <path/File.ext:88 — the stub code in the rebuild's
    own stack, cited file:line by the build step, followed by how it is
    dev/test scoped. Reads "not yet implemented" until the build task lands.
    An item-split entry reads "n/a — no stub code; split into BL-0##".>
  - **Mock seed:** <mock-data strategy ONLY: the declared seed/fixture path.
    Omit the field entirely for the other three strategies. This is a
    declaration for humans and for the retirement check, NOT an assertion:
    no specclaw command can observe which seed data a rebuild loaded during
    a run. What bash does with it is narrow and stated — see below.>
  - **Retirement:** <blank while ACTIVE. On retirement: the date, the replay
    run id that came back clean, and which consuming items were re-replayed
    to earn it.>

  ── STATUS SEMANTICS — three states, deliberately ────────────────────────

    ACTIVE   — the stub is in the tree. Every consuming item's fixtures are
               stamped tainted; no module holding one reads a plain PASSED.
    RETIRING — a human has removed or disabled the stub code and is
               re-replaying the consumers to prove the real module carries
               them. NOT tainting, because the stub is genuinely gone — but
               the report names the entry, so a PASS earned here is legible
               as the run that retires it.
    RETIRED  — the re-replay came back clean. The entry stays here forever.

  WHY THREE AND NOT TWO. With only ACTIVE/RETIRED, the run meant to PROVE the
  stub is gone is itself stamped tainted (the entry is still ACTIVE while it
  runs), so the evidence contradicts what it demonstrates. Flipping to
  RETIRED first inverts the problem: a FAILing re-replay leaves an entry
  falsely marked retired. RETIRING is the state in between, and it is the
  only state in which a clean run can honestly retire a stub.

  A RETIRING entry whose re-replay FAILs is flipped back to ACTIVE by the
  human, with the failing run id noted — the stub goes back in, or the real
  module gets fixed. It is never left in RETIRING indefinitely.

  ── WHAT BASH DOES, AND DOES NOT DO, WITH THIS FILE ──────────────────────

  Does:
    - /specclaw:propose  reads it to see whether a dependency already has an
      entry, and appends the entry a human chose.
    - /specclaw-bf:bf-replay resolve  joins Consumed by -> each selected
      fixture's bl_items_resolved (the BL items whose acceptance-basis DR
      rules that fixture pins), stamping stub_refs on each tainted fixture
      and carrying it through compare.json into the report and
      run-metadata.json.
    - /specclaw-bf:bf-rebuild-plan  marks consuming items ⚠ STUB-BACKED, and
      computes the Stub Retirement block from Substitutes vs. the
      substituted item's own declared BUILT: status note.
    - module-status  counts stub-tainted items per module and lists which
      ST-### entries fake each module for others.
    - resolve WARNs — never fails, never changes a verdict — when a
      mock-data entry is RETIRING or RETIRED and its declared Mock seed
      file still exists on disk.

  Does not:
    - Decide that a bypass is needed, or pick a strategy. Ever.
    - Infer that a stub is retirable from anything but a declared BUILT:
      note on the substituted item.
    - Change a verdict, a divergence class, or an exit code. Taint is a
      marker riding alongside PASS/FAIL exactly as PROVISIONAL does — it
      never softens a FAIL and never introduces an exit code of its own.
      See templates/CONTRACT.md (m).
    - Observe which data a running application actually loaded.

  ── The file's absence is a normal state ─────────────────────────────────
  Most projects never bypass anything. A project with no module-stubs.md has
  no stubs: every reader treats it as an empty registry, silently. Nothing
  warns, nothing degrades, and no verdict changes. This file is created by
  the first /specclaw:propose that elicits a bypass — in the REBUILD repo,
  where changes live. It is not part of the Phase A copy set and does not
  travel from the legacy repo.
-->

## Stubs

{{stub_entries}}
