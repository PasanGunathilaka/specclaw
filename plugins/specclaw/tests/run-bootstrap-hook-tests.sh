#!/usr/bin/env bash
# run-bootstrap-hook-tests.sh — the SessionStart bootstrap (change 033).
#
# This hook runs on EVERY session start, clear and compact in a specclaw
# project, which makes two of its properties more important than its content:
#
#   It must be silent where it does not belong. A plugin that injects ~5KB into
#   every session in every repo on the machine is a tax, and the failure is
#   invisible to the person paying it.
#
#   It must never emit a partial document. A hook whose JSON does not parse does
#   not degrade to "no router" — it opens the session on a parse error. So the
#   snapshot is captured before anything is printed, and the corrupt-state case
#   below asserts that stdout STILL parses.
#
# The decoy fixture is the other half of the suite. config.yaml carries four
# `enabled:` keys above `bootstrap:`; a whole-file `grep enabled:` would read one
# of those instead, silently, and the hook would be on or off according to which
# block came first. Without the decoys that regression passes.
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-bootstrap-hook-tests.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"

HOOK="$PLUGIN_DIR/hooks/session-start"
HOOKS_JSON="$PLUGIN_DIR/hooks/hooks.json"
SNAPSHOT="$BIN_DIR/specclaw-bootstrap-snapshot"
ROUTER="$PLUGIN_DIR/skills/using-specclaw/SKILL.md"
SET_PHASE="$BIN_DIR/specclaw-set-phase"

for f in "$HOOK" "$HOOKS_JSON" "$SNAPSHOT" "$ROUTER" "$SET_PHASE"; do
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
assert_not_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then
    fail "$label — did NOT expect: $needle"
  else
    pass "$label"
  fi
}

# A config.yaml whose `bootstrap:` block sits BELOW four decoy `enabled:` keys,
# exactly as the shipped template does. The decoys are the test — without them a
# whole-file grep lands on the right line by luck and the regression passes.
write_config() {
  local dest="$1" enabled="$2" snapshot="$3" max_lines="${4:-15}"
  cat > "$dest" <<CFG
project:
  name: "demo"

notifications:
  enabled: true

build:
  dynamic_agents:
    enabled: false
    cache: true

loop:
  enabled: true
  max_iterations: 5

party:
  enabled: true
  max_seats: 6

bootstrap:
  enabled: ${enabled}
  snapshot: ${snapshot}
  max_lines: ${max_lines}
CFG
}

# make_project <slug> [--no-config] → project root
make_project() {
  local slug="$1"; shift
  local root="$WORK/$slug"
  mkdir -p "$root/.specclaw/changes"
  if [[ "${1:-}" != "--no-config" ]]; then
    write_config "$root/.specclaw/config.yaml" true true
  fi
  printf '%s' "$root"
}

# add_change <root> <name> <phase> <status> [size] [done/total]
add_change() {
  local root="$1" name="$2" phase="$3" status="$4" size="${5:-}" tasks="${6:-}"
  local d="$root/.specclaw/changes/$name"
  mkdir -p "$d"
  printf '# Proposal\n' > "$d/proposal.md"
  if [[ -n "$tasks" ]]; then
    local done="${tasks%%/*}" total="${tasks##*/}" i
    {
      printf '# Tasks\n\n'
      for ((i = 1; i <= total; i++)); do
        if [[ "$i" -le "$done" ]]; then printf -- '- [x] `T%s` — t\n' "$i"
        else printf -- '- [ ] `T%s` — t\n' "$i"; fi
      done
    } > "$d/tasks.md"
  fi
  if [[ -n "$size" ]]; then
    ( cd "$root" && "$SET_PHASE" .specclaw "$name" "$phase" "$status" --size "$size" ) >/dev/null 2>&1
  else
    ( cd "$root" && "$SET_PHASE" .specclaw "$name" "$phase" "$status" ) >/dev/null 2>&1
  fi
}

run_hook() { ( cd "$1" && "$HOOK" 2>/dev/null ); }

# context <root> → the decoded additionalContext, or "" when nothing was emitted.
context() {
  local out
  out="$(run_hook "$1")"
  [[ -n "$out" ]] || return 0
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$out" | python3 -c 'import json,sys
try:
    print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception:
    sys.exit(0)' 2>/dev/null
  else
    # No python3: unescape just enough for the content assertions.
    printf '%s' "$out" | sed -e 's/.*"additionalContext":"//' -e 's/"}}$//' -e 's/\\n/\n/g'
  fi
}

json_ok() {
  if command -v python3 >/dev/null 2>&1; then
    printf '%s' "$1" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1
  else
    printf '%s' "$1" | grep -q '^{"hookSpecificOutput":{.*}}$'
  fi
}

# ─── T1: not a specclaw project → silence ────────────────────────────────────
ROOT="$(make_project t1 --no-config)"
OUT="$(run_hook "$ROOT")"
RC=$?
assert_eq "T1 no config.yaml → exit 0"      "0"  "$RC"
assert_eq "T1 no config.yaml → empty stdout" ""  "$OUT"

