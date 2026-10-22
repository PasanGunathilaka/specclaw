# Screenshot Capture Checklist: {{title}}

**Path analyzed:** {{path}}
**Date generated:** {{date}}
**Legacy commit at design time:** {{legacy_commit_sha}}
**Screens to capture:** {{screen_count}} · **Rows (screen × state):** {{row_count}}

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder
  token inside this comment's own prose — filling this template is a dumb
  global string replace and would corrupt the comment.

  THIS IS A HUMAN WORK ORDER. /specclaw-bf:bf-ui designs it; a human runs the
  legacy application and captures the screenshots. No specclaw command
  ever runs the legacy app, ever takes a screenshot, ever simulates one,
  and ever writes, edits, moves, or deletes anything under screens/ —
  exactly the same boundary /specclaw-bf:bf-baseline draws around fixture
  capture.

  HOW TO USE IT:
    1. Run the legacy application yourself.
    2. For each row below, reach the named screen in the named state
       (the Setup notes tell you how, with a citation to the code that
       evidences that state), and save a PNG at the exact Target file
       path shown.
    3. Run `/specclaw-bf:bf-ui --record`. It hashes every PNG it finds,
       validates the filenames against this checklist, and writes
       .specclaw/ui/ui-manifest.json. Missing captures are reported as a
       normal state, never an error — capture as many as you can now and
       re-run --record later.

  FILENAME CONVENTION (validated mechanically by --record):
    screens/SCR-###.png              for the "default" state
    screens/SCR-###-<state>.png      for every other state
  <state> is lowercase and matches [a-z0-9-]+ (the same slug shown in the
  State column). A file under screens/ whose name does not match this
  convention, or whose SCR/state pair matches no row below, is reported
  under the manifest's "extra" list — never silently ignored, and never
  deleted.

  THE Captured? COLUMN IS INFORMATIONAL ONLY. ui-manifest.json is the
  authoritative record of what exists and what its hash is; --record never
  rewrites this file. Tick the boxes by hand if you find it useful.

  ROWS COME FROM EVIDENCE, NOT IMAGINATION. One row per state actually
  evidenced in the code for that screen (ui-inventory.md's "States
  evidenced in code" field). A state nobody can reach is not a row — that
  belongs in ui-inventory.md's Named Gaps instead.

  ARCHIVE-THEN-REPLACE applies to this file (a re-run of Mode A archives
  the prior version under .specclaw/ui/archive/). It never applies to
  screens/ — human-captured evidence is never archived, moved, or deleted
  by any specclaw command.
-->

## Capture Checklist

| SCR | Screen | State | Target file | Setup notes | Captured? |
|---|---|---|---|---|---|
{{checklist_rows}}

## Setup Prerequisites

<!--
  Anything a human needs in place before capture that is not row-specific:
  the data state the screens assume (a seeded database, a specific record),
  a login, a required external dependency, a window size the layout
  depends on. Cited where the code evidences it. Reads "None beyond
  launching the application." when there is nothing.
-->

{{setup_prerequisites}}

## Not Capturable

<!--
  Screens or states from ui-inventory.md that a human cannot reach in the
  running application (dead code paths, states guarded by an unavailable
  dependency). Named here with the reason instead of being issued as a row
  no one can complete. Reads "None — every screen and state below is
  reachable." when there are none.
-->

{{not_capturable}}
