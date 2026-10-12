#!/usr/bin/env bash
# run-stub-registry-tests.sh — regression suite for the module-bypass
# mechanism (templates/CONTRACT.md (m)):
#
#   - bypass-check's per-dependency classification, including the refusals
#     it must NOT resolve by guessing (ambiguous title, dangling id)
#   - the declared BUILT: signal, and the prose it must keep ignoring
#   - stub-append/stub-update: id allocation, malformed-entry refusals,
#     in-place edits confined to one block
#   - THE CENTRAL INVARIANT: taint changes no verdict and no exit code
#   - module-status's latest-run-wins taint column
#   - the retirement block's ready/waiting split
#
# The verdict-invariance tests are the reason this suite exists. Everything
# else here is a convenience that fails loudly when it breaks; a regression
# that let stub taint leak into a verdict, or that silently stopped stamping
# taint at all, would turn "we checked and it was fine" into a false claim
# nobody notices. Both directions are tested.
#
# Bash + coreutils + jq (the artifacts under test are nested JSON).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLLECT_BIN="$PLUGIN_ROOT/bin/specclaw-bf-rebuild-collect"
REPLAY_BIN="$PLUGIN_ROOT/bin/specclaw-bf-replay"

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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed — skipping stub-registry suite (exit 0)."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixture: two modules, three items, one cross-module dependency ─────────
new_project() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis"
  cat > "$root/.specclaw/analysis/module-map.md" <<'EOF'
# Module Map: T

**Status:** CONFIRMED by Tester, 2026-08-01

## Modules

### MOD-005 — Auth

- **Depends on:** None

### MOD-009 — Invoicing

- **Depends on:** MOD-005
EOF
  cat > "$root/.specclaw/analysis/rebuild-backlog.md" <<'EOF'
# Rebuild Backlog: T

## Backlog

## MOD-005 — Auth

### BL-014 — User authentication

**Module:** MOD-005
**Depends on:** None
**Acceptance basis (domain-model.md):**
- DR-002: a session is authenticated before any action.

---

### BL-015 — Role assignment

**Module:** MOD-005
**Depends on:** BL-014
**Acceptance basis (domain-model.md):**
- DR-005: a role grants exactly its declared permissions.

---

## MOD-009 — Invoicing

### BL-021 — Invoice approval

**Module:** MOD-009
**Depends on:** BL-014, BL-099
**Acceptance basis (domain-model.md):**
- DR-001: an invoice is approved once.

---
EOF
}

echo "== bypass-check: classification =="
P="$WORK/p1"; new_project "$P"
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw BL-021 2>/dev/null)"
assert_eq "true" "$(jq -r '.applicable' <<< "$OUT")" "a backlog item is applicable"
assert_eq "MOD-009" "$(jq -r '.item.module' <<< "$OUT")" "the item's own module is reported"
assert_eq "needs-bypass" "$(jq -r '.dependencies[]|select(.id=="BL-014")|.action' <<< "$OUT")" \
  "an unmet cross-module dependency needs a bypass"
assert_eq "false" "$(jq -r '.dependencies[]|select(.id=="BL-014")|.same_module' <<< "$OUT")" \
  "and is reported as cross-module"
assert_eq "dependency-unknown" "$(jq -r '.dependencies[]|select(.id=="BL-099")|.action' <<< "$OUT")" \
  "a dependency absent from the backlog is reported, not assumed met"
assert_eq "ST-001" "$(jq -r '.next_stub_id' <<< "$OUT")" "the next free stub id is offered"

OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw BL-015 2>/dev/null)"
assert_eq "same-module-prerequisite" "$(jq -r '.dependencies[0].action' <<< "$OUT")" \
  "a same-module dependency is a prerequisite, never a bypass candidate"

echo "== bypass-check: refusals it must not resolve by guessing =="
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw --title "Invoice" 2>/dev/null)"
# "Invoice approval" is the only match here, so force real ambiguity instead.
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw --title "assignment" 2>/dev/null)"
assert_eq "BL-015" "$(jq -r '.item.id' <<< "$OUT")" "a unique substring title resolves"
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw --title "a" 2>/dev/null)"
assert_eq "false" "$(jq -r '.applicable' <<< "$OUT")" "an ambiguous title refuses rather than picking one"
assert_contains "$(jq -r '.reason' <<< "$OUT")" "more than one" "and says why"