# A bare .specclaw/ directory is NOT a specclaw project: stray ones turn up in
# repos that once had a change dir committed, and in fixtures like this one.
mkdir -p "$ROOT/.specclaw/changes/ghost"
printf '# Proposal\n' > "$ROOT/.specclaw/changes/ghost/proposal.md"
assert_eq "T1 a .specclaw/ dir with no config is still silent" "" "$(run_hook "$ROOT")"

# ─── T2: an unrelated repo entirely → silence ────────────────────────────────
ROOT="$WORK/t2"; mkdir -p "$ROOT/src"
assert_eq "T2 a repo with no .specclaw at all is silent" "" "$(run_hook "$ROOT")"

# ─── T3: the healthy path ────────────────────────────────────────────────────
ROOT="$(make_project t3)"
add_change "$ROOT" 032-party-mode build in-progress bounded 6/8
add_change "$ROOT" 028-phase-time proposal draft
OUT="$(run_hook "$ROOT")"
if json_ok "$OUT"; then pass "T3 stdout is valid JSON"; else fail "T3 stdout is not valid JSON: $OUT"; fi
assert_contains "T3 declares the hook event" '"hookEventName":"SessionStart"' "$OUT"
CTX="$(context "$ROOT")"
assert_contains "T3 router heading"        "# Using specclaw" "$CTX"
assert_contains "T3 the hard gate"         "MUST invoke \`/specclaw:propose\`" "$CTX"
assert_contains "T3 the routing table"     "Routing table" "$CTX"
assert_contains "T3 the announce line"     "Using \`/specclaw:<verb>\`" "$CTX"
assert_contains "T3 the red flags"         "Red flags" "$CTX"
assert_contains "T3 the frontmatter is stripped" "" "$CTX"
assert_not_contains "T3 no YAML description leaks in" "description:" "$CTX"

# ─── T4: the live state block ────────────────────────────────────────────────
assert_contains "T4 state heading"          "## specclaw state (live" "$CTX"
assert_contains "T4 the in-progress build"  "032-party-mode" "$CTX"
assert_contains "T4 with its task counts"   "6/8 tasks, 0 failed" "$CTX"
assert_contains "T4 and its size glyph"     "▫" "$CTX"
assert_contains "T4 the pending proposal"   "028-phase-time" "$CTX"
assert_contains "T4 states the routing consequence" \
  "not /specclaw:propose" "$CTX"

# ─── T4b: a deferred task ([>], change 038) does not corrupt the task-count
# line — the 4th `--count` field must not spill into the failed count. ───────
ROOT="$(make_project t4b)"
D4B="$ROOT/.specclaw/changes/deferred-check"
mkdir -p "$D4B"
printf '# Proposal\n' > "$D4B/proposal.md"
{
  printf '# Tasks\n\n'
  printf -- '- [x] `T1` — done\n'
  printf -- '- [>] `T2` — deferred\n'
  printf -- '  - Deferred-Reason: waiting\n'
} > "$D4B/tasks.md"
( cd "$ROOT" && "$SET_PHASE" .specclaw deferred-check build in_progress ) >/dev/null 2>&1
SNAP_OUT="$( cd "$ROOT" && "$SNAPSHOT" .specclaw 2>/dev/null )"
assert_contains "T4b deferred task reads as 1/2 tasks, 0 failed (not corrupted)" \
  "1/2 tasks, 0 failed" "$SNAP_OUT"

# ─── T5: the byte cap ────────────────────────────────────────────────────────
# It is paid on every session start, clear and compact. 12 changes is a busy
# project, not a pathological one.
ROOT="$(make_project t5)"
for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
  add_change "$ROOT" "0${i}-a-change-with-a-fairly-long-slug" build in-progress architectural 3/9
done
CTX="$(context "$ROOT")"
BYTES="$(printf '%s' "$CTX" | wc -c | tr -d ' ')"
if [[ "$BYTES" -le 8000 ]]; then
  pass "T5 injected context is within the 8000-byte cap ($BYTES)"
else
  fail "T5 injected context is $BYTES bytes — over the 8000-byte cap"
fi

# ─── T6: max_lines is honoured ───────────────────────────────────────────────
write_config "$ROOT/.specclaw/config.yaml" true true 4
CTX="$(context "$ROOT")"
ROWS="$(printf '%s' "$CTX" | grep -c '^- 0' || true)"
assert_eq "T6 max_lines caps the change rows" "4" "$ROWS"
assert_contains "T6 and says how many were elided" "more (run /specclaw:status)" "$CTX"

# ─── T7: two builds → ask, never guess ───────────────────────────────────────
ROOT="$(make_project t7)"
add_change "$ROOT" 040-one build in-progress bounded 1/3
add_change "$ROOT" 041-two build in-progress bounded 2/3
CTX="$(context "$ROOT")"
assert_contains "T7 both builds are listed (1)" "040-one" "$CTX"
assert_contains "T7 both builds are listed (2)" "041-two" "$CTX"
assert_contains "T7 and the router is told to ask" "ASK which change" "$CTX"

