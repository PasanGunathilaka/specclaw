#!/usr/bin/env bash
# run-staged-files-tests.sh — does the branch carry exactly what this change should? (change 029)
#
# The two failures this gate exists for both shipped, repeatedly, and both were
# SILENT:
#
#   A PR opened without its proposal — reported three separate times on one
#   change, because validate-change checks that artifacts exist ON DISK and
#   nothing asked whether they were COMMITTED.
#
#   `git add -A` in the loop's escalation sweeping in .session-id.rotated-*
#   files, a watchdog-kills.jsonl and an untracked GOALS.md.
#
# The third property under test is the one that decides whether anyone keeps the
# gate switched on: `undeclared` must NOT block. tasks.md file lists are a scope
# SIGNAL, not a contract, and a gate that blocks a correct PR is worse than the
# silent failure it replaces.
#
# Plain bash + coreutils + git only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"

CHECK="$BIN_DIR/specclaw-check-staged"
LOOP="$BIN_DIR/specclaw-loop"
BUILD="$BIN_DIR/specclaw-build"
AUDITOR="$PLUGIN_DIR/agents/staged-files-auditor.md"
CONFIG_TEMPLATE="$PLUGIN_DIR/templates/config.yaml"
BUILD_SKILL="$PLUGIN_DIR/skills/build/SKILL.md"
LOOP_SKILL="$PLUGIN_DIR/skills/loop/SKILL.md"

for f in "$CHECK" "$LOOP" "$BUILD" "$AUDITOR" "$CONFIG_TEMPLATE" "$BUILD_SKILL" "$LOOP_SKILL"; do
  if [[ ! -f "$f" ]]; then echo "FATAL: missing file: $f" >&2; exit 2; fi
done

if ! command -v git >/dev/null 2>&1; then
  echo "FATAL: git is required for this suite" >&2
  exit 2
fi

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

# mk_repo <slug> [size] [extra-config-lines]  → repo root on a feature branch
# with a complete artifact set, one declared file changed, and one undeclared.
mk_repo() {
  local slug="$1" size="${2:-architectural}" extra="${3:-}"
  local root="$WORK/$slug"
  mkdir -p "$root/src" "$root/.specclaw/changes/demo"
  (
    cd "$root" || exit 1
    git init -q -b main .
    git config user.email t@example.com
    git config user.name t
    # The pr: block is emitted ONCE. Appending an override after the defaults
    # would leave two `allowed_extra_paths:` keys in one block, and a
    # first-match reader takes the empty one — so the override would be
    # silently ignored and every escape-hatch case would "pass" for the wrong
    # reason.
    {
      printf 'project:\n  name: "demo"\n\ngit:\n  base_branch: "main"\n\npr:\n'
      if [ -n "$extra" ]; then
        printf '%s\n' "$extra"
      else
        printf '  allowed_extra_paths: []\n  junk_patterns: []\n'
      fi
    } > .specclaw/config.yaml
    printf 'base\n' > src/a.txt
    git add -A && git commit -qm base
    git checkout -qb feat

    local f
    for f in proposal spec design status verify-report findings; do
      printf '# %s\n' "$f" > ".specclaw/changes/demo/${f}.md"
    done
    printf '# Tasks\n\n- [x] `T1` — do it\n  - Files: src/a.txt\n' > .specclaw/changes/demo/tasks.md
    printf '{"change":"demo","phase":"verify","size":"%s"}\n' "$size" > .specclaw/changes/demo/state.json
    printf 'changed\n' > src/a.txt
    printf 'ripple\n' > src/barrel.ts
    git add -A && git commit -qm "specclaw(demo): T1 — do it"
  ) >/dev/null 2>&1
  printf '%s' "$root"
}

run_check() { ( cd "$1" && shift && "$CHECK" .specclaw demo "$@" 2>&1 ); }
rc_check()  { ( cd "$1" && shift && "$CHECK" .specclaw demo "$@" >/dev/null 2>&1; echo $? ); }

# ─── T1: the reported failure — a missing artifact ───────────────────────────
ROOT="$(mk_repo t1)"
( cd "$ROOT" && git rm -q .specclaw/changes/demo/spec.md && git commit -qm "oops" ) >/dev/null 2>&1
OUT="$(run_check "$ROOT")"
assert_eq "T1 a missing mandatory artifact blocks" "1" "$(rc_check "$ROOT")"
assert_contains "T1 named in required-missing" "required-missing" "$OUT"
assert_contains "T1 and the file is named"     "spec.md" "$OUT"
assert_contains "T1 and the verdict is BLOCK"  "VERDICT: BLOCK" "$OUT"

