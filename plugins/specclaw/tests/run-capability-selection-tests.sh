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
    sed -n '/^cap_roster_lines() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^capability_coverage_section() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^classified_not_replayable_caps() {/,/^}/p' "$REPLAY_BIN"
    sed -n '/^covered_caps() {/,/^}/p' "$REPLAY_BIN"
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
EMPTY_MD5="d41d8cd98f00b204e9800998ecf8427e"

# ONE data-driven table: function, then every script that carries it. Adding a
# carrier is one word. An earlier hand-written version pinned
# strip_html_comments across "all three carriers" while there were FOUR, and
# left cap_roster_lines pinned by nothing at all even though the code claimed
# this suite asserted it — a comment asserting a test that does not exist is
# worse than no comment.
#
# The vacuity guard is applied to EVERY row, not just the first two: two
# failed extractions both hash the empty string, so a renamed function would
# otherwise make the assertion compare "" to "" and pass.
identity_rows=(
  "strip_non_basis_fields|REPLAY REBUILD"
  "extract_basis_ids|REPLAY REBUILD"
  "strip_html_comments|REPLAY REBUILD BASELINE DOMAIN"
  "cap_roster_lines|REPLAY REBUILD BASELINE DOMAIN"
  "capability_coverage_section|REPLAY REBUILD"
  "classified_not_replayable_caps|REPLAY REBUILD"
  "covered_caps|REPLAY REBUILD"
  "basis_is_wholly_not_replayable|REPLAY REBUILD"
  "not_replayable_reason|REPLAY REBUILD"
)
bin_for() {
  case "$1" in
    REPLAY)   printf '%s' "$REPLAY_BIN" ;;
    REBUILD)  printf '%s' "$REBUILD_BIN" ;;
    BASELINE) printf '%s' "$BASELINE_BIN" ;;
    DOMAIN)   printf '%s' "$DOMAIN_BIN" ;;
  esac
}
for row in "${identity_rows[@]}"; do
  fn="${row%%|*}"; carriers="${row#*|}"
  ref=""; ref_name=""; mismatch=""; vacuous=false
  for c in $carriers; do
    h="$(fn_hash "$(bin_for "$c")" "$fn")"
    if [ -z "$h" ] || [ "$h" = "$EMPTY_MD5" ]; then vacuous=true; fi
    if [ -z "$ref" ]; then ref="$h"; ref_name="$c"
    elif [ "$h" != "$ref" ]; then mismatch="${mismatch}${mismatch:+, }${c}"; fi
  done
  if $vacuous; then
    bad "${fn}: extraction produced nothing in at least one carrier — the identity check would be vacuous"
  elif [ -n "$mismatch" ]; then
    bad "${fn}: differs from ${ref_name} in ${mismatch}"
  else
    ok "${fn} is byte-identical across $(printf '%s' "$carriers" | wc -w | tr -d ' ') carriers"
  fi
done

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

