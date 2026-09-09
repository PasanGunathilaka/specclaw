#!/usr/bin/env bash
# run-capability-selection-tests.sh — regression suite for the CAP-### half of
# the acceptance basis: the id family, the selection join, and the verdict a
# capability-coverage classification gates.
#
#   - CAP-### roster extraction and id permanence (tombstones count toward the
#     next free id; the template comment's EXAMPLE ids never leak in)
#   - the union {DR-###, CAP-###} selection join, at every scope
#   - the paired-widening invariant: the two scripts that compute the two
#     halves of `--item`'s selection agree, byte for byte, on both the FILTER
#     (what the acceptance basis is) and the FAMILIES (which ids count)
#   - the acceptance-basis filter: "Maps to capability:" and human status
#     notes are DESCRIPTIVE and never enter the basis
#   - the classification-gated verdict, all four corners: exit 0 only behind a
#     complete classification with a recorded reason; zero fixtures found is
#     never, by itself, success
#   - backward compatibility: a pre-schema-4 manifest still resolves
#
# Every one of these is bash/jq computing a fact from declared data. Two of
# them exist because the first implementation was silently WRONG in a way no
# amount of reading caught: jq's scan() returns the captures rather than the
# match when the regex carries a capture group, so the widened join matched
# nothing at all while looking correct.
#
# Bash + coreutils + jq (the artifacts under test are nested JSON).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_BIN="$PLUGIN_ROOT/bin/specclaw-bf-baseline"
REPLAY_BIN="$PLUGIN_ROOT/bin/specclaw-bf-replay"
DOMAIN_BIN="$PLUGIN_ROOT/bin/specclaw-bf-domain-collect"
REBUILD_BIN="$PLUGIN_ROOT/bin/specclaw-bf-rebuild-collect"
FSPEC_TPL="$PLUGIN_ROOT/templates/functional-spec.md"
SCEN_TPL="$PLUGIN_ROOT/templates/scenarios.md"

PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL — $1"; [ $# -gt 1 ] && echo "         $2"; }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then ok "$desc"
  else bad "$desc" "expected [${expected}] got [${actual}]"; fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  case "$haystack" in
    *"$needle"*) ok "$desc" ;;
    *) bad "$desc" "output did not contain [${needle}]" ;;
  esac
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The four classification functions and the two basis helpers are exercised
# through a harness rather than the full CLI: they are pure text readers, and
# driving them through `resolve` would need a manifest, a backlog, a change
# folder and a captured fixture set to assert one grep.
harness() {
  local out="$T/harness.sh"
  {
    sed -n '/^strip_html_comments() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^classified_not_replayable_caps() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^basis_is_wholly_not_replayable() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^not_replayable_reason() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^strip_non_basis_fields() {/,/^}/p' "$REPLAY_BIN"
  } | tr -d '\r' > "$out"
  printf '%s' "$out"
}
HARNESS="$(harness)"

# ─────────────────────────────────────────────────────────────────────────────
echo "== the duplicated-helper identity (context.md convention) =="
#
# These are standalone executables with no sourcing convention between them,
# so the repo keeps deliberate copies byte-identical and pins the identity
# here. This is not tidiness: specclaw-bf-replay and
# specclaw-bf-rebuild-collect compute the two halves of a tested invariant
# (`--item BL-020`'s selection must equal the backlog's own Verification
# fixture list for BL-020), and that equality holds only while both agree on
# what the basis IS and which ids count.

fn_hash() { sed -n "/^$2() {/,/^}/p" "$1" | tr -d '\r' | md5sum | cut -d' ' -f1; }