# ─── T2: declared paths and the change dir are in scope ──────────────────────
ROOT="$(mk_repo t2)"
OUT="$(run_check "$ROOT")"
JSON="$(run_check "$ROOT" --json)"
DECLARED_ONLY="$(printf '%s' "$JSON" | sed -E 's/.*"declared":\[([^]]*)\].*/\1/')"
UNDECLARED_ONLY="$(printf '%s' "$JSON" | sed -E 's/.*"undeclared":\[([^]]*)\].*/\1/')"
assert_contains "T2 a task's declared file is declared" "src/a.txt" "$DECLARED_ONLY"
assert_contains "T2 the change dir is declared too"     ".specclaw/changes/demo/proposal.md" "$DECLARED_ONLY"
assert_not_contains "T2 and neither is undeclared"      "src/a.txt" "$UNDECLARED_ONLY"

# ─── T3: undeclared WARNs, and does NOT block ────────────────────────────────
# The decision the gate's usability rests on.
assert_eq "T3 an undeclared ripple does not block" "0" "$(rc_check "$ROOT")"
assert_contains "T3 but it is reported"            "undeclared" "$OUT"
assert_contains "T3 naming the file"               "src/barrel.ts" "$OUT"
assert_contains "T3 and the verdict is WARN"       "VERDICT: WARN" "$OUT"

# ─── T4: --strict is the opt-in for a caller wanting no judgement calls ──────
assert_eq "T4 --strict makes the same case block" "1" "$(rc_check "$ROOT" --strict)"

# ─── T5: junk blocks ─────────────────────────────────────────────────────────
ROOT="$(mk_repo t5)"
printf 'junk\n' > "$ROOT/.session-id.rotated-3"
printf 'kills\n' > "$ROOT/watchdog-kills.jsonl"
printf 'log\n' > "$ROOT/build.log"
OUT="$(run_check "$ROOT")"
assert_eq "T5 junk blocks" "1" "$(rc_check "$ROOT")"
assert_contains "T5 .session-id.rotated-3 is suspicious" ".session-id.rotated-3" "$OUT"
assert_contains "T5 so is a kills jsonl"                 "watchdog-kills.jsonl" "$OUT"
assert_contains "T5 so is a log"                         "build.log" "$OUT"
assert_contains "T5 and the report names the real fix"   ".gitignore" "$OUT"

# ─── T6: allowed_extra_paths wins over everything ────────────────────────────
ROOT="$(mk_repo t6 architectural '  allowed_extra_paths: [CHANGELOG.md, "*.log"]
  junk_patterns: []')"
printf 'log\n' > "$ROOT/build.log"
printf 'changes\n' > "$ROOT/CHANGELOG.md"
OUT="$(run_check "$ROOT")"
assert_eq "T6 an allowlisted path does not block" "0" "$(rc_check "$ROOT")"
JSON="$(run_check "$ROOT" --json)"
assert_not_contains "T6 nor is it suspicious" "build.log" \
  "$(printf '%s' "$JSON" | sed -E 's/.*"suspicious":\[([^]]*)\].*/\1/')"
assert_not_contains "T6 nor undeclared" "CHANGELOG.md" \
  "$(printf '%s' "$JSON" | sed -E 's/.*"undeclared":\[([^]]*)\].*/\1/')"

# ─── T7: project junk patterns extend the defaults ───────────────────────────
ROOT="$(mk_repo t7 architectural '  allowed_extra_paths: []
  junk_patterns: ["*.scratch"]')"
printf 'x\n' > "$ROOT/notes.scratch"
OUT="$(run_check "$ROOT")"
assert_eq "T7 a project junk pattern blocks"     "1" "$(rc_check "$ROOT")"
assert_contains "T7 and is reported as suspicious" "notes.scratch" "$OUT"
printf 'j\n' > "$ROOT/other.log"
assert_contains "T7 the shipped defaults still apply" "other.log" "$(run_check "$ROOT")"

# ─── T8: the artifact set is size-aware (change 036) ─────────────────────────
ROOT="$(mk_repo t8 bounded)"
( cd "$ROOT" && git rm -q .specclaw/changes/demo/design.md && git commit -qm "bounded needs no design" ) >/dev/null 2>&1
assert_eq "T8 a bounded change does not need design.md" "0" "$(rc_check "$ROOT")"

ROOT="$(mk_repo t8b architectural)"
( cd "$ROOT" && git rm -q .specclaw/changes/demo/design.md && git commit -qm "drop design" ) >/dev/null 2>&1
assert_eq "T8 an architectural one does" "1" "$(rc_check "$ROOT")"
assert_contains "T8 and says which file" "design.md" "$(run_check "$ROOT")"

ROOT="$(mk_repo t8c spike)"
( cd "$ROOT" && git rm -q .specclaw/changes/demo/spec.md .specclaw/changes/demo/design.md \
    .specclaw/changes/demo/verify-report.md && git commit -qm "spike" ) >/dev/null 2>&1
assert_eq "T8 a spike needs findings.md and not a verify report" "0" "$(rc_check "$ROOT")"

