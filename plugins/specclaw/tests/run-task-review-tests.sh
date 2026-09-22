#!/usr/bin/env bash
# run-task-review-tests.sh — evidence-before-done and the per-task review gate (change 035).
#
# The footer check is the half of change 035 that ships ON, and the reason it
# ships on is that it cannot be got wrong in an expensive direction: a task that
# cannot show what it ran, and that the run exited 0, should not be `complete`.
#
# The decoy case (T3) is the one that matters most. A coding agent's report
# routinely QUOTES the footer template it was handed, or pastes an earlier
# attempt, putting a literal `## Verification` / `Exit: 0` inside a code fence.
# A fence-blind check reads that as evidence that something ran — which is
# precisely the failure the check exists to catch, passed off as a success.
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-task-review-tests.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"

BUILD="$BIN_DIR/specclaw-build"
BUILD_CONTEXT="$BIN_DIR/specclaw-build-context"
PROMPTS="$PLUGIN_DIR/references/agent-prompts.md"
REVIEWER="$PLUGIN_DIR/agents/code-reviewer.md"
STATUS_TEMPLATE="$PLUGIN_DIR/templates/status.md"
CONFIG_TEMPLATE="$PLUGIN_DIR/templates/config.yaml"
BUILD_SKILL="$PLUGIN_DIR/skills/build/SKILL.md"
VERIFY_SKILL="$PLUGIN_DIR/skills/verify/SKILL.md"

for f in "$BUILD" "$BUILD_CONTEXT" "$PROMPTS" "$REVIEWER" "$STATUS_TEMPLATE" \
         "$CONFIG_TEMPLATE" "$BUILD_SKILL" "$VERIFY_SKILL"; do
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
  if [[ "$actual" == "$expected" ]]; then pass "$label (= '$actual')"
  else fail "$label — expected '$expected', got '$actual'"; fi
}
assert_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then pass "$label"
  else fail "$label — expected to find: $needle"; fi
}

# check <file> → "rc<newline>output"
check() {
  local out rc
  out="$("$BUILD" check-report "$1" --task T5 2>&1)"; rc=$?
  printf '%s\n%s' "$rc" "$out"
}
check_rc()  { check "$1" | head -1; }
check_out() { check "$1" | tail -n +2; }

R="$WORK/reports"; mkdir -p "$R"

# ─── T1: a complete footer passes ────────────────────────────────────────────
cat > "$R/good.md" <<'EOF'
# T5 report

Implemented the widget.

## Verification
Command: bash tests/run-widget-tests.sh
Exit: 0
Output (tail):
12 passed, 0 failed
EOF
assert_eq "T1 a complete footer exits 0" "0" "$(check_rc "$R/good.md")"
assert_contains "T1 and echoes the command it accepted" "bash tests/run-widget-tests.sh" "$(check_out "$R/good.md")"

# ─── T2: each of the three failures is distinguished ─────────────────────────
printf '# T5 report\n\nAll done!\n' > "$R/nofooter.md"
assert_eq "T2 no footer exits 1" "1" "$(check_rc "$R/nofooter.md")"
assert_contains "T2 and says the section is missing" "no '## Verification' section" "$(check_out "$R/nofooter.md")"
assert_contains "T2 and names the reason code" "no-verification-evidence" "$(check_out "$R/nofooter.md")"

printf '# r\n\n## Verification\nCommand:\nExit: 0\n' > "$R/nocmd.md"
assert_eq "T2 an empty Command: exits 1" "1" "$(check_rc "$R/nocmd.md")"
assert_contains "T2 and says so" "'Command:' is missing or empty" "$(check_out "$R/nocmd.md")"

printf '# r\n\n## Verification\nCommand: npm test\nExit: 1\n' > "$R/failed.md"
assert_eq "T2 a non-zero Exit: exits 1" "1" "$(check_rc "$R/failed.md")"
assert_contains "T2 and quotes the code" "exited 1, not 0" "$(check_out "$R/failed.md")"

printf '# r\n\n## Verification\nCommand: npm test\n' > "$R/noexit.md"
assert_eq "T2 a missing Exit: exits 1" "1" "$(check_rc "$R/noexit.md")"
assert_contains "T2 and says a command with no exit code is not evidence" \
  "'Exit:' is missing" "$(check_out "$R/noexit.md")"

