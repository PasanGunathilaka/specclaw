#!/usr/bin/env bash
# run-item-split-tests.sh — regression suite for the item-split mechanism
# (templates/CONTRACT.md (o)):
#
#   - item-split is NOT a stub strategy, and stub-append refuses it by name
#   - THE TWO GUARDS AGAINST A SPLIT SILENTLY WIDENING: the DR partition, and
#     the layer-removal confirmation for a screen-bearing item
#   - the IS-### record carries every field a resume months later needs
#   - the state model: ACTIVE -> READY-TO-RESUME (computed and written by BASH
#     from declared BUILT: notes) -> COMPLETE (only on a clean --item run)
#   - the PARTIALLY BUILT marker: rendered, recomputed, and CLEARED by
#     regeneration — never hand-edited, never doubled
#   - propose resumes rather than restarting: a dependency an active split
#     already deferred is never re-elicited
#   - --item replay reports PARTIAL and CHANGES NO VERDICT AND NO EXIT CODE
#
# The verdict-invariance test at the end is the reason this suite exists, and
# so are the two marker-persistence regressions: a marker that never cleared,
# and a section comment that duplicated on every refresh, were both shipped
# defects that made a document quietly lie about its own state.
#
# THE INCIDENT THIS ENCODES. BL-010 (a screen-bearing patient grid) depended on
# BL-001/BL-003 (auth). item-split was chosen to defer THE AUTH INTEGRATION;
# what shipped instead cut THE ENTIRE FRONTEND. The layer-removal test below is
# that exact scenario, and it now refuses.
#
# Bash + coreutils + jq.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
COLLECT_BIN="$PLUGIN_ROOT/bin/specclaw-bf-rebuild-collect"
REPLAY_BIN="$PLUGIN_ROOT/bin/specclaw-bf-replay"
BASELINE_BIN="$PLUGIN_ROOT/bin/specclaw-bf-baseline"

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
  echo "jq not installed — skipping item-split suite (exit 0)."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixture: the dental project, reduced to the three items that matter ─────
# BL-010 is SCREEN-BEARING (it cites SCR-004), which is what makes the
# layer-removal guard applicable to it.
new_project() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis"
  cat > "$root/.specclaw/analysis/module-map.md" <<'EOF'
# Module Map: Dental

**Status:** CONFIRMED by Tester, 2026-08-14

## Modules

### MOD-001 — Auth

- **Business rules:** DR-001, DR-003
- **Depends on:** None

### MOD-002 — Patients

- **Business rules:** DR-002, DR-014, DR-015
- **Depends on:** MOD-001
EOF
  printf '### DR-001 — a\n### DR-002 — b\n### DR-003 — c\n### DR-014 — d\n### DR-015 — e\n' \
    > "$root/.specclaw/analysis/domain-model.md"
  cat > "$root/draft.md" <<'EOF'
### BL-001 — Sign In

**Module:** MOD-001
**Depends on:** None
**Acceptance basis (domain-model.md):**
- DR-001: a session is authenticated before any action.

### BL-003 — Route guards

**Module:** MOD-001
**Depends on:** BL-001
**Acceptance basis (domain-model.md):**
- DR-003: an unauthenticated request never reaches a protected route.

### BL-010 — View/Search the Patient Grid

**Module:** MOD-002
**Depends on:** BL-001, BL-003
**Acceptance basis (domain-model.md):**
- DR-014: the grid lists active patients with their prescriptions.
- DR-015: search filters on name and identifier.
- DR-002: the grid is only reachable by an authenticated user.
- Screens: SCR-004
EOF
  bash "$COLLECT_BIN" render "$root/.specclaw" "$root/draft.md" >/dev/null 2>&1
}

refresh() { local root="$1"; : > "$root/empty-draft.md"; bash "$COLLECT_BIN" render "$root/.specclaw" "$root/empty-draft.md" 2>&1 >/dev/null; }