for fn in strip_non_basis_fields extract_basis_ids; do
  a="$(fn_hash "$REPLAY_BIN" "$fn")"; b="$(fn_hash "$REBUILD_BIN" "$fn")"
  assert_eq "${fn} is byte-identical in replay and rebuild-collect" "$a" "$b"
  # Guards the assertion above against being vacuously true: two failed
  # extractions both hash the empty string and would "match".
  if [ -n "$a" ] && [ "$a" != "d41d8cd98f00b204e9800998ecf8427e" ]; then
    ok "${fn} was actually found in both (not two empty matches)"
  else
    bad "${fn} extraction produced nothing — the identity assertion above is vacuous"
  fi
done

for fn in classified_not_replayable_caps basis_is_wholly_not_replayable not_replayable_reason; do
  assert_eq "${fn} is byte-identical in replay and rebuild-collect" \
    "$(fn_hash "$REPLAY_BIN" "$fn")" "$(fn_hash "$REBUILD_BIN" "$fn")"
done

assert_eq "strip_html_comments is byte-identical across all three carriers" \
  "$(fn_hash "$REPLAY_BIN" strip_html_comments)$(fn_hash "$BASELINE_BIN" strip_html_comments)" \
  "$(fn_hash "$DOMAIN_BIN" strip_html_comments)$(fn_hash "$DOMAIN_BIN" strip_html_comments)"

assert_eq "BASIS_ID_RE is identical in both scripts" \
  "$(grep -h '^BASIS_ID_RE=' "$REPLAY_BIN" | tr -d '\r')" \
  "$(grep -h '^BASIS_ID_RE=' "$REBUILD_BIN" | tr -d '\r')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the two regex spellings are NOT interchangeable =="
#
# jq's scan() returns THE CAPTURES, not the match, as soon as the regex holds
# a capture group. grep -o is immune. So the bash constant may use (DR|CAP)
# while every jq site MUST use (?:DR|CAP) — and the failure mode of getting it
# wrong is silent: every join matches nothing and no error is raised anywhere.

assert_eq "jq scan with a capturing group truncates ids to the family prefix" \
  '[["DR"],["CAP"]]' \
  "$(printf '"DR-001 CAP-007"' | jq -c '[scan("(DR|CAP)-[0-9]{3}")]')"
assert_eq "jq scan with a NON-capturing group returns whole ids" \
  '["DR-001","CAP-007"]' \
  "$(printf '"DR-001 CAP-007"' | jq -c '[scan("(?:DR|CAP)-[0-9]{3}")]')"
assert_eq "grep -oE is immune to the same group, so the bash form is safe" \
  "DR-001 CAP-007" \
  "$(printf 'DR-001 CAP-007\n' | grep -oE '(DR|CAP)-[0-9]{3}' | paste -sd' ' -)"
# Comment lines are excluded deliberately: the constant's own documentation
# quotes the capturing form as the example of what NOT to write, and a naive
# grep counts that as a violation.
assert_eq "no live jq scan() site in replay uses the capturing form" "0" \
  "$(grep -v '^[[:space:]]*#' "$REPLAY_BIN" | grep -c 'scan("(DR|CAP)' | tr -d ' \r')"
assert_eq "the capturing form does still appear, as documentation" "1" \
  "$(grep -c '^[[:space:]]*#.*scan("(DR|CAP)' "$REPLAY_BIN" | tr -d ' \r')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== CAP-### roster extraction and id permanence =="

R="$T/roster"; mkdir -p "$R/.specclaw/analysis" "$R/src"
printf 'class Foo { }\n' > "$R/src/foo.cs"
{
  printf '# Functional Spec\n\n## Capabilities\n\n'
  # The REAL template comment, which documents the shape by example and so
  # carries CAP-014/CAP-015 inside it. A roster that counted those would hand
  # the agent ids the document does not use.
  sed -n '/^<!--$/,/^-->$/p' "$FSPEC_TPL"
  printf '\n1. **CAP-007 — Create a PO** — File > New\n'
  printf '2. **CAP-003 — Delete a customer** — grid context menu\n'
  printf '3. **CAP-012 — WITHDRAWN 2026-09-01, screen removed**\n\n## Workflows\n\nnone\n'
} > "$R/.specclaw/analysis/functional-spec.md"

