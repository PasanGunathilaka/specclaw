#!/usr/bin/env bash
# run-change-size-tests.sh — right-sized change paths (change 036).
#
# Two things are being pinned, and the second is the one that would hurt.
#
#   1. The validation matrix. `specclaw-validate-change` is the prerequisite
#      gate EVERY phase passes through, so a bug in it blocks every change in
#      the project at once. The matrix is therefore enumerated per size rather
#      than sampled, and the no-size row is enumerated too — a change that
#      predates sizes must behave exactly as it did before this feature landed.
#
#   2. The ratchet's refusals. A downgrade that appeared to work would quietly
#      drop design.md from the required set of a change somebody had already
#      judged to need one, and nothing downstream would mention it. The refusal
#      must be BY NAME and must change nothing on disk.
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-change-size-tests.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SET_PHASE="$BIN_DIR/specclaw-set-phase"
SET_SIZE="$BIN_DIR/specclaw-set-size"
VALIDATE="$BIN_DIR/specclaw-validate-change"
UPDATE_STATUS="$BIN_DIR/specclaw-update-status"
FINDINGS_TEMPLATE="$PLUGIN_DIR/templates/findings.md"

for f in "$SET_PHASE" "$SET_SIZE" "$VALIDATE" "$UPDATE_STATUS" "$FINDINGS_TEMPLATE"; do
  if [[ ! -f "$f" ]]; then
    echo "FATAL: missing file: $f" >&2
    exit 2
  fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label (= '$actual')"
  else
    fail "$label — expected '$expected', got '$actual'"
  fi
}

assert_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    pass "$label"
  else
    fail "$label — expected to find: $needle"
  fi
}

# make_change <slug> <size|-> [artifacts...]  → prints the project root
# artifacts are file basenames to create inside the change dir.
make_change() {
  local slug="$1" size="$2"; shift 2
  local root="$WORK/$slug"
  local cd_="$root/.specclaw/changes/demo"
  mkdir -p "$cd_"
  printf 'project:\n  name: "demo"\n\nworkflow:\n  strict: true\n' > "$root/.specclaw/config.yaml"
  printf '# Proposal\n' > "$cd_/proposal.md"
  local a
  for a in "$@"; do
    case "$a" in
      tasks.md) printf '# Tasks\n\n- [x] `T1` — done\n' > "$cd_/$a" ;;
      *)        printf '# %s\n' "$a" > "$cd_/$a" ;;
    esac
  done
  if [[ "$size" == "-" ]]; then
    ( cd "$root" && "$SET_PHASE" .specclaw demo proposal approved ) >/dev/null 2>&1
  else
    ( cd "$root" && "$SET_PHASE" .specclaw demo proposal approved --size "$size" ) >/dev/null 2>&1
  fi
  printf '%s' "$root"
}

# gate <root> <phase> → "0" or "1"
gate() {
  ( cd "$1" && "$VALIDATE" .specclaw demo "$2" >/dev/null 2>&1; echo $? )
}
gate_msg() {
  ( cd "$1" && "$VALIDATE" .specclaw demo "$2" 2>&1 >/dev/null )
}

# ─── T1: --size round-trips and carries over ─────────────────────────────────
ROOT="$(make_change t1 bounded)"
STATE="$ROOT/.specclaw/changes/demo/state.json"
assert_contains "T1 --size is recorded" '"size": "bounded"' "$(cat "$STATE")"
( cd "$ROOT" && "$SET_PHASE" .specclaw demo spec done ) >/dev/null 2>&1
assert_contains "T1 a later write with no --size preserves it" '"size": "bounded"' "$(cat "$STATE")"

OUT="$( cd "$ROOT" && "$SET_PHASE" .specclaw demo spec done --size nonsense 2>&1 )"
RC=$?
assert_eq "T1 an unknown size is refused" "2" "$RC"
assert_contains "T1 the refusal lists the valid set" "spike bounded architectural" "$OUT"
assert_contains "T1 and the recorded size is untouched" '"size": "bounded"' "$(cat "$STATE")"