# The correct BL-010 split: a VERTICAL slice — grid UI through to persistence —
# deferring only the auth integration that is genuinely missing.
good_split() {
  local root="$1"; shift
  bash "$COLLECT_BIN" split-append "$root/.specclaw" \
    --item BL-010 --module MOD-002 \
    --reason "BL-001/BL-003 authentication and route guards are not built" \
    --unmet-deps "BL-001, BL-003" \
    --implemented-now "patient listing, search/filter, paging, backend API, React Patient Grid" \
    --deferred "BL-001 authentication integration, BL-003 route-guard integration" \
    --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
    --layers-implemented "ui, api, domain, persistence" --layers-deferred "auth-integration" \
    --blocked-until "BL-001, BL-003" --chosen-by "Tester, 2026-08-14" \
    --change "view-patient-grid" \
    --summary "BL-010 ships the grid; auth integration waits" "$@"
}

# Add the declared BUILT: signal to an item, exactly where a human would: in
# its own "**Status notes (human-added):**" block. Anchored on the item's
# Verification: line, which render writes for every active item — rendered
# items carry no "---" separator to anchor on.
mark_built() {
  local root="$1" id="$2"
  local f="$root/.specclaw/analysis/rebuild-backlog.md"
  awk -v id="$id" '
    $0 ~ ("^### " id " ") { inblock = 1 }
    { print }
    inblock && /^\*\*Verification:\*\*/ {
      print ""
      print "**Status notes (human-added):**"
      print "- BUILT: PR #57, merged 2026-08-20"
      inblock = 0
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

item_block() {
  awk -v id="$2" '$0 ~ ("^### " id " ") {f=1;next} f && /^### / {exit} f' "$1"
}

# ─────────────────────────────────────────────────────────────────────────────
echo "== item-split is not a stub strategy =="

P="$WORK/p1"; new_project "$P"
ERR="$(bash "$COLLECT_BIN" stub-append "$P/.specclaw" --substitutes "BL-001 (MOD-001)" \
        --strategy item-split --consumed-by BL-010 --chosen-by "T, 2026-08-14" \
        --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "not a stub strategy" "stub-append refuses item-split"
assert_contains "$ERR" "split-append" "and names the command that does record it"
assert_contains "$ERR" "taints nothing" "and says why the two mechanisms are separate"

# ─────────────────────────────────────────────────────────────────────────────
echo "== guard 1: the DR partition =="

P="$WORK/p2"; new_project "$P"
ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps "BL-001" --implemented-now now --deferred later \
        --rules-implemented "DR-014" --rules-deferred "DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "IN NEITHER HALF: DR-015" \
  "a rule in neither half is refused — that is scope belonging to nobody"

ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps "BL-001" --implemented-now now --deferred later \
        --rules-implemented "DR-014, DR-015, DR-002" --rules-deferred "DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "IN BOTH HALVES: DR-002" \
  "a rule that is simultaneously built and deferred is refused"

ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps "BL-001" --implemented-now now --deferred later \
        --rules-implemented "DR-014, DR-015, DR-999" --rules-deferred "DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "NOT IN THIS ITEM'S BASIS: DR-999" \
  "a rule the item does not cite cannot be partitioned into either half"

# A now-slice covering no rule at all is LEGAL (groundwork no rule describes),
# but it has to be stated: the flag's omission is an oversight, an explicit
# empty value is a decision, and those are different things.
ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps "BL-001" --implemented-now now --deferred later \
        --rules-deferred "DR-014, DR-015, DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "rules-implemented is required" "omitting the now-half is refused"
OUT="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps "BL-001" --implemented-now "groundwork" --deferred later \
        --rules-implemented "" --rules-deferred "DR-014, DR-015, DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1)"
assert_contains "$OUT" "covers NONE of BL-010's acceptance-basis rules" \
  "an explicitly empty now-half is accepted, with a warning"

# ─────────────────────────────────────────────────────────────────────────────
echo "== guard 2: layer removal (THE BL-010 INCIDENT) =="

P="$WORK/p3"; new_project "$P"
ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason "auth not built" \
        --unmet-deps "BL-001, BL-003" \
        --implemented-now "backend API + EF Core + persistence" \
        --deferred "the entire React frontend" \
        --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
        --layers-implemented "api, domain, persistence" --layers-deferred "ui" \
        --blocked-until "BL-001, BL-003" --chosen-by "T, 2026-08-14" \
        --summary "BL-010 backend only" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "deferring the whole UI from a screen-bearing item is REFUSED"
assert_contains "$ERR" "SCR-004" "and the refusal names the screen the item renders"
assert_contains "$ERR" "no user-visible part at all" "and states the consequence in those terms"
assert_contains "$ERR" "VERTICAL slice" "and points at the alternative"
assert_eq "no" "$([ -f "$P/.specclaw/analysis/item-splits.md" ] && echo yes || echo no)" \
  "and nothing at all is recorded"

OUT="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason "auth not built" \
        --unmet-deps "BL-001, BL-003" --implemented-now "backend API" \
        --deferred "the entire React frontend" \
        --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
        --layers-implemented "api, domain, persistence" --layers-deferred "ui" \
        --blocked-until "BL-001, BL-003" --chosen-by "T, 2026-08-14" \
        --layer-removal-confirmed-by "Tester, 2026-08-14" \
        --summary "BL-010 backend only" 2>/dev/null)"
