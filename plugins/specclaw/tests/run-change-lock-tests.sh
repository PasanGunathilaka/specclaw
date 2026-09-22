#!/usr/bin/env bash
# run-change-lock-tests.sh — regression suite for bin/specclaw-change-lock, the
# per-change dispatch lock (change 038), and its wiring into specclaw-build,
# specclaw-pr, and specclaw-azdo-pr.
#
# What this pins:
#
#   AC1  a second acquire on a live lock refuses, naming the held phase/start
#   AC2  a stale lock refuses without --force, succeeds with it
#   AC3  --force on a NON-stale lock still refuses (never clears a live lock)
#   AC4  release on an absent lock exits 0 (idempotent)
#   AC5  specclaw-build setup refuses when locked; finalize releases even
#        after a recorded build failure
#   AC6  specclaw-pr / specclaw-azdo-pr refuse when locked, and release via
#        their EXIT trap on a `die` path
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-change-lock-tests.sh
# Exits non-zero if any case fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"

LOCK="$BIN_DIR/specclaw-change-lock"
BUILD_BIN="$BIN_DIR/specclaw-build"
PR_BIN="$BIN_DIR/specclaw-pr"
AZDO_PR_BIN="$BIN_DIR/specclaw-azdo-pr"

for f in "$LOCK" "$BUILD_BIN" "$PR_BIN" "$AZDO_PR_BIN"; do
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

# ─────────────────────────────────────────────────────────────────────────────
# Case 1 — acquire / status / release round-trip.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 1: acquire / status / release round-trip ---"
S1="$WORK/c1/.specclaw"
mkdir -p "$S1"

"$LOCK" "$S1" acquire c1 --phase build >/dev/null 2>&1
assert_eq "1a acquire on an unlocked change succeeds" "0" "$?"

st="$("$LOCK" "$S1" status c1 2>/dev/null)"
if [[ "$st" == locked\ phase=build* ]]; then
  pass "1b status reports the held phase (= '$st')"
else
  fail "1b status should report the held phase (got '$st')"
fi

"$LOCK" "$S1" release c1 >/dev/null 2>&1
assert_eq "1c release exits 0" "0" "$?"
assert_eq "1d status after release" "unlocked" "$("$LOCK" "$S1" status c1 2>/dev/null)"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 2 (AC1) — a second acquire on a live lock refuses and names the phase
# and start time; any phase, not just the same one (the "any phase" default).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 2 (AC1): second acquire on a live lock refuses ---"
S2="$WORK/c2/.specclaw"
mkdir -p "$S2"
"$LOCK" "$S2" acquire c2 --phase build >/dev/null 2>&1

err2="$("$LOCK" "$S2" acquire c2 --phase verify 2>&1 >/dev/null)"
rc2=$?
if [[ "$rc2" -ne 0 ]]; then
  pass "2a second acquire (different phase) refuses (rc=$rc2)"
else
  fail "2a second acquire (different phase) should refuse (rc=$rc2)"
fi
if [[ "$err2" == *"phase=build"* && "$err2" == *"started="* ]]; then
  pass "2b refusal names the held phase and start time (= '$err2')"
else
  fail "2b refusal should name the held phase and start time (got '$err2')"
fi
"$LOCK" "$S2" release c2 >/dev/null 2>&1
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 3 (AC2, AC3) — staleness and --force.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 3 (AC2/AC3): stale lock refuses without --force, --force never clears a live lock ---"
S3="$WORK/c3/.specclaw"
mkdir -p "$S3/changes/c3/.lock"
cat > "$S3/changes/c3/.lock/meta.json" <<'EOF'
{"pid":1,"phase":"build","started_at":"2020-01-01T00:00:00Z","host":"old"}
EOF
mkdir -p "$S3"
printf 'git:\n  lock_stale_minutes: 120\n' > "$S3/config.yaml"

"$LOCK" "$S3" acquire c3 --phase verify >/dev/null 2>&1
assert_eq "3a stale lock without --force refuses" "1" "$?"

"$LOCK" "$S3" acquire c3 --phase verify --force >/dev/null 2>&1
assert_eq "3b stale lock WITH --force succeeds" "0" "$?"

st3="$("$LOCK" "$S3" status c3 2>/dev/null)"
if [[ "$st3" == locked\ phase=verify* ]]; then
  pass "3c the freshly-acquired lock now shows phase=verify (= '$st3')"
else
  fail "3c expected phase=verify after force-acquire (got '$st3')"
fi

# Now the lock is LIVE (just acquired) — --force must NOT clear it.
"$LOCK" "$S3" acquire c3 --phase pr --force >/dev/null 2>&1
assert_eq "3d --force on a non-stale (live) lock still refuses" "1" "$?"
st3b="$("$LOCK" "$S3" status c3 2>/dev/null)"
if [[ "$st3b" == locked\ phase=verify* ]]; then
  pass "3e the live lock survived the bogus --force (= '$st3b')"
else
  fail "3e the live lock should have survived the bogus --force (got '$st3b')"
