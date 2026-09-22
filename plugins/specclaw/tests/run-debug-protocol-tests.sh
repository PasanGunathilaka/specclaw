#!/usr/bin/env bash
# run-debug-protocol-tests.sh — the /specclaw:debug record and the three-strikes halt.
#
# What this pins, and why each case exists:
#
#   The investigation record is the only structured account of WHY something
#   failed that specclaw keeps. Two things read it mechanically — `loop decide`
#   counts withdrawn verdicts to raise an architecture-question halt, and
#   `detect-patterns` clusters on the upheld hypothesis rather than the error
#   string — so the record's grammar is a contract, not a rendering preference.
#
#   The refusals matter most. A payload whose verdict prefixes do not parse
#   would be filed as a record the counter silently reads as ZERO withdrawn
#   hypotheses: the loop would keep spending on a design that is what is
#   actually wrong, and the journal would look complete while doing it. Refusing
#   at write time is the only point where that is visible.
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-debug-protocol-tests.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LOG_ERROR="$BIN_DIR/specclaw-log-error"
LOOP="$BIN_DIR/specclaw-loop"
BUILD_CONTEXT="$BIN_DIR/specclaw-build-context"
DETECT="$BIN_DIR/specclaw-detect-patterns"
SKILL="$PLUGIN_DIR/skills/debug/SKILL.md"

for f in "$LOG_ERROR" "$LOOP" "$BUILD_CONTEXT" "$DETECT" "$SKILL"; do
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

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label (= '$actual')"
  else
    fail "$label — expected '$expected', got '$actual'"
  fi
}

# A .specclaw with one change dir, returned on stdout.
make_project() {
  local root="$WORK/$1"
  mkdir -p "$root/.specclaw/changes/demo"
  # `project.name` is not optional in the fixture: specclaw-build-context greps
  # for `name:` under `set -e`, so a config without it aborts the script.
  printf 'project:\n  name: "demo"\n\nloop:\n  max_iterations: 5\n  no_progress_limit: 9\n' \
    > "$root/.specclaw/config.yaml"
  printf '%s' "$root"
}

# file_investigation <root> <json>  → exit code, stderr merged into stdout
file_investigation() {
  local root="$1" payload="$2"
  ( cd "$root" && printf '%s' "$payload" | "$LOG_ERROR" .specclaw demo --investigation - 2>&1 )
}

# ─── T1: the rendered block carries every field, in the documented grammar ────
ROOT="$(make_project t1)"
file_investigation "$ROOT" '{
  "symptom": "verify exits 1 with no output on a clean tree",
  "task": "T5",
  "failure_sig": "abc123",
  "reproduce": "specclaw-verify .specclaw demo",
  "reproduce_exit": 1,
  "evidence": "verify-report.md is written but empty",
  "hypotheses": [
    "withdrawn: the report template is missing — it is present and readable",
    "upheld: collect exits early on an empty test_command"
  ],
  "fix": "treat an unset test_command as skipped",
  "commit": "a1b2c3d",
  "proof": "same command → exit 0"
}' >/dev/null
ERRORS="$(cat "$ROOT/.specclaw/changes/demo/errors.md")"
assert_contains "T1 heading carries task, ordinal and symptom" \
  "## [T5] Investigation 1 — verify exits 1 with no output on a clean tree" "$ERRORS"
assert_contains "T1 status is upheld when a hypothesis was upheld" "**Status:** upheld" "$ERRORS"
assert_contains "T1 failure signature is recorded"  "**Failure-Sig:** abc123" "$ERRORS"
assert_contains "T1 reproduce carries the exit code" \
  '**Reproduce:** `specclaw-verify .specclaw demo` → exit 1' "$ERRORS"
assert_contains "T1 evidence line"   "**Evidence:** verify-report.md is written but empty" "$ERRORS"
assert_contains "T1 withdrawn hypothesis is numbered and labelled" \
  "**Hypothesis 1 (withdrawn):** the report template is missing" "$ERRORS"
assert_contains "T1 upheld hypothesis is numbered and labelled" \
  "**Hypothesis 2 (upheld):** collect exits early on an empty test_command" "$ERRORS"