# ─── T9: --json and exit-code separation ─────────────────────────────────────
ROOT="$(mk_repo t9)"
JSON="$(run_check "$ROOT" --json)"
for key in required_missing declared undeclared suspicious blocked size; do
  assert_contains "T9 json carries $key" "\"$key\"" "$JSON"
done
if command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$JSON" | python3 -c 'import json,sys; json.load(sys.stdin)' >/dev/null 2>&1; then
    pass "T9 json parses"
  else
    fail "T9 json does not parse: $JSON"
  fi
fi

RC="$( ( cd "$ROOT" && "$CHECK" .specclaw no-such-change >/dev/null 2>&1; echo $? ) )"
assert_eq "T9 a usage error exits 2, not 1" "2" "$RC"
RC="$( ( cd "$ROOT" && "$CHECK" >/dev/null 2>&1; echo $? ) )"
assert_eq "T9 missing arguments also exit 2" "2" "$RC"

# ─── T10: the loop's escalation no longer sweeps the filesystem ──────────────
ROOT="$(mk_repo t10)"
printf 'work in progress\n' > "$ROOT/src/a.txt"       # tracked modification — must be kept
printf 'junk\n' > "$ROOT/.session-id.rotated-9"        # untracked junk — must NOT be
printf 'scratch\n' > "$ROOT/GOALS.md"                  # untracked, undeclared — must NOT be
OUT="$( cd "$ROOT" && "$LOOP" escalate .specclaw demo "no progress" 2>&1 || true )"

COMMITTED="$( cd "$ROOT" && git show --name-only --format='' HEAD 2>/dev/null || true )"
assert_contains "T10 the tracked work in progress is preserved" "src/a.txt" "$COMMITTED"
assert_not_contains "T10 the junk file is not committed"        ".session-id.rotated-9" "$COMMITTED"
assert_not_contains "T10 nor the undeclared scratch file"       "GOALS.md" "$COMMITTED"

STILL="$( cd "$ROOT" && git status --porcelain 2>/dev/null || true )"
assert_contains "T10 the junk is still in the working tree" ".session-id.rotated-9" "$STILL"

LOGTEXT="$OUT$(cat "$ROOT/.specclaw/changes/demo/loop-log.md" 2>/dev/null || true)"
assert_contains "T10 and the escalation names what it left behind" \
  ".session-id.rotated-9" "$LOGTEXT"

if grep -vE '^[[:space:]]*#' "$LOOP" | grep -q 'git add -A'; then
  fail "T10 specclaw-loop still contains a live 'git add -A'"
else
  pass "T10 specclaw-loop has no live 'git add -A'"
fi
if grep -vE '^[[:space:]]*#' "$LOOP_SKILL" | grep -q 'git add -A'; then
  fail "T10 the loop skill still documents 'git add -A'"
else
  pass "T10 the loop skill documents a scoped add"
fi

# ─── T11: build does not open a PR ───────────────────────────────────────────
# The gate is worthless if a PR can be hand-rolled elsewhere. specclaw-build
# never created one; this pins that it stays that way.
if grep -qE 'gh pr create|az repos pr create' "$BUILD"; then
  fail "T11 specclaw-build creates a PR — every specclaw-pr guarantee is bypassed"
else
  pass "T11 specclaw-build creates no PR"
fi
# As a COMMAND, not as prose: the skill explains at length why a hand-rolled
# `gh pr create` bypasses every specclaw-pr guarantee, and a bare grep hits that
# explanation.
if grep -E '^[[:space:]]*(\$ )?gh pr create' "$BUILD_SKILL" >/dev/null; then
  fail "T11 the build skill tells the model to run gh pr create"
else
  pass "T11 the build skill issues no PR-creation command"
fi
assert_contains "T11 and it says so out loud" \
  "never creates or announces a pull request" "$(cat "$BUILD_SKILL")"

# ─── T12: config and the auditor's contract ──────────────────────────────────
CFG="$(cat "$CONFIG_TEMPLATE")"
assert_contains "T12 staged_files_audit exists" "staged_files_audit:" "$CFG"
BLOCK_SETTING="$(printf '%s' "$CFG" | grep -E '^[[:space:]]+staged_files_block:' | sed -E 's/.*staged_files_block:[[:space:]]*([a-z]+).*/\1/')"
assert_eq "T12 staged_files_block ships false" "false" "$BLOCK_SETTING"
assert_contains "T12 allowed_extra_paths exists" "allowed_extra_paths:" "$CFG"
assert_contains "T12 junk_patterns exists"       "junk_patterns:" "$CFG"
assert_contains "T12 and the spawn threshold"    "audit_undeclared_threshold:" "$CFG"

AU="$(cat "$AUDITOR")"
assert_contains "T12 the auditor is read-only"        "Read-only" "$AU"
assert_contains "T12 judges paths, not code"          "Judge the path, not the code" "$AU"
assert_contains "T12 and uses the shared verdicts"    "CHANGES_REQUESTED" "$AU"
assert_contains "T12 with a trigger-first description" "description: Use when" "$AU"

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