assert_eq "IS-001" "$OUT" "the same split IS recorded once a human confirms the consequence"
assert_contains "$(cat "$P/.specclaw/analysis/item-splits.md")" \
  "Layer removal confirmed by:** Tester, 2026-08-14" \
  "and the record names who confirmed it"

# An item that renders no screen is not held to this guard.
P="$WORK/p4"; new_project "$P"
OUT="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-003 --reason r \
        --unmet-deps BL-001 --implemented-now now --deferred later \
        --rules-implemented "" --rules-deferred "DR-003" \
        --layers-implemented api --layers-deferred ui \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>/dev/null)"
assert_eq "IS-001" "$OUT" "a non-screen-bearing item may defer its ui layer freely"

P="$WORK/p5"; new_project "$P"
ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps BL-001 --implemented-now now --deferred later \
        --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
        --layers-implemented "frontend" --layers-deferred auth-integration \
        --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "unknown layer token(s): frontend" "the layer vocabulary is closed"

# ─────────────────────────────────────────────────────────────────────────────
echo "== the record carries what a resume needs =="

P="$WORK/p6"; new_project "$P"; good_split "$P" >/dev/null 2>&1
REG="$P/.specclaw/analysis/item-splits.md"
for field in "Status:** ACTIVE" "Item:** BL-010" "Module:** MOD-002" \
             "Reason:** BL-001/BL-003" "Unmet dependencies:** BL-001,BL-003" \
             "Implemented now:** patient listing" "Deferred:** BL-001 authentication" \
             "Rules implemented:** DR-014,DR-015" "Rules deferred:** DR-002" \
             "Layers implemented:** ui, api" "Layers deferred:** auth-integration" \
             "Blocked until:** BL-001 BUILT, BL-003 BUILT" \
             "Chosen by:** Tester, 2026-08-14" "Change:** view-patient-grid" \
             "Evidence:** not yet merged" "Replay evidence:** not yet replayed"; do
  assert_contains "$(cat "$REG")" "$field" "the record carries ${field%%:*}"
done

ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps BL-001 --implemented-now n --deferred d \
        --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --blocked-until BL-001 --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "chosen-by is required" "a split with no named chooser is refused"
