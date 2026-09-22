#!/usr/bin/env bash
# run-timing-tests.sh — the timing ledger (change 028).
#
# Two properties carry the design and are pinned first:
#
#   THE LEDGER IS APPEND-ONLY. Build runs up to parallel_tasks agents at once;
#   a ledger each of them read, modified and wrote back would lose spans.
#
#   AN UNCLOSED SPAN IS VISIBLE. A crashed run leaves an open span that renders
#   "still running". A ledger that dropped it instead would make a hang
#   indistinguishable from a step that never started — which is the exact
#   question this change exists to answer.
#
# And one that is not about timing at all: EVERY PATH EXITS 0. A build that
# failed because its stopwatch broke would be strictly worse than the
# unaccountability being fixed.
#
# Plain bash + coreutils only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"

TIMER="$BIN_DIR/specclaw-timer"
PROGRESS="$BIN_DIR/specclaw-progress"
RUN_LONG="$BIN_DIR/specclaw-run-long"
INIT="$BIN_DIR/specclaw-init"
CONFIG_TEMPLATE="$PLUGIN_DIR/templates/config.yaml"

for f in "$TIMER" "$PROGRESS" "$RUN_LONG" "$INIT" "$CONFIG_TEMPLATE"; do
  if [[ ! -f "$f" ]]; then echo "FATAL: missing file: $f" >&2; exit 2; fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then pass "$label (= '$actual')"
  else fail "$label — expected '$expected', got '$actual'"; fi
}
assert_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then pass "$label"
  else fail "$label — expected to find: $needle"; fi
}
assert_not_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then fail "$label — did NOT expect: $needle"
  else pass "$label"; fi
}

mk_project() {
  local slug="$1" enabled="${2:-true}"
  local root="$WORK/$slug"
  mkdir -p "$root/.specclaw/changes/demo"
  printf 'project:\n  name: "demo"\n\ntiming:\n  enabled: %s\n  anomaly_factor: 3\n' \
    "$enabled" > "$root/.specclaw/config.yaml"
  printf '%s' "$root"
}

# ─── T1: a span round-trips ──────────────────────────────────────────────────
ROOT="$(mk_project t1)"
( cd "$ROOT" && "$TIMER" start .specclaw demo T1 --kind task --label "build it" --model sonnet-5 --attempt 2 )
sleep 1
( cd "$ROOT" && "$TIMER" stop .specclaw demo T1 --status ok )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo )"
assert_contains "T1 the span appears"        '`T1`' "$REPORT"
assert_contains "T1 with its label"          "build it" "$REPORT"
assert_contains "T1 with its model"          "sonnet-5" "$REPORT"
assert_contains "T1 with its attempt"        "| 2 |" "$REPORT"
# NOT an exact "1s": a `sleep 1` under parallel load measures 1s or 2s, and a
# suite that fails on machine load is a suite people learn to ignore. What is
# being pinned is that the span was MEASURED at all.
T1_ROW="$(printf '%s' "$REPORT" | grep '^| `T1` |' || true)"
if printf '%s' "$T1_ROW" | grep -qE '\| [0-9]+s \|'; then
  pass "T1 and a measured, non-zero duration"
else
  fail "T1 duration not measured — row: $T1_ROW"
fi
assert_not_contains "T1 and is not still running" "still running" "$REPORT"

# ─── T2: append-only survives interleaving ───────────────────────────────────
# Two spans opened together and closed in the OPPOSITE order — the wave case.
ROOT="$(mk_project t2)"
( cd "$ROOT" && "$TIMER" start .specclaw demo A --kind task --label alpha )
( cd "$ROOT" && "$TIMER" start .specclaw demo B --kind task --label beta )
sleep 1
( cd "$ROOT" && "$TIMER" stop .specclaw demo B --status ok )
( cd "$ROOT" && "$TIMER" stop .specclaw demo A --status ok )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo )"
assert_contains "T2 the first span survives"  "alpha" "$REPORT"
assert_contains "T2 the second survives too"  "beta" "$REPORT"
assert_not_contains "T2 neither is left open" "still running" "$REPORT"

# Genuinely concurrent writers, which is what build does.
ROOT="$(mk_project t2b)"
for i in 1 2 3 4 5 6 7 8; do
  ( cd "$ROOT" && "$TIMER" start .specclaw demo "P$i" --kind task --label "parallel $i" ) &
done
wait
LINES="$(grep -c '^{' "$ROOT/.specclaw/changes/demo/timeline.jsonl" 2>/dev/null || echo 0)"
assert_eq "T2 eight concurrent writers lose nothing" "8" "$LINES"

# ─── T3: an unclosed span is visible, and excluded from the total ────────────
ROOT="$(mk_project t3)"
( cd "$ROOT" && "$TIMER" start .specclaw demo HUNG --kind task --label "the one that hung" )
( cd "$ROOT" && "$TIMER" start .specclaw demo OK1 --kind task --label fine )
sleep 1
( cd "$ROOT" && "$TIMER" stop .specclaw demo OK1 --status ok )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo )"
assert_contains "T3 an open span renders as still running" "still running" "$REPORT"
assert_contains "T3 and is counted as open"                "Open spans:** 1" "$REPORT"

