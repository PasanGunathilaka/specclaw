#!/usr/bin/env bash
# run-lint-meta-tests.sh — tests for the description lint and the trigger fixture.
#
# The lint is itself a test script, so its rules are pinned HERE, against
# synthetic skills in a temp tree. That separation is the point: asserting the
# rules against the repo's real descriptions would make this suite pass or fail
# on what those descriptions happen to say today, and every rewrite would have
# to edit the test that is supposed to be judging it.
#
# Plain bash + coreutils only.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

LINT="$SCRIPT_DIR/run-description-lint-tests.sh"
RUNNER="$SCRIPT_DIR/run-trigger-tests.sh"
FIXTURE="$SCRIPT_DIR/fixtures/triggers.tsv"
BASELINE="$SCRIPT_DIR/description-lint-baseline.txt"
PR_SCRIPT="$PLUGIN_DIR/bin/specclaw-pr"

for f in "$LINT" "$RUNNER" "$FIXTURE" "$BASELINE"; do
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
assert_not_contains() {
  local label="$1" needle="$2" hay="$3"
  if printf '%s' "$hay" | grep -qF -- "$needle"; then fail "$label — did NOT expect: $needle"
  else pass "$label"; fi
}

# mk_skill <dir> <name> <description> [--dmi]
mk_skill() {
  local dir="$1" name="$2" desc="$3" dmi="${4:-}"
  mkdir -p "$dir/$name"
  {
    printf -- '---\n'
    printf 'description: %s\n' "$desc"
    [[ "$dmi" == "--dmi" ]] && printf 'disable-model-invocation: true\n'
    printf -- '---\n\n# %s\n' "$name"
  } > "$dir/$name/SKILL.md"
}

# lint <skills_dir> [baseline] → "rc<TAB>output"
lint() {
  local sd="$1" bl="${2:-/dev/null}" out rc
  out="$(bash "$LINT" --skills-dir "$sd" --baseline "$bl" 2>&1)"; rc=$?
  printf '%s\n%s' "$rc" "$out"
}
lint_rc()  { lint "$@" | head -1; }
lint_out() { lint "$@" | tail -n +2; }

# 340 characters, carrying a trigger clause and NO narration marker, so LEN is
# the only rule it can trip. A fixture that trips two rules cannot tell you
# which one the lint actually found.
LONG_DESC="Use when a description is comfortably over the three hundred character limit, which requires a genuinely long sentence, so here is one that keeps going past every reasonable length a routing surface should ever have, continuing well beyond any point at which a reader would still be paying attention to it."

# ─── T1: the real repo passes against its own baseline ───────────────────────
RC="$(bash "$LINT" >/dev/null 2>&1; echo $?)"
assert_eq "T1 the lint is green on this repo as it stands" "0" "$RC"

# ─── T2: LEN ─────────────────────────────────────────────────────────────────
SD="$WORK/t2"; mk_skill "$SD" long "$LONG_DESC"
assert_eq "T2 an over-long description fails" "1" "$(lint_rc "$SD")"
assert_contains "T2 and reports the character count" "LEN: 3" "$(lint_out "$SD")"

SD="$WORK/t2b"; mk_skill "$SD" short "Use when the user asks for the dashboard."
assert_eq "T2 a short, triggered description passes" "0" "$(lint_rc "$SD")"

# ─── T3: TRIGGER ─────────────────────────────────────────────────────────────
SD="$WORK/t3"; mk_skill "$SD" narrator "Show the project dashboard with active and completed changes."
assert_eq "T3 a description with no trigger clause fails" "1" "$(lint_rc "$SD")"
assert_contains "T3 and names the rule" "TRIGGER" "$(lint_out "$SD")"

SD="$WORK/t3b"; mk_skill "$SD" nodesc ""
assert_eq "T3 an empty description fails" "1" "$(lint_rc "$SD")"
assert_contains "T3 and says there is none" "no description" "$(lint_out "$SD")"