ERR="$(bash "$COLLECT_BIN" split-append "$P/.specclaw" --item BL-010 --reason r \
        --unmet-deps BL-001 --implemented-now n --deferred d \
        --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
        --layers-implemented api --layers-deferred auth-integration \
        --chosen-by "T, 2026-08-14" --summary s 2>&1 >/dev/null)"
assert_contains "$ERR" "blocked-until is required" \
  "a split with nothing to unblock it is refused — it would sit ACTIVE forever"

good_split "$P" >/dev/null 2>&1
assert_eq "2" "$(grep -c '^### IS-' "$REG")" "a second split is appended, never overwriting the first"
assert_contains "$(cat "$REG")" "### IS-002" "and takes the next id — ids increment and are never reused"

# ─────────────────────────────────────────────────────────────────────────────
echo "== the PARTIALLY BUILT marker =="

P="$WORK/m1"; new_project "$P"; good_split "$P" >/dev/null 2>&1
refresh "$P" >/dev/null
BL="$P/.specclaw/analysis/rebuild-backlog.md"
assert_eq "1" "$(item_block "$BL" BL-010 | grep -c 'PARTIALLY BUILT')" \
  "a split item renders exactly one PARTIALLY BUILT marker"
assert_contains "$(item_block "$BL" BL-010)" "IS-001" "naming the split"
assert_contains "$(item_block "$BL" BL-010)" "not this item's final acceptance" \
  "and stating that an --item replay of it is not its acceptance"
assert_eq "0" "$(item_block "$BL" BL-001 | grep -c 'PARTIALLY BUILT')" \
  "an unsplit item carries no marker"

# REGRESSION (shipped defect): markers were preserved into the item's static
# body and a fresh one prepended, so they DOUBLED on every refresh and never
# cleared when the underlying condition went away.
refresh "$P" >/dev/null; refresh "$P" >/dev/null
assert_eq "1" "$(item_block "$BL" BL-010 | grep -c 'PARTIALLY BUILT')" \
  "the marker does not double across repeated refreshes"

# REGRESSION (shipped defect): the section comment duplicated once per refresh.
assert_eq "1" "$(grep -c 'Capability-bullet coverage, authored by' "$BL")" \
  "a preserved section's own comment is not re-appended on every refresh"

# ─────────────────────────────────────────────────────────────────────────────
echo "== ACTIVE -> READY-TO-RESUME is computed and written by BASH =="

P="$WORK/s1"; new_project "$P"; good_split "$P" >/dev/null 2>&1
refresh "$P" >/dev/null
REG="$P/.specclaw/analysis/item-splits.md"
assert_contains "$(cat "$REG")" "Status:** ACTIVE" \
  "the split stays ACTIVE while its blockers carry no BUILT: note"

mark_built "$P" BL-001
OUT="$(refresh "$P")"
assert_contains "$(cat "$REG")" "Status:** ACTIVE" \
  "one of two blockers built is still not ready — every one must carry the signal"

mark_built "$P" BL-003
OUT="$(refresh "$P")"
assert_contains "$(cat "$REG")" "Status:** READY-TO-RESUME" \
  "bash flips the status once EVERY blocked-until item declares BUILT:"
assert_contains "$OUT" "IS-001 flipped ACTIVE -> READY-TO-RESUME" \
  "and says so out loud rather than transitioning silently"
assert_contains "$(item_block "$P/.specclaw/analysis/rebuild-backlog.md" BL-010)" \
  "READY TO RESUME" "the item's marker changes to the resume hint"
assert_eq "2" "$(grep -c 'BUILT: PR #57' "$P/.specclaw/analysis/rebuild-backlog.md")" \
  "and the human-added Status notes survive the regeneration untouched"

# Prose is never a built signal — only the declared token counts.
P="$WORK/s2"; new_project "$P"; good_split "$P" >/dev/null 2>&1
sed -i 's|^\*\*Depends on:\*\* None$|**Depends on:** None\n\n**Status notes (human-added):**\n- shipped last week, all done ✅|' \
  "$P/.specclaw/analysis/rebuild-backlog.md"