# ─── T4: report formats ──────────────────────────────────────────────────────
assert_contains "T4 md names the total"    "Total measured" "$REPORT"
assert_contains "T4 md has a by-kind split" "## By kind" "$REPORT"
assert_contains "T4 md names the slowest"   "## Slowest" "$REPORT"
assert_contains "T4 md counts retries"      "Retries:" "$REPORT"

JSON="$( cd "$ROOT" && "$TIMER" report .specclaw demo --format json )"
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    pass "T4 json parses"
  else
    fail "T4 json does not parse: $JSON"
  fi
else
  assert_contains "T4 json looks like json" '"spans"' "$JSON"
fi

# ─── T5: --write installs timeline.md ────────────────────────────────────────
( cd "$ROOT" && "$TIMER" report .specclaw demo --write ) >/dev/null
if [[ -f "$ROOT/.specclaw/changes/demo/timeline.md" ]]; then
  pass "T5 --write installs timeline.md"
else
  fail "T5 --write did not write timeline.md"
fi

# ─── T6: agent-runs fills the column nothing ever filled ─────────────────────
ROWS="$( cd "$ROOT" && "$TIMER" agent-runs .specclaw demo )"
assert_contains "T6 one row per task span" "| OK1 |" "$ROWS"
assert_contains "T6 carrying its label"    "fine" "$ROWS"
assert_contains "T6 an open task says so"  "running" "$ROWS"
NONTASK="$(printf '%s' "$ROWS" | grep -c 'wave' || true)"
assert_eq "T6 and only task spans appear" "0" "$NONTASK"

# ─── T7: enclosing spans do not double-count ─────────────────────────────────
# A wave encloses its tasks. Counting both reports a build as longer than it was.
ROOT="$(mk_project t7)"
( cd "$ROOT" && "$TIMER" start .specclaw demo W1 --kind wave --label "wave 1" --duration 100 )
( cd "$ROOT" && "$TIMER" start .specclaw demo T1 --kind task --label a --duration 60 )
( cd "$ROOT" && "$TIMER" start .specclaw demo T2 --kind task --label b --duration 40 )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo )"
assert_contains "T7 the total is the leaf spans only" "1m40s" "$REPORT"
assert_contains "T7 while the wave still shows in the breakdown" "**wave**" "$REPORT"

# ─── T8: the baseline, present and absent ────────────────────────────────────
ROOT="$(mk_project t8)"
( cd "$ROOT" && "$TIMER" start .specclaw demo T1 --kind task --label "npm test" --duration 100 )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo --baseline )"
assert_contains "T8 no history says so, out loud" "no archived timelines" "$REPORT"

# Three archived runs of the same kind+label, median 10s.
mkdir -p "$ROOT/.specclaw/changes/archive/old1" \
         "$ROOT/.specclaw/changes/archive/old2" \
         "$ROOT/.specclaw/changes/archive/old3"
i=0
for d in 8 10 12; do
  i=$((i + 1))
  cat > "$ROOT/.specclaw/changes/archive/old$i/timeline.jsonl" <<EOT
{"ev":"start","span":"T1","kind":"task","label":"npm test","at":"x","ts":1000}
{"ev":"stop","span":"T1","at":"x","ts":$((1000 + d)),"status":"ok"}
EOT
done
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo --baseline )"
assert_contains "T8 a 10x-median span is marked" "× median" "$REPORT"
assert_not_contains "T8 and the no-baseline note is gone" "no archived timelines" "$REPORT"

# Below the factor → not marked.
ROOT2="$(mk_project t8b)"
cp -R "$ROOT/.specclaw/changes/archive" "$ROOT2/.specclaw/changes/archive"
( cd "$ROOT2" && "$TIMER" start .specclaw demo T1 --kind task --label "npm test" --duration 20 )
REPORT="$( cd "$ROOT2" && "$TIMER" report .specclaw demo --baseline )"
assert_not_contains "T8 a 2x-median span is not marked (factor is 3)" "× median" "$REPORT"

# ─── T9: timing.enabled:false is a total no-op ───────────────────────────────
ROOT="$(mk_project t9 false)"
( cd "$ROOT" && "$TIMER" start .specclaw demo T1 --kind task --label x )
RC=$?
( cd "$ROOT" && "$TIMER" stop .specclaw demo T1 )
assert_eq "T9 start exits 0 when disabled" "0" "$RC"
if [[ -f "$ROOT/.specclaw/changes/demo/timeline.jsonl" ]]; then
  fail "T9 disabled timing still wrote a ledger"
else
  pass "T9 disabled timing wrote nothing at all"
fi

