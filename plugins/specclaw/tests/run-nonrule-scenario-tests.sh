#!/usr/bin/env bash
# run-nonrule-scenario-tests.sh — regression suite for the four non-rule
# scenario classes: entity round-trip, composite flow, defaults-at-rest, and
# promoted-T6.
#
# WHAT THIS SUITE CAN AND CANNOT ASSERT, stated up front because the
# distinction is the whole design of the file:
#
# Scenario derivation is done by the `bf-baseline-designer` AGENT, not by bash.
# `bf-baseline` design mode spawns it and the agent writes scenarios.md. So
# "the designer derives exactly one round-trip per entity" is NOT assertable
# here — it would need a live, non-deterministic model run.
#
# This suite therefore splits in two, and labels which is which:
#
#   INSTRUCTION (doc-lint)  — the bounds exist, verbatim, in the designer and
#                             in templates/scenarios.md. Weaker than an
#                             execution test, and honest about being weaker.
#                             It exists because R-1 (the highest risk in this
#                             change) is that the COST MODEL gets silently
#                             deleted in a later edit, and a lint fails when
#                             that happens.
#   MECHANICAL (execution)  — scenarios of these shapes travel 033's record /
#                             coverage / schema chain unchanged. Real code,
#                             real assertions.
#
# A doc-lint that merely checked "the class is mentioned" would be theatre, so
# every instruction assertion below pins the SPECIFIC BOUNDING WORDS — the
# phrases whose removal is exactly the regression being guarded against.
#
# Bash + coreutils + jq (jq only against JSON artefacts, per the convention).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BASELINE_BIN="$PLUGIN_ROOT/bin/specclaw-bf-baseline"
DESIGNER="$PLUGIN_ROOT/agents/bf-baseline-designer.md"
SCEN_TPL="$PLUGIN_ROOT/templates/scenarios.md"

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL — $1"; [ $# -gt 1 ] && echo "         $2"; }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$expected" = "$actual" ]; then ok "$desc"
  else bad "$desc" "expected [${expected}] got [${actual}]"; fi
}

# Asserts a file contains a literal phrase. Used for every instruction
# criterion: the phrase IS the contract, so its disappearance is the failure.
assert_has() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then ok "$desc"
  else bad "$desc" "missing from $(basename "$file"): [${needle}]"; fi
}

assert_lacks() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF -- "$needle" "$file"; then
    bad "$desc" "unexpectedly present in $(basename "$file"): [${needle}]"
  else ok "$desc"; fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
echo "== INSTRUCTION (doc-lint): the four classes and their bounds =="
#
# Each assertion pins a phrase whose removal IS the regression. "One per
# entity" deleted, or softened to "per form", is how the cost model erodes —
# and because derivation is agent work, a lint is the only mechanism that
# notices.

# AC-1 — the round-trip bound, and the words that forbid the explosion.
assert_has "AC-1 round-trip is bounded ONE PER ENTITY" "$DESIGNER" \
  "ONE scenario per entity"
assert_has "AC-1 and forbids per-form explicitly" "$DESIGNER" "Never one per form"
assert_has "AC-1 and forbids per-field explicitly" "$DESIGNER" "never one per field"

# AC-2 — both load-bearing constraints on the round-trip.
assert_has "AC-2 requires distinguishable arrange values" "$DESIGNER" \
  "Distinguishable arrange values"
assert_has "AC-2 and names the swap it exists to catch" "$DESIGNER" "field *swap*"
assert_has "AC-2 requires the whole shape, not a field list" "$DESIGNER" \
  "Assert the shape, not a field list"

# AC-3 / AC-4 — the composite-flow bound, assertion target, and pin.
assert_has "AC-3 composite flow is bounded per named workflow" "$DESIGNER" \
  "ONE scenario per named composite workflow"
assert_has "AC-3 asserts the observable end state" "$DESIGNER" \
  "observable end state"
assert_has "AC-3 and says NOT the individual calls" "$DESIGNER" \
  "not the individual calls"
