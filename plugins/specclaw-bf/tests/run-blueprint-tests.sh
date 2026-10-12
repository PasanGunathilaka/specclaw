#!/usr/bin/env bash
# run-blueprint-tests.sh — regression suite for the client options pack
# (/specclaw-bf:bf-clarify --options-pack) and the target blueprint
# (/specclaw-bf:bf-blueprint).
#
# What these two features share, and what this suite is really about:
#
#   BASH COMPUTES DECISION STATUS; NO AGENT EVER DOES. Both documents key
#   everything off whether a question is DECIDED / UNDECIDED / NOT-APPLICABLE.
#   That verdict is computed in bash from decisions.md's literal heading
#   structure plus clarifications.md's own `## Not Applicable` section, and
#   handed to the agents already resolved. If that computation is wrong, a
#   client is shown a question that was already answered, or — far worse — a
#   blueprint claims COMPLETE while resting on something nobody decided.
#
#   THE CITATION GATE. Every row of the blueprint's legacy->target mapping
#   table must cite the decision that sanctions it. A target element nobody
#   decided is precisely what that table exists to make impossible, so an
#   uncited row must FAIL the run rather than render.
#
# The tests that matter most are the three status-derivation ones (an empty
# `Decision:` line is not an answer; an Outstanding-Questions bullet is not an
# answer; a declared "not applicable" IS one) and the citation gate. Between
# them they are the whole trust model: everything else in both documents is
# presentation.
#
# ALSO REGRESSION-GUARDED HERE: the field-separator bug. The scan emits one
# record per question with several optionally-empty columns. A tab separator
# silently collapses runs of empties (a tab is IFS whitespace), shifting every
# later field left by a column — which an empty Type on a Not-Applicable entry
# produces every single time. That is not a hypothetical; it was the first bug
# these collectors had.
#
# WHAT THIS SUITE CANNOT TEST, stated rather than implied: both commands are
# SKILLS — prose an agent follows — and the option text, the diagrams and the
# recommendations are agent-authored. No bash suite can prove an option is
# well-reasoned or a diagram is right. What is testable, and tested here, is
# every mechanical decision the bash side makes on the agent's output.
#
# Bash + coreutils only (no jq).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLARIFY_BIN="$PLUGIN_ROOT/bin/specclaw-bf-clarify"
BLUEPRINT_BIN="$PLUGIN_ROOT/bin/specclaw-bf-blueprint"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL — $1"; [ $# -gt 1 ] && echo "         $2"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then ok "$label"
  else bad "$label" "expected [$expected], got [$actual]"; fi
}
assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in *"$needle"*) ok "$label" ;;
    *) bad "$label" "missing [$needle]" ;; esac
}
assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in *"$needle"*) bad "$label" "unexpectedly found [$needle]" ;;
    *) ok "$label" ;; esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixture builders ────────────────────────────────────────────────────────
# Deliberately stack-blind: the fixture names no database, framework or host,
# because the collectors under test must work identically whatever a project's
# answers happen to be.

new_project() {
  local root="$WORK/$1"
  rm -rf "$root"
  mkdir -p "$root/.specclaw/analysis"
  printf 'project:\n  name: Fixture Project\n' > "$root/.specclaw/config.yaml"
  printf '%s' "$root"
}

# A question block. $1 file, $2 id, $3 title, $4 type, $5 blocking, $6 answer,
# $7 decider, $8 date
add_question() {
  cat >> "$1" <<EOF

### $2 — $3

- **Type:** $4
- **Blocking:** $5
- **Source:** fixture
- **Finding:** fixture finding for $2
- **Why it matters:** fixture consequence
- **Options:**
  1. one
  2. two
- **Proposed default:** 1
- **Answer:** $6
- **Decided by:** $7
- **Date:** $8
EOF
}

start_clarifications() {
  cat > "$1" <<'EOF'
# Clarifications: Fixture Project

**Date generated:** 2026-08-19
**Documents swept:** architecture.md

## Summary

fixture

## Standard Questions
EOF
}

write_architecture() {
  cat > "$1" <<'EOF'
# Architecture Report: Fixture Project

**Path analyzed:** /fixture
**Date analyzed:** 2026-08-19

## System Context (L1)

```mermaid
flowchart TD
  user([Operator]):::person
  subgraph sys["Fixture System"]
    app["The application"]
  end
  user --> sys
```

Fixture narrative.

## Containers (L2)

```mermaid
flowchart TD
  subgraph sys["Fixture System"]
    subgraph shell["Client shell"]
      f1["Views"]
    end
    subgraph core["Domain core"]
      s1["Domain service"]
    end
  end
  shell --> core
```

Fixture narrative.

## Components (L3)

```mermaid
flowchart TD
  subgraph core["Domain core"]
    svc["Domain service"]
    rep["Repository"]
  end
  svc --> rep
```

Fixture narrative.

## Code (L4)

```mermaid
flowchart TD
  a["X"] --> b["Y"]
```

L4 not warranted for this component.
EOF
}