assert_eq "T2 a missing report file exits 1 rather than crashing" "1" "$(check_rc "$R/does-not-exist.md")"
assert_contains "T2 and names the path" "report file not found" "$(check_out "$R/does-not-exist.md")"

# ─── T3: a fenced footer is NOT evidence ─────────────────────────────────────
# The whole point. An agent that pastes back the template it was given, or
# quotes an earlier attempt, must not be read as having run anything.
cat > "$R/decoy.md" <<'EOF'
# T5 report

I was asked to end with:

```
## Verification
Command: bash tests/run.sh
Exit: 0
```

…but I did not actually run it.
EOF
assert_eq "T3 a fenced footer does not satisfy the check" "1" "$(check_rc "$R/decoy.md")"
assert_contains "T3 and reports it as absent" "no '## Verification' section" "$(check_out "$R/decoy.md")"

# ─── T4: the LAST footer wins ────────────────────────────────────────────────
# A retry appends its own footer; the retry is what should be judged.
cat > "$R/retry.md" <<'EOF'
# T5 report — attempt 1

## Verification
Command: bash tests/run.sh
Exit: 1
Output (tail): 1 failed

# T5 report — attempt 2

## Verification
Command: bash tests/run.sh
Exit: 0
Output (tail): 12 passed
EOF
assert_eq "T4 the last footer is the one judged" "0" "$(check_rc "$R/retry.md")"

cat > "$R/regressed.md" <<'EOF'
## Verification
Command: bash tests/run.sh
Exit: 0

## Verification
Command: bash tests/run.sh
Exit: 2
EOF
assert_eq "T4 and a later failing footer is not masked by an earlier pass" \
  "1" "$(check_rc "$R/regressed.md")"

# ─── T5: a docs-only footer is a legitimate footer ───────────────────────────
# There is no exemption, because an exemption is a hole shaped exactly like the
# failure — and the footer that satisfies it costs nothing.
printf '# r\n\n## Verification\nCommand: ls docs/guide.md\nExit: 0\nOutput (tail): docs/guide.md\n' > "$R/docs.md"
assert_eq "T5 a docs-only task can satisfy the footer" "0" "$(check_rc "$R/docs.md")"

# ─── T6: review-package contents ─────────────────────────────────────────────
REPO="$WORK/repo"; mkdir -p "$REPO"
(
  cd "$REPO" || exit 1
  git init -q . && git config user.email t@example.com && git config user.name t
  mkdir -p .specclaw/changes/demo
  cat > .specclaw/changes/demo/tasks.md <<'EOT'
# Tasks

### Wave 1

- [x] `T1` — build the widget
  - Files: a.txt, b.txt
  - Notes: keep it small

- [ ] `T2` — nothing yet
  - Files: c.txt
EOT
  printf 'base\n' > a.txt
  git add -A && git commit -qm "initial"
  printf 'one\n' > a.txt && printf 'two\n' > b.txt
  git add -A && git commit -qm "specclaw(demo): T1 — build the widget"
) >/dev/null 2>&1

IDX_BEFORE="$( cd "$REPO" && git diff --cached --name-only )"
TRACKED_BEFORE="$( cd "$REPO" && git status --porcelain --untracked-files=no )"
OUT="$( cd "$REPO" && "$BUILD" review-package .specclaw demo T1 )"
PKG="$(cat "$REPO/$OUT" 2>/dev/null || true)"

assert_contains "T6 the package names the change and task" "# Review package — demo / T1" "$PKG"
assert_contains "T6 the task brief travels with it"        "build the widget" "$PKG"
assert_contains "T6 including its declared files"          "Files: a.txt, b.txt" "$PKG"
assert_contains "T6 and its notes"                         "Notes: keep it small" "$PKG"
assert_contains "T6 a diff stat section"                   "## Stat" "$PKG"
assert_contains "T6 the full diff"                         "+two" "$PKG"
if printf '%s' "$PKG" | grep -qE '^Base: [0-9a-f]{40}$'; then pass "T6 a real base SHA"
else fail "T6 base SHA not resolved — check the git log --grep invocation"; fi
if printf '%s' "$PKG" | grep -qE '^Head: [0-9a-f]{40}$'; then pass "T6 a real head SHA"
else fail "T6 head SHA not resolved"; fi