assert_has "AC-4 pins the cross-referenced capability" "$DESIGNER" \
  "whose capability bullet cross-references that workflow"

# AC-5 — defaults-at-rest bound and the mechanical-recording requirement.
assert_has "AC-5 defaults-at-rest is per entity WITH defaultable fields" "$DESIGNER" \
  "ONE scenario per entity that has defaultable fields"
assert_has "AC-5 records the default mechanically" "$DESIGNER" \
  "never an invented rationale for why"

# AC-6 — promoted-T6 fires only on a resolved decision.
assert_has "AC-6 promoted-T6 requires an ANSWERED question" "$DESIGNER" \
  "ONE scenario per *answered* ordering/formatting question"
assert_has "AC-6 and an unanswered one yields nothing" "$DESIGNER" \
  "An **unanswered** T6 yields nothing"

# AC-7 — the divergence test is stated as the test, and no class is phrased
# per-form/per-field. This is the criterion most likely to erode.
assert_has "AC-7 the divergence test is stated as the test for deriving" "$DESIGNER" \
  "A fixture earns its place when replaying it could plausibly diverge"
assert_has "AC-7 the bound is named a cost model, not a preference" "$DESIGNER" \
  "cost models rather than style preferences"
assert_lacks "AC-7 no class is phrased per-form" "$DESIGNER" "one scenario per form"
assert_lacks "AC-7 no class is phrased per-field" "$DESIGNER" "one scenario per field"

# AC-7 (second half) — the same bounds must survive in the document authors
# read, not only in the agent charter.
assert_has "AC-7 the template carries the per-entity bound" "$SCEN_TPL" \
  "ONE PER ENTITY"
assert_has "AC-7 the template names it a COST MODEL" "$SCEN_TPL" \
  "COST MODEL, not a style preference"
assert_has "AC-7 the template states the divergence test" "$SCEN_TPL" \
  "A FIXTURE EARNS ITS PLACE WHEN"
assert_has "AC-7 the template routes unstable values to normalized_fields" "$SCEN_TPL" \
  "NORMALIZED_FIELDS IS WHERE THE UNSTABLE PARTS GO"

# AC-12 — the designer must report cost and declined candidates.
assert_has "AC-12 the designer must report the added fixture count" "$DESIGNER" \
  "The added fixture count"
assert_has "AC-12 and name the candidates it declined" "$DESIGNER" \
  "Which candidate scenarios you declined"

# AC-10 — the three pre-existing classes survive untouched.
assert_has "AC-10 cascade/SetNull class survives" "$DESIGNER" \
  "Every cascade/\`SetNull\` delete behavior"
assert_has "AC-10 computed read-model boundary class survives" "$DESIGNER" \
  "Boundary values of any computed read-model property"
assert_has "AC-10 coexisting-mechanisms class survives" "$DESIGNER" \
  "two mechanisms independently coexist"
assert_has "AC-10 DR-### derivation is still the primary instruction" "$DESIGNER" \
  "Derive scenarios directly from \`domain-model.md\`'s numbered Business Rules"

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "== MECHANICAL: scenarios of these shapes travel 033's chain unchanged =="
#
# Real execution. A round-trip scenario is, mechanically, a scenario pinning a
# CAP-### and no DR-### — exactly the shape 033 made selectable. These
# assertions prove this change did not disturb that.