write_module_map() {
  local file="$1" status="$2"
  cat > "$file" <<EOF
# Module Map: Fixture Project

**Path analyzed:** /fixture
**Date analyzed:** 2026-08-19
**Status:** ${status}

## Modules

### MOD-001 — Core

- **Purpose:** The fixture's first module.
- **Owns (entities):** Thing
- **References (not owned):** None
- **Services/routes:** Domain service
- **Screens:** none
- **Business rules:** DR-001
- **Depends on:** None
- **Backlog items:** BL-001
- **Evidence:**
  - fixture

### MOD-002 — Edge

- **Purpose:** The fixture's second module.
- **Owns (entities):** Other
- **References (not owned):** Thing (MOD-001)
- **Services/routes:** Edge service
- **Screens:** none
- **Business rules:** DR-002
- **Depends on:** MOD-001
- **Backlog items:** BL-002
- **Evidence:**
  - fixture

## Cross-Module References

Thing is shared.

## Module Dependencies

\`\`\`mermaid
flowchart TD
  MOD001["MOD-001"]
\`\`\`

fixture

## Unassigned

None.

## Coverage Check

fixture
EOF
}

blueprint_draft() {
  # $1 outfile, $2 mapping rows, $3 module sections
  cat > "$1" <<EOF
<!-- SECTION: sources_consumed -->
architecture.md
module-map.md
decisions.md
<!-- SECTION: overview -->
Fixture overview.
<!-- SECTION: stack_sections -->
### Stack
fixture
<!-- SECTION: context_diagram -->
C4Context
  title Fixture context
  Person(u, "Operator")
<!-- SECTION: context_narrative -->
fixture
<!-- SECTION: container_diagram -->
C4Container
  title Fixture containers
  Container(c, "Thing")
<!-- SECTION: container_narrative -->
fixture
<!-- SECTION: component_sections -->
$3
<!-- SECTION: mapping_table -->
| Legacy element | Target element | Sanctioning decision | Status |
|---|---|---|---|
$2
<!-- SECTION: data_migration -->
fixture
<!-- SECTION: deployment -->
fixture
EOF
}

BOTH_MODULE_SECTIONS='## MOD-001 — Core

```mermaid
C4Component
  title MOD-001 components
  Component(a, "Domain service")
```

## MOD-002 — Edge

```mermaid
C4Component
  title MOD-002 components
  Component(b, "Edge service")
```'

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Decision status: the one computation both documents rest on ──────────"
# ════════════════════════════════════════════════════════════════════════════

ROOT="$(new_project status)"
CLAR="$ROOT/.specclaw/analysis/clarifications.md"
DEC="$ROOT/.specclaw/analysis/decisions.md"
start_clarifications "$CLAR"
add_question "$CLAR" "SQ-001" "Answered in clarifications only" "DECISION" "yes" "Chosen option one" "Ada Okoro" "2026-08-18"
add_question "$CLAR" "SQ-002" "Open" "DECISION" "yes" "" "" ""
add_question "$CLAR" "SQ-003" "Open but not blocking" "SCOPE" "no" "" "" ""
add_question "$CLAR" "SQ-004" "Decided in decisions.md" "TARGET-GAP" "yes" "" "" ""
add_question "$CLAR" "SQ-005" "Heading present, Decision line empty" "SCOPE" "yes" "" "" ""
cat >> "$CLAR" <<'EOF'

## Not Applicable

- **SQ-013** — No screens are in scope; nothing for the policy to bind to.
EOF

cat > "$DEC" <<'EOF'
# Decisions: Fixture Project

## Decisions

### SQ-004 — Decided in decisions.md

- **Type:** TARGET-GAP
- **Decision:** The approach recorded by a human
- **Decided by:** Bo Lindqvist
- **Date:** 2026-08-17

### SQ-005 — Heading present, Decision line empty

- **Type:** SCOPE
- **Decision:**
- **Decided by:**
- **Date:**

## Outstanding Questions

- **SQ-002** — Open (Type: DECISION, Family: Standard bank, Blocking: yes)
EOF

OUT="$("$CLARIFY_BIN" options-pack-collect "$ROOT/.specclaw" 2>&1)"
assert_contains "$OUT" '"undecided": 2' "blocking undecided count is 2 (SQ-002, SQ-005)"
assert_contains "$OUT" '"decided": 2' "blocking decided count is 2 (SQ-001, SQ-004)"
assert_contains "$OUT" '"not_applicable": 1' "blocking not-applicable count is 1 (SQ-013)"

UND="$(printf '%s' "$OUT" | tr -d ' \n' | sed -n 's/.*"undecided_blocking_ids":\[\([^]]*\)\].*/\1/p')"
assert_eq '"SQ-002","SQ-005"' "$UND" "undecided blocking roster is exactly SQ-002 and SQ-005"

DECIDED="$(printf '%s' "$OUT" | tr -d ' \n' | sed -n 's/.*"decided_blocking_ids":\[\([^]]*\)\].*/\1/p')"
assert_eq '"SQ-001","SQ-004"' "$DECIDED" "decided blocking roster is exactly SQ-001 and SQ-004"

# The three status rules, each stated as its own assertion so a regression
# names which rule broke rather than just "counts changed".
assert_not_contains "$UND" "SQ-001" "an Answer in clarifications.md alone counts as DECIDED"
assert_contains "$UND" "SQ-005" "a decisions.md heading with an EMPTY Decision line is NOT an answer"
assert_contains "$UND" "SQ-002" "an Outstanding-Questions bullet is NOT an answer"
assert_not_contains "$UND" "SQ-013" "a declared 'not applicable' IS an answer"
assert_not_contains "$UND" "SQ-003" "a non-blocking open question never reaches the client pack"

assert_contains "$OUT" 'Bo Lindqvist' "decisions.md attribution is transcribed"
assert_contains "$OUT" '"status_source": ".specclaw/analysis/decisions.md"' "the file that proves a verdict is recorded"

# The field-separator regression: an empty Type column on the Not-Applicable
# entry must not shift every later field left by one.
assert_contains "$OUT" '"id": "SQ-013"' "not-applicable entry is emitted"
assert_contains "$OUT" '"status": "NOT-APPLICABLE"' "not-applicable status survives the empty Type column"
assert_contains "$OUT" '"na_reason": "No screens are in scope; nothing for the policy to bind to."' \
  "not-applicable reason lands in its own column, not shifted"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Options pack: preconditions, refusals, and the clean zero state ──────"
# ════════════════════════════════════════════════════════════════════════════

EMPTY="$(new_project nopack)"
OUT="$("$CLARIFY_BIN" options-pack-collect "$EMPTY/.specclaw" 2>&1)"; RC=$?
assert_eq "1" "$RC" "collect refuses a project with no clarifications.md"
assert_contains "$OUT" "run /specclaw-bf:bf-clarify first" "the refusal names the command that fixes it"

# render refuses a draft missing an undecided blocking id
DRAFT="$ROOT/.specclaw/analysis/.options-pack-draft.md"
cat > "$DRAFT" <<'EOF'
### SQ-002 — Only one of the two

**Recommended:** Option A — fixture.
EOF
OUT="$("$CLARIFY_BIN" options-pack-render "$ROOT/.specclaw" "$DRAFT" 2>&1)"; RC=$?
assert_eq "1" "$RC" "render refuses a draft missing an undecided blocking question"
assert_contains "$OUT" "SQ-005" "the refusal names the question that would have gone unasked"

# render refuses a draft carrying a block for an already-decided question
cat > "$DRAFT" <<'EOF'
### SQ-002 — Fine

**Recommended:** Option A — fixture.

### SQ-005 — Fine

**Recommended:** Option A — fixture.

### SQ-004 — Already decided, must not be re-asked

**Recommended:** Option A — fixture.
EOF
OUT="$("$CLARIFY_BIN" options-pack-render "$ROOT/.specclaw" "$DRAFT" 2>&1)"; RC=$?
assert_eq "1" "$RC" "render refuses a block for a question that is already decided"
assert_contains "$OUT" "SQ-004" "the refusal names the already-decided question"

# The happy render.
cat > "$DRAFT" <<'EOF'
### SQ-002 — A real question, restated

**What this is.** Fixture.

**Recommended:** Option A — fixture rationale.

### SQ-005 — Another real question

**What this is.** Fixture.

**Recommended:** Option B — fixture rationale.
EOF
OUT="$("$CLARIFY_BIN" options-pack-render "$ROOT/.specclaw" "$DRAFT" 2>&1)"; RC=$?
assert_eq "0" "$RC" "render accepts a complete draft"
PACK="$(cat "$ROOT/.specclaw/analysis/options-pack.md")"
assert_contains "$PACK" "2 undecided · 2 decided · 1 not applicable" "header counts are bash-computed"
assert_contains "$PACK" "Client decision:" "bash appends the Client-decision line"
assert_contains "$PACK" "record via bf-clarify answer, attributed by name" "the line insists on a named human"
assert_contains "$PACK" "Bo Lindqvist, 2026-08-17" "Already Decided transcribes decider and date"
assert_contains "$PACK" "Ada Okoro" "a clarifications-only answer is transcribed too"
ANSWER_FIELDS="$(grep -c '^- \*\*Answer:\*\*' "$ROOT/.specclaw/analysis/options-pack.md" || true)"
assert_eq "0" "$ANSWER_FIELDS" "the pack carries no fillable Answer field of its own (it points at clarifications.md instead)"
assert_contains "$PACK" "SQ-013" "the not-applicable question is still listed, for auditability"
if [ -f "$DRAFT" ]; then bad "render deletes the draft on success"; else ok "render deletes the draft on success"; fi

# Zero-pending clean state: a pack is still written, and it is not an error.
CLEAN="$(new_project clean)"
CCLAR="$CLEAN/.specclaw/analysis/clarifications.md"
start_clarifications "$CCLAR"
add_question "$CCLAR" "SQ-001" "All settled" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-18"
add_question "$CCLAR" "SQ-006" "Non-blocking and open" "DECISION" "no" "" "" ""
OUT="$("$CLARIFY_BIN" options-pack-collect "$CLEAN/.specclaw" 2>&1)"; RC=$?
assert_eq "0" "$RC" "zero undecided blocking questions exits 0, not an error"
assert_contains "$OUT" '"undecided_blocking_ids": []' "the undecided roster is empty"
OUT="$("$CLARIFY_BIN" options-pack-render "$CLEAN/.specclaw" - 2>&1)"; RC=$?
assert_eq "0" "$RC" "render with '-' succeeds when nothing is pending"
PACK="$(cat "$CLEAN/.specclaw/analysis/options-pack.md")"
assert_contains "$PACK" "Nothing pending — all blocking decisions recorded." "the clean state says so plainly"
assert_contains "$PACK" "Ada Okoro" "the clean pack still records who decided what"
assert_contains "$PACK" "1 further non-blocking question" "excluded non-blocking questions are counted, not hidden"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Blueprint: preconditions, the WARN that is not a stop, and the gates ─"
# ════════════════════════════════════════════════════════════════════════════

BP="$(new_project bp)"
BPA="$BP/.specclaw/analysis"
OUT="$("$BLUEPRINT_BIN" collect "$BP/.specclaw" 2>&1)"; RC=$?
assert_eq "1" "$RC" "collect refuses when the required documents are absent"
assert_contains "$OUT" "architecture.md (run /specclaw-bf:bf-architecture)" "the refusal names architecture.md and its command"
assert_contains "$OUT" "module-map.md (run /specclaw-bf:bf-domain)" "the refusal names module-map.md and its command"
assert_contains "$OUT" "decisions.md (run /specclaw-bf:bf-clarify" "the refusal names decisions.md and its command"

write_architecture "$BPA/architecture.md"
write_module_map "$BPA/module-map.md" "PROPOSED"
start_clarifications "$BPA/clarifications.md"
add_question "$BPA/clarifications.md" "SQ-001" "Settled" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-18"
add_question "$BPA/clarifications.md" "SQ-002" "Still open" "DECISION" "yes" "" "" ""
cat > "$BPA/decisions.md" <<'EOF'
# Decisions: Fixture Project

## Decisions

### SQ-001 — Settled

- **Decision:** Chosen
- **Decided by:** Ada Okoro
- **Date:** 2026-08-18
EOF

OUT="$("$BLUEPRINT_BIN" collect "$BP/.specclaw" 2>&1)"; RC=$?
assert_eq "0" "$RC" "an unconfirmed module map does NOT stop the run"
assert_contains "$OUT" "not CONFIRMED" "an unconfirmed module map is reported as a warning"
assert_contains "$OUT" '"blueprint_status": "PROVISIONAL"' "an open blocking question makes the blueprint PROVISIONAL"
assert_contains "$OUT" 'unresolved blocking questions: SQ-002' "the status line names the ids"
assert_contains "$OUT" '"Client shell"' "the legacy container inventory is extracted structurally"
assert_contains "$OUT" '"Repository"' "the legacy component inventory is extracted structurally"
assert_contains "$OUT" '"machine_readable": true' "a parseable architecture.md yields a machine-readable inventory"

# A module-map.md whose Services/routes label contains a slash must not break
# parsing — it did, when the field was stripped with sed.
assert_contains "$OUT" '"services_routes": "Domain service"' "a label containing a slash parses (Services/routes)"

# ── The gates ──────────────────────────────────────────────────────────────
D="$BPA/.blueprint-draft.md"

blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |
| Domain core | Application service | | |' "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "1" "$RC" "GATE 1: an uncited mapping row fails the run"
assert_contains "$OUT" "Domain core | Application service" "the refusal prints the offending row"

blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |
| Domain core | Application service | SQ-099 | DECIDED |' "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "1" "$RC" "GATE 2: a citation to a non-existent id fails the run"
assert_contains "$OUT" "SQ-099" "the refusal names the id that resolves to nothing"

blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |' '## MOD-001 — Core

```mermaid
C4Component
  Component(a, "Domain service")
```'
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "1" "$RC" "GATE 3: a missing component section for an active module fails the run"
assert_contains "$OUT" "MOD-002" "the refusal names the module left out"

blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |' "$BOTH_MODULE_SECTIONS

## MOD-009 — Invented

\`\`\`mermaid
C4Component
  Component(z, \"Nope\")
\`\`\`"
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "1" "$RC" "GATE 3: a section for a module the map does not define fails the run"
assert_contains "$OUT" "MOD-009" "the refusal names the invented module"

# ── The accepted forms of a citation ───────────────────────────────────────
blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |
| Domain core | Application service | SQ-002 | PROVISIONAL(SQ-002) |
| Repository | — dropped — | SQ-001 | RETIRED-BY-DECISION |' "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "0" "$RC" "PROVISIONAL and RETIRED-BY-DECISION rows are accepted citations"
DOC="$(cat "$BPA/target-architecture.md")"
assert_contains "$DOC" "**Blueprint status:** PROVISIONAL (1 unresolved blocking questions: SQ-002)" \
  "the status line is bash-injected into the rendered document"
assert_contains "$DOC" "WARN — Status reads" "the unconfirmed-map warning travels onto the document's face"
assert_contains "$DOC" "PROVISIONAL(SQ-002)" "provisional markers survive rendering"
assert_contains "$DOC" "**SQ-002** — Still open" "the Open Questions section is bash-computed"
if [ -f "$D" ]; then bad "render deletes the draft on success"; else ok "render deletes the draft on success"; fi

# ── COMPLETE: no open blocking questions, no PROVISIONAL anywhere ──────────
cat >> "$BPA/decisions.md" <<'EOF'

### SQ-002 — Still open no longer

- **Decision:** Also chosen
- **Decided by:** Bo Lindqvist
- **Date:** 2026-08-19
EOF
write_module_map "$BPA/module-map.md" "CONFIRMED by Ada Okoro, 2026-08-19"
blueprint_draft "$D" '| Client shell | Browser client | SQ-001 | DECIDED |
| Domain core | Application service | SQ-002 | DECIDED |' "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$BP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "0" "$RC" "a fully-decided project renders cleanly"
DOC="$(cat "$BPA/target-architecture.md")"
assert_contains "$DOC" "**Blueprint status:** COMPLETE" "answering the last blocking question yields COMPLETE"
BODY="$(sed '/^<!--/,/^-->/d' "$BPA/target-architecture.md")"
assert_not_contains "$BODY" "PROVISIONAL(" "no PROVISIONAL marker survives once everything is decided"
assert_not_contains "$DOC" "WARN — Status reads" "a confirmed map produces no warning"
assert_contains "$DOC" "None. Every blocking question" "Open Questions says so plainly rather than sitting empty"

# The prior blueprint is archived, never overwritten in place.
ARCHIVED="$(find "$BPA/archive" -name '*-target-architecture.md' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$ARCHIVED" -ge 1 ]; then ok "the prior blueprint is archived, not overwritten"
else bad "the prior blueprint is archived, not overwritten" "found $ARCHIVED archived copies"; fi

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── One state: status, header, PROVISIONAL markers and Open Questions ────"
# ════════════════════════════════════════════════════════════════════════════
#
# The defect this whole section exists for: a generated blueprint that said
# "Blueprint status: COMPLETE", "Pending questions raised this run: PQ-001,
# PQ-002, PQ-007" and "Open Questions: None" simultaneously. Three statements,
# three different computations, no shared authority. Every assertion below
# pins one of them to the same source of truth.

write_pending_questions() {
  # $1 file; remaining args: "PQ-00N|STATUS|title"
  local file="$1"; shift
  cat > "$file" <<'PQHDR'
# Pending Questions

PQHDR
  local spec id st title rest
  for spec in "$@"; do
    id="${spec%%|*}"; rest="${spec#*|}"; st="${rest%%|*}"; title="${rest#*|}"
    cat >> "$file" <<PQE

### ${id} — ${title}

- **Status:** ${st}
- **Source:** fixture
- **Trigger:** T3
- **Blocks:** MOD-001
- **Evidence found:** fixture
- **Could not determine:** fixture
- **Candidates considered:** fixture
- **Proposed default (UNCONFIRMED):** fixture
PQE
  done
}

decisions_two() {
  cat > "$1" <<'EOF'
# Decisions: Fixture Project

## Decisions

### CQ-001 — Settled by promotion

- **Decision:** The recorded answer
- **Decided by:** Ada Okoro
- **Date:** 2026-08-19

### SQ-001 — Also settled

- **Decision:** The recorded answer
- **Decided by:** Ada Okoro
- **Date:** 2026-08-19
EOF
}

decisions_one() {
  cat > "$1" <<'EOF'
# Decisions: Fixture Project

## Decisions

### SQ-001 — Settled

- **Decision:** The recorded answer
- **Decided by:** Ada Okoro
- **Date:** 2026-08-19
EOF
}

# ── A resolved PQ must not be reported open, however loudly the prose
# mentions it. This is the exact reported bug. ───────────────────────────────
PQP="$(new_project pqresolved)"
PA="$PQP/.specclaw/analysis"
write_architecture "$PA/architecture.md"
write_module_map "$PA/module-map.md" "CONFIRMED by Ada Okoro, 2026-08-19"
start_clarifications "$PA/clarifications.md"
add_question "$PA/clarifications.md" "CQ-001" "Settled by promotion" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-19"
add_question "$PA/clarifications.md" "SQ-001" "Also settled" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-19"
decisions_two "$PA/decisions.md"
# PQ-001 promoted to a DECIDED CQ; PQ-002 withdrawn; PQ-007 genuinely open.
write_pending_questions "$PA/pending-questions.md" \
  "PQ-001|PROMOTED → CQ-001|An older annotation that has since been decided" \
  "PQ-002|WITHDRAWN|Retracted by its author" \
  "PQ-007|OPEN|A question nobody has answered"

D="$PA/.blueprint-draft.md"
PQROWS='| Client shell | Browser client | SQ-001 | DECIDED |
| Domain core | Application service | CQ-001 | DECIDED |'
blueprint_draft "$D" "$PQROWS" "$BOTH_MODULE_SECTIONS"
# Reference all three PQs in prose, exactly as a real draft does when it
# carries an annotation forward out of an older architecture.md.
sed -i 's|^Fixture overview\.$|Fixture overview. PQ-001 was resolved by CQ-001. PQ-002 was withdrawn. One area is PROVISIONAL(PQ-007).|' "$D"

OUT="$("$BLUEPRINT_BIN" render "$PQP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "0" "$RC" "a draft mentioning resolved PQs still renders"
DOC="$(cat "$PA/target-architecture.md")"
assert_not_contains "$DOC" "**Open pending questions:** PQ-001" "a PQ promoted to a DECIDED CQ is not reported open"
assert_not_contains "$DOC" "- **PQ-001**" "a resolved PQ is not listed under Open Questions"
assert_not_contains "$DOC" "- **PQ-002**" "a WITHDRAWN PQ is not listed under Open Questions"
assert_contains "$DOC" "**Open pending questions:** PQ-007" "the genuinely open PQ is reported, alone"
assert_contains "$DOC" "**Blueprint status:** PROVISIONAL" "an open PQ makes the blueprint PROVISIONAL, not COMPLETE"
assert_contains "$DOC" "unresolved blocking questions: PQ-007" "the status line names the open PQ"
assert_contains "$DOC" "- **PQ-007**" "the open PQ is listed in the Open Questions section"

# The three statements must agree — the reported bug was that they did not.
assert_eq "1" "$(printf '%s\n' "$DOC" | grep -c 'Open pending questions:' || true)" \
  "header carries exactly one open-pending-questions line"
assert_eq "0" "$(printf '%s\n' "$DOC" | grep -c '^None\.' || true)" \
  "Open Questions does not simultaneously claim None"

# ── A PQ id with no registry entry is refused, like an unknown CQ. ──────────
blueprint_draft "$D" "$PQROWS" "$BOTH_MODULE_SECTIONS"
sed -i 's|^Fixture overview\.$|Fixture overview. Something is PROVISIONAL(PQ-404).|' "$D"
OUT="$("$BLUEPRINT_BIN" render "$PQP/.specclaw" "$D" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a PQ id with no registry entry fails the run"
assert_contains "$OUT" "PQ-404" "the refusal names the untracked PQ id"

# ── Module map PROPOSED: warning preserved, no auto-confirmation, and the
# status says structurally-complete-but-not-accepted rather than COMPLETE. ──
MP="$(new_project mapproposed)"
MA="$MP/.specclaw/analysis"
write_architecture "$MA/architecture.md"
write_module_map "$MA/module-map.md" "PROPOSED — awaiting human confirmation"
start_clarifications "$MA/clarifications.md"
add_question "$MA/clarifications.md" "SQ-001" "Settled" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-19"
decisions_one "$MA/decisions.md"
MD="$MA/.blueprint-draft.md"
ROW='| Client shell | Browser client | SQ-001 | DECIDED |'
MAP_BEFORE="$(cat "$MA/module-map.md")"
blueprint_draft "$MD" "$ROW" "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$MP/.specclaw" "$MD" 2>&1)"; RC=$?
assert_eq "0" "$RC" "an unconfirmed map still renders (soft block, per the contract)"
DOC="$(cat "$MA/target-architecture.md")"
assert_contains "$DOC" "COMPLETE — PENDING MODULE-MAP CONFIRMATION" \
  "an unconfirmed map yields structurally-complete-but-not-accepted, never bare COMPLETE"
assert_contains "$DOC" "WARN — Status reads" "the unconfirmed-map warning is preserved"
assert_contains "$DOC" "human action this command never performs" "the warning says confirmation stays a human action"
assert_eq "$MAP_BEFORE" "$(cat "$MA/module-map.md")" "module-map.md is never auto-confirmed"
assert_contains "$DOC" "acceptance gate, not an unanswered question" \
  "Open Questions explains the status rather than contradicting it"

# Same project, map confirmed -> bare COMPLETE, no manual cleanup needed.
write_module_map "$MA/module-map.md" "CONFIRMED by Ada Okoro, 2026-08-20"
blueprint_draft "$MD" "$ROW" "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$MP/.specclaw" "$MD" 2>&1)"; RC=$?
DOC="$(cat "$MA/target-architecture.md")"
assert_eq "0" "$RC" "confirming the map and regenerating succeeds"
assert_contains "$DOC" "**Blueprint status:** COMPLETE" "a confirmed map with everything decided reads COMPLETE"
assert_not_contains "$DOC" "PENDING MODULE-MAP" "the pending-confirmation qualifier clears by regeneration alone"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Draft structure: markers, containment, and no detached content ───────"
# ════════════════════════════════════════════════════════════════════════════

SB="$(new_project structure)"
SA="$SB/.specclaw/analysis"
write_architecture "$SA/architecture.md"
write_module_map "$SA/module-map.md" "CONFIRMED by Ada Okoro, 2026-08-19"
start_clarifications "$SA/clarifications.md"
add_question "$SA/clarifications.md" "SQ-001" "Settled" "DECISION" "yes" "Chosen" "Ada Okoro" "2026-08-19"
decisions_one "$SA/decisions.md"
SD="$SA/.blueprint-draft.md"

# A missing marker used to be silent: the preceding section swallowed
# everything after it and content surfaced at the bottom of the document.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
grep -v '^<!-- SECTION: data_migration -->$' "$SD" > "$SD.tmp" && mv "$SD.tmp" "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a missing section marker fails the run instead of silently swallowing content"
assert_contains "$OUT" "missing section marker" "the refusal says a marker is missing"
assert_contains "$OUT" "data_migration" "the refusal names the missing marker"

# A duplicated marker.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
printf '\n<!-- SECTION: deployment -->\nduplicate\n' >> "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a duplicated section marker fails the run"
assert_contains "$OUT" "appears 2 times" "the refusal says how many times it appeared"

# Content before the first marker would be silently dropped.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
{ printf 'orphan preamble\n'; cat "$SD"; } > "$SD.tmp" && mv "$SD.tmp" "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "content before the first marker fails the run"
assert_contains "$OUT" "before the first section marker" "the refusal explains it would be dropped"

# THE REPORTED DEFECT: a module heading emitted outside component_sections.
# It used to satisfy the module gate (which counted '## MOD-' across the whole
# draft) and then render detached at the very bottom, under Open Questions.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
cat >> "$SD" <<'STRAY'

## MOD-002 — Edge

```mermaid
C4Component
  title stray
  Component(z, "Detached")
```
STRAY
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a module heading outside component_sections fails the run"
assert_contains "$OUT" "outside the component_sections block" "the refusal names the containment rule"
assert_contains "$OUT" "MOD-002" "the refusal names the detached module"

# And on a clean render, no module content may appear after the final section.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "0" "$RC" "a well-formed draft renders"
DOCF="$SA/target-architecture.md"
assert_eq "0" "$(sed -n '/^## Open Questions/,$p' "$DOCF" | grep -c '^## MOD-' || true)" \
  "no module section leaks past the final Open Questions section"
assert_eq "0" "$(sed -n '/^## Open Questions/,$p' "$DOCF" | grep -c '```mermaid' || true)" \
  "no diagram fence leaks past the final section"
assert_eq "$(grep -c '^## MOD-' "$DOCF" || true)" \
  "$(sed -n '/^## Components by Module/,/^## Legacy/p' "$DOCF" | grep -c '^## MOD-' || true)" \
  "every module heading stays inside its intended section"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Diagram validation: malformed Mermaid cannot render as success ───────"
# ════════════════════════════════════════════════════════════════════════════
#
# Stated limit: this is deterministic STRUCTURAL validation, not rendering.
# Full Mermaid needs a browser. A pass proves the source is well-formed; it
# does not prove Mermaid draws it. It fails only on what cannot be valid.

bad_module_sections() {
  printf '## MOD-001 — Core\n\n```mermaid\nC4Component\n  title MOD-001\n%s\n```\n\n## MOD-002 — Edge\n\n```mermaid\nC4Component\n  title MOD-002\n  Component(b, "Edge service")\n```\n' "$1"
}

blueprint_draft "$SD" "$ROW" "$(bad_module_sections '  Component(a, "Domain service)')"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "an unbalanced quote in a component label fails the run"
assert_contains "$OUT" "odd number of double quotes" "the refusal explains the unterminated label"
assert_contains "$OUT" "MOD-001" "the diagram refusal names the module"