# These assertions drive the REAL `specclaw-bf-replay resolve`, never a local
# copy of its jq. That distinction is the whole value of this group: an earlier
# draft of this suite re-implemented the selection expression here, so it
# asserted that a hand-written query behaved correctly while production could
# have been broken (or absent) and every test would still have passed. A test
# that duplicates the logic under test verifies the duplicate.
# GM-001's "Verifies backlog item" is deliberately BL-099, NOT BL-020. It pins
# DR-001, which BL-020's acceptance basis does not cite, so naming BL-020 there
# would make the document self-inconsistent — and would then fail AC-5 for a
# reason that has nothing to do with capabilities:
# specclaw-bf-rebuild-collect:2608 ORs that field in as a JOIN KEY
# (`[ "${GM_ITEM[$gid]}" = "$id" ] && touches=true`) while CONTRACT.md and
# specclaw-bf-replay both state it is "metadata, and a cross-check only — never
# a join key". That divergence is real and PRE-EXISTING; it is recorded as a
# finding for its own change rather than smuggled into this one. This fixture
# keeps the document well-formed so AC-5 tests the invariant it claims to.
seed_cap_replay() {
  local root="$1"
  rm -rf "$root"
  mkdir -p "$root/.specclaw/baseline/fixtures" "$root/.specclaw/analysis" "$root/.specclaw/changes/po-form"

  # GM-001 pins a rule only; GM-002 pins a CAPABILITY only — the case the
  # whole change exists for; GM-003 pins both and so spans two modules.
  cat > "$root/.specclaw/baseline/scenarios.md" <<'SCEOF'
### GM-001 — rule only

- **Seam:** Svc.Do
- **Seam layer:** service
- **Modules:** MOD-001
- **Business rules pinned:** DR-001
- **Verifies backlog item:** BL-099 — other

### GM-002 — capability only

- **Seam:** Svc.Save
- **Seam layer:** persistence
- **Modules:** MOD-002
- **Business rules pinned:** none
- **Capabilities pinned:** CAP-007
- **Verifies backlog item:** BL-020 — po form

### GM-003 — both families

- **Seam:** Svc.Both
- **Seam layer:** service
- **Modules:** MOD-001, MOD-002
- **Business rules pinned:** DR-009
- **Capabilities pinned:** CAP-012
- **Verifies backlog item:** BL-021 — other
SCEOF

  local gm
  for gm in GM-001 GM-002 GM-003; do
    cat > "$root/.specclaw/baseline/fixtures/${gm}.json" <<FXEOF
{"scenario_id":"${gm}","captured_at":"2026-09-01T00:00:00Z","anchor_date":"2026-09-01",
 "legacy_commit_sha":"abc","runtime_version":"1.0","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false}}
FXEOF
  done

  printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-007 — Create a PO** — File > New\n2. **CAP-012 — Amend a PO** — Edit menu\n' \
    > "$root/.specclaw/analysis/functional-spec.md"
  printf '# Module Map\n\n**Status:** CONFIRMED by t, 2026-09-01\n\n## Modules\n\n### MOD-001 — Rules\n- **Business rules:** DR-001, DR-009\n\n### MOD-002 — Forms\n- **Owns (capabilities):** CAP-007, CAP-012\n' \
    > "$root/.specclaw/analysis/module-map.md"
  printf 'DR-001 DR-009\n' > "$root/.specclaw/analysis/domain-model.md"

  # BL-020's basis cites a CAPABILITY and no rule. Its "Maps to capability"
  # names a DIFFERENT id on purpose: that field is descriptive and must never
  # reach the basis, so if the filter regressed this item would also select
  # GM-003 via CAP-012.
  cat > "$root/.specclaw/analysis/rebuild-backlog.md" <<'BLEOF'
### BL-020 — po form

- **Module:** MOD-002
- **Maps to capability:** CAP-012 — Amend a PO
- **Acceptance basis (domain-model.md, functional-spec.md):**
  - CAP-007: the form field set round-trips.
- **Depends on:** None
BLEOF
  printf 'Rebuild-backlog item BL-020 — po form.\n' > "$root/.specclaw/changes/po-form/proposal.md"
  bash "$BASELINE_BIN" record "$root/.specclaw" >/dev/null 2>&1
}

sel_ids() {  # <root> <target> <tag>
  local root="$1" target="$2" tag="$3"
  # Separate statement, deliberately: in a single `local a=$1 b=$a`, bash
  # expands $a while parsing the builtin's arguments, BEFORE the assignment
  # to a happens — so under `set -u` it dies with "a: unbound variable".
  local out="$root/.specclaw/replay/run-$tag/selection.json"
  bash "$REPLAY_BIN" resolve "$root/.specclaw" "$target" "$out" >/dev/null 2>&1
  [ -f "$out" ] || { printf 'NO-SELECTION-FILE'; return 0; }
  jq -r '[.fixtures[].scenario_id] | sort | join(",")' "$out" | tr -d '\r'
}

P="$T/e2e"
seed_cap_replay "$P"
assert_eq "the seeded manifest recorded at schema 4" "4" \
  "$(jq -r '.manifest_schema' "$P/.specclaw/baseline/manifest.json" | tr -d '\r')"

assert_eq "AC-3 item scope: a capability-only basis selects the DR-less fixture" \
  "GM-002" "$(sel_ids "$P" BL-020 A)"
assert_eq "AC-4 change scope: the same item resolved via its change folder agrees" \
  "GM-002" "$(sel_ids "$P" po-form B)"
assert_eq "AC-2 module scope: MOD-002 selects the DR-less fixture and the shared one" \
  "GM-002,GM-003" "$(sel_ids "$P" MOD-002 C)"
assert_eq "AC-1 all scope: every fixture including the DR-less one" \
  "GM-001,GM-002,GM-003" "$(sel_ids "$P" --all D)"
assert_eq "a rule-only module is unaffected by the widening" \
  "GM-001,GM-003" "$(sel_ids "$P" MOD-001 E)"

# The filter, end to end: BL-020's Maps-to-capability names CAP-012, which
# GM-003 pins. If that field leaked into the basis, selection A above would
# have been GM-002,GM-003.
assert_eq "AC-3b 'Maps to capability' does not widen the real selection" \
  "GM-002" "$(sel_ids "$P" BL-020 F)"

# AC-6: the capability floor fires only when the item actually cites a
# capability, and names the fix.
seed_cap_replay "$P"
jq '.manifest_schema=3 | del(.fixtures[].capabilities_pinned)' \
  "$P/.specclaw/baseline/manifest.json" > "$P/m" && mv "$P/m" "$P/.specclaw/baseline/manifest.json"
out="$(bash "$REPLAY_BIN" resolve "$P/.specclaw" BL-020 "$P/.specclaw/replay/run-G/selection.json" 2>&1)"; rc=$?
assert_eq "AC-6 a capability-citing item refuses a pre-schema-4 manifest" "1" "$rc"
assert_contains "and the refusal names the fix" "$out" "re-run /specclaw:bf-baseline --record"
assert_contains "and names the capability that needs the newer schema" "$out" "CAP-007"

# ...while a rule-only target keeps working against that same old manifest,
# which is the entire point of a per-field floor.
assert_eq "AC-6 a DR-only module still resolves against schema 3" \
  "GM-001,GM-003" "$(sel_ids "$P" MOD-001 H)"

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

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the exit-0 gate refuses everything ambiguous (fail-closed) =="
#
# This reader is the ONLY path on which a zero-fixture run exits 0, so every
# one of these was a way to arm a green gate by accident. All four were
# reachable and are now refused.

# A VISIBLE FENCED EXAMPLE. bf-baseline-designer.md illustrates the two forms
# inside a fence; an agent rendering that guidance visibly rather than as an
# HTML comment armed the gate for whatever id the example named — while the
# document plainly recorded that id as COVERED two lines below.
# Heredoc rather than printf: the fence characters inside a single-quoted
# printf read as command substitution to shellcheck.
cat > "$T/scen.md" <<'FENCEDEOF'
# S

## Capability Coverage Check

Format reference:

```
CAP-014 — NOT-REPLAYABLE: <why no non-UI seam can observe it>
```

CAP-014 — covered by GM-001
FENCEDEOF
assert_eq "a fenced example is not a classification" "" \
  "$(bash -c ". '$HARNESS'; classified_not_replayable_caps '$T/scen.md' | paste -sd, -")"
assert_eq "so an item citing that id still gates" "1" "$(rc_of 'CAP-014')"

# AN ID IN BOTH FORMS — a stale exclusion left behind after a fixture was
# finally captured must not outrank the coverage entry beside it.
mk_scen "CAP-014 — covered by GM-031
CAP-014 — NOT-REPLAYABLE: stale leftover line"
assert_eq "an id recorded as BOTH covered and not-replayable is refused" "1" "$(rc_of 'CAP-014')"

# A CLASSIFIED ID THAT DOES NOT EXIST — one typo should not turn a red gate
# green. Needs the roster, so it is passed as the third argument.
mk_scen "CAP-999 — NOT-REPLAYABLE: made up id"
printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-014 — Real one** — menu\n' > "$T/fspec.md"
assert_eq "with no roster available the classification is taken at face value" "0" \
  "$(bash -c ". '$HARNESS'; basis_is_wholly_not_replayable '$T/scen.md' 'CAP-999' >/dev/null"; echo $?)"
assert_eq "but against a real roster a non-existent id is refused" "1" \
  "$(bash -c ". '$HARNESS'; basis_is_wholly_not_replayable '$T/scen.md' 'CAP-999' '$T/fspec.md' >/dev/null"; echo $?)"

# A WITHDRAWN capability is not an active one.
mk_scen "CAP-014 — NOT-REPLAYABLE: gone but still classified"
printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-014 — WITHDRAWN 2026-09-01, removed**\n' > "$T/fspec.md"
assert_eq "a tombstoned capability cannot be classified into a green gate" "1" \
  "$(bash -c ". '$HARNESS'; basis_is_wholly_not_replayable '$T/scen.md' 'CAP-014' '$T/fspec.md' >/dev/null"; echo $?)"

# A DECORATED HEADING yields no classifications — fail-closed, but silent, so
# it is pinned to keep the template's warning honest.
printf '# S\n\n## Capability Coverage Check (12 capabilities)\n\nCAP-014 — NOT-REPLAYABLE: reason here\n' > "$T/scen.md"
assert_eq "a decorated section heading finds nothing (fails closed)" "1" "$(rc_of 'CAP-014')"

# AN ID MID-SENTENCE is prose, not an entry.
printf '# S\n\n## Capability Coverage Check\n\nWe decided CAP-014 — NOT-REPLAYABLE: was wrong here\n' > "$T/scen.md"
assert_eq "an id that does not open its line is not an entry" "1" "$(rc_of 'CAP-014')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== the verdict AT THE CLI: exit code and rendered report =="
#
# The group above asserts a helper's RETURN CODE. That is not the contract.
# AC-8 says the RUN exits 0 and PRINTS the reasons, and asserting the helper
# instead let two defects through a green suite: the exit-0 path did not exist
# at all (resolve printed the message, render unconditionally set exit 2), and
# the message dropped its final reason, so a single-capability basis printed
# none. Same mistake as re-implementing the selection query, one level up:
# assert the thing the user gets.
seed_nbtv() {  # <root> <coverage-check-body>
  local root="$1"
  local body="$2"
  rm -rf "$root"
  mkdir -p "$root/.specclaw/baseline/fixtures" "$root/.specclaw/analysis" "$root/.specclaw/changes/po-form"
  # A scenario exists but pins a DIFFERENT capability, so the item's basis
  # resolves to ZERO fixtures while the manifest is still schema 4 and valid.
  cat > "$root/.specclaw/baseline/scenarios.md" <<SCEOF
### GM-001 — unrelated

- **Seam:** Svc.Other
- **Seam layer:** service
- **Business rules pinned:** DR-001
- **Verifies backlog item:** BL-099 — other

## Capability Coverage Check

${body}
SCEOF
  cat > "$root/.specclaw/baseline/fixtures/GM-001.json" <<'FXEOF'
{"scenario_id":"GM-001","captured_at":"2026-09-01T00:00:00Z","anchor_date":"2026-09-01",
 "legacy_commit_sha":"abc","runtime_version":"1.0","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false}}
FXEOF
  printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-014 — Print a PO** — File > Print\n2. **CAP-015 — Preview a PO** — File > Preview\n' \
    > "$root/.specclaw/analysis/functional-spec.md"
  printf 'DR-001\n' > "$root/.specclaw/analysis/domain-model.md"
  cat > "$root/.specclaw/analysis/rebuild-backlog.md" <<'BLEOF'
### BL-020 — po printing

- **Module:** MOD-001
- **Acceptance basis (domain-model.md, functional-spec.md):**
  - CAP-014: the print layout.
- **Depends on:** None
BLEOF
  printf 'Rebuild-backlog item BL-020 — po printing.\n' > "$root/.specclaw/changes/po-form/proposal.md"
  bash "$BASELINE_BIN" record "$root/.specclaw" >/dev/null 2>&1
}

run_item() {  # <root> <tag>  -> "<rc>|<verdict line>"
  local root="$1" tag="$2"
  local rd="$root/.specclaw/replay/run-$tag"
  bash "$REPLAY_BIN" resolve "$root/.specclaw" BL-020 "$rd/selection.json" >/dev/null 2>&1
  bash "$REPLAY_BIN" render "$root/.specclaw" BL-020 "$rd" >/dev/null 2>&1
  local rc=$?
  local v
  v="$(grep -m1 -h '^\*\*Overall verdict:\*\*' "$root/.specclaw/replay"/report-*BL-020*.md \
       "$root/.specclaw/changes/po-form/replay-report.md" 2>/dev/null \
       | sed 's/^\*\*Overall verdict:\*\* *//' | tr -d '\r')"
  printf '%s|%s' "$rc" "$v"
}

N="$T/nbtv"
seed_nbtv "$N" "CAP-014 — NOT-REPLAYABLE: print layout is asserted by SCR-004 screenshots"
res="$(run_item "$N" A)"
assert_eq "AC-8 a fully classified basis EXITS 0 at the CLI" "0" "${res%%|*}"
assert_contains "AC-8 and the rendered verdict says so" "${res#*|}" "NO BEHAVIOUR TO VERIFY"
# An `--item BL-###` run writes .specclaw/replay/report-<ts>-BL-###.md, not
# the change folder's replay-report.md — that path is for a change-scoped run.
assert_contains "AC-8 the report states the reason, not an empty dash" \
  "$(cat "$N/.specclaw/replay"/report-*BL-020*.md 2>/dev/null)" "SCR-004 screenshots"
assert_eq "the selection records the classification for render to read" "CAP-014" \
  "$(jq -r '.not_replayable_caps' "$N/.specclaw/replay/run-A/selection.json" | tr -d '\r')"
assert_contains "and records the reason alongside it" \
  "$(jq -r '.not_replayable_reasons' "$N/.specclaw/replay/run-A/selection.json" | tr -d '\r')" \
  "SCR-004"

# BLOCK-2's exact shape: with ONE capability the reason was dropped entirely.
assert_eq "a single-capability basis still names its reason (no dropped field)" "1" \
  "$(jq -r '.not_replayable_reasons' "$N/.specclaw/replay/run-A/selection.json" \
     | grep -c 'CAP-014: print layout' | tr -d ' \r')"

seed_nbtv "$N" "CAP-014 — covered by GM-001"
res="$(run_item "$N" B)"
assert_eq "AC-11 an unclassified zero-fixture item EXITS 2 at the CLI" "2" "${res%%|*}"
assert_contains "AC-11 and renders INCOMPLETE" "${res#*|}" "INCOMPLETE"

seed_nbtv "$N" "CAP-014 — NOT-REPLAYABLE:"
res="$(run_item "$N" C)"
assert_eq "AC-10 an empty reason EXITS 2 at the CLI" "2" "${res%%|*}"

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
echo "== AC-5: the paired-join invariant, both sides actually computed =="
#
# design.md R-1 calls this the highest risk in the change, and until now the
# suite only pinned that the two extractors are byte-identical. THAT IS NOT
# THE INVARIANT. Byte-identical functions can still be fed different inputs,
# called from different filters, or consumed differently — the property that
# matters is that the two SETS come out equal:
#
#   specclaw-bf-replay      --item BL-###  -> selected fixture ids
#   specclaw-bf-rebuild-collect render     -> that item's own
#                                             "**Verification:** VERIFIABLE —
#                                             fixtures: ..." list
#
# Asserted here for a CAPABILITY-ONLY item, because that is the case the
# widening introduced and the one no prior test could have covered.
I="$T/inv"
seed_cap_replay "$I"

cat > "$I/draft.md" <<'DRAFTEOF'
### BL-020 — po form

**Module:** MOD-002
**Maps to capability:** CAP-012 — Amend a PO
**Depends on:** None
**Acceptance basis (domain-model.md, functional-spec.md):**
- CAP-007: the form field set round-trips

**Verification inputs needed:**
- A golden-master capture of the PO form.

## Sequencing Rationale

Single item.

## Coverage Check

- **MOD-002** — "Create a PO" → BL-020

**Orphaned:** none

### Open Questions Blocking Readiness

None.
DRAFTEOF

( cd "$I" && bash "$REBUILD_BIN" render .specclaw ./draft.md >/dev/null 2>&1 )
# Take the first Verification line AFTER the template comment closes. Two
# traps here, both hit while writing this: the rendered field carries a
# LEADING SPACE (so "^**Verification:**" matches nothing), and the template
# comment at the top of the document mentions the label as documentation (so
# an unscoped grep returns the comment instead of the item).
backlog_fixtures="$(awk '/^-->/{c=1; next} c && /Verification:/ {print; exit}' \
  "$I/.specclaw/analysis/rebuild-backlog.md" 2>/dev/null \
  | grep -oE 'GM-[0-9]{3}' | sort -u | paste -sd, - | tr -d '\r')"
replay_fixtures="$(sel_ids "$I" BL-020 INV)"

assert_eq "AC-5 the backlog's own Verification line names the capability fixture" \
  "GM-002" "$backlog_fixtures"
assert_eq "AC-5 --item's selection EQUALS the backlog's Verification list" \
  "$backlog_fixtures" "$replay_fixtures"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== AC-7: adding the new fields flips no existing fixture to SUPERSEDED =="
#
# `record` derives SUPERSEDED from the scenario's own text hash. Template edits
# must not reach generated documents, so a fixture set recorded BEFORE this
# change must still read VERIFIABLE after it. Asserted rather than reasoned
# about: the reasoning was already in design.md R-3 and reasoning is not
# evidence.
S="$T/sup"
seed_cap_replay "$S"
assert_eq "AC-7 every recorded fixture reads VERIFIABLE" "VERIFIABLE" \
  "$(jq -r '[.fixtures[].status] | unique | join(",")' "$S/.specclaw/baseline/manifest.json" | tr -d '\r')"
# Re-record over the same scenarios: the hash is stable, so nothing supersedes.
bash "$BASELINE_BIN" record "$S/.specclaw" >/dev/null 2>&1
assert_eq "AC-7 and still does after a second record over unchanged scenarios" "VERIFIABLE" \
  "$(jq -r '[.fixtures[].status] | unique | join(",")' "$S/.specclaw/baseline/manifest.json" | tr -d '\r')"
# Sanity: the mechanism DOES fire when the scenario text really changes, so the
# assertion above is not vacuously green.
# The title in seed_cap_replay is "capability only"; the previous target
# ("capability round-trip") belongs to a different fixture, so the sed
# matched nothing and the scenario text never changed.
sed -i 's/GM-002 — capability only/GM-002 — capability only AMENDED/' "$S/.specclaw/baseline/scenarios.md"
bash "$BASELINE_BIN" record "$S/.specclaw" >/dev/null 2>&1
assert_eq "AC-7 sanity: a genuinely changed scenario DOES supersede its fixture" "1" \
  "$(jq '[.fixtures[] | select(.status=="SUPERSEDED")] | length' "$S/.specclaw/baseline/manifest.json" | tr -d '\r')"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== AC-16: every suite this change adds is registered in CI =="
#
# An unregistered suite silently never runs, which .specclaw/context.md records
# as having happened twice in this repo. Asserted mechanically rather than by
# having looked once.
CI=".github/workflows/ci.yml"
[ -f "$CI" ] || CI="$PLUGIN_ROOT/../../.github/workflows/ci.yml"
assert_eq "AC-16 run-capability-selection-tests.sh is registered in ci.yml" "1" \
  "$(grep -c 'run-capability-selection-tests\.sh' "$CI" 2>/dev/null | tr -d ' \r')"
# Run from the PLUGIN_ROOT-relative repo root: `git -C .github/workflows`
# cannot resolve a path given relative to the repository root.
assert_eq "AC-16 and this file is executable in the git index" "100755" \
  "$(git -C "$PLUGIN_ROOT" ls-files -s -- "$SCRIPT_DIR/run-capability-selection-tests.sh" 2>/dev/null | cut -c1-6)"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "Passed: ${PASS}   Failed: ${FAIL}"
[ "$FAIL" -eq 0 ] || exit 1
