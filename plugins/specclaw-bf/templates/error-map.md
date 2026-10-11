# Error Map: {{title}}

**Date created:** {{date}}
**Grounded in:** the legacy application's own source — every entry cites the
line that raises the condition it names.

<!--
  THIS FILE IS PER-PROJECT DATA. It lives in the target repo at
  .specclaw/baseline/error-map.md and belongs to that project alone. The
  specclaw plugin ships this skeleton and nothing else — no code tables, no
  framework exception names, no mapping between them. If any specclaw command
  ever READS OR MATCHES ON a specific code or exception name, that is a bug:
  the plugin's only interest in this file is that a heading exists for each
  code a fixture asserts. (Prose elsewhere may name a code to illustrate the
  format; an illustration a command never reads is documentation, a lookup a
  command consults is a dictionary. Only the second is forbidden.)

  WHAT IT IS FOR

  A golden-master fixture records what the legacy app DECIDED, not how its
  framework happened to express the decision. An exception class plus a
  human-worded message is a representation of a decision; the code is the
  decision. A rebuild on a different framework raises differently-named
  exceptions with differently worded messages while making exactly the same
  decision — so the raw surface is recorded as evidence
  (templates/CONTRACT.md (b.2)) and the code is what is actually compared
  (CONTRACT.md (b.1), (h)).

  WHO WRITES IT

  - bf-baseline-designer, in harness mode, CREATES or EXTENDS this file as it
    reads the legacy app's error paths. It cites the legacy file:line that
    raises each condition.
  - bf-replay-mapper, in the rebuild repo, READS it and maps the rebuild's
    own errors into the SAME codes, filling in each entry's Rebuild source.
    It never adds a code, never renames one, and never invents one to make a
    comparison line up.

  APPEND-AND-AMEND, NEVER REGENERATE. Codes are permanent once assigned, on
  the same terms as GM-/DR-/CQ-/BL- ids: a code already cited by a captured
  fixture must keep meaning exactly what it meant at capture time. A new
  condition gets a new code appended; an existing entry is only ever amended
  to fill in its Rebuild source or to correct a citation.

  ASK, DON'T GUESS. An error neither agent can confidently map does NOT get a
  plausible-looking code. The agent appends a pending question
  (.specclaw/analysis/pending-questions.md, triggers T2/T3/T4), leaves
  error_code null on the affected fixture or actual result, and marks the
  scenario PROVISIONAL. `specclaw-bf-baseline record` enforces this: a
  REJECTED fixture with a null error_code is only legal when its scenario
  carries the ⚠ PROVISIONAL marker, and every non-null code in any fixture
  must have a "### <CODE>" heading below.

  ENTRY FORMAT — one "###" heading per code, so record can verify a code
  exists by literal heading grep, exactly as sanction-check verifies a CQ
  citation. SCREAMING_SNAKE, named for the business condition, never for the
  exception class that happens to carry it.

  ### <SEMANTIC_CODE>

  - **Condition:** <the business condition, in this project's own language>
  - **Legacy source:** <path/File.ext:142>
  - **Rebuild source:** <path/File.ext:88, or "not yet mapped">
  - **Raised as (legacy):** <raw exception type / message shape — reference
    only, never compared as behaviour>
  - **Pinned by:** <GM-NNN scenario id(s) whose fixtures carry this code>
-->

## Codes

{{codes}}

## Unmapped Conditions

<!--
  Error conditions observed in source but not yet given a code, each with the
  PQ-NNN that asked about it. An entry here is a live pending question, not a
  parking lot: it holds every fixture that hits the condition at
  PASS-PENDING-DECISIONS until a human answers. Write "None — every observed
  error condition above is mapped." when there genuinely are none.
-->

{{unmapped}}