blueprint_draft "$SD" "$ROW" "$(bad_module_sections '  Component(a, "Rooms (all types")')"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "an unbalanced parenthesis from a label fails the run"
assert_contains "$OUT" "parenthes" "the refusal explains the parenthesis rule"

blueprint_draft "$SD" "$ROW" "$(bad_module_sections '  Component(a, "Register / browse / fire tabs; no decorative") \')"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a truncated line ending in a backslash fails the run"
assert_contains "$OUT" "bare backslash" "the refusal names the truncation"

blueprint_draft "$SD" "$ROW" "$(bad_module_sections '  Component(a, "x")
  Syntax error in text')"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "Mermaid parser error text in the source fails the run"
assert_contains "$OUT" "parser error text" "the refusal says the error was copied in rather than fixed"

blueprint_draft "$SD" "$ROW" "$(bad_module_sections '  Container_Boundary(api, "API") {
  Component(a, "x")')"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "an unclosed boundary brace fails the run"
assert_contains "$OUT" "unbalanced braces" "the refusal names the unclosed block"

blueprint_draft "$SD" "$ROW" '## MOD-001 — Core

```mermaid
C4Component
```

## MOD-002 — Edge

```mermaid
C4Component
  title MOD-002
  Component(b, "Edge service")
```'
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a diagram with no element declarations fails the run"
assert_contains "$OUT" "no element declarations" "the refusal says the diagram is empty"

blueprint_draft "$SD" "$ROW" '## MOD-001 — Core

Prose only, no diagram.

## MOD-002 — Edge

```mermaid
C4Component
  title MOD-002
  Component(b, "Edge service")
```'
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a module with no mermaid block fails the run"
assert_contains "$OUT" "no \`\`\`mermaid block found" "the refusal names the missing diagram"
assert_contains "$OUT" "Do NOT delete a diagram" "the refusal forbids deleting diagrams to pass"

# The top-level Context/Container diagrams are validated too.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
sed -i 's|^  Person(u, "Operator")$|  Person(u, "Operator (primary")|' "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a malformed System Context diagram fails the run"
assert_contains "$OUT" "System Context diagram" "the refusal names which top-level diagram"

blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
sed -i 's|^C4Container$|NotADiagramType|' "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a diagram with an unrecognised opening type fails the run"
assert_contains "$OUT" "recognised type" "the refusal lists the accepted diagram types"

# And the clean case still renders, with no error text anywhere.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "0" "$RC" "well-formed diagrams render successfully"
DOCTXT="$(cat "$SA/target-architecture.md")"
assert_not_contains "$DOCTXT" "Syntax error in text" "no parser error text reaches the document"
assert_not_contains "$DOCTXT" "Cannot read properties of undefined" "no renderer crash text reaches the document"

# ════════════════════════════════════════════════════════════════════════════
echo
echo "── Provenance: one list, reflecting what the run actually read ──────────"
# ════════════════════════════════════════════════════════════════════════════

printf '# Domain Model: Fixture\n\n## Rules\n\n- DR-001 fixture rule.\n' > "$SA/domain-model.md"
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
sed -i 's|^decisions\.md$|decisions.md\ndomain-model.md|' "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "0" "$RC" "a draft declaring an extra consumed source renders"
assert_contains "$(cat "$SA/target-architecture.md")" "**Source documents consumed:**" "provenance is rendered under one heading"
assert_contains "$(cat "$SA/target-architecture.md")" "domain-model.md" "a document the agent actually read appears in provenance"
assert_eq "1" "$(grep -c 'Source documents' "$SA/target-architecture.md" || true)" \
  "there is exactly ONE provenance list, not two drifting ones"
assert_eq "0" "$(grep -c 'Inputs consumed' "$SA/target-architecture.md" || true)" \
  "the old second provenance list is gone"

# Not added unconditionally: a run that does not declare it does not claim it.
#
# Scoped to the provenance LINE, not the whole file. The template's own
# explanatory comment legitimately names domain-model.md while describing what
# the legacy side of the pipeline documents, and that comment is rendered into
# every blueprint by design. Grepping the whole document for a bare filename
# therefore tests the comment, not the claim — which is what this assertion
# used to do, and why it failed against a provenance line that was correct.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "0" "$RC" "a run that declares no extra source still renders"
PROV_LINE="$(grep -m1 '^\*\*Source documents consumed:' "$SA/target-architecture.md" || true)"
assert_not_contains "$PROV_LINE" "domain-model.md" \
  "a document the run did not read is NOT claimed as a source"
assert_contains "$PROV_LINE" "architecture.md" \
  "the provenance line still names what the run did read"

# A declared source that does not exist is refused.
blueprint_draft "$SD" "$ROW" "$BOTH_MODULE_SECTIONS"
sed -i 's|^decisions\.md$|decisions.md\nnot-a-real-document.md|' "$SD"
OUT="$("$BLUEPRINT_BIN" render "$SB/.specclaw" "$SD" 2>&1)"; RC=$?
assert_eq "1" "$RC" "a declared source that does not exist fails the run"
assert_contains "$OUT" "not-a-real-document.md" "the refusal names the phantom source"
# ════════════════════════════════════════════════════════════════════════════
echo
echo "── No stack knowledge in bash or templates ──────────────────────────────"
# ════════════════════════════════════════════════════════════════════════════
#
# The options a client chooses between are generated per run by the agent from
# this repo's own analysis. A product name baked into a collector or a template
# would turn that into a curated menu — the exact failure the design forbids —
# and would do it silently, because the output would still look plausible.

VIOLATIONS='(^|[^A-Za-z])(dotnet|postgres|mysql|sqlite|sqlserver|sql server|mongo|mongodb|azure|aws|react|vue|blazor|express|prisma|django|rails|spring|kubernetes|docker)([^A-Za-z]|$)'
HITS="$(grep -riEl "$VIOLATIONS" \
  "$PLUGIN_ROOT/bin/specclaw-bf-blueprint" \
  "$PLUGIN_ROOT/templates/target-architecture.md" \
  "$PLUGIN_ROOT/templates/options-pack.md" 2>/dev/null || true)"
assert_eq "" "$HITS" "no stack, vendor or framework name in the new collector or templates"

# The options-pack section of the clarify collector, likewise.
OPSEC="$(sed -n '/Options-pack support/,$p' "$CLARIFY_BIN")"
OPHITS="$(printf '%s' "$OPSEC" | grep -iEc "$VIOLATIONS" || true)"
assert_eq "0" "$OPHITS" "no stack name in the options-pack half of specclaw-bf-clarify"

# No new ID registry: the pack is keyed by SQ/CQ/UQ, the blueprint by MOD.
IDHITS="$(grep -rEc '\b(OP|BP)-[0-9]{3}\b' \
  "$PLUGIN_ROOT/bin/specclaw-bf-blueprint" "$CLARIFY_BIN" \
  "$PLUGIN_ROOT/templates/target-architecture.md" \
  "$PLUGIN_ROOT/templates/options-pack.md" 2>/dev/null | grep -v ':0$' || true)"
assert_eq "" "$IDHITS" "no new OP-/BP- ID family was invented"

echo
echo "──────────────────────────────────────────────────────────────────────────"
echo "  blueprint + options-pack suite: $PASS passed, $FAIL failed"
echo "──────────────────────────────────────────────────────────────────────────"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