# ─── T4: every accepted clause is accepted, and nothing else is ──────────────
i=0
for clause in "Use when the tree is dirty." \
              "Use after a proposal is approved." \
              "Use before touching source files." \
              "Run after the build completes." \
              "Run before opening a PR." \
              "Invoke when a bug is reported." \
              "Invoke immediately when the user mentions a proposal." \
              "Trigger when tests fail." \
              "Called when a change is merged." \
              "Archive a change when its PR has merged."; do
  i=$((i + 1))
  SD="$WORK/t4-$i"; mk_skill "$SD" s "$clause"
  assert_eq "T4 accepted clause: ${clause%% *}…" "0" "$(lint_rc "$SD")"
done

# The negative side of the same rule — an imperative opener is NOT a trigger.
# This is the whole reason the set is closed: admit "Show …" and you admit
# "Manage …", "Create …", "Produce …", which is every description ever written.
for opener in "Show the dashboard." "Manage the context document." "Create a GitHub issue." \
              "Generate a spec and a design." "Produce a C4 architecture view."; do
  SD="$WORK/t4n-$RANDOM"; mk_skill "$SD" s "$opener"
  assert_eq "T4 rejected opener: ${opener%% *}…" "1" "$(lint_rc "$SD")"
done

# ─── T5: NARRATION ───────────────────────────────────────────────────────────
SD="$WORK/t5"; mk_skill "$SD" arrow "Use when planning. Runs propose → plan → build → verify."
assert_eq "T5 a lifecycle arrow fails" "1" "$(lint_rc "$SD")"
assert_contains "T5 and names the rule" "NARRATION" "$(lint_out "$SD")"

SD="$WORK/t5b"; mk_skill "$SD" thenword "Use when asked. Reads the spec then writes the tasks."
assert_eq "T5 a ' then ' narration fails" "1" "$(lint_rc "$SD")"

SD="$WORK/t5c"; mk_skill "$SD" stepword "Use when asked. Step 1 reads the config."
assert_eq "T5 a 'Step N' narration fails" "1" "$(lint_rc "$SD")"

# ─── T6: disable-model-invocation exempts TRIGGER only ───────────────────────
SD="$WORK/t6"; mk_skill "$SD" creds "Interactive setup for Azure DevOps authentication." --dmi
assert_eq "T6 a DMI skill owes no trigger clause" "0" "$(lint_rc "$SD")"

SD="$WORK/t6b"; mk_skill "$SD" credslong "$LONG_DESC" --dmi
assert_eq "T6 but still owes brevity" "1" "$(lint_rc "$SD")"
assert_contains "T6 and it is LEN that fires, not TRIGGER" "LEN" "$(lint_out "$SD")"
assert_not_contains "T6 TRIGGER does not fire on a DMI skill" "TRIGGER" "$(lint_out "$SD")"

# ─── T7: the baseline suppresses, and reports what it no longer needs ────────
SD="$WORK/t7"; mk_skill "$SD" legacy "$LONG_DESC"
BL="$WORK/t7-baseline.txt"
printf '# a comment\n\nskills/legacy/SKILL.md LEN\n' > "$BL"
assert_eq "T7 a baselined offence does not fail" "0" "$(lint_rc "$SD" "$BL")"

mk_skill "$SD" legacy "Use when the legacy thing is needed."
OUT="$(lint_out "$SD" "$BL")"
assert_eq "T7 a fixed offence still exits 0" "0" "$(lint_rc "$SD" "$BL")"
assert_contains "T7 and the stale entry is reported as prunable" "no longer offend" "$OUT"
assert_contains "T7 naming the entry" "skills/legacy/SKILL.md LEN" "$OUT"

# ─── T8: a new skill gets no free pass ───────────────────────────────────────
mk_skill "$SD" brandnew "Show a thing."
assert_eq "T8 a skill absent from the baseline fails on its first commit" "1" "$(lint_rc "$SD" "$BL")"

# ─── T9: the skills added alongside the lint are not baselined ───────────────
for s in debug using-specclaw; do
  if grep -q "skills/${s}/SKILL.md" "$BASELINE"; then
    fail "T9 skills/$s is baselined — new skills must pass the rules outright"
  else
    pass "T9 skills/$s carries no baseline entry"
  fi
done