fi
"$LOCK" "$S3" release c3 >/dev/null 2>&1
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 4 (AC4) — release is idempotent.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 4 (AC4): release on an absent lock is a no-op ---"
S4="$WORK/c4/.specclaw"
mkdir -p "$S4"
"$LOCK" "$S4" release never-locked >/dev/null 2>&1
assert_eq "4a release on a change with no lock exits 0" "0" "$?"
"$LOCK" "$S4" release never-locked >/dev/null 2>&1
assert_eq "4b releasing twice is still exit 0" "0" "$?"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 5 (AC5) — specclaw-build setup refuses when locked; finalize releases
# even after a recorded build failure.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 5 (AC5): specclaw-build setup/finalize honour the lock ---"
GPROJ5="$WORK/build-proj"
mkdir -p "$GPROJ5"
(
  cd "$GPROJ5"
  git init -q .
  git config user.email t@t && git config user.name t
  git commit -q --allow-empty -m init
  mkdir -p .specclaw/changes/c5
  printf 'git:\n  strategy: "branch-per-change"\n  branch_prefix: "specclaw/"\n' > .specclaw/config.yaml
  printf '# t\n- [x] `T1` — x\n' > .specclaw/changes/c5/tasks.md
)

# Pre-lock the change from an "other dispatch".
(cd "$GPROJ5" && bash "$LOCK" .specclaw acquire c5 --phase verify >/dev/null 2>&1)
setup_err="$(cd "$GPROJ5" && bash "$BUILD_BIN" setup .specclaw c5 2>&1 >/dev/null)"
setup_rc=$?
if [[ "$setup_rc" -ne 0 ]]; then
  pass "5a setup refuses when the change is already locked (rc=$setup_rc)"
else
  fail "5a setup should refuse when the change is already locked (rc=$setup_rc)"
fi
if [[ "$setup_err" == *"change-lock"* ]]; then
  pass "5b setup's refusal names the lock error"
else
  fail "5b setup's refusal should name the lock error (got '$setup_err')"
fi
(cd "$GPROJ5" && bash "$LOCK" .specclaw release c5 >/dev/null 2>&1)

# Now a real setup should succeed and hold the lock.
(cd "$GPROJ5" && bash "$BUILD_BIN" setup .specclaw c5 >/dev/null 2>&1)
st5="$(cd "$GPROJ5" && bash "$LOCK" .specclaw status c5 2>/dev/null)"
if [[ "$st5" == locked\ phase=build* ]]; then
  pass "5c setup acquired the lock (= '$st5')"
else
  fail "5c setup should have acquired the lock (got '$st5')"
fi

# finalize (no test/lint/build configured, so it can only report build_status
# from the task counts; a failed task count still must release the lock).
printf '# t\n- [!] `T1` — x\n' > "$GPROJ5/.specclaw/changes/c5/tasks.md"
(cd "$GPROJ5" && bash "$BUILD_BIN" finalize .specclaw c5 >/dev/null 2>&1)
st5b="$(cd "$GPROJ5" && bash "$LOCK" .specclaw status c5 2>/dev/null)"
assert_eq "5d finalize releases the lock even after a failed task count" "unlocked" "$st5b"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 6 (AC6) — specclaw-pr / specclaw-azdo-pr refuse when locked, and
# release via their EXIT trap on a `die` path.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 6 (AC6): specclaw-pr / specclaw-azdo-pr honour the lock and release via trap ---"
for pair in "specclaw-pr:$PR_BIN" "specclaw-azdo-pr:$AZDO_PR_BIN"; do
  name="${pair%%:*}"; bin="${pair#*:}"
  GPROJ6="$WORK/${name}-proj"
  mkdir -p "$GPROJ6"
  (
    cd "$GPROJ6"
    git init -q .
    git config user.email t@t && git config user.name t
    git commit -q --allow-empty -m init
    mkdir -p .specclaw/changes/c6
    printf 'git:\n  strategy: "branch-per-change"\n' > .specclaw/config.yaml
  )

  # Pre-lock it — the script must refuse before ever reaching validate_phase.
  (cd "$GPROJ6" && bash "$LOCK" .specclaw acquire c6 --phase build >/dev/null 2>&1)
  out="$(cd "$GPROJ6" && bash "$bin" .specclaw c6 2>&1)"
  rc=$?
  if [[ "$rc" -ne 0 ]]; then
    pass "6a $name refuses when the change is locked (rc=$rc)"
  else
    fail "6a $name should refuse when the change is locked (rc=$rc)"
  fi
  if [[ "$out" == *"change-lock"* ]]; then
    pass "6b $name's refusal names the lock error"
  else
    fail "6b $name's refusal should name the lock error (got '$out')"
  fi
  # The pre-existing (other dispatch's) lock must survive untouched — this
  # script never acquired it, so it must not release it either.
  st6="$(cd "$GPROJ6" && bash "$LOCK" .specclaw status c6 2>/dev/null)"
  if [[ "$st6" == locked\ phase=build* ]]; then
    pass "6c $name did not release a lock it never held"
  else
    fail "6c $name should not have touched the pre-existing lock (got '$st6')"
  fi
  (cd "$GPROJ6" && bash "$LOCK" .specclaw release c6 >/dev/null 2>&1)

  # Now let the script acquire its own lock, then hit a later `die` (missing
  # verify-report.md is an early, reliable failure point in both scripts) —
  # the EXIT trap must still release it.
  out2="$(cd "$GPROJ6" && bash "$bin" .specclaw c6 2>&1)"
  rc2=$?
  if [[ "$rc2" -ne 0 ]]; then
    pass "6d $name exits non-zero on a real validation failure (rc=$rc2, out='$out2')"
  else
    fail "6d $name should have failed validation (no spec/tasks/verify-report present)"
  fi
  st6b="$(cd "$GPROJ6" && bash "$LOCK" .specclaw status c6 2>/dev/null)"
  assert_eq "6e $name's EXIT trap released the lock after a die" "unlocked" "$st6b"
done
echo

# ─────────────────────────────────────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo "=================================================="
echo "$PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