refresh "$P" >/dev/null
assert_contains "$(cat "$P/.specclaw/analysis/item-splits.md")" "Status:** ACTIVE" \
  "prose in a status note is never read as a built signal"

# ─────────────────────────────────────────────────────────────────────────────
echo "== COMPLETE, and the marker clearing by regeneration =="

P="$WORK/c1"; new_project "$P"; good_split "$P" >/dev/null 2>&1
ERR="$(bash "$COLLECT_BIN" split-update "$P/.specclaw" IS-001 \
        --status "COMPLETE 2026-08-22, cleared by run r" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "COMPLETE straight from ACTIVE is refused"
assert_contains "$ERR" "ACTIVE -> READY-TO-RESUME" "and the refusal names the real path"

mark_built "$P" BL-001; mark_built "$P" BL-003; refresh "$P" >/dev/null
bash "$COLLECT_BIN" split-update "$P/.specclaw" IS-001 \
  --status "COMPLETE 2026-08-22, cleared by run 2026-08-22-101500" \
  --completion "2026-08-22, run 2026-08-22-101500, auth integration implemented" >/dev/null 2>&1
rc=$?
assert_eq "0" "$rc" "COMPLETE is allowed from READY-TO-RESUME"
refresh "$P" >/dev/null
assert_eq "0" "$(item_block "$P/.specclaw/analysis/rebuild-backlog.md" BL-010 | grep -c 'PARTIALLY BUILT')" \
  "and the marker clears by REGENERATION, with no hand-editing"
assert_contains "$(cat "$P/.specclaw/analysis/item-splits.md")" "IS-001" \
  "while the entry itself stays forever — the record outlives the split"

# ─────────────────────────────────────────────────────────────────────────────
echo "== propose resumes rather than restarting =="

P="$WORK/r1"; new_project "$P"; good_split "$P" >/dev/null 2>&1
OUT="$(bash "$COLLECT_BIN" bypass-check "$P/.specclaw" BL-010 2>/dev/null)"
assert_eq "true" "$(jq -r '.item.screen_bearing' <<< "$OUT")" \
  "bypass-check reports whether the item renders a screen"
assert_eq "IS-001" "$(jq -r '.splits[0].id' <<< "$OUT")" "and reports the open split"
assert_eq "ACTIVE" "$(jq -r '.splits[0].status' <<< "$OUT")" "with its status"
assert_eq "false" "$(jq -r '.splits[0].resume_ready' <<< "$OUT")" "and whether it can resume yet"
assert_eq "BL-001,BL-003" "$(jq -r '.splits[0].blocked_until_unbuilt | join(",")' <<< "$OUT")" \
  "naming exactly which blockers are still unbuilt"
assert_eq "view-patient-grid" "$(jq -r '.splits[0].change' <<< "$OUT")" \
  "and the change that built the first slice, so a resume can cite it"
# THE RESUME RULE: a dependency an active split already deferred is never
# re-elicited. Before this, re-proposing BL-010 offered four bypass strategies
# all over again for something the human had already decided.
assert_eq "deferred-by-split" "$(jq -r '.dependencies[] | select(.id=="BL-001") | .action' <<< "$OUT")" \
  "a dependency the split already deferred is not re-elicited"
assert_eq "0" "$(jq -r '.summary.needs_bypass' <<< "$OUT")" "so nothing needs a new bypass"

mark_built "$P" BL-001; mark_built "$P" BL-003; refresh "$P" >/dev/null
OUT="$(bash "$COLLECT_BIN" bypass-check "$P/.specclaw" BL-010 2>/dev/null)"
assert_eq "READY-TO-RESUME" "$(jq -r '.splits[0].status' <<< "$OUT")" \
  "once ready, propose sees the resumable state"
