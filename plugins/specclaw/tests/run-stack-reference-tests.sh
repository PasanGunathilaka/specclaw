#!/usr/bin/env bash
# run-stack-reference-tests.sh — the stack-reference mechanism (references/stacks/)
# resolved on demand by bf-analyze, bf-domain and bf-architecture from the
# collector's existing `artifact_categories` facts.
#
# What this suite pins:
#   A. The registry (references/stacks/index.json) parses and every mapped file
#      exists.
#   B. The oracle-era predicates are exactly the approved ones — strong evidence,
#      never bare key-presence. A repo with only generic `.sql` must NOT resolve.
#   C. A generic, test-only predicate evaluator (NOT production logic — resolution
#      is the agent's job) proves the resolve/no-resolve outcome for each fixture.
#   D. The identical "Stack references" rule block is present in all three agents.
#   E. The conditional, additive A4 instruction is present in all three templates,
#      and the templates' heading inventory is byte-for-byte the pre-change set
#      (no new heading, so the no-reference report shape is unchanged — PD-04).
#   F. oracle-era.md carries all nine required headings, the two verbatim
#      insufficient-evidence sentences, and none of the prohibited target/
#      modernisation terms (PD-07).
#
# Bash + coreutils + jq. jq absent → skip with exit 0 (same tolerant pattern as
# the sibling suites).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STACKS_DIR="$PLUGIN_ROOT/references/stacks"
REGISTRY="$STACKS_DIR/index.json"
FIX="$SCRIPT_DIR/fixtures/stack-reference"
AGENTS="$PLUGIN_ROOT/agents"
TEMPLATES="$PLUGIN_ROOT/templates"

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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed — skipping stack-reference suite (exit 0)."
  exit 0
fi