# ─── T2: no recorded size behaves exactly as before ──────────────────────────
# The regression that matters most: every change that predates this feature.
ROOT="$(make_change t2a - spec.md design.md tasks.md)"
assert_eq "T2 unsized + all three artifacts → build ready"  "0" "$(gate "$ROOT" build)"
ROOT="$(make_change t2b - spec.md tasks.md)"
assert_eq "T2 unsized without design.md → build refused"    "1" "$(gate "$ROOT" build)"
assert_contains "T2 and it names design.md" "design.md" "$(gate_msg "$ROOT" build)"
assert_eq "T2 unsized reports as architectural" \
  "Size: architectural" \
  "$( cd "$ROOT" && "$VALIDATE" .specclaw demo status 2>/dev/null | grep '^Size:' )"

# ─── T3: bounded drops design.md and nothing else ────────────────────────────
ROOT="$(make_change t3 bounded spec.md tasks.md)"
assert_eq "T3 bounded + spec + tasks → build ready"  "0" "$(gate "$ROOT" build)"
ROOT="$(make_change t3b bounded tasks.md)"
assert_eq "T3 bounded still requires spec.md"        "1" "$(gate "$ROOT" build)"
assert_contains "T3 and names it" "spec.md" "$(gate_msg "$ROOT" build)"
ROOT="$(make_change t3c bounded spec.md)"
assert_eq "T3 bounded still requires tasks.md"       "1" "$(gate "$ROOT" build)"

# ─── T4: architectural is today's behaviour, explicitly ──────────────────────
ROOT="$(make_change t4 architectural spec.md tasks.md)"
assert_eq "T4 architectural without design.md → refused" "1" "$(gate "$ROOT" build)"
ROOT="$(make_change t4b architectural spec.md design.md tasks.md)"
assert_eq "T4 architectural with all three → ready"      "0" "$(gate "$ROOT" build)"

# ─── T5: a spike is refused the three code phases ────────────────────────────
# Note the fixture: it HAS spec.md, design.md and tasks.md. The size decides,
# not the file set — otherwise a spike that someone helpfully planned would walk
# straight into build.
ROOT="$(make_change t5 spike spec.md design.md tasks.md verify-report.md)"
for phase in build verify pr; do
  assert_eq "T5 spike is refused $phase" "1" "$(gate "$ROOT" "$phase")"
  assert_contains "T5 the $phase refusal names the recovery" \
    "propose the follow-up as its own change" "$(gate_msg "$ROOT" "$phase")"
done

# ─── T6: a spike archives on findings.md ─────────────────────────────────────
ROOT="$(make_change t6 spike)"
assert_eq "T6 spike without findings.md → archive refused" "1" "$(gate "$ROOT" archive)"
assert_contains "T6 and asks for findings.md, not a verify report" \
  "findings.md" "$(gate_msg "$ROOT" archive)"
printf '# Findings\n' > "$ROOT/.specclaw/changes/demo/findings.md"
assert_eq "T6 spike with findings.md → archive ready" "0" "$(gate "$ROOT" archive)"
assert_eq "T6 a spike is not asked for a verify report" \
  "" "$(gate_msg "$ROOT" archive | grep 'verify-report' || true)"

# ─── T7: non-strict mode degrades the spike refusals like every other check ──
ROOT="$(make_change t7 spike spec.md design.md tasks.md)"
printf 'project:\n  name: "demo"\n\nworkflow:\n  strict: false\n' > "$ROOT/.specclaw/config.yaml"
assert_eq "T7 non-strict turns the spike refusal into a warning" "0" "$(gate "$ROOT" build)"
assert_contains "T7 and still says it" "WARNING" "$(gate_msg "$ROOT" build)"