# ─── T10: a corrupt line is skipped, and the report still renders ────────────
ROOT="$(mk_project t10)"
( cd "$ROOT" && "$TIMER" start .specclaw demo T1 --kind task --label good --duration 5 )
printf 'this is not json at all\n' >> "$ROOT/.specclaw/changes/demo/timeline.jsonl"
( cd "$ROOT" && "$TIMER" start .specclaw demo T2 --kind task --label "also good" --duration 5 )
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo 2>/dev/null )"
RC=$?
assert_eq "T10 a corrupt line does not fail the report" "0" "$RC"
assert_contains "T10 spans before it survive" "good" "$REPORT"
assert_contains "T10 spans after it survive"  "also good" "$REPORT"
WARN_OUT="$( cd "$ROOT" && "$TIMER" report .specclaw demo 2>&1 >/dev/null )"
assert_contains "T10 and the skip is announced" "unparseable" "$WARN_OUT"

# ─── T11: every path exits 0 ─────────────────────────────────────────────────
ROOT="$(mk_project t11)"
( cd "$ROOT" && "$TIMER" start .specclaw no-such-change T1 --kind task ) >/dev/null 2>&1
assert_eq "T11 a change dir that does not exist is not an error" "0" "$?"
( cd "$ROOT" && "$TIMER" report .specclaw no-such-change ) >/dev/null 2>&1
assert_eq "T11 nor is reporting on one"                         "0" "$?"
( cd "$ROOT" && "$TIMER" stop .specclaw no-such-change T1 ) >/dev/null 2>&1
assert_eq "T11 nor is stopping a span that was never started"   "0" "$?"
( cd "$ROOT" && "$TIMER" bogus-subcommand .specclaw demo ) >/dev/null 2>&1
assert_eq "T11 but a usage error exits 2"                       "2" "$?"

# ─── T12: the progress line names step, elapsed and bottleneck ───────────────
ROOT="$(mk_project t12)"
( cd "$ROOT" && "$TIMER" start .specclaw demo SLOW --kind task --label "the slow one" --duration 600 )
( cd "$ROOT" && "$TIMER" start .specclaw demo T5 --kind task --label "in flight" --model sonnet-5 --attempt 2 )
LINE="$( cd "$ROOT" && "$PROGRESS" .specclaw demo --phase build )"
assert_contains "T12 names the phase"           "⏱ build" "$LINE"
assert_contains "T12 names the active span"     "T5 in flight" "$LINE"
assert_contains "T12 with its model"            "sonnet-5" "$LINE"
assert_contains "T12 and its attempt"           "attempt 2" "$LINE"
assert_contains "T12 and the bottleneck so far" "slowest so far: SLOW" "$LINE"

LOG="$WORK/loop-log.md"
( cd "$ROOT" && "$PROGRESS" .specclaw demo --phase build --append-to "$LOG" ) >/dev/null
assert_contains "T12 --append-to also writes it where it survives the session" \
  "in flight" "$(cat "$LOG" 2>/dev/null || true)"

( cd "$ROOT" && "$PROGRESS" .specclaw nothing-here ) >/dev/null 2>&1
assert_eq "T12 and a change with no ledger prints nothing, exit 0" "0" "$?"

# ─── T13: run-long without --change is unchanged ─────────────────────────────
ROOT="$(mk_project t13)"
( cd "$ROOT" && "$RUN_LONG" --phase test -- "echo hi" ) >/dev/null 2>&1
if [[ -f "$ROOT/.specclaw/changes/demo/timeline.jsonl" ]]; then
  fail "T13 run-long wrote a ledger entry without --change"
else
  pass "T13 run-long without --change records nothing"
fi

( cd "$ROOT" && "$RUN_LONG" --phase test --change .specclaw:demo -- "echo hi" ) >/dev/null 2>&1
REPORT="$( cd "$ROOT" && "$TIMER" report .specclaw demo )"
assert_contains "T13 with --change the command lands in the ledger" "echo hi" "$REPORT"
assert_contains "T13 as a cmd span"                                 "**cmd**" "$REPORT"
assert_not_contains "T13 and is closed, not left running"           "still running" "$REPORT"

( cd "$ROOT" && "$RUN_LONG" --phase test --change .specclaw:demo -- "exit 3" ) >/dev/null 2>&1
LEDGER="$(cat "$ROOT/.specclaw/changes/demo/timeline.jsonl")"
assert_contains "T13 a failing command records status fail" '"status":"fail"' "$LEDGER"

# ─── T14: config and gitignore ───────────────────────────────────────────────
CFG="$(cat "$CONFIG_TEMPLATE")"
assert_contains "T14 the template carries a timing block" "timing:" "$CFG"
assert_contains "T14 with heartbeat_seconds"              "heartbeat_seconds:" "$CFG"
assert_contains "T14 and anomaly_factor"                  "anomaly_factor:" "$CFG"

FRESH="$WORK/fresh"; mkdir -p "$FRESH"
( cd "$FRESH" && "$INIT" . demo ) >/dev/null 2>&1
assert_contains "T14 init gitignores the raw ledger" \
  "timeline.jsonl" "$(cat "$FRESH/.gitignore" 2>/dev/null || true)"
assert_contains "T14 and seeds the timing block" \
  "timing:" "$(cat "$FRESH/.specclaw/config.yaml" 2>/dev/null || true)"

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