roster="$(cd "$R" && bash "$DOMAIN_BIN" collect .specclaw . 2>/dev/null)"
assert_eq "next_cap_id counts the tombstone, and ignores the template examples" \
  "CAP-013" "$(printf '%s' "$roster" | jq -r '.capabilities.next_cap_id')"
assert_eq "the roster holds exactly the three real capabilities" "3" \
  "$(printf '%s' "$roster" | jq '.capabilities.prior_capabilities | length')"
assert_eq "ids are reported in document order, not sorted" "CAP-007,CAP-003,CAP-012" \
  "$(printf '%s' "$roster" | jq -r '[.capabilities.prior_capabilities[].cap_id] | join(",")')"
assert_eq "the tombstone is reported withdrawn, never omitted" "withdrawn" \
  "$(printf '%s' "$roster" | jq -r '.capabilities.prior_capabilities[] | select(.cap_id=="CAP-012") | .status')"
assert_eq "an example id from the template comment is absent from the roster" "0" \
  "$(printf '%s' "$roster" | jq '[.capabilities.prior_capabilities[] | select(.cap_id=="CAP-014" or .cap_id=="CAP-015")] | length')"

rm -f "$R/.specclaw/analysis/functional-spec.md"
roster2="$(cd "$R" && bash "$DOMAIN_BIN" collect .specclaw . 2>/dev/null)"
assert_eq "an absent functional-spec.md is a first-ever generation, not an error" "CAP-001" \
  "$(printf '%s' "$roster2" | jq -r '.capabilities.next_cap_id')"
assert_eq "and reports present:false rather than failing" "false" \
  "$(printf '%s' "$roster2" | jq -r '.capabilities.present')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the acceptance-basis filter =="

cat > "$T/backlog.md" <<'EOF'
### BL-020 — Purchase order form

**Module:** MOD-001
**Maps to capability:** CAP-099 — Create a purchase order
**Depends on:** None
**Acceptance basis (domain-model.md, functional-spec.md):**
- DR-001: a thing must hold
- CAP-007: the field set round-trips

**Verification inputs needed:**
- golden-master capture

**Gate:** CLEAR
**Verification:** VERIFIABLE — fixtures: GM-001 (abc123)
**Status notes (human-added):** also touches DR-042 and CAP-055 someday
EOF

basis="$(bash -c ". '$HARNESS'; tail -n +2 '$T/backlog.md' | strip_non_basis_fields \
  | grep -oE '(DR|CAP)-[0-9]{3}' | sort -u | paste -sd, -")"
assert_eq "the basis is exactly what the Acceptance basis field declares" \
  "CAP-007,DR-001" "$basis"
assert_contains "a CAP in 'Maps to capability' never enters the basis" \
  "|$basis|" "|CAP-007,DR-001|"
assert_eq "an id in a human status note never enters the basis" "0" \
  "$(printf '%s' "$basis" | grep -cE 'DR-042|CAP-055' | tr -d ' \r')"
assert_eq "and the Verification line's own GM id never does either" "0" \
  "$(printf '%s' "$basis" | grep -c 'GM-001' | tr -d ' \r')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the union selection join, at every scope =="

cat > "$T/man.json" <<'EOF'
{"manifest_schema":4,"fixtures":[
 {"scenario_id":"GM-001","business_rules_pinned":"DR-001","capabilities_pinned":"","module_ids":["MOD-001"]},
 {"scenario_id":"GM-002","business_rules_pinned":"","capabilities_pinned":"CAP-007","module_ids":["MOD-002"]},
 {"scenario_id":"GM-003","business_rules_pinned":"DR-009","capabilities_pinned":"CAP-012","module_ids":["MOD-001","MOD-002"]},
 {"scenario_id":"GM-004","business_rules_pinned":"DR-055","capabilities_pinned":"","module_ids":[]}
]}
EOF