assert_eq "true" "$(jq -r '.splits[0].resume_ready' <<< "$OUT")" "and that it can proceed"
assert_eq "DR-002" "$(jq -r '.splits[0].rules_deferred | join(",")' <<< "$OUT")" \
  "with exactly the rules still to build — the remainder, not the whole item"

bash "$COLLECT_BIN" split-update "$P/.specclaw" IS-001 \
  --status "COMPLETE 2026-08-22, cleared by run r" >/dev/null 2>&1
OUT="$(bash "$COLLECT_BIN" bypass-check "$P/.specclaw" BL-010 2>/dev/null)"
assert_eq "0" "$(jq -r '.splits | length' <<< "$OUT")" \
  "a COMPLETE split is history, not an outstanding constraint"

# ─────────────────────────────────────────────────────────────────────────────
echo "== a legacy item-split ST entry taints nothing =="

P="$WORK/l1"; new_project "$P"
# Written by hand: stub-append refuses this strategy now, and the point is that
# an entry recorded BEFORE it did must keep parsing and must not taint.
mkdir -p "$P/.specclaw/analysis"
cat > "$P/.specclaw/analysis/module-stubs.md" <<'EOF'
# Module Stubs: Dental

## Stubs

### ST-001 — legacy split recorded before item-splits.md existed

- **Status:** ACTIVE
- **Substitutes:** BL-001 (MOD-001)
- **Strategy:** item-split
- **Consumed by:** BL-010
- **Chosen by:** Tester, 2026-08-01
- **Fakes:** n/a
- **Implementation:** n/a — no stub code; split into BL-011
- **Retirement:**
EOF
refresh "$P" >/dev/null
BL="$P/.specclaw/analysis/rebuild-backlog.md"
assert_eq "0" "$(item_block "$BL" BL-010 | grep -c 'STUB-BACKED')" \
  "a legacy item-split entry does not mark its item STUB-BACKED — it fakes nothing"
assert_contains "$(cat "$BL")" "Legacy item-split entries (nothing to retire)" \
  "it is listed once, separately, with nothing to retire"
assert_not_contains "$(awk '/^### Ready to retire/{f=1} f&&/^### Still waiting/{exit} f' "$BL")" \
  "ST-001" "and never appears in the retirement flow, which is meaningless for it"

# ─────────────────────────────────────────────────────────────────────────────
echo "== module-status counts partially built items =="

P="$WORK/ms"; new_project "$P"; good_split "$P" >/dev/null 2>&1
bash "$COLLECT_BIN" module-status "$P/.specclaw" >/dev/null 2>&1
MS="$P/.specclaw/analysis/module-status.md"
assert_contains "$(grep '^| MOD-002' "$MS")" "⚠ 1" \
  "the module owning a split item shows a partial count"
assert_contains "$(grep '^| MOD-001' "$MS")" "| 0 | 0 |" \
  "a module with no splits shows zero, distinct from the tainted column"
assert_contains "$(cat "$MS")" "| IS-001 | MOD-002 | BL-010 | ACTIVE |" \
  "and the split is listed under its module"

# ─────────────────────────────────────────────────────────────────────────────
echo "== --item replay: PARTIAL changes no verdict and no exit code =="

# A minimal baseline whose two fixtures split cleanly across the partition:
# GM-001 pins DR-014 (BUILT scope), GM-002 pins DR-002 (DEFERRED scope).
seed_replay() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/baseline/fixtures" "$root/.specclaw/analysis"
  cat > "$root/.specclaw/baseline/scenarios.md" <<'EOF'
### GM-001 — grid lists patients

- **Seam:** Svc.List
- **Seam layer:** service
- **Business rules pinned:** DR-014
- **Verifies backlog item:** BL-010 — View/Search the Patient Grid

### GM-002 — grid requires auth

