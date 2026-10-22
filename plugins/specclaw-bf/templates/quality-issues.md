# Quality Issues: {{title}}

**Path measured:** {{path}}
**Last updated:** {{date}}

<!--
  THE QI-### REGISTRY. One ### QI-### entry per code-quality hotspot that
  reached the registering severity band, ever.

  ── ONE WRITER, AND IT IS NOT A HUMAN ────────────────────────────────────

  Unlike module-stubs.md and item-splits.md — which record human decisions and
  are therefore strictly append-only, edited field by field, never rewritten —
  this registry has exactly one writer: the quality collector. It rewrites the
  document in full on every run, because every entry's Status, Value and Last
  checked are recomputed from a fresh measurement and a stale Status here would
  be indistinguishable from a hotspot nobody has got round to.

  That wholesale rewrite is SAFE ONLY BECAUSE OF THE INVARIANT BELOW, and the
  invariant is the whole reason this file exists rather than the numbers just
  living in quality.json. Do not hand-edit entries: the next run overwrites
  them. Anything a human needs to say about a hotspot belongs in the change
  that fixes it.

  ── THE INVARIANT: NO ID IS EVER LOST ────────────────────────────────────

  Every run reads this file BEFORE writing anything, and the document it writes
  contains an entry for every key it read, plus one for every newly-found
  hotspot. A key that is still a hotspot keeps its id and its First seen date;
  a key that no longer exceeds its threshold is written back with Status
  `resolved`. Nothing is dropped, so the id space only ever grows.

  QI-### joins MOD/GM/DR/CQ/SQ/UQ/BL/ST/IS under templates/CONTRACT.md (c):
  ids are assigned once, sequentially, and are never renumbered, reused or
  reformatted across any regeneration.

  ── NEVER ARCHIVED ───────────────────────────────────────────────────────

  This document carries the ST-###/IS-### carve-out from (c)'s archive rule,
  and for the same reason: a registry that gets archived and regenerated is
  precisely the silent re-pointing (c) exists to prevent. quality.json IS
  archived on every run; this file is not, and that asymmetry is deliberate —
  which is also why the registry lives here rather than inside the snapshot
  that gets rotated. quality.json's quality_issues[] is a regenerated
  PROJECTION of this file, never the source of it. One direction per fact.

  ── IDENTITY IS THE KEY FIELD, NEVER THE VALUE ───────────────────────────

  Key is the tuple

    metric | file | scope | module | start_line

  and it is what makes a hotspot the same hotspot across runs. The measured
  Value is explicitly NOT part of identity: values move on every commit, and
  keying on one would mint a fresh id every run and make two reports months
  apart incomparable — which is the only thing a permanent id is for.

  NO SLOT IS EVER EMPTY, and that is the whole of what scope and start_line buy:

    scope       the function name where the measuring tool gives one,
                <anonymous> where it measured a function it could not name,
                *global* where the metric has no function at all (a file-length
                hotspot, a module-level duplication percentage)
    start_line  the function's first line; 1 for a file-level metric, whose span
                is the file; 0 for a module-level one, which has no line

  The scope is the BARE function name. The measuring tool emits it wrapped in
  double quotes, as a CSV field, and for one release those quotes reached the key
  — so `"Login"` and `Login` named the same function and never met. A registry
  written in that period is migrated in place: the entry keeps its id and its
  first-seen date and the key is respelled, which is recorded below under
  Migrations. Nothing is renumbered, because unquoting a scope is a rename and
  not a re-identification — same metric, same file, same start line, same
  hotspot. The collector now refuses to write a key whose scope still carries the
  wrapping quotes.

  The key held four fields until an identity collision made it hold five. The
  measuring tool reports the SHORT function name, so two overloads are one
  string; every unnamed function is reported under one name; and some parsers
  report the name empty. Any two of those in a file produced one key for two
  hotspots — and because the prior registry is read into a map, the second run
  gave every colliding hotspot the same id and DELETED the others. Three
  over-length functions in one file registered QI-001/002/003 and came back on
  the next run as three copies of QI-003. The start line is what physically
  separates them, and the collector now refuses to write a set in which two
  entries share a key at all.

  A `duplication-clone` entry carries FIVE fields instead of four, because a
  clone is a relationship and no single location identifies it:

    duplication-clone|fileA|fileB|module|sha256:<hash of the fragment>

  Slot 2 holds the PEER FILE, not a function — a clone entry always reports
  Function as —, and names its other side in Clone peer instead. The two sides
  are put in a canonical order (smaller path, then smaller start line) before
  the key is built, because the detector reports first/second in scan order and
  an unordered pair would flip between runs and mint a new id each time.

  The hash is of the fragment with whitespace normalised, not of the raw text:
  clone detection works on a token stream, so re-indenting a block leaves the
  same clone, and hashing raw text would retire a hotspot nobody touched. Line
  numbers are deliberately absent from the key for the same reason — editing
  code ABOVE a clone shifts it down without changing it at all.

  A RENAMED FILE therefore yields a new QI-### plus a resolved old one. That is
  the intended behaviour and not a defect: inferring the rename would carry an
  id, and its whole history, onto code nobody measured.

  ── STATUS ───────────────────────────────────────────────────────────────

    open                  the hotspot exceeded its threshold in the most recent
                          run
    resolved              it did not
    excluded-by-scope     it was not measured: the file it names is outside the
                          configured scan scope
    superseded-duplicate  TERMINAL. This id was one of several sharing a single
                          key before the key gained its start line, and another
                          id now owns the hotspot it was pointing at

  `resolved` is not deletion and is not absolution. The entry stays here
  forever, because "this used to be a hotspot" is itself a finding — it is how
  anyone can later tell a module that was cleaned up from one that was never
  bad. A resolved entry that exceeds its threshold again flips back to `open`
  under its ORIGINAL id, with its original First seen date intact.

  `excluded-by-scope` IS NOT `resolved`, and the distinction is the reason it
  exists as a third status rather than being folded into the second. `resolved`
  says the code was measured and came back under its threshold. This says the
  code was not measured at all — the scan scope changed and stopped looking. In
  the first case someone did something; in the second, nobody did, and the
  module only LOOKS better. Recording that as `resolved` would be the most
  flattering lie this registry could tell, and the reader least able to catch it
  is the one most likely to be shown it.

  Such an entry keeps its id and its original First seen date, gains an
  **Excluded by scope:** line naming the category and the exclusion config hash
  that produced the decision, and leaves the open-hotspot rollups — because it
  is not open. It generates no rebuild remediation item, and a module's existing
  item records its departure as a dated `⊘ Scope change` line rather than as a
  retirement, for exactly the same reason.

  A file brought back into scope — the category switched off, or the path added
  to `include_overrides` — is measured again on the next run and its entry flips
  back to `open` or `resolved` on the evidence, under its original id.

  `superseded-duplicate` is the one TERMINAL status: such an entry is carried
  forward verbatim on every later run and is never re-judged. It does not reopen
  and it does not resolve, because there is nothing left to measure it against —
  the hotspot it was pointing at is now owned, by name, by the id in its
  **Superseded by:** field.

  It is also the one entry type that may share a Key with another entry, and
  deliberately so. The key it carries is the HISTORICAL four-field one it was a
  duplicate under; that key is the fact the entry exists to record, and
  rewriting it to force uniqueness would falsify the only thing it says. Every
  other entry's key is unique, and the collector fails the run if it is not.

  Nothing is deleted here either. An id that stopped meaning what it used to
  mean is a fact about this registry's history, and a reader who finds QI-026
  cited in an old report is entitled to find out what happened to it.

  ── WHICH SEVERITIES GET REGISTERED ──────────────────────────────────────

  Controlled by config.yaml's `quality.register_severity`, default HIGH. Ids
  are permanent and entries are never deleted, so a registry admitting every
  WARN on a large legacy tree would accumulate thousands of rows that outlive
  the code they describe. WARN findings are still counted in every module
  rollup — they are simply not individually immortalised.

  ── PER-ENTRY STRUCTURE ──────────────────────────────────────────────────

  ### QI-###

  - **Key:** <metric|file|scope|module|start_line — the identity tuple>
  - **Module:** <MOD-###, or MOD-UNASSIGNED when no module cites this file>
  - **File:** <repo-relative path, or — for a module-level metric>
  - **Function:** <function name, or — for a file- or module-level metric, and
    for a function the measuring tool could not name>
  - **Line:** <the start line from the key, or — where the metric has none>
  - **Metric:** <complexity | function_length | file_length | duplication |
    duplication-clone>
  - **Clone peer:** <the other side of a duplication-clone pair, as a
    repo-relative path — present ONLY on a duplication-clone entry, absent on
    every other. The File field above names the first side.>
  - **Value:** <the measured value at the last check, or — when resolved>
  - **Severity:** <WARN | HIGH at the last check, or — when resolved>
  - **Status:** <open | resolved | excluded-by-scope | superseded-duplicate>
  - **Superseded by:** <the QI-### that now owns this entry's hotspot — present
    ONLY on a superseded-duplicate entry, absent on every other>
  - **Excluded by scope:** <category (exclusion config hash) — present ONLY on
    an excluded-by-scope entry, absent on every other>
  - **First seen:** <ISO-8601 of the run that first registered it — never
    updated afterwards, on any subsequent run, for any reason>
  - **Last checked:** <ISO-8601 of the most recent run>

  ── NOTHING IS BLOCKED BY ANYTHING IN HERE ───────────────────────────────

  No command reads this file, and no command's behaviour changes because of an
  entry in it. It is a record, not a gate.
-->

{{quality_issues}}

## Migration record

<!--
  WRITTEN BY THE COLLECTOR, ONE DATED ENTRY PER MIGRATION, AND READ BACK ON
  EVERY RUN. The registry is rewritten in full each time, so a record that is
  not carried forward survives exactly one run — and a migration nobody can find
  afterwards is indistinguishable from ids that moved on their own, which is the
  single thing permanent ids exist to rule out.

  A migration happens when the SHAPE of the identity key changes. Ids are mapped
  onto the new shape, never renumbered: an entry whose old key named exactly one
  hotspot keeps its number and records the new key, and an entry whose old key
  turned out to name several is decided by the Value each one recorded. Where
  the recorded values do not decide it, the collector STOPS and says so rather
  than guessing — a guess here moves a permanent id onto code nobody checked.

  Each line names the id and what happened to it, so the mapping can be checked
  rather than taken.
-->

{{migrations}}