# ─── T7: read-only with respect to git ───────────────────────────────────────
# A review step that can disturb the tree can lose an in-flight task in a
# parallel wave. It writes its own package and nothing else.
assert_eq "T7 the git index is untouched" \
  "$IDX_BEFORE" "$( cd "$REPO" && git diff --cached --name-only )"
assert_eq "T7 no tracked file changed" \
  "$TRACKED_BEFORE" "$( cd "$REPO" && git status --porcelain --untracked-files=no )"

# ─── T8: a task with no commits is described, not failed ─────────────────────
OUT2="$( cd "$REPO" && "$BUILD" review-package .specclaw demo T2 )"; RC=$?
assert_eq "T8 a task with no commits still succeeds" "0" "$RC"
PKG2="$(cat "$REPO/$OUT2" 2>/dev/null || true)"
assert_contains "T8 and says why there is no diff" "No commits found for T2" "$PKG2"

# ─── T9: the config key ships off ────────────────────────────────────────────
CFG="$(cat "$CONFIG_TEMPLATE")"
assert_contains "T9 task_review exists in the template" "task_review:" "$CFG"
SETTING="$(printf '%s' "$CFG" | grep -E '^[[:space:]]+task_review:' | sed -E 's/.*task_review:[[:space:]]*([a-z]+).*/\1/')"
assert_eq "T9 and ships off" "off" "$SETTING"
assert_contains "T9 the config says the footer is not configurable" \
  "not configurable" "$CFG"

# ─── T10: the footer requirement reaches the agent ───────────────────────────
PROJ="$WORK/proj"; mkdir -p "$PROJ/.specclaw/changes/demo"
cp "$CONFIG_TEMPLATE" "$PROJ/.specclaw/config.yaml"
printf '# Tasks\n\n- [ ] `T1` — do it\n  - Files: a.txt\n' > "$PROJ/.specclaw/changes/demo/tasks.md"
printf '# Spec\n' > "$PROJ/.specclaw/changes/demo/spec.md"
PAYLOAD="$( cd "$PROJ" && "$BUILD_CONTEXT" .specclaw demo T1 2>/dev/null )"
assert_contains "T10 the payload demands the footer"      "Required Report Footer" "$PAYLOAD"
assert_contains "T10 naming the three fields"             "Command:" "$PAYLOAD"
assert_contains "T10 and the check that reads it"         "check-report" "$PAYLOAD"
assert_contains "T10 and that docs-only is not exempt"    "is not exempt" "$PAYLOAD"

PT="$(cat "$PROMPTS")"
assert_contains "T10 agent-prompts documents the footer"  "Required report footer" "$PT"
assert_contains "T10 and the task-scoped reviewer prompt" "Reviewer Agent — task-scoped" "$PT"
assert_contains "T10 with the read-once rule"             "DO NOT CRAWL THE REPOSITORY" "$PT"

# ─── T11: the reviewer knows both of its modes ───────────────────────────────
RV="$(cat "$REVIEWER")"
assert_contains "T11 the agent documents task-scoped mode" "Task-scoped" "$RV"
assert_contains "T11 spec compliance comes first"          "spec compliance first" "$RV"
assert_contains "T11 and the whole-change pass is told not to repeat findings" \
  "do not repeat a finding already recorded there" "$RV"

# ─── T12: the verdicts surface where people look ─────────────────────────────
ST="$(cat "$STATUS_TEMPLATE")"
assert_contains "T12 status.md has a Review column" "| Review |" "$ST"
assert_contains "T12 documenting BLOCK→retry"       "BLOCK→retry" "$ST"

BS="$(cat "$BUILD_SKILL")"
assert_contains "T12 build checks the report before marking complete" "check-report" "$BS"
assert_contains "T12 build states the retry budget is shared" \
  "shares the task's normal retry budget" "$BS"
assert_contains "T12 build pins the reviewer's model" "never" "$BS"

VS="$(cat "$VERIFY_SKILL")"
assert_contains "T12 verify lists per-task verdicts" "per-task" "$VS"

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