echo "== bypass-check: inert without a backlog =="
mkdir -p "$WORK/green/.specclaw"
OUT="$(cd "$WORK/green" && bash "$COLLECT_BIN" bypass-check .specclaw --title "anything" 2>/dev/null)"
assert_eq "false" "$(jq -r '.applicable' <<< "$OUT")" "a project with no backlog is inert"
assert_eq "0" "$(jq -r '.dependencies|length' <<< "$OUT")" "and reports no dependencies"

echo "== the declared BUILT: signal =="
P="$WORK/p2"; new_project "$P"
cat >> "$P/.specclaw/analysis/rebuild-backlog.md" <<'EOF'
EOF
# Prose must NOT read as built.
perl -0pi -e 's/(### BL-014 — User authentication\n\n\*\*Module:\*\* MOD-005\n\*\*Depends on:\*\* None\n)/$1\n**Status notes (human-added):**\ndone last week, shipped in #42\n/' \
  "$P/.specclaw/analysis/rebuild-backlog.md" 2>/dev/null
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw BL-021 2>/dev/null)"
assert_eq "unknown" "$(jq -r '.dependencies[]|select(.id=="BL-014")|.built_signal' <<< "$OUT")" \
  "prose is never read as a completion signal"
perl -0pi -e 's/done last week, shipped in #42/BUILT: PR #42, merged 2026-08-11/' \
  "$P/.specclaw/analysis/rebuild-backlog.md" 2>/dev/null
OUT="$(cd "$P" && bash "$COLLECT_BIN" bypass-check .specclaw BL-021 2>/dev/null)"
assert_eq "declared" "$(jq -r '.dependencies[]|select(.id=="BL-014")|.built_signal' <<< "$OUT")" \
  "a declared BUILT: line is read"
assert_eq "ok-built" "$(jq -r '.dependencies[]|select(.id=="BL-014")|.action' <<< "$OUT")" \
  "and no bypass is elicited for it"

echo "== stub-append: id allocation and malformed-entry refusals =="
P="$WORK/p3"; new_project "$P"
ID1="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014 (MOD-005)" \
        --strategy stub-interface --consumed-by "BL-021" --chosen-by "Tester, 2026-08-12" \
        --summary "dev-only auth stub" 2>/dev/null)"
assert_eq "ST-001" "$ID1" "the first entry takes ST-001"
ID2="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "MOD-005" \
        --strategy mock-data --consumed-by "BL-021" --chosen-by "Tester, 2026-08-12" \
        --summary "seeded rows" --mock-seed "db/seed.sql" 2>/dev/null)"
assert_eq "ST-002" "$ID2" "ids increment and are never reused"

ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014" \
        --strategy wishful --consumed-by "BL-021" --chosen-by "T, d" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "unknown strategy" "an invented strategy is refused"
# These two used --strategy item-split purely as a vehicle for the refusal
# being tested. item-split is now refused by name before any other validation
# (it belongs in item-splits.md, not here), so they carry a real faking
# strategy instead — the assertions themselves are unchanged.
ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014" \
        --strategy feature-flag --consumed-by "BL-021" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "chosen-by is required" "an entry with no named chooser is refused"
ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014" \
        --strategy stub-interface --chosen-by "T, d" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "consumed-by is required" "an entry that taints nothing is refused"
ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014" \
        --strategy item-split --consumed-by "BL-021" --chosen-by "T, d" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "not a stub strategy" "item-split is refused here and sent to its own registry"
assert_contains "$ERR" "split-append" "and the refusal names the command that does record it"
ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014" \
        --strategy feature-flag --consumed-by "BL-021" --chosen-by "T, d" --summary s \
        --mock-seed x 2>&1 >/dev/null)"
assert_contains "$ERR" "mock-seed applies only" "a mock seed on a non-mock-data strategy is refused"

echo "== stub-update: in-place edits stay in their own block =="
(cd "$P" && bash "$COLLECT_BIN" stub-update .specclaw ST-001 \
   --fakes "returns stub-user/STUB_ADMIN" --implementation "src/dev/Stub.cs:24 — dev profile only" >/dev/null 2>&1)