assert_contains "T1 fix carries its commit" \
  "**Fix:** treat an unset test_command as skipped (commit a1b2c3d)" "$ERRORS"
assert_contains "T1 proof line" "**Proof:** same command → exit 0" "$ERRORS"

# ─── T2: a second investigation on the same task numbers itself ──────────────
file_investigation "$ROOT" '{"symptom":"again","task":"T5","hypotheses":["withdrawn: x"]}' >/dev/null
ERRORS="$(cat "$ROOT/.specclaw/changes/demo/errors.md")"
assert_contains "T2 second record on the same task is Investigation 2" \
  "## [T5] Investigation 2 — again" "$ERRORS"
assert_contains "T2 all-withdrawn record is open, not upheld" "**Status:** open" "$ERRORS"

# ─── T3: a payload with no symptom is refused, and writes nothing ────────────
ROOT="$(make_project t3)"
OUT="$(file_investigation "$ROOT" '{"task":"T1","hypotheses":["upheld: x"]}')"
RC=$?
assert_eq "T3 missing symptom exits 2" "2" "$RC"
assert_contains "T3 refusal names the missing field" 'no "symptom"' "$OUT"
if [[ -f "$ROOT/.specclaw/changes/demo/errors.md" ]]; then
  fail "T3 refused payload must not create errors.md"
else
  pass "T3 refused payload wrote nothing"
fi

# ─── T4: an unparseable verdict prefix is refused ────────────────────────────
# The case the whole refusal exists for: this record would otherwise file with
# zero countable verdicts, and the architecture-question halt would never fire.
ROOT="$(make_project t4)"
OUT="$(file_investigation "$ROOT" '{"symptom":"x","hypotheses":["maybe it is the cache"]}')"
RC=$?
assert_eq "T4 verdict-less hypothesis exits 2" "2" "$RC"
assert_contains "T4 refusal quotes the offending hypothesis" "maybe it is the cache" "$OUT"
if [[ -f "$ROOT/.specclaw/changes/demo/errors.md" ]]; then
  fail "T4 refused payload must not create errors.md"
else
  pass "T4 refused payload wrote nothing"
fi