- **Seam:** Svc.List
- **Seam layer:** service
- **Business rules pinned:** DR-002
- **Verifies backlog item:** BL-010 — View/Search the Patient Grid
EOF
  printf '### AUTH_REQUIRED\n\n- **Condition:** x\n' > "$root/.specclaw/baseline/error-map.md"
  local i
  for i in 1 2; do
    cat > "$root/.specclaw/baseline/fixtures/GM-00$i.json" <<FX
{"scenario_id":"GM-00$i","captured_at":"2026-08-07T10:1${i}:00Z","anchor_date":"2026-08-07",
 "legacy_commit_sha":"abc","runtime_version":"1","normalized_fields":[],
 "input":{},"output":{"outcome":"OK","error_code":null,"threw":false,"n":$i}}
FX
  done
  cat > "$root/.specclaw/analysis/rebuild-backlog.md" <<'EOF'
### BL-010 — View/Search the Patient Grid

- **Module:** MOD-002
- **Acceptance basis (domain-model.md):**
  - DR-014: the grid lists active patients.
  - DR-015: search filters on name.
  - DR-002: the grid is only reachable by an authenticated user.
  - Screens: SCR-004
- **Depends on:** BL-001
EOF
  printf 'DR-002 DR-014 DR-015\n' > "$root/.specclaw/analysis/domain-model.md"
  bash "$BASELINE_BIN" record "$root/.specclaw" >/dev/null 2>&1
}

run_item_replay() {
  local root="$1" a2="$2"
  local rd="$root/.specclaw/replay/run-C"
  rm -rf "$rd"; mkdir -p "$rd/actual"
  bash "$REPLAY_BIN" resolve "$root/.specclaw" BL-010 "$rd/selection.json" >/dev/null 2>&1
  printf '{"stack":"t","build_command":null,"test_command":"true","results_dir":"actual","evidence_exclusions":[]}' > "$rd/run-config.json"
  printf '%s' '[{"scenario_id":"GM-001","verdict":"REPLAYABLE","test_file":"a","legacy_seam_layer":"service","replay_seam_layer":"service"},{"scenario_id":"GM-002","verdict":"REPLAYABLE","test_file":"b","legacy_seam_layer":"service","replay_seam_layer":"service"}]' > "$rd/mapping.json"
  printf '%s' '{"output":{"outcome":"OK","error_code":null,"threw":false,"n":1}}' > "$rd/actual/GM-001.json"
  printf '%s' "$a2" > "$rd/actual/GM-002.json"
  bash "$REPLAY_BIN" compare "$root/.specclaw" "$rd" >/dev/null 2>&1
  bash "$REPLAY_BIN" sanction-check "$root/.specclaw" "$rd" >/dev/null 2>&1
  bash "$REPLAY_BIN" render "$root/.specclaw" BL-010 "$rd" >/dev/null 2>&1
  RENDER_RC=$?
  REPORT="$(ls "$root"/.specclaw/replay/report-*-BL-010.md 2>/dev/null | tail -1)"
  VERDICT_LINE="$(grep -m1 '^\*\*Overall verdict:\*\*' "$REPORT" 2>/dev/null)"
  VERDICT="$(sed 's/^\*\*Overall verdict:\*\* //' <<< "$VERDICT_LINE" | awk '{print $1}')"
}

CLEAN='{"output":{"outcome":"OK","error_code":null,"threw":false,"n":2}}'
DIVERGE='{"output":{"outcome":"REJECTED","error_code":"AUTH_REQUIRED","threw":true,"n":2}}'

# Baseline: no split at all.
Q="$WORK/rp1"; seed_replay "$Q"
run_item_replay "$Q" "$CLEAN"
NOSPLIT_VERDICT="$VERDICT"; NOSPLIT_RC="$RENDER_RC"
assert_eq "PASS" "$NOSPLIT_VERDICT" "a clean --item run with no split is PASS"
assert_eq "0" "$NOSPLIT_RC" "and exits 0"
assert_contains "$(cat "$REPORT")" "_None — this run covers a whole backlog item" \
  "and its report says no split applies"