REG="$(cat "$P/.specclaw/analysis/module-stubs.md")"
assert_contains "$REG" "returns stub-user/STUB_ADMIN" "the edited field is written"
assert_eq "1" "$(grep -c 'returns stub-user' "$P/.specclaw/analysis/module-stubs.md")" \
  "and exactly once — the other entry is untouched"
# Scoped to the entries themselves — the template's own comment documents the
# "not yet implemented" placeholder and would otherwise be counted.
assert_eq "2" "$(sed -n '/^## Stubs/,$p' "$P/.specclaw/analysis/module-stubs.md" | grep -c 'not yet implemented')" \
  "ST-002's own placeholders survive an edit to ST-001"
ERR="$(cd "$P" && bash "$COLLECT_BIN" stub-update .specclaw ST-001 --status GONE 2>&1 >/dev/null)"
assert_contains "$ERR" "must be ACTIVE, RETIRING, or RETIRED" "an unknown status is refused"
(cd "$P" && bash "$COLLECT_BIN" stub-update .specclaw ST-001 --consumed-by-add BL-021 >/dev/null 2>&1)
assert_eq "0" "$?" "re-adding an existing consumer is idempotent, not an error"

echo "== replay: taint stamping, and its invariance =="
# A two-fixture baseline: GM-001 verifies the stub-backed BL-021, GM-002 does not.
build_replay_project() {
  local root="$1"; new_project "$root"
  mkdir -p "$root/.specclaw/baseline/fixtures"
  local i
  for i in 1 2; do
    cat > "$root/.specclaw/baseline/fixtures/GM-00$i.json" <<EOF
{"scenario_id":"GM-00$i","captured_at":"2026-08-01T00:00:00Z","anchor_date":"2026-08-01",
 "legacy_commit_sha":"aaa","runtime_version":"1","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false,"total":$i}}
EOF
  done
  local h1 h2
  h1="$(sha256sum "$root/.specclaw/baseline/fixtures/GM-001.json" | awk '{print $1}')"
  h2="$(sha256sum "$root/.specclaw/baseline/fixtures/GM-002.json" | awk '{print $1}')"
  cat > "$root/.specclaw/baseline/manifest.json" <<EOF
{"manifest_schema":3,"plugin_version":"0.11.0","generated":"2026-08-01","total_scenarios":2,
 "fixtures":[
  {"scenario_id":"GM-001","status":"VERIFIABLE","seam_layer":"service","module_ids":["MOD-009"],
   "business_rules_pinned":"DR-001","verifies_backlog_item":"BL-021",
   "fixture_path":".specclaw/baseline/fixtures/GM-001.json","content_hash":"sha256:$h1",
   "legacy_commit_sha":"aaa","normalized_fields":[]},
  {"scenario_id":"GM-002","status":"VERIFIABLE","seam_layer":"service","module_ids":["MOD-005"],
   "business_rules_pinned":"DR-002","verifies_backlog_item":"BL-014",
   "fixture_path":".specclaw/baseline/fixtures/GM-002.json","content_hash":"sha256:$h2",
   "legacy_commit_sha":"aaa","normalized_fields":[]}]}
EOF
}

# $1 = project root, $2 = "clean" | "diverge"  → prints "<exit>|<summary line>"
run_replay() {
  local root="$1" mode="$2" rd=".specclaw/replay/run-t"
  ( cd "$root" || return 1
    rm -rf .specclaw/replay
    bash "$REPLAY_BIN" resolve .specclaw --all "$rd/selection.json" >/dev/null 2>&1
    bash "$REPLAY_BIN" init-rundir .specclaw "$rd" >/dev/null 2>&1
    cat > "$rd/mapping.json" <<'EOF'
[{"scenario_id":"GM-001","verdict":"REPLAYABLE","legacy_seam_layer":"service","replay_seam_layer":"service"},
 {"scenario_id":"GM-002","verdict":"REPLAYABLE","legacy_seam_layer":"service","replay_seam_layer":"service"}]
EOF
    if [ "$mode" = "diverge" ]; then
      jq '{output:(.output|.total=99)}' .specclaw/baseline/fixtures/GM-001.json > "$rd/actual/GM-001.json"
    else
      jq '{output:.output}' .specclaw/baseline/fixtures/GM-001.json > "$rd/actual/GM-001.json"
    fi
    jq '{output:.output}' .specclaw/baseline/fixtures/GM-002.json > "$rd/actual/GM-002.json"
    bash "$REPLAY_BIN" compare .specclaw "$rd" >/dev/null 2>&1
    local out rc
    out="$(bash "$REPLAY_BIN" render .specclaw --all "$rd" 2>&1)"; rc=$?
    printf '%s|%s' "$rc" "$(printf '%s' "$out" | tail -1)"
  )
}

PU="$WORK/untainted"; build_replay_project "$PU"
R_CLEAN="$(run_replay "$PU" clean)"
R_FAILC="$(run_replay "$PU" diverge)"

PT="$WORK/tainted"; build_replay_project "$PT"
(cd "$PT" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014 (MOD-005)" \
   --strategy stub-interface --consumed-by "BL-021" --chosen-by "Tester, 2026-08-12" \
   --summary "dev-only auth stub" >/dev/null 2>&1)
R_TAINT="$(run_replay "$PT" clean)"
R_FAILT="$(run_replay "$PT" diverge)"

assert_eq "0" "${R_CLEAN%%|*}" "a clean run with no registry exits 0"
assert_eq "0" "${R_TAINT%%|*}" "a clean run WITH an active stub still exits 0"
assert_eq "1" "${R_FAILC%%|*}" "a behavioural divergence exits 1"
assert_eq "1" "${R_FAILT%%|*}" "a TAINTED behavioural divergence still exits 1 — taint never softens FAIL"
assert_contains "${R_FAILT#*|}" "FAIL" "and is still reported as FAIL"
assert_contains "${R_TAINT#*|}" "with active stubs: ST-001" "a tainted PASS says so on the verdict line"
assert_not_contains "${R_CLEAN#*|}" "with active stubs" "an untainted run says nothing about stubs"
assert_contains "${R_TAINT#*|}" "PASS (with active stubs" "the verdict token still comes first"
assert_eq "1" "$(jq '[.results[]|select((.stub_refs//[])|length>0)]|length' "$PT/.specclaw/replay/run-t/compare.json" 2>/dev/null || echo x)" \
  "only the fixture verifying the stub-backed item is stamped"

echo "== replay: taint renders identically in an item-scoped run =="
# Taint is a property of the fixtures selected, never of how they were selected.
# An --item run over the stub-backed item must report the same taint, the same
# way, as the --all run above — a scope that changed how honestly a run reported
# its own standing would defeat the point of having scopes.
run_replay_item() {
  local root="$1" bl="$2" rd=".specclaw/replay/run-i"
  ( cd "$root" || return 1
    rm -rf "$rd"
    bash "$REPLAY_BIN" resolve .specclaw "$bl" "$rd/selection.json" >/dev/null 2>&1
    bash "$REPLAY_BIN" init-rundir .specclaw "$rd" >/dev/null 2>&1
    cat > "$rd/mapping.json" <<'EOF'
[{"scenario_id":"GM-001","verdict":"REPLAYABLE","legacy_seam_layer":"service","replay_seam_layer":"service"}]
EOF
    jq '{output:.output}' .specclaw/baseline/fixtures/GM-001.json > "$rd/actual/GM-001.json"
    bash "$REPLAY_BIN" compare .specclaw "$rd" >/dev/null 2>&1
    local out rc
    out="$(bash "$REPLAY_BIN" render .specclaw "$bl" "$rd" 2>&1)"; rc=$?
    printf '%s|%s' "$rc" "$(printf '%s' "$out" | tail -1)"
  )
}
# ST-001 is RETIRING by the end of this file, so re-assert it ACTIVE first.
(cd "$PT" && bash "$COLLECT_BIN" stub-update .specclaw ST-001 --status ACTIVE >/dev/null 2>&1)
R_ITEM="$(run_replay_item "$PT" BL-021)"
assert_eq "0" "${R_ITEM%%|*}" "an item-scoped run over a stub-backed item still exits 0"
assert_contains "${R_ITEM#*|}" "with active stubs: ST-001" \
  "an item-scoped run reports the same taint as an --all run"
assert_contains "${R_ITEM#*|}" "PASS (with active stubs" \
  "and the verdict token still comes first in an item-scoped run"
assert_eq "1" "$(jq '[.results[]|select((.stub_refs//[])|length>0)]|length' "$PT/.specclaw/replay/run-i/compare.json" 2>/dev/null || echo x)" \
  "the item-scoped selection stamps the same fixture"
# The taint travels into the evidence metadata, and an item run records EXACTLY
# the item it was asked about — module-status reads both.
(cd "$PT" && bash "$REPLAY_BIN" finalize .specclaw BL-021 ".specclaw/replay/run-i" >/dev/null 2>&1)
IMETA="$(find "$PT/.specclaw/replay/evidence" -name run-metadata.json | head -1)"
assert_eq '["BL-021"]' "$(jq -c '.bl_items_covered' "$IMETA" 2>/dev/null | tr -d '\r')" \
  "an item run records exactly the item it was asked about"
assert_eq '["BL-021"]' "$(jq -c '.stub_tainted_items' "$IMETA" 2>/dev/null | tr -d '\r')" \
  "and records that item as stub-tainted"

echo "== replay: RETIRING stops tainting =="
(cd "$PT" && bash "$COLLECT_BIN" stub-update .specclaw ST-001 --status "RETIRING 2026-08-12" >/dev/null 2>&1)
R_RET="$(run_replay "$PT" clean)"
assert_eq "0" "${R_RET%%|*}" "a retirement-verification run exits 0"
assert_not_contains "${R_RET#*|}" "with active stubs" "a RETIRING stub taints nothing"
assert_contains "$(cat "$PT/.specclaw/replay/report-"*.md)" "RETIRING" \
  "but the report still names it as the retirement run"

echo "== module-status: latest run wins =="
P="$WORK/ms"; new_project "$P"
(cd "$P" && bash "$COLLECT_BIN" stub-append .specclaw --substitutes "BL-014 (MOD-005)" \
   --strategy stub-interface --consumed-by "BL-021" --chosen-by "Tester, 2026-08-12" \
   --summary "dev-only auth stub" >/dev/null 2>&1)
mkdir -p "$P/.specclaw/replay/evidence/run-2026-08-12-100000"
cat > "$P/.specclaw/replay/evidence/run-2026-08-12-100000/run-metadata.json" <<'EOF'
{"run_id":"2026-08-12-100000","module":"MOD-009","date":"2026-08-12","overall_verdict":"PASS",
 "selected_count":1,"counts":{"match":1},"stub_tainted":true,"stubs_in_effect":["ST-001"],
 "stub_tainted_items":["BL-021"],"bl_items_covered":["BL-021"]}
EOF
(cd "$P" && bash "$COLLECT_BIN" module-status .specclaw >/dev/null 2>&1)
ROW="$(grep '^| MOD-009' "$P/.specclaw/analysis/module-status.md")"
assert_contains "$ROW" "PASS*" "a module holding a tainted item reads PASS*, not PASS"
assert_contains "$ROW" "⚠ 1" "and counts the tainted item"

mkdir -p "$P/.specclaw/replay/evidence/run-2026-08-12-200000"
cat > "$P/.specclaw/replay/evidence/run-2026-08-12-200000/run-metadata.json" <<'EOF'
{"run_id":"2026-08-12-200000","module":"MOD-009","date":"2026-08-13","overall_verdict":"PASS",
 "selected_count":1,"counts":{"match":1},"stub_tainted":false,"stubs_in_effect":[],
 "stub_tainted_items":[],"bl_items_covered":["BL-021"]}
EOF
(cd "$P" && bash "$COLLECT_BIN" module-status .specclaw >/dev/null 2>&1)
ROW="$(grep '^| MOD-009' "$P/.specclaw/analysis/module-status.md")"
assert_not_contains "$ROW" "PASS*" "a newer clean run clears the asterisk"
assert_contains "$(grep -A3 '^| Stub' "$P/.specclaw/analysis/module-status.md")" "ST-001" \
  "the stub is still listed under the module it fakes"

echo
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ]