# ── A generic, test-only predicate evaluator ────────────────────────────────
# Reads the registry and a fixture's artifact_categories, and prints the sorted
# list of resolved reference filenames (one per line). This is the executable
# spec of the predicate vocabulary the agents are told to evaluate; it lives ONLY
# in the test, never in a command or agent implementation (PD-02).
resolve_files() {
  local fixture="$1"
  jq -rn \
    --slurpfile reg "$REGISTRY" \
    --slurpfile fx "$fixture" '
    ($fx[0].artifact_categories // {}) as $ac
    | def present($n): ($ac | has($n));
      def ext_any($c; $es): (($ac[$c].by_extension // {}) | keys) as $k
                            | ($es | any(. as $e | $k | index($e)));
      def evalp($p):
        if   ($p.category_present)       then present($p.category_present)
        elif ($p.category_extension_any) then ext_any($p.category_extension_any.category;
                                                       $p.category_extension_any.extensions)
        elif ($p.all_of)                 then ($p.all_of | all(evalp(.)))
        else false end;
      [ $reg[0].stacks[] | select(.resolve_any | any(evalp(.))) | .file ]
      | sort | .[]' | tr -d '\r'
}

echo "=== A. Registry integrity ==="

if [ -f "$REGISTRY" ]; then ok "index.json exists"
else bad "index.json exists" "$REGISTRY missing"; fi

if jq empty "$REGISTRY" >/dev/null 2>&1; then ok "index.json is valid JSON"
else bad "index.json is valid JSON"; fi

# Every mapped file exists. (Strip CR — a Windows jq build emits CRLF in raw
# output; the committed blob is LF via .gitattributes, but a local run is not.)
missing=""
while IFS= read -r f; do
  f="${f%$'\r'}"
  [ -z "$f" ] && continue
  [ -f "$STACKS_DIR/$f" ] || missing="$missing $f"
done < <(jq -r '.stacks[].file' "$REGISTRY")
if [ -z "$missing" ]; then ok "every mapped reference file exists"
else bad "every mapped reference file exists" "missing:$missing"; fi

echo "=== B. oracle-era predicates are the approved strong-evidence set ==="

oracle_exts="$(jq -rc '
  .stacks[] | select(.id=="oracle-era") | .resolve_any[]
  | select(.category_extension_any.category=="database_source")
  | .category_extension_any.extensions | sort | join(",")' "$REGISTRY")"
assert_eq "fnc,pkb,pkh,pks,plb,pls,prc,tpb,tps" "$oracle_exts" \
  "database_source oracle extension list is exactly the approved nine"

# The generic .sql must never be an Oracle-resolving extension.
if printf '%s' "$oracle_exts" | grep -qw sql; then
  bad "generic .sql is NOT in the oracle extension list" "sql present"
else ok "generic .sql is NOT in the oracle extension list"; fi

has_forms="$(jq -r '[.stacks[] | select(.id=="oracle-era") | .resolve_any[]
  | select(.category_present=="forms_reports_binary")] | length' "$REGISTRY")"
assert_eq "1" "$has_forms" "forms_reports_binary presence is a resolving predicate"

# loader_control resolves only together with database_source, never alone.
loader_allof="$(jq -rc '
  .stacks[] | select(.id=="oracle-era") | .resolve_any[]
  | select(.all_of != null)
  | [.all_of[].category_present] | sort | join(",")' "$REGISTRY")"
assert_eq "database_source,loader_control" "$loader_allof" \
  "loader_control resolves only paired with database_source"

echo "=== C. Resolution outcomes over fixtures ==="

assert_eq "oracle-era.md" "$(resolve_files "$FIX/oracle-pkg.json")" \
  "database_source with .pkb/.pks resolves oracle-era"
assert_eq "oracle-era.md" "$(resolve_files "$FIX/forms-binary.json")" \
  "forms_reports_binary resolves oracle-era"
assert_eq "" "$(resolve_files "$FIX/generic-sql.json")" \
  "generic .sql only does NOT resolve oracle-era"
assert_eq "" "$(resolve_files "$FIX/ctl-only.json")" \
  "loader_control alone does NOT resolve oracle-era"
assert_eq "oracle-era.md" "$(resolve_files "$FIX/ctl-plus-sql.json")" \
  "loader_control + database_source resolves oracle-era"
assert_eq "" "$(resolve_files "$FIX/none.json")" \
  "empty artifact_categories resolves nothing (no-reference path)"

echo "=== D. The identical rule block is in all three agents ==="

for a in bf-codebase-analyst bf-domain-analyst bf-architecture-analyst; do
  if grep -qF "# Stack references" "$AGENTS/$a.md" \
     && grep -qF "references/stacks/index.json" "$AGENTS/$a.md" \
     && grep -qF "methodology only" "$AGENTS/$a.md"; then
    ok "$a.md carries the Stack references rule block"
  else
    bad "$a.md carries the Stack references rule block"
  fi
done

echo "=== E. Templates: conditional instruction + unchanged heading inventory ==="

for t in codebase-report architecture domain-model; do
  if grep -qF "Stack references applied:" "$TEMPLATES/$t.md"; then
    ok "$t.md carries the conditional Stack references instruction"
  else
    bad "$t.md carries the conditional Stack references instruction"
  fi
done

# The instruction lives inside an HTML comment, so it adds no heading. Assert the
# exact heading inventory (any `#`-level ATX heading) per template.
headings() { grep -E '^#{1,6} ' "$1"; }

expected_codebase='# Codebase Report: {{title}}
## Tech Stack
## Dependencies
## Structure/Architecture
## Domain
## Risks/Tech-Debt
## Suggested First Changes'
assert_eq "$expected_codebase" "$(headings "$TEMPLATES/codebase-report.md")" \
  "codebase-report.md heading inventory unchanged"

expected_arch='# Architecture Report: {{title}}
## System Context (L1)
## Containers (L2)
## Components (L3)
## Code (L4)'
assert_eq "$expected_arch" "$(headings "$TEMPLATES/architecture.md")" \
  "architecture.md heading inventory unchanged"

expected_domain='# Domain Model: {{title}}
## Entities
## Relationships
## Business Rules
## Enumerations'
assert_eq "$expected_domain" "$(headings "$TEMPLATES/domain-model.md")" \
  "domain-model.md heading inventory unchanged"

echo "=== F. oracle-era.md content ==="

ORACLE="$STACKS_DIR/oracle-era.md"
for h in \
  "1. Artifact map" \
  "2. Where the business rules usually are" \
  "3. Coupling and boundaries" \
  "4. Version and topology signals" \
  "5. Binary limitations" \
  "6. Guidance for bf-analyze" \
  "7. Guidance for bf-domain" \
  "8. Guidance for bf-architecture" \
  "9. Not in this file"; do
  if grep -qF "$h" "$ORACLE"; then ok "oracle-era.md has section: $h"
  else bad "oracle-era.md has section: $h"; fi
done

assert_contains "$(cat "$ORACLE")" \
  "Insufficient evidence to determine current runtime; signals:" \
  "oracle-era.md carries the section-4 runtime sentence"
assert_contains "$(cat "$ORACLE")" \
  "only binary artifact <path> is available." \
  "oracle-era.md carries the section-5 binary sentence"

# Prohibited target/modernisation terms (PD-07). Case-insensitive.
prohibited='migrate to|replace with|modernise to|modernize to|recommend|React|Spring|\.NET|APEX'
if grep -qniE "$prohibited" "$ORACLE"; then
  bad "oracle-era.md contains no prohibited target/modernisation term" \
      "$(grep -niE "$prohibited" "$ORACLE" | head -3)"
else
  ok "oracle-era.md contains no prohibited target/modernisation term"
fi

# ≤ 250 lines.
lc="$(grep -c '' "$ORACLE")"
if [ "$lc" -le 250 ]; then ok "oracle-era.md is within the 250-line cap ($lc)"
else bad "oracle-era.md is within the 250-line cap" "$lc lines"; fi

echo ""
echo "stack-reference: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