seed() {  # <root> <scenario-body>
  local root="$1" body="$2"
  rm -rf "$root"
  mkdir -p "$root/.specclaw/baseline/fixtures" "$root/.specclaw/analysis"
  printf '%s\n' "$body" > "$root/.specclaw/baseline/scenarios.md"
  cat > "$root/.specclaw/baseline/fixtures/GM-001.json" <<'FX'
{"scenario_id":"GM-001","captured_at":"2026-09-01T00:00:00Z","anchor_date":"2026-09-01",
 "legacy_commit_sha":"abc","runtime_version":"1.0","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false}}
FX
  printf '# Functional Spec\n\n## Capabilities\n\n1. **CAP-007 — Create an Invoice** — File > New\n' \
    > "$root/.specclaw/analysis/functional-spec.md"
  printf 'DR-001\n' > "$root/.specclaw/analysis/domain-model.md"
}

ROUNDTRIP='### GM-001 — Invoice round-trip

- **Seam:** InvoiceService.Create
- **Seam layer:** persistence
- **Business rules pinned:** none
- **Capabilities pinned:** CAP-007
- **Kind:** boundary
- **Verifies backlog item:** BL-020 — invoice form'

R="$T/rt"
seed "$R" "$ROUNDTRIP"
bash "$BASELINE_BIN" record "$R/.specclaw" >/dev/null 2>&1; rc=$?
assert_eq "AC-8 a round-trip-shaped scenario records cleanly" "0" "$rc"
assert_eq "AC-8 and its capability reaches the manifest" "CAP-007" \
  "$(jq -r '.fixtures[0].capabilities_pinned' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"
assert_eq "AC-8 with no DR rule pinned, as the class intends" "none" \
  "$(jq -r '.fixtures[0].business_rules_pinned' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"

# AC-11 — no schema move, no new manifest field.
assert_eq "AC-11 manifest_schema is still 4" "4" \
  "$(jq -r '.manifest_schema' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"
# The allow-list is the manifest's key set as of 033. `normalized_fields_resolved`
# predates both changes (added by 13eabd0, present on main) and was simply
# missing from the first draft of this list — a test bug, verified against
# `git show main:` rather than assumed.
assert_eq "AC-11 no new per-fixture field beyond 033's set" "" \
  "$(jq -r '.fixtures[0] | keys - ["scenario_id","seam","seam_layer","business_rules_pinned","capabilities_pinned","verifies_backlog_item","module_ids","fixture_path","content_hash","scenario_content_hash","status","provisional_ref","captured_at","anchor_date","legacy_commit_sha","runtime_version","normalized_fields","normalized_fields_resolved","outcome","error_code","threw","matches"] | join(",")' \
     "$R/.specclaw/baseline/manifest.json" 2>/dev/null | tr -d '\r')"

# AC-9 — no SUPERSEDED flip, WITH a companion proving the mechanism fires.
assert_eq "AC-9 the recorded fixture reads VERIFIABLE" "VERIFIABLE" \
  "$(jq -r '[.fixtures[].status] | unique | join(",")' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"
bash "$BASELINE_BIN" record "$R/.specclaw" >/dev/null 2>&1
assert_eq "AC-9 and still does after a second record over unchanged text" "VERIFIABLE" \
  "$(jq -r '[.fixtures[].status] | unique | join(",")' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"
sed -i 's/Invoice round-trip/Invoice round-trip AMENDED/' "$R/.specclaw/baseline/scenarios.md"
bash "$BASELINE_BIN" record "$R/.specclaw" >/dev/null 2>&1
assert_eq "AC-9 companion: genuinely changed text DOES supersede" "1" \
  "$(jq '[.fixtures[] | select(.status=="SUPERSEDED")] | length' "$R/.specclaw/baseline/manifest.json" | tr -d '\r')"

# AC-11b — the NFR-3 tripwire, asserted rather than trusted. This change is
# agent instruction plus one template; a bin/ edit means scope creep or a gap
# in 033, and either way it should fail here rather than pass review.
CHANGED_BIN="$(git -C "$PLUGIN_ROOT" diff --name-only 0439516~1 -- ':(top)plugins/specclaw/bin' 2>/dev/null | wc -l | tr -d ' ')"
if [ "$CHANGED_BIN" = "0" ] || [ -z "$CHANGED_BIN" ]; then
  ok "AC-11b NFR-3 tripwire: no bin/ script modified by this change"
else
  bad "AC-11b NFR-3 tripwire tripped" "${CHANGED_BIN} bin/ script(s) modified — see design D-7"
fi

# ─────────────────────────────────────────────────────────────────────────────
echo
echo "Passed: ${PASS}   Failed: ${FAIL}"
[ "$FAIL" -eq 0 ] || exit 1