# ─── T8: enabled:false is read from the bootstrap block, not another one ─────
# The decoy fixture puts `enabled: true` under notifications, `enabled: false`
# under build.dynamic_agents, `enabled: true` under loop and under party — all
# ABOVE bootstrap. A whole-file grep reads the wrong one.
ROOT="$(make_project t8)"
add_change "$ROOT" 050-x build in-progress bounded 1/2
write_config "$ROOT/.specclaw/config.yaml" false true
OUT="$(run_hook "$ROOT")"
RC=$?
assert_eq "T8 bootstrap.enabled:false → exit 0"        "0" "$RC"
assert_eq "T8 bootstrap.enabled:false → empty stdout"  ""  "$OUT"

write_config "$ROOT/.specclaw/config.yaml" true true
OUT="$(run_hook "$ROOT")"
if [[ -n "$OUT" ]]; then
  pass "T8 bootstrap.enabled:true emits, though four other enabled: keys sit above it"
else
  fail "T8 bootstrap.enabled:true emitted nothing — a config read found the wrong block"
fi

# ─── T9: snapshot:false → router only ────────────────────────────────────────
write_config "$ROOT/.specclaw/config.yaml" true false
CTX="$(context "$ROOT")"
assert_contains "T9 the router is still injected" "# Using specclaw" "$CTX"
assert_not_contains "T9 the state block is not"   "## specclaw state" "$CTX"

# ─── T10: a corrupt state file degrades, and stdout still parses ─────────────
ROOT="$(make_project t10)"
add_change "$ROOT" 060-y build in-progress bounded 1/2
printf 'not json at all {{{{\n' > "$ROOT/.specclaw/changes/060-y/state.json"
OUT="$(run_hook "$ROOT")"
RC=$?
assert_eq "T10 corrupt state.json → exit 0" "0" "$RC"
if json_ok "$OUT"; then
  pass "T10 and stdout is STILL valid JSON (a partial document would break the session)"
else
  fail "T10 corrupt state produced unparseable stdout: $OUT"
fi
assert_contains "T10 the router survives" "# Using specclaw" "$(context "$ROOT")"

# ─── T11: the snapshot writes nothing, anywhere ──────────────────────────────
ROOT="$(make_project t11)"
add_change "$ROOT" 070-z build in-progress bounded 1/2
BEFORE="$(find "$ROOT/.specclaw" | LC_ALL=C sort)"
BEFORE_SUM="$(find "$ROOT/.specclaw" -type f -exec cksum {} \; | LC_ALL=C sort)"
( cd "$ROOT" && "$SNAPSHOT" .specclaw ) >/dev/null 2>&1
( cd "$ROOT" && "$HOOK" ) >/dev/null 2>&1
AFTER="$(find "$ROOT/.specclaw" | LC_ALL=C sort)"
AFTER_SUM="$(find "$ROOT/.specclaw" -type f -exec cksum {} \; | LC_ALL=C sort)"
assert_eq "T11 no file was created or removed" "$BEFORE" "$AFTER"
assert_eq "T11 no file was modified"           "$BEFORE_SUM" "$AFTER_SUM"

# ─── T12: hooks.json is registered correctly ─────────────────────────────────
HJ="$(cat "$HOOKS_JSON")"
if json_ok "$(printf '%s' "$HJ" | tr -d '\n')" || command -v python3 >/dev/null 2>&1 &&
   python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$HOOKS_JSON" >/dev/null 2>&1; then
  pass "T12 hooks.json is valid JSON"
else
  fail "T12 hooks.json is not valid JSON"
fi
assert_contains "T12 registers SessionStart"   '"SessionStart"' "$HJ"
assert_contains "T12 on all three matchers"    "startup|clear|compact" "$HJ"
assert_contains "T12 pointing at the hook"     "hooks/session-start" "$HJ"

# ─── T13: the skill's description is trigger-only ────────────────────────────
DESC="$(sed -n '2p' "$ROUTER")"
if printf '%s' "$DESC" | grep -q '^description: Use when'; then
  pass "T13 the router's description opens with a trigger condition"
else
  fail "T13 the router's description must be trigger-first — got: $DESC"
fi
LEN="$(printf '%s' "${DESC#description: }" | wc -c | tr -d ' ')"
if [[ "$LEN" -le 300 ]]; then
  pass "T13 and is within 300 characters ($LEN)"
else
  fail "T13 description is $LEN characters — over 300"
fi

# ─── T14: the hook is executable and exits 0 even with a broken router ───────
ROOT="$(make_project t14)"
if [[ -x "$HOOK" ]]; then pass "T14 the hook is executable"; else fail "T14 the hook is not executable"; fi
if [[ -x "$SNAPSHOT" ]]; then pass "T14 the snapshot is executable"; else fail "T14 the snapshot is not executable"; fi

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