# ─── T10: the fixture is well-formed ─────────────────────────────────────────
MALFORMED="$(awk -F'\t' '!/^#/ && NF>0 && NF!=4 {n++} END {print n+0}' "$FIXTURE")"
assert_eq "T10 every fixture row has four fields" "0" "$MALFORMED"

ROWS="$(awk -F'\t' '!/^#/ && NF==4 {n++} END {print n+0}' "$FIXTURE")"
if [[ "$ROWS" -ge 10 ]]; then pass "T10 the fixture has $ROWS rows"; else fail "T10 only $ROWS fixture rows"; fi

NEG="$(awk -F'\t' '!/^#/ && NF==4 && $2=="none" {n++} END {print n+0}' "$FIXTURE")"
if [[ "$NEG" -ge 2 ]]; then
  pass "T10 the fixture has $NEG negative rows (over-triggering is measurable)"
else
  fail "T10 only $NEG negative rows — a positive-only suite scores 100% on a router that always fires"
fi

# Every non-`none` expectation must name a real skill directory.
BADEXP=""
while IFS=$'\t' read -r _u expect _s _n; do
  case "${_u:-}" in ''|\#*) continue ;; esac
  [ -n "${expect:-}" ] || continue
  [ "$expect" = "none" ] && continue
  [ -d "$PLUGIN_DIR/skills/$expect" ] || BADEXP="${BADEXP} ${expect}"
done < "$FIXTURE"
assert_eq "T10 every expected verb is a real skill" "" "$BADEXP"

# ─── T11: the state-dependent pair exists ────────────────────────────────────
# Same utterance, two states, two different correct answers — the sharpest test
# of change 033's claim that injected state makes routing controlled.
DUPES="$(awk -F'\t' '!/^#/ && NF==4 {print $1}' "$FIXTURE" | sort | uniq -d | grep -c '^' || true)"
if [[ "$DUPES" -ge 1 ]]; then
  pass "T11 the fixture carries a state-dependent utterance pair"
else
  fail "T11 no utterance appears under two states — 033's snapshot has no target"
fi

# ─── T12: the runner is opt-in, and a missing CLI is not a pass ──────────────
OUT="$(bash "$RUNNER" 2>&1)"; RC=$?
assert_eq "T12 without the env flag the runner exits 0" "0" "$RC"
assert_contains "T12 and says why it skipped" "costs API calls" "$OUT"

OUT="$(PATH="$WORK/empty-path" SPECCLAW_TRIGGER_EVALS=1 bash "$RUNNER" 2>&1)"; RC=$?
if [[ "$RC" -ne 0 ]]; then
  pass "T12 with the flag set and no claude CLI, the runner FAILS (rc=$RC)"
else
  fail "T12 a missing CLI reported success — that is the failure this suite exists to prevent"
fi

# ─── T12b: skipping is the workflow's decision, never the runner's ───────────
# Both halves matter. The runner must fail loudly when asked to measure and
# unable to; the workflow must skip when the repo has no key, because a job that
# goes red for a missing secret on every skills PR is a red X people learn to
# ignore.
WF="$PLUGIN_DIR/../../.github/workflows/trigger-evals.yml"
if [[ -f "$WF" ]]; then
  WFTEXT="$(cat "$WF")"
  assert_contains "T12b the workflow checks for the key first" \
    "Is the eval key configured?" "$WFTEXT"
  assert_contains "T12b and gates the run on it" \
    "steps.key.outputs.present == 'true'" "$WFTEXT"
  assert_contains "T12b saying so rather than failing" "::notice::" "$WFTEXT"
else
  fail "T12b trigger-evals.yml not found at $WF"
fi

# ─── T13: specclaw-pr attaches a matrix when there is one ────────────────────
if [[ -f "$PR_SCRIPT" ]]; then
  if grep -q 'triggers-' "$PR_SCRIPT"; then
    pass "T13 specclaw-pr knows about the trigger matrix"
  else
    fail "T13 specclaw-pr does not reference the trigger matrix"
  fi
  if grep -q 'Skill-trigger matrix' "$PR_SCRIPT"; then
    pass "T13 and gives the section a heading"
  else
    fail "T13 no matrix section heading in specclaw-pr"
  fi
else
  fail "T13 specclaw-pr not found"
fi

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