# ─── T8: the ratchet climbs ──────────────────────────────────────────────────
ROOT="$(make_change t8 spike)"
STATE="$ROOT/.specclaw/changes/demo/state.json"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo bounded --reason "it alters an existing flow" 2>&1 )"
assert_eq "T8 spike → bounded succeeds" "0" "$?"
assert_contains "T8 and says what moved"  "spike → bounded" "$OUT"
assert_contains "T8 and records it"       '"size": "bounded"' "$(cat "$STATE")"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo architectural --reason "new interface" 2>&1 )"
assert_contains "T8 bounded → architectural succeeds" "bounded → architectural" "$OUT"
assert_contains "T8 and warns that design.md is now required" "design.md is now required" "$OUT"

# ─── T9: the ratchet refuses to fall, by name, changing nothing ──────────────
BEFORE="$(cat "$STATE")"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo bounded --reason "reconsidered" 2>&1 )"
RC=$?
assert_eq "T9 a downgrade exits 2" "2" "$RC"
assert_contains "T9 the refusal names both sizes" \
  "refusing to downgrade demo from architectural to bounded" "$OUT"
assert_eq "T9 and nothing on disk changed" "$BEFORE" "$(cat "$STATE")"

OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo architectural --reason "again" 2>&1 )"
RC=$?
assert_eq "T9 a no-op exits 2" "2" "$RC"
assert_contains "T9 and says it is already that size" "already architectural" "$OUT"

# ─── T10: --reason is not optional ───────────────────────────────────────────
ROOT="$(make_change t10 spike)"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo bounded 2>&1 )"
RC=$?
assert_eq "T10 an upgrade with no reason exits 2" "2" "$RC"
assert_contains "T10 and says why it is required" "changes what the operator approved" "$OUT"

# ─── T11: a change with no recorded phase cannot be sized ────────────────────
ROOT="$WORK/t11"; mkdir -p "$ROOT/.specclaw/changes/demo"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo bounded --reason x 2>&1 )"
RC=$?
assert_eq "T11 no state.json exits 2" "2" "$RC"
assert_contains "T11 and names the command that fixes it" "specclaw-set-phase" "$OUT"

# ─── T12: an unsized change is at the top of the ratchet, so it is inert ─────
ROOT="$(make_change t12 -)"
OUT="$( cd "$ROOT" && "$SET_SIZE" .specclaw demo architectural --reason x 2>&1 )"
RC=$?
assert_eq "T12 an unsized change cannot be 'upgraded' to architectural" "2" "$RC"
assert_contains "T12 because it already reads as one" "already architectural" "$OUT"

# ─── T13: the upgrade lands in status.md, and touches nothing else ───────────
ROOT="$(make_change t13 bounded spec.md tasks.md)"
STATUS="$ROOT/.specclaw/changes/demo/status.md"
cp "$STATUS" "$WORK/status-before.md"
( cd "$ROOT" && "$SET_SIZE" .specclaw demo architectural --reason "grew a public interface" ) >/dev/null 2>&1
assert_contains "T13 a Size row appears" "| Size |" "$(cat "$STATUS")"
assert_contains "T13 carrying the new size"  "architectural" "$(grep '| Size |' "$STATUS")"
assert_contains "T13 and the reason"         "grew a public interface" "$(grep '| Size |' "$STATUS")"
OTHER_DIFF="$(diff <(grep -v '| Size |' "$STATUS") <(grep -v '| Size |' "$WORK/status-before.md") || true)"
if [[ -z "$OTHER_DIFF" ]]; then
  pass "T13 every other line is byte-identical"
else
  fail "T13 the upgrade disturbed other lines:
$OTHER_DIFF"
fi

# ─── T14: bounded → architectural re-requires design.md ──────────────────────
# The whole point of the ratchet: a gate that passed a moment ago now stops.
assert_eq "T14 architectural now demands design.md" "1" "$(gate "$ROOT" build)"
assert_contains "T14 and says which size requires it" \
  "required for architectural changes" "$(gate_msg "$ROOT" build)"
printf '# Design\n' > "$ROOT/.specclaw/changes/demo/design.md"
assert_eq "T14 and passes once it exists" "0" "$(gate "$ROOT" build)"