# ─── T5: a fenced payload with an escaped quote still parses ─────────────────
# Models wrap JSON in code fences and quote things inside prose. Both are the
# normal case here, not an edge one.
ROOT="$(make_project t5)"
file_investigation "$ROOT" '```json
{"symptom":"fenced","hypotheses":["upheld: the \"exit 2\" path is unreachable"]}
```' >/dev/null
ERRORS="$(cat "$ROOT/.specclaw/changes/demo/errors.md")"
assert_contains "T5 fenced payload parses" "## [GENERAL] Investigation 1 — fenced" "$ERRORS"
assert_contains "T5 escaped quote survives the reader" \
  'the "exit 2" path is unreachable' "$ERRORS"

# ─── T6: log mode is untouched ───────────────────────────────────────────────
ROOT="$(make_project t6)"
# `< /dev/null` is required, not tidiness: log mode reads stdin whenever stdin is
# not a TTY, so without it this blocks forever under a non-interactive runner.
( cd "$ROOT" && "$LOG_ERROR" .specclaw demo T1 1 coder "npm test failed" < /dev/null ) >/dev/null 2>&1
ERRORS="$(cat "$ROOT/.specclaw/changes/demo/errors.md")"
assert_contains "T6 attempt entries still render"   "## [T1] Attempt 1 — Wave 1" "$ERRORS"
assert_contains "T6 attempt entries keep Summary"   "npm test failed" "$ERRORS"
assert_not_contains "T6 attempt entries gain no investigation fields" "**Failure-Sig:**" "$ERRORS"

# ─── T7: two all-withdrawn records on one sig raise architecture-question ────
ROOT="$(make_project t7)"
file_investigation "$ROOT" '{"symptom":"a","failure_sig":"sig1","hypotheses":["withdrawn: p"]}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 sig1 )"
assert_not_contains "T7 one ruled-out record does not halt" "architecture-question" "$DECIDE"
file_investigation "$ROOT" '{"symptom":"b","failure_sig":"sig1","hypotheses":["withdrawn: q","withdrawn: r"]}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 sig1 )"
assert_contains "T7 two ruled-out records halt"        '"action": "halt"' "$DECIDE"
assert_contains "T7 halt carries the slug"             '"halt_reason": "architecture-question"' "$DECIDE"
assert_contains "T7 reason names what was ruled out"   "hypotheses ruled out" "$DECIDE"

# ─── T8: the counter is scoped to the signature ──────────────────────────────
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 othersig )"
assert_not_contains "T8 records on another sig do not count" "architecture-question" "$DECIDE"

# ─── T9: an upheld hypothesis disqualifies a record from the count ───────────
ROOT="$(make_project t9)"
file_investigation "$ROOT" '{"symptom":"a","failure_sig":"s","hypotheses":["upheld: p"]}' >/dev/null
file_investigation "$ROOT" '{"symptom":"b","failure_sig":"s","hypotheses":["upheld: q"]}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 s )"
assert_not_contains "T9 upheld records never raise an architecture question" \
  "architecture-question" "$DECIDE"

# ─── T10: a record with no hypotheses rules nothing out ──────────────────────
ROOT="$(make_project t10)"
file_investigation "$ROOT" '{"symptom":"a","failure_sig":"s"}' >/dev/null
file_investigation "$ROOT" '{"symptom":"b","failure_sig":"s"}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 s )"
assert_not_contains "T10 hypothesis-free records do not count" "architecture-question" "$DECIDE"

# ─── T11: the limit is configurable ──────────────────────────────────────────
ROOT="$(make_project t11)"
printf 'project:\n  name: "demo"\n\nloop:\n  max_iterations: 5\n  no_progress_limit: 9\n  architecture_question_limit: 3\n' \
  > "$ROOT/.specclaw/config.yaml"
file_investigation "$ROOT" '{"symptom":"a","failure_sig":"s","hypotheses":["withdrawn: p"]}' >/dev/null
file_investigation "$ROOT" '{"symptom":"b","failure_sig":"s","hypotheses":["withdrawn: q"]}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 s )"
assert_not_contains "T11 limit 3 does not fire at 2" "architecture-question" "$DECIDE"
file_investigation "$ROOT" '{"symptom":"c","failure_sig":"s","hypotheses":["withdrawn: r"]}' >/dev/null
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 s )"
assert_contains "T11 limit 3 fires at 3" "architecture-question" "$DECIDE"

# ─── T12: existing halts keep their reason text and gain a slug ──────────────
ROOT="$(make_project t12)"
printf 'project:\n  name: "demo"\n\nloop:\n  max_iterations: 0\n' > "$ROOT/.specclaw/config.yaml"
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 sig )"
assert_contains "T12 cap halt keeps its wording"  "iteration cap 0 reached" "$DECIDE"
assert_contains "T12 cap halt carries its slug"   '"halt_reason": "iteration-cap"' "$DECIDE"

ROOT="$(make_project t12b)"
printf 'project:\n  name: "demo"\n\nloop:\n  max_iterations: 5\n  no_progress_limit: 2\n' > "$ROOT/.specclaw/config.yaml"
printf '{"turn": 1, "passing_count": 3, "sig_history": ["s"]}\n' \
  > "$ROOT/.specclaw/changes/demo/loop-state.json"
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 s )"
assert_contains "T12 regression halt keeps its wording" "regression: passing gates dropped" "$DECIDE"
assert_contains "T12 regression halt carries its slug"  '"halt_reason": "regression"' "$DECIDE"

# ─── T13: a continue decision carries no halt_reason ─────────────────────────
ROOT="$(make_project t13)"
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 "" )"
assert_contains "T13 continue still emits action"      '"action": "continue"' "$DECIDE"
assert_not_contains "T13 continue emits no halt_reason" "halt_reason" "$DECIDE"

# ─── T14: a missing errors.md cannot break decide ────────────────────────────
ROOT="$(make_project t14)"
DECIDE="$( cd "$ROOT" && "$LOOP" decide .specclaw demo 1 sig 2>/dev/null )"
RC=$?
assert_eq "T14 decide survives a change with no errors.md" "0" "$RC"
assert_contains "T14 and still decides" '"action"' "$DECIDE"

# ─── T15: the fix agent's payload leads with the Root-Cause Protocol ─────────
ROOT="$(make_project t15)"
# The shipped template, not the minimal fixture: specclaw-build-context reads
# several config keys with a bare `grep` under `set -e`, so any key it looks for
# and does not find aborts it outright.
cp "$PLUGIN_DIR/templates/config.yaml" "$ROOT/.specclaw/config.yaml"
mkdir -p "$ROOT/.specclaw/changes/demo"
printf '# Tasks\n\n- [ ] `T1` — do the thing\n  - Files: a.txt\n' \
  > "$ROOT/.specclaw/changes/demo/tasks.md"
printf '# Spec\n' > "$ROOT/.specclaw/changes/demo/spec.md"
printf 'gate: test failed\n' > "$WORK/fail.json"
PAYLOAD="$( cd "$ROOT" && "$BUILD_CONTEXT" .specclaw demo T1 --failure-record "$WORK/fail.json" 2>/dev/null )"
assert_contains "T15 remediation payload states the protocol" \
  "Root-Cause Protocol" "$PAYLOAD"
assert_contains "T15 payload demands evidence with the hypothesis" \
  "because <evidence>" "$PAYLOAD"
assert_contains "T15 payload retargets the diff at the cause" \
  "removes the stated root cause" "$PAYLOAD"
assert_contains "T15 payload demands the investigation record" \
  "specclaw-log-error --investigation" "$PAYLOAD"
assert_not_contains "T15 payload no longer aims at a green gate" \
  "smallest diff that turns the failing gate(s) green" "$PAYLOAD"

# ─── T16: patterns cluster on the cause, not the error string ────────────────
# Two investigations that phrase the symptom differently but share a root cause
# must land in ONE pattern. Clustering on the symptom is what this replaces.
ROOT="$(make_project t16)"
file_investigation "$ROOT" '{
  "symptom": "verify exits 1 with no output",
  "hypotheses": ["upheld: collect treats an unset test_command as a failed gate"],
  "fix": "treat an unset command as skipped"
}' >/dev/null
file_investigation "$ROOT" '{
  "symptom": "the dashboard shows FAIL on a repo with no tests",
  "hypotheses": ["upheld: collect treats an unset test_command as a failed gate"],
  "fix": "treat an unset command as skipped"
}' >/dev/null
( cd "$ROOT" && "$DETECT" .specclaw scan demo ) >/dev/null 2>&1
PATTERNS="$(cat "$ROOT/.specclaw/patterns.md" 2>/dev/null || true)"
if [[ -z "$PATTERNS" ]]; then
  fail "T16 detect-patterns wrote no patterns.md"
else
  assert_contains "T16 the cause is what got clustered" "test_command" "$PATTERNS"
  RECUR="$(printf '%s' "$PATTERNS" | grep -c 'Recurrence' || true)"
  assert_eq "T16 two phrasings of one cause make a single pattern" "1" "$RECUR"
fi

# ─── T16b: the pattern-id reader is portable ─────────────────────────────────
# `grep -oP` is GNU-only. On BSD grep it returned nothing, so every entry looked
# like a new pattern, nothing ever clustered, and the scan still printed
# "Created PAT-00n" and exited 0 — a tool reporting success while doing the
# opposite of its job.
if grep -vE '^[[:space:]]*#' "$DETECT" | grep -q 'grep -oP'; then
  fail "T16b detect-patterns uses grep -oP (unavailable on BSD grep)"
else
  pass "T16b detect-patterns reads pattern ids portably"
fi

# ─── T17: the skill states the law it exists to enforce ──────────────────────
SKILL_TEXT="$(cat "$SKILL")"
assert_contains "T17 skill states the Iron Law"        "No fix without a stated root cause" "$SKILL_TEXT"
assert_contains "T17 skill has a three-strikes rule"   "Three strikes" "$SKILL_TEXT"
assert_contains "T17 skill names the halt it maps to"  "architecture-question" "$SKILL_TEXT"
assert_contains "T17 skill documents the record"       "--investigation" "$SKILL_TEXT"
DESC="$(sed -n '2p' "$SKILL")"
if printf '%s' "$DESC" | grep -q '^description: Use when'; then
  pass "T17 skill description is trigger-first"
else
  fail "T17 skill description must open with a trigger condition — got: $DESC"
fi

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