sel() {
  jq -r --arg drs "$1" '
    ($drs | [scan("(?:DR|CAP)-[0-9]{3}")]) as $want
    | [ .fixtures[]
        | select( (((.business_rules_pinned // "") + " " + (.capabilities_pinned // ""))
                   | [scan("(?:DR|CAP)-[0-9]{3}")])
                  | any(. as $p | $want | index($p)) ) ]
    | map(.scenario_id) | join(",")' "$2"
}

assert_eq "item scope: a capability-only basis selects the DR-less fixture" \
  "GM-002" "$(sel 'CAP-007' "$T/man.json")"
assert_eq "item scope: a DR-only basis is unchanged by the widening" \
  "GM-001" "$(sel 'DR-001' "$T/man.json")"
assert_eq "item scope: a mixed basis selects both" \
  "GM-001,GM-002" "$(sel 'DR-001,CAP-007' "$T/man.json")"
assert_eq "item scope: a fixture pinning both families is selected by either" \
  "GM-003" "$(sel 'CAP-012' "$T/man.json")"
assert_eq "item scope: an id nothing pins selects nothing (a real answer)" \
  "" "$(sel 'CAP-999' "$T/man.json")"

assert_eq "module scope: a DR-less fixture is selected by the module owning its capability" \
  "GM-002,GM-003" \
  "$(jq -r --arg m MOD-002 '[.fixtures[] | select((.module_ids // []) | index($m))] | map(.scenario_id) | join(",")' "$T/man.json")"
assert_eq "all scope: a DR-less fixture is in the corpus with no join at all" "1" \
  "$(jq '[.fixtures[] | select(.scenario_id=="GM-002")] | length' "$T/man.json")"

jq 'del(.fixtures[].capabilities_pinned) | .manifest_schema=3' "$T/man.json" > "$T/man3.json"
assert_eq "a pre-schema-4 manifest (no capabilities_pinned at all) still resolves a DR basis" \
  "GM-001" "$(sel 'DR-001' "$T/man3.json")"
assert_eq "and yields nothing for a capability basis rather than erroring" \
  "" "$(sel 'CAP-007' "$T/man3.json")"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the classification-gated verdict, all four corners =="
#
# ZERO FIXTURES FOUND IS NEVER, BY ITSELF, SUCCESS. The absence of a fixture
# is the symptom both outcomes share; the classification is the only thing
# separating a decision from an omission.

mk_scen() { printf '# Baseline Scenarios\n\n## Capability Coverage Check\n\n%s\n' "$1" > "$T/scen.md"; }
verdict() { bash -c ". '$HARNESS'; basis_is_wholly_not_replayable '$T/scen.md' '$1'" 2>/dev/null; }
rc_of()   { bash -c ". '$HARNESS'; basis_is_wholly_not_replayable '$T/scen.md' '$1' >/dev/null" 2>/dev/null; echo $?; }

mk_scen "CAP-014 — NOT-REPLAYABLE: human UI sign-off via SCR-004
CAP-015 — NOT-REPLAYABLE: layout only, no seam observes it"
assert_eq "a fully classified capability basis qualifies for exit 0" "0" "$(rc_of 'CAP-014,CAP-015')"
assert_eq "and names every classified id for the verdict line" "CAP-014, CAP-015" "$(verdict 'CAP-014,CAP-015')"
assert_contains "the recorded reason is read back for the message" \
  "$(bash -c ". '$HARNESS'; not_replayable_reason '$T/scen.md' CAP-014")" "human UI sign-off"

mk_scen "CAP-014 — NOT-REPLAYABLE: human UI sign-off
CAP-015 — covered by GM-031"
assert_eq "a PARTIALLY classified basis gates (all-of, never any-of)" "1" "$(rc_of 'CAP-014,CAP-015')"

mk_scen "CAP-014 — NOT-REPLAYABLE:
CAP-015 — NOT-REPLAYABLE:     "
assert_eq "an empty or whitespace-only reason reads as unclassified" "1" "$(rc_of 'CAP-014,CAP-015')"

mk_scen "CAP-014 — covered by GM-001"
assert_eq "an unclassified capability basis keeps gating" "1" "$(rc_of 'CAP-014')"

mk_scen "CAP-014 — NOT-REPLAYABLE: human UI sign-off"
assert_eq "a basis citing any DR rule is disqualified outright" "1" "$(rc_of 'DR-001,CAP-014')"
assert_eq "an empty basis qualifies for nothing" "1" "$(rc_of '')"

# The template documents this very section BY EXAMPLE, and its comment holds
# NOT-REPLAYABLE text. Counting that would hand exit 0 to an item whose
# capability nobody ever classified.
{
  printf '# Baseline Scenarios\n\n## Capability Coverage Check\n\n'
  sed -n '/^## Capability Coverage Check/,$p' "$SCEN_TPL" | sed -n '/<!--/,/-->/p'
  printf '\nCAP-014 — covered by GM-001\n'
} > "$T/scen.md"
assert_eq "the template comment carries an example classification" "1" \
  "$([ "$(grep -c 'NOT-REPLAYABLE' "$T/scen.md")" -gt 0 ] && echo 1 || echo 0)"
assert_eq "but no example is read as a real classification" "" \
  "$(bash -c ". '$HARNESS'; classified_not_replayable_caps '$T/scen.md' | paste -sd, -")"
assert_eq "so an item citing an example id still gates" "1" "$(rc_of 'CAP-015')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== record writes the manifest half of the basis =="

B="$T/rec"; mkdir -p "$B/.specclaw/baseline/fixtures" "$B/.specclaw/analysis"
cat > "$B/.specclaw/baseline/scenarios.md" <<'EOF'
### GM-001 — capability round-trip

- **Seam:** Svc.Do
- **Seam layer:** service
- **Business rules pinned:** none
- **Capabilities pinned:** CAP-007
- **Verifies backlog item:** BL-002 — thing
EOF
cat > "$B/.specclaw/baseline/fixtures/GM-001.json" <<'EOF'
{"scenario_id":"GM-001","captured_at":"2026-09-01T00:00:00Z","anchor_date":"2026-09-01",
 "legacy_commit_sha":"abc","runtime_version":"1.0","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false}}
EOF
printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-007 — Create a PO** — File > New\n' \
  > "$B/.specclaw/analysis/functional-spec.md"

out="$(bash "$BASELINE_BIN" record "$B/.specclaw" 2>&1)"; rc=$?
assert_eq "a valid capability pin records cleanly" "0" "$rc"
assert_eq "the manifest stamps schema 4" "4" \
  "$(jq -r '.manifest_schema' "$B/.specclaw/baseline/manifest.json")"
assert_eq "and carries capabilities_pinned verbatim" "CAP-007" \
  "$(jq -r '.fixtures[0].capabilities_pinned' "$B/.specclaw/baseline/manifest.json")"

sed -i 's/CAP-007/CAP-999/' "$B/.specclaw/baseline/scenarios.md"
out="$(bash "$BASELINE_BIN" record "$B/.specclaw" 2>&1)"; rc=$?
assert_eq "a pin naming no capability fails the record" "1" "$rc"
assert_contains "and names the offending id" "$out" "CAP-999"

sed -i 's/CAP-999/CAP-007/' "$B/.specclaw/baseline/scenarios.md"
printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-007 — WITHDRAWN 2026-09-01, removed**\n' \
  > "$B/.specclaw/analysis/functional-spec.md"
out="$(bash "$BASELINE_BIN" record "$B/.specclaw" 2>&1)"; rc=$?
assert_eq "pinning a TOMBSTONED capability fails too — a claimed id verifies nothing" "1" "$rc"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "Passed: ${PASS}   Failed: ${FAIL}"
[ "$FAIL" -eq 0 ] || exit 1