# ─── T15: corrupt state degrades to architectural, never to an error ─────────
ROOT="$(make_change t15 bounded spec.md tasks.md)"
printf 'this is not json {{{\n' > "$ROOT/.specclaw/changes/demo/state.json"
assert_eq "T15 unparseable state.json does not error the gate" "1" "$(gate "$ROOT" build)"
assert_contains "T15 it falls back to architectural (design.md demanded)" \
  "design.md" "$(gate_msg "$ROOT" build)"

# ─── T19: a deferred task ([>], change 038) does not block the verify gate ───
# count_incomplete = total - done - deferred, so a change with one done task
# and one correctly-deferred task reads as "verify ready", not "1 incomplete".
ROOT="$(make_change t19 bounded spec.md tasks.md)"
CD19="$ROOT/.specclaw/changes/demo"
{
  printf '# Tasks\n\n### Wave 1\n\n'
  printf -- '- [x] `T1` — done\n\n'
  printf -- '- [>] `T2` — deferred\n'
  printf -- '  - Deferred-Reason: waiting on a sibling change\n'
} > "$CD19/tasks.md"
assert_eq "T19a a deferred task does not block the verify gate" "0" "$(gate "$ROOT" verify)"
assert_contains "T19b the status view names it deferred, not incomplete" \
  "1 deferred" "$(cd "$ROOT" && "$VALIDATE" .specclaw demo status 2>/dev/null)"

# A genuinely incomplete (pending) task must still block — the exclusion is
# specific to deferred, not a general loosening of the gate.
printf -- '- [ ] `T3` — not started\n' >> "$CD19/tasks.md"
assert_eq "T19c a real pending task still blocks the verify gate" "1" "$(gate "$ROOT" verify)"

# ─── T16: the dashboard glyphs a recorded size and only a recorded size ──────
ROOT="$WORK/t16"; mkdir -p "$ROOT/.specclaw/changes"
printf 'project:\n  name: "demo"\n' > "$ROOT/.specclaw/config.yaml"
for pair in "sp:spike" "bo:bounded" "ar:architectural" "un:-"; do
  slug="${pair%%:*}"; size="${pair##*:}"
  mkdir -p "$ROOT/.specclaw/changes/$slug"
  printf '# Proposal\n' > "$ROOT/.specclaw/changes/$slug/proposal.md"
  if [[ "$size" == "-" ]]; then
    ( cd "$ROOT" && "$SET_PHASE" .specclaw "$slug" proposal approved ) >/dev/null 2>&1
  else
    ( cd "$ROOT" && "$SET_PHASE" .specclaw "$slug" proposal approved --size "$size" ) >/dev/null 2>&1
  fi
done
( cd "$ROOT" && "$UPDATE_STATUS" .specclaw ) >/dev/null 2>&1
DASH="$(cat "$ROOT/.specclaw/STATUS.md" 2>/dev/null || true)"
assert_contains "T16 spike glyph"         "**sp** ⚡" "$DASH"
assert_contains "T16 bounded glyph"       "**bo** ▫" "$DASH"
assert_contains "T16 architectural glyph" "**ar** ▣" "$DASH"
if printf '%s' "$DASH" | grep -q '\*\*un\*\* [⚡▫▣]'; then
  fail "T16 an unsized change was glyphed — that is a declaration nobody made"
else
  pass "T16 an unsized change carries no glyph"
fi

# ─── T17: the findings template says the thing that keeps a spike a spike ────
FT="$(cat "$FINDINGS_TEMPLATE")"
assert_contains "T17 findings.md states the question"    "## The question" "$FT"
assert_contains "T17 findings.md states a recommendation" "## Recommendation" "$FT"
assert_contains "T17 findings.md pins the no-code rule"   "**Code kept:** none" "$FT"

# ─── T18: the proposal template carries the size field ───────────────────────
PT="$(cat "$PLUGIN_DIR/templates/proposal.md")"
assert_contains "T18 proposal.md has a Size line" "**Size:**" "$PT"
assert_contains "T18 and lists the closed set"    "spike / bounded / architectural" "$PT"

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