# The SAME run, with an open split. THE CENTRAL INVARIANT: identical verdict,
# identical exit code — PARTIAL is a marker on a verdict, never an input to it.
Q="$WORK/rp2"; seed_replay "$Q"
bash "$COLLECT_BIN" split-append "$Q/.specclaw" --item BL-010 --reason "auth not built" \
  --unmet-deps BL-001 --implemented-now "grid + search" --deferred "auth integration" \
  --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
  --layers-implemented "ui, api" --layers-deferred "auth-integration" \
  --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary "grid now, auth later" \
  >/dev/null 2>&1
run_item_replay "$Q" "$CLEAN"
assert_eq "$NOSPLIT_VERDICT" "$VERDICT" "an open split changes no verdict"
assert_eq "$NOSPLIT_RC" "$RENDER_RC" "and no exit code"
assert_contains "$VERDICT_LINE" "partial — split IS-001" \
  "but the verdict LINE says the run is partial"
assert_eq "PASS" "$(awk '{print $3}' <<< "$VERDICT_LINE")" \
  "with the verdict token still first, so PASS still parses as PASS"
assert_contains "$(cat "$REPORT")" "is NOT" "the report states it is not the item's final acceptance"
assert_contains "$(cat "$REPORT")" "GM-002" "and names the fixture covering deferred scope"

SEL="$Q/.specclaw/replay/run-C/selection.json"
assert_eq "GM-002" "$(jq -r '.item_split.fixtures_covering_deferred | join(",")' "$SEL" | tr -d '\r')" \
  "selection partitions the fixtures by the split's own declared rules"
assert_eq "GM-001" "$(jq -r '.item_split.fixtures_covering_built | join(",")' "$SEL" | tr -d '\r')" \
  "naming the built-scope fixtures too"

# A FAIL stays a FAIL: PARTIAL never softens a verdict, exactly as taint never
# does. This is the other half of the invariance claim.
Q="$WORK/rp3"; seed_replay "$Q"
run_item_replay "$Q" "$DIVERGE"
NOSPLIT_VERDICT="$VERDICT"; NOSPLIT_RC="$RENDER_RC"
assert_eq "FAIL" "$NOSPLIT_VERDICT" "an unsanctioned divergence is FAIL without a split"
Q="$WORK/rp4"; seed_replay "$Q"
bash "$COLLECT_BIN" split-append "$Q/.specclaw" --item BL-010 --reason r \
  --unmet-deps BL-001 --implemented-now n --deferred d \
  --rules-implemented "DR-014, DR-015" --rules-deferred "DR-002" \
  --layers-implemented api --layers-deferred auth-integration \
  --blocked-until BL-001 --chosen-by "T, 2026-08-14" --summary s >/dev/null 2>&1
run_item_replay "$Q" "$DIVERGE"
assert_eq "$NOSPLIT_VERDICT" "$VERDICT" "a split never softens a FAIL"
assert_eq "$NOSPLIT_RC" "$RENDER_RC" "and never changes its exit code"

# A COMPLETE split is history: the run is that item's acceptance again.
# READY-TO-RESUME first, because COMPLETE straight from ACTIVE is refused —
# which is itself the behaviour asserted earlier in this suite.
bash "$COLLECT_BIN" split-update "$Q/.specclaw" IS-001 --status "READY-TO-RESUME 2026-08-21" >/dev/null 2>&1
bash "$COLLECT_BIN" split-update "$Q/.specclaw" IS-001 --status "COMPLETE 2026-08-22, cleared by run r" >/dev/null 2>&1
run_item_replay "$Q" "$CLEAN"
assert_not_contains "$VERDICT_LINE" "partial" \
  "once a split is COMPLETE the run is the item's acceptance again"
assert_eq "PASS" "$VERDICT" "and its verdict is the item's own, unqualified"

echo
echo "=================================================="
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
