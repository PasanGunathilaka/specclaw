#!/usr/bin/env bash
# run-pending-question-contract-tests.sh — the contract between the PQ entries
# the analysis agents (bf-domain-analyst, bf-architecture-analyst,
# bf-ui-analyst, bf-rebuild-planner, bf-baseline-designer) append to
# .specclaw/analysis/pending-questions.md and the parser
# `specclaw-bf-clarify collect` reads back out of it.
#
# WHY THIS SUITE EXISTS. Each agent writes a PQ block as prose-with-structure;
# bash reads it back field by field into the JSON the ingestion step consumes.
# That split is what lets an agent "ask, don't guess" without a human in the
# loop at write time — but it also means the two halves can drift apart
# silently. The failure mode is not an error: it is a PQ whose Proposed default
# survives into clarifications.md as an empty string, so the human is asked a
# question stripped of the very default the agent reasoned out.
#
# The bug this suite pins: `bank_field_multiline` builds a *dynamic awk regex*
# from the field label, so a label carrying regex metacharacters —
# "Proposed default (UNCONFIRMED)", whose parens awk reads as a group — matched
# nothing and returned "". Every OPEN PQ lost its proposed default. The fix
# escapes metacharacters in the label; this suite runs the REAL parser against
# a PQ written the way the agents are instructed to write one and asserts the
# default survives, while the malformed shapes the agents are warned against
# still drop out exactly as before.
#
# Bash + coreutils + jq.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CLARIFY_BIN="$PLUGIN_ROOT/bin/specclaw-bf-clarify"
PQ_TEMPLATE="$PLUGIN_ROOT/templates/pending-questions.md"
AGENTS_DIR="$PLUGIN_ROOT/agents"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL — $1"; [ $# -gt 1 ] && echo "         $2"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then ok "$label"
  else bad "$label" "expected [$expected], got [$actual]"; fi
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed — skipping pending-question contract suite (exit 0)."
  exit 0
fi
[ -f "$CLARIFY_BIN" ] || { echo "parser missing: $CLARIFY_BIN"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SPEC="$WORK/.specclaw"
mkdir -p "$SPEC/analysis"
# collect needs at least one analysis document present to run at all.
printf '# Domain Model\n\nstub — presence is all this suite needs.\n' \
  > "$SPEC/analysis/domain-model.md"

collect() { bash "$CLARIFY_BIN" collect "$SPEC" 2>/dev/null; }

echo "== A well-formed PQ round-trips every field, proposed default included =="

# Written exactly the way each agent is instructed to write one: a "### PQ-NNN"
# heading, every field as its own "- **Field:**" bullet, and the proposed
# default under the parenthesised label the template and parser share.
cat > "$SPEC/analysis/pending-questions.md" <<'EOF'
# Pending Questions

### PQ-001 — Should archived orders remain editable?

- **Status:** OPEN
- **Source:** /specclaw:bf-domain (bf-domain-analyst)
- **Trigger:** T3
- **Blocks:** DR-012
- **Evidence found:** OrderService.cs:88 edits with no status guard
- **Could not determine:** whether that is intentional
- **Candidates considered:** lock on archive; allow with a warning
- **Proposed default (UNCONFIRMED):** lock on archive — safest for auditability
EOF

J="$(collect)"
assert_eq "1" "$(printf '%s' "$J" | jq -r '.pending_questions.open_count')" \
  "the OPEN PQ is ingested"
assert_eq "PQ-001" "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].pq_id')" \
  "…with its id"
# The bug: this field came back "" for every PQ before the label-escape fix.
assert_eq "lock on archive — safest for auditability" \
  "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].proposed_default')" \
  "the Proposed default (UNCONFIRMED) survives rather than being silently dropped"
# Regression guard: labels WITHOUT metacharacters must still parse unchanged.
assert_eq "T3" "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].trigger')" \
  "a plain-label field (Trigger) still parses"
assert_eq "DR-012" "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].blocks')" \
  "…and Blocks"
assert_eq "lock on archive; allow with a warning" \
  "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].candidates_considered')" \
  "…and Candidates considered"
assert_eq "OrderService.cs:88 edits with no status guard" \
  "$(printf '%s' "$J" | jq -r '.pending_questions.open[0].evidence_found')" \
  "…and Evidence found"

echo
echo "== Malformed PQ shapes the agents are warned against still drop out =="

# A "##" heading (two hashes) is not a PQ block start — split keys on "### PQ".
cat > "$SPEC/analysis/pending-questions.md" <<'EOF'
# Pending Questions

## PQ-002 — Wrong heading level, two hashes

- **Status:** OPEN
- **Proposed default (UNCONFIRMED):** anything
EOF
assert_eq "0" "$(collect | jq -r '.pending_questions.open_count')" \
  "a '##' heading is not ingested (the agents' 'three hashes' rule bites)"

# Status written as plain text, not a "- **Status:**" bullet — read as not-OPEN.
cat > "$SPEC/analysis/pending-questions.md" <<'EOF'
# Pending Questions

### PQ-003 — Status is plain text, not a bullet

Status: OPEN
- **Proposed default (UNCONFIRMED):** anything
EOF
assert_eq "0" "$(collect | jq -r '.pending_questions.open_count')" \
  "a plain 'Status:' line (not a '- **Status:**' bullet) is skipped as not-OPEN"

# A non-OPEN status is honoured, not force-ingested.
cat > "$SPEC/analysis/pending-questions.md" <<'EOF'
# Pending Questions

### PQ-004 — Already promoted

- **Status:** PROMOTED → CQ-009
- **Proposed default (UNCONFIRMED):** anything
EOF
assert_eq "0" "$(collect | jq -r '.pending_questions.open_count')" \
  "a PROMOTED PQ is not re-ingested as OPEN"

echo
echo "== The fix is a generic label escape, not a special case =="

# The escape must cover regex metacharacters as a class, so ANY label the parser
# reads is matched literally — not a one-off unquoting of the word UNCONFIRMED.
if grep -q 'gsub(/\[.*()' "$CLARIFY_BIN" || grep -q 'gsub(/\[\]\[' "$CLARIFY_BIN"; then
  ok "bank_field_multiline escapes label metacharacters generically"
else
  bad "bank_field_multiline escapes label metacharacters generically" \
    "no metacharacter-class gsub found in $CLARIFY_BIN"
fi
assert_eq "1" \
  "$(grep -c 'bank_field_multiline "$pf" "Proposed default (UNCONFIRMED)"' "$CLARIFY_BIN")" \
  "the parser still reads the parenthesised label the template documents"

echo
echo "== Template and every emitting agent agree on the format the parser reads =="

grep -q 'Proposed default (UNCONFIRMED)' "$PQ_TEMPLATE" \
  && ok "template documents the 'Proposed default (UNCONFIRMED)' label" \
  || bad "template documents the 'Proposed default (UNCONFIRMED)' label" "not in $PQ_TEMPLATE"

for a in bf-domain-analyst bf-architecture-analyst bf-ui-analyst bf-rebuild-planner bf-baseline-designer; do
  f="$AGENTS_DIR/$a.md"
  if [ ! -f "$f" ]; then bad "$a references the parenthesised label" "missing $f"; continue; fi
  grep -q 'Proposed default (UNCONFIRMED)' "$f" \
    && ok "$a emits the 'Proposed default (UNCONFIRMED)' label the parser reads" \
    || bad "$a emits the 'Proposed default (UNCONFIRMED)' label the parser reads" "not in $f"
done

echo
echo "pending-question contract suite: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
