#!/usr/bin/env bash
# run-parser-tests.sh — regression suite for specclaw's bin parsers.
#
# Locks in the recently fixed behaviors:
#   B2: validate-change task counting ignores ``` fenced blocks and only
#       counts backtick-wrapped `T<n>` ids.
#   B3: verify collect parses ACs as AC1 / AC-1, with/without `- [ ]`,
#       with/without **bold**.
#   B4: verify collect parses `Files:` lines that begin with a `  - ` bullet.
# Plus NFR2: existing in-repo change docs still parse (no regression).
# The brownfield collector cases (formerly 9-12) live in
# plugins/specclaw-bf/tests/run-bf-collect-tests.sh.
#
# Plain bash only — no bats/npm. Run from anywhere:
#   bash plugins/specclaw/tests/run-parser-tests.sh
# Exits non-zero if any case fails.

set -uo pipefail

# --- Resolve own dir and locate ../bin ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# Brownfield analyze collector, analyst agent, and report template moved to the
# specclaw-bf plugin in the four-plugin split; the collector and
# evidence-discipline cases below resolve them there rather than under this
# (core) plugin.
BF_PLUGIN_ROOT="$REPO_ROOT/plugins/specclaw-bf"
BF_BIN_DIR="$BF_PLUGIN_ROOT/bin"

PARSE_TASKS="$BIN_DIR/specclaw-parse-tasks"
VALIDATE_CHANGE="$BIN_DIR/specclaw-validate-change"
VERIFY="$BIN_DIR/specclaw-verify"

for b in "$PARSE_TASKS" "$VALIDATE_CHANGE" "$VERIFY"; do
  if [[ ! -x "$b" && ! -f "$b" ]]; then
    echo "FATAL: missing bin script: $b" >&2
    exit 2
  fi
done

# --- mktemp workspace with a real .specclaw-like layout (changes/<name>/) ---
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# assert_eq <label> <expected> <actual>
assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    pass "$label (= '$actual')"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

# Build a change dir under the temp workspace and echo its specclaw_dir.
# Usage: make_change <change_name> [spec_fixture] [tasks_fixture]
make_change() {
  local name="$1" spec="${2:-}" tasks="${3:-}"
  local cdir="$WORK/changes/$name"
  mkdir -p "$cdir"
  [[ -n "$spec" ]] && cp "$FIXTURES_DIR/$spec" "$cdir/spec.md"
  [[ -n "$tasks" ]] && cp "$FIXTURES_DIR/$tasks" "$cdir/tasks.md"
  echo "$cdir"
}

echo "=== specclaw bin parser regression suite ==="
echo "bin:      $BIN_DIR"
echo "fixtures: $FIXTURES_DIR"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 1 — parse-tasks finds exactly the real T-tasks (template Legend +
# fenced `T<n>` placeholder are not numeric ids, so they are not picked up).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 1: parse-tasks finds exactly the real T-tasks ---"
c1="$(make_change c1-tasks "" tasks.md)"
ids="$("$PARSE_TASKS" "$c1/tasks.md" | jq -r '[.[].id] | sort | join(",")')"
assert_eq "parse-tasks task ids" "T1,T2,T3" "$ids"
# Statuses round-trip correctly for the three markers.
st="$("$PARSE_TASKS" "$c1/tasks.md" | jq -r '[.[] | .status] | join(",")')"
assert_eq "parse-tasks statuses (x,space,~)" "complete,pending,in_progress" "$st"
# --validate exits 0 on well-formed output.
if "$PARSE_TASKS" --validate "$c1/tasks.md" >/dev/null 2>&1; then
  pass "parse-tasks --validate exits 0"
else
  fail "parse-tasks --validate exits 0"
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 2 — B2: validate-change `status` counts only real backtick T-ids,
# excluding the fenced block (numeric `T9`/`T8` examples) and bare legend lines.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 2 (B2): validate-change status excludes fence + legend ---"
c2="$(make_change b2-fence "" tasks-fenced-id.md)"
line="$("$VALIDATE_CHANGE" "$WORK" b2-fence status | grep -o 'tasks.md ([0-9]*/[0-9]* complete)')"
# Real tasks: T1 [x], T2 [ ] -> 1 complete of 2 total. Fenced T9/T8 ignored.
assert_eq "B2 status line" "tasks.md (1/2 complete)" "$line"

# Same fixture against the c1 tasks (which has 3 real tasks, 1 complete) to
# confirm counting tracks the real markers and not the fenced placeholder.
line1="$("$VALIDATE_CHANGE" "$WORK" c1-tasks status | grep -o 'tasks.md ([0-9]*/[0-9]* complete)')"
assert_eq "B2 status line (case-1 tasks)" "tasks.md (1/3 complete)" "$line1"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 3 — B3: verify collect parses all three AC formats.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 3 (B3): verify collect parses mixed AC formats ---"
c3="$(make_change b3-ac spec.md tasks.md)"
ac_count="$("$VERIFY" collect "$WORK" b3-ac 2>/dev/null | jq '.acceptance_criteria | length')"
assert_eq "AC count" "3" "$ac_count"
# Each AC line is non-empty and the AC ids are all represented.
ac_join="$("$VERIFY" collect "$WORK" b3-ac 2>/dev/null | jq -r '.acceptance_criteria | join("\n")')"
for needle in "AC-1" "AC2" "AC-3"; do
  if grep -q "$needle" <<<"$ac_join"; then
    pass "AC contains $needle"
  else
    fail "AC contains $needle"
  fi
done
empty_acs="$("$VERIFY" collect "$WORK" b3-ac 2>/dev/null | jq '[.acceptance_criteria[] | select(. == "")] | length')"
assert_eq "no empty AC entries" "0" "$empty_acs"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 4 — B4: verify collect parses `  - Files:` bullet lines.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 4 (B4): verify collect parses bulleted Files: lines ---"
# Reuse the b3-ac change (its tasks.md has `  - Files:` bullets with backticks).
paths="$("$VERIFY" collect "$WORK" b3-ac 2>/dev/null | jq -r '[.changed_files[].path] | sort | join(",")')"
assert_eq "changed_files paths" "src/a.ts,src/b.ts,src/c.ts,src/d.ts" "$paths"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 5 — NFR2: existing in-repo change still parses (no regression).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 5 (NFR2): real in-repo change still parses ---"
REAL_SPECCLAW="$REPO_ROOT/.specclaw"
REAL_CHANGE="build-engine"
# REAL_CHANGE is the change path relative to changes/ (e.g. "build-engine" or
# "archive/2026-07-22-build-engine"), so both PARSE_TASKS (full path) and
# VERIFY collect (specclaw_dir + change_name) resolve it.
if [[ ! -f "$REAL_SPECCLAW/changes/$REAL_CHANGE/spec.md" ]]; then
  # Fallback: pick any change with both spec.md and tasks.md — active first,
  # then archived (all active changes may be archived, e.g. after cleanup).
  REAL_CHANGE=""
  for d in "$REAL_SPECCLAW"/changes/*/ "$REAL_SPECCLAW"/changes/archive/*/; do
    if [[ -f "$d/spec.md" && -f "$d/tasks.md" ]]; then
      REAL_CHANGE="${d#"$REAL_SPECCLAW"/changes/}"; REAL_CHANGE="${REAL_CHANGE%/}"
      break
    fi
  done
fi

if [[ -n "$REAL_CHANGE" && -f "$REAL_SPECCLAW/changes/$REAL_CHANGE/spec.md" && -f "$REAL_SPECCLAW/changes/$REAL_CHANGE/tasks.md" ]]; then
  echo "    using real change: $REAL_CHANGE"
  real_ids="$("$PARSE_TASKS" "$REAL_SPECCLAW/changes/$REAL_CHANGE/tasks.md" | jq 'length')"
  if [[ "$real_ids" -gt 0 ]]; then
    pass "NFR2 parse-tasks found $real_ids tasks in $REAL_CHANGE"
  else
    fail "NFR2 parse-tasks found 0 tasks in $REAL_CHANGE"
  fi
  real_acs="$("$VERIFY" collect "$REAL_SPECCLAW" "$REAL_CHANGE" 2>/dev/null | jq '.acceptance_criteria | length')"
  if [[ "$real_acs" -gt 0 ]]; then
    pass "NFR2 verify collect found $real_acs ACs in $REAL_CHANGE"
  else
    fail "NFR2 verify collect found 0 ACs in $REAL_CHANGE"
  fi
else
  fail "NFR2 could not locate a real change with spec.md + tasks.md under $REAL_SPECCLAW"
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 6 — grounded-context: specclaw-discover-context ranking, filtering,
# budget, and off-switch (all jq-free; runs in a non-git temp tree, which also
# exercises the find fallback).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 6: discover-context ranking / filtering / budget ---"
DISCOVER="$BIN_DIR/specclaw-discover-context"
if [[ ! -f "$DISCOVER" ]]; then
  fail "discover-context script missing at $DISCOVER"
else
  # Fixture project: copy the static tree, add a .specclaw dir per sub-case.
  DPROJ="$WORK/discovery-proj"
  mkdir -p "$DPROJ/.specclaw"
  cp -R "$FIXTURES_DIR/discovery/." "$DPROJ/"
  printf 'context:\n  discovery: true\n' > "$DPROJ/.specclaw/config.yaml"

  # 6a (AC1/AC2) — ranking: llms.txt-listed guide.md first (tier 1), root
  # canonical CLAUDE/README (tier 2), nested src/README (tier 4).
  paths="$(bash "$DISCOVER" "$DPROJ/.specclaw" list 2>/dev/null | cut -f3 | tr '\n' ',')"
  assert_eq "6a ranked order" "docs/guide.md,CLAUDE.md,README.md,docs/skip.md,src/README.md," "$paths"

  # 6b (AC2) — missing llms.txt entry warns but does not fail.
  if bash "$DISCOVER" "$DPROJ/.specclaw" list 2>&1 >/dev/null | grep -q "docs/nope.md"; then
    pass "6b llms.txt missing entry warned"
  else
    fail "6b llms.txt missing entry warned"
  fi

  # 6c (AC3) — defaults exclude CHANGELOG.md and archive/.
  listed="$(bash "$DISCOVER" "$DPROJ/.specclaw" list 2>/dev/null | cut -f3)"
  if grep -q "CHANGELOG.md" <<<"$listed" || grep -q "archive/old.md" <<<"$listed"; then
    fail "6c default exclusions (CHANGELOG/archive leaked)"
  else
    pass "6c default exclusions"
  fi

  # 6d (AC4) — precedence: folders includes docs/, exclude still beats it;
  # root-relative pattern excludes root README.
  printf 'context:\n  discovery: true\n  folders:\n    - "docs"\n  exclude:\n    - "docs/skip.md"\n' > "$DPROJ/.specclaw/config.yaml"
  paths="$(bash "$DISCOVER" "$DPROJ/.specclaw" list 2>/dev/null | cut -f3 | tr '\n' ',')"
  assert_eq "6d exclude beats folders" "docs/guide.md," "$paths"
  printf 'context:\n  discovery: true\n  exclude:\n    - "./README.md"\n    - "src"\n' > "$DPROJ/.specclaw/config.yaml"
  paths="$(bash "$DISCOVER" "$DPROJ/.specclaw" list 2>/dev/null | cut -f3 | tr '\n' ',')"
  assert_eq "6d root-relative + segment excludes" "docs/guide.md,CLAUDE.md,docs/skip.md," "$paths"

  # 6e (AC5) — budget: emit stays within budget and names every casualty.
  printf 'context:\n  discovery: true\n' > "$DPROJ/.specclaw/config.yaml"
  out="$(bash "$DISCOVER" "$DPROJ/.specclaw" emit --budget 4 2>/dev/null)"
  if grep -q '^<!-- dropped (over 4-line budget):' <<<"$out"; then
    pass "6e budget footer present"
  else
    fail "6e budget footer present"
  fi
  # Budget 4: guide.md (2) + CLAUDE.md (2) fit exactly; the rest must be
  # named as dropped. " README.md" (leading space) avoids matching src/README.md.
  for casualty in " README.md" "docs/skip.md" "src/README.md"; do
    if grep "^<!-- dropped" <<<"$out" | grep -q "$casualty"; then
      pass "6e names dropped:$casualty"
    else
      fail "6e names dropped:$casualty"
    fi
  done

  # 6f (AC6) — discovery off: zero output, exit 0.
  printf 'context:\n  discovery: false\n' > "$DPROJ/.specclaw/config.yaml"
  out="$(bash "$DISCOVER" "$DPROJ/.specclaw" emit 2>/dev/null)"; rc=$?
  if [[ -z "$out" && "$rc" -eq 0 ]]; then
    pass "6f discovery off = empty output, exit 0"
  else
    fail "6f discovery off = empty output, exit 0 (rc=$rc, ${#out} bytes)"
  fi

  # 6g — git enumeration path: run against the real repo, expect README.md
  # (tier 2) present and .specclaw/ absent.
  real_list="$(bash "$DISCOVER" "$REPO_ROOT/.specclaw" list 2>/dev/null | cut -f3)"
  if grep -qx "README.md" <<<"$real_list" && ! grep -q "^\.specclaw/" <<<"$real_list"; then
    pass "6g git-tree enumeration on real repo"
  else
    fail "6g git-tree enumeration on real repo"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 8 — update-check: compare logic, gate, fail-silence, cache (all offline).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 8: update-check compare / gate / silence / cache ---"
CHECK_BIN="$BIN_DIR/specclaw-check-update"
UPROJ="$WORK/update-proj/.specclaw"
mkdir -p "$UPROJ"
printf 'version: 1\n' > "$UPROJ/config.yaml"

if [[ ! -f "$CHECK_BIN" ]]; then
  fail "specclaw-check-update missing"
else
  local_ver="$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$BIN_DIR/../.claude-plugin/plugin.json" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')"

  # 8a (AC1) — newer remote → exactly one line with both versions + update hint
  out="$(bash "$CHECK_BIN" "$UPROJ" --remote-version 99.0.0)"
  # `tr -d ' '` is load-bearing: BSD wc pads its count ("       1"), so on macOS
  # this comparison was ALWAYS false and case 8a failed for an environment
  # reason rather than a real one. That masked a genuine regression — a second
  # line added to the notice — which only CI caught, because a before/after
  # failure COUNT is blind to a test that was already red for another reason.
  if [[ "$(wc -l <<<"$out" | tr -d ' ')" == "1" ]] && grep -q "99.0.0" <<<"$out" && grep -q "$local_ver" <<<"$out" && grep -q "/plugin update specclaw" <<<"$out"; then
    pass "8a newer remote notifies"
  else
    fail "8a newer remote notifies (got: $out)"
  fi

  # 8b (AC2) — equal and older remote → silent, exit 0
  out_eq="$(bash "$CHECK_BIN" "$UPROJ" --remote-version "$local_ver")"; rc_eq=$?
  out_old="$(bash "$CHECK_BIN" "$UPROJ" --remote-version 0.0.1)"; rc_old=$?
  if [[ -z "$out_eq" && -z "$out_old" && "$rc_eq" -eq 0 && "$rc_old" -eq 0 ]]; then
    pass "8b equal/older silent"
  else
    fail "8b equal/older silent"
  fi

  # 8c (AC3) — gate beats hook: update_check false + newer remote → silent
  printf 'version: 1\nplugin:\n  update_check: false\n' > "$UPROJ/config.yaml"
  out="$(bash "$CHECK_BIN" "$UPROJ" --remote-version 99.0.0)"; rc=$?
  if [[ -z "$out" && "$rc" -eq 0 ]]; then
    pass "8c gate disables check"
  else
    fail "8c gate disables check"
  fi
  printf 'version: 1\n' > "$UPROJ/config.yaml"

  # 8d (AC5) — fresh cache short-circuits network: seed newer cached version,
  # no --remote-version, notification comes from the cache alone
  printf '%s 99.0.0\n' "$(date +%s)" > "$UPROJ/.update-check"
  out="$(bash "$CHECK_BIN" "$UPROJ")"
  if grep -q "99.0.0 available" <<<"$out"; then
    pass "8d cache short-circuit notifies"
  else
    fail "8d cache short-circuit notifies (got: $out)"
  fi

  # 8e (AC5) — corrupt cache ignored (treated stale); with no network result
  # available the check stays silent rather than erroring
  printf 'garbage-not-epoch 99.0.0\n' > "$UPROJ/.update-check"
  out="$(bash "$CHECK_BIN" "$UPROJ" --remote-version 0.0.1)"; rc=$?
  if [[ -z "$out" && "$rc" -eq 0 ]]; then
    pass "8e corrupt cache ignored"
  else
    fail "8e corrupt cache ignored"
  fi
  rm -f "$UPROJ/.update-check"

  # 8f (AC4) — unreachable repo host: silent exit 0 (fail-silent network path).
  # Copy the script beside a fake manifest so repo derivation hits a dead host.
  FAKEBIN="$WORK/fake-plugin/bin"
  mkdir -p "$FAKEBIN" "$WORK/fake-plugin/.claude-plugin"
  cp "$CHECK_BIN" "$FAKEBIN/"
  printf '{ "name": "specclaw", "version": "0.0.1", "repository": "https://invalid.invalid/nobody/nothing" }\n' > "$WORK/fake-plugin/.claude-plugin/plugin.json"
  out="$(bash "$FAKEBIN/specclaw-check-update" "$UPROJ" --force 2>/dev/null)"; rc=$?
  if [[ -z "$out" && "$rc" -eq 0 ]]; then
    pass "8f unreachable host silent"
  else
    fail "8f unreachable host silent (rc=$rc, out: $out)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 7 — smart-base-branch: detect_base_branch chain + base-aware setup.
# Local bare origin with default branch 'develop'; jq-free asserts.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 7: base branch detection + base-aware setup ---"
BUILD_BIN="$BIN_DIR/specclaw-build"
GPROJ="$WORK/base-branch-proj"

# Build a bare origin whose default branch is 'develop'
mkdir -p "$WORK/origin-src" && (
  cd "$WORK/origin-src"
  git init -q -b develop .
  git config user.email t@t && git config user.name t
  echo base > base.txt && git add . && git commit -qm base
  echo dev2 > dev2.txt && git add . && git commit -qm dev2
) && git clone -q --bare "$WORK/origin-src" "$WORK/origin.git" && (
  git -C "$WORK/origin.git" symbolic-ref HEAD refs/heads/develop
) && git clone -q "$WORK/origin.git" "$GPROJ" && (
  cd "$GPROJ"
  git config user.email t@t && git config user.name t
  mkdir -p .specclaw/changes/bb-test
  printf 'version: 1\ngit:\n  strategy: "branch-per-change"\n  branch_prefix: "specclaw/"\n' > .specclaw/config.yaml
  printf '# t\n- [ ] `T1` — x\n  - Files: a\n' > .specclaw/changes/bb-test/tasks.md
)

if [[ ! -f "$BUILD_BIN" ]]; then
  fail "specclaw-build missing"
else
  # 7a (AC1) — detection resolves origin/HEAD -> develop; setup JSON reports it
  setup_json="$(cd "$GPROJ" && bash "$BUILD_BIN" setup .specclaw bb-test 2>/dev/null)"
  base_val="$(printf '%s' "$setup_json" | grep -o '"base_branch": "[^"]*"' | sed 's/.*: "//;s/"//')"
  assert_eq "7a detected base (origin/HEAD)" "develop" "$base_val"

  # 7b (AC4) — new change branch starts at origin/develop tip
  tip_origin="$(git -C "$GPROJ" rev-parse origin/develop)"
  tip_branch="$(git -C "$GPROJ" rev-parse specclaw/bb-test)"
  assert_eq "7b branch starts at origin/develop tip" "$tip_origin" "$tip_branch"

  # 7c (AC5) — resume path unchanged (second run warns, same branch).
  # Release the dispatch lock first (change 038): this test calls `setup`
  # twice in sequence to exercise base-branch resume logic, not concurrency —
  # a real caller would reach `finalize` (which releases) between dispatches.
  (cd "$GPROJ" && bash "$BIN_DIR/specclaw-change-lock" .specclaw release bb-test)
  resume_out="$(cd "$GPROJ" && bash "$BUILD_BIN" setup .specclaw bb-test 2>&1 >/dev/null)"
  if grep -q "already exists — resuming" <<<"$resume_out"; then
    pass "7c resume warning intact"
  else
    fail "7c resume warning intact"
  fi

  # 7d (AC2) — config override beats origin/HEAD
  (cd "$GPROJ" && git checkout -q develop && git branch -q -D specclaw/bb-test)
  printf 'version: 1\ngit:\n  strategy: "branch-per-change"\n  branch_prefix: "specclaw/"\n  base_branch: "release/1.0"\n' > "$GPROJ/.specclaw/config.yaml"
  (cd "$GPROJ" && git branch -q "release/1.0")
  (cd "$GPROJ" && bash "$BIN_DIR/specclaw-change-lock" .specclaw release bb-test)
  setup_json="$(cd "$GPROJ" && bash "$BUILD_BIN" setup .specclaw bb-test 2>/dev/null)"
  base_val="$(printf '%s' "$setup_json" | grep -o '"base_branch": "[^"]*"' | sed 's/.*: "//;s/"//')"
  assert_eq "7d config override wins" "release/1.0" "$base_val"

  # 7e (AC3) — no origin remote: falls back to local main/master without error
  NOREMOTE="$WORK/noremote-proj"
  mkdir -p "$NOREMOTE" && (
    cd "$NOREMOTE"
    git init -q -b main .
    git config user.email t@t && git config user.name t
    echo x > x.txt && git add . && git commit -qm x
    mkdir -p .specclaw/changes/nr-test
    printf 'version: 1\ngit:\n  strategy: "branch-per-change"\n  branch_prefix: "specclaw/"\n' > .specclaw/config.yaml
    printf '# t\n- [ ] `T1` — x\n  - Files: a\n' > .specclaw/changes/nr-test/tasks.md
  )
  setup_json="$(cd "$NOREMOTE" && bash "$BUILD_BIN" setup .specclaw nr-test 2>/dev/null)"
  base_val="$(printf '%s' "$setup_json" | grep -o '"base_branch": "[^"]*"' | sed 's/.*: "//;s/"//')"
  assert_eq "7e no-remote fallback" "main" "$base_val"

  # 7f (AC6) — specclaw-pr uses detected base, no hardcoded '--base main'
  if grep -q -- '--base "\$pr_base"' "$BIN_DIR/specclaw-pr" && ! grep -q -- '--base main' "$BIN_DIR/specclaw-pr"; then
    pass "7f pr --base uses detection"
  else
    fail "7f pr --base uses detection"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 13 — verify-glob-oom-fix: `Files:` paths with glob metacharacters (e.g.
# Next.js dynamic routes `app/[id]/page.tsx`) must extract verbatim and NOT
# hang. Pre-fix the strip glob-interpreted the captured path, no-op'd, and
# infinite-looped until OOM. Guard with `timeout` so a regression fails fast.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 13: verify collect handles glob/dynamic-route paths (no hang) ---"
gdir="$WORK/changes/glob-path"
mkdir -p "$gdir"
printf '# spec\n## Acceptance Criteria\n- [ ] AC-1: works\n' > "$gdir/spec.md"
{
  printf '# tasks\n'
  printf -- '- [ ] `T1` — dynamic route\n'
  printf -- '  - Files: `app/[id]/page.tsx`\n'
  printf -- '- [ ] `T2` — catch-all + plain\n'
  printf -- '  - Files: `app/[...slug]/route.ts`, `src/plain.ts`\n'
} > "$gdir/tasks.md"

# The critical assertion: collect terminates. `timeout` kills a runaway loop
# (exit 124) so the hang manifests as a fail, not a stalled suite.
gout="$(timeout 10 "$VERIFY" collect "$WORK" glob-path 2>/dev/null)"; grc=$?
if [[ "$grc" -eq 0 ]]; then
  pass "AC-1/AC-2 verify collect terminates on glob paths (no hang)"
else
  fail "AC-1/AC-2 verify collect terminates on glob paths (rc=$grc — 124=timeout/hang)"
fi

# jq-free asserts (jq is not guaranteed on every runner): count and match the
# "path": entries directly in the JSON so a glob path that got dropped or
# duplicated is caught regardless of jq availability.
gcount="$(printf '%s' "$gout" | grep -c '"path":')"
assert_eq "glob paths extracted count" "3" "${gcount:-0}"
for needle in 'app/[id]/page.tsx' 'app/[...slug]/route.ts' 'src/plain.ts'; do
  if grep -qF "\"path\": \"$needle\"" <<<"$gout"; then
    pass "glob path extracted verbatim: $needle"
  else
    fail "glob path extracted verbatim: $needle"
  fi
done
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 10 — fence-aware task counting, one counter for every caller.
#
# parse-tasks itself had no fence tracking, so `- [ ] `T9`` inside a ``` block
# was emitted as a real task. Two consequences, both silent: task totals ran one
# high (`5/6 done` on a finished change), and `specclaw-loop` gate 1 — which
# reads `--status pending` — reported an incomplete task that does not exist and
# could never be completed, so the loop burned every iteration on it.
#
# All asserts here are jq-free: they read the JSON text directly so the case
# runs on a runner without jq, which is exactly where a regression would hide.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 10: fenced tasks excluded from parse, count, and filters ---"
FENCED="$FIXTURES_DIR/tasks-fenced-id.md"

# --count prints "<done> <total> <failed> <deferred>" (4th field, change 038).
# Real tasks: T1 [x], T2 [ ].
assert_eq "10a --count ignores fenced T9/T8" "1 2 0 0" \
  "$("$PARSE_TASKS" --count "$FENCED" 2>/dev/null)"

# The JSON must not carry the fenced ids either — the loop reads this, not the count.
fenced_json="$("$PARSE_TASKS" "$FENCED" 2>/dev/null)"
assert_eq "10b JSON task count excludes fence" "2" "$(grep -c '"id":' <<<"$fenced_json")"
for ghost in T9 T8; do
  if grep -q "\"id\":\"$ghost\"" <<<"$fenced_json"; then
    fail "10b fenced id leaked into JSON: $ghost"
  else
    pass "10b fenced id absent from JSON: $ghost"
  fi
done

# The loop-gate path: a fenced pending task must not surface as incomplete.
pending_json="$("$PARSE_TASKS" --status pending "$FENCED" 2>/dev/null)"
assert_eq "10c --status pending sees only the real pending task" "1" \
  "$(grep -c '"id":' <<<"$pending_json")"
if grep -q '"id":"T9"' <<<"$pending_json"; then
  fail "10c fenced T9 reported pending (loop gate 1 can never go green)"
else
  pass "10c fenced T9 not reported pending"
fi

# All four markers tally correctly, with a fenced example present.
c10="$WORK/changes/c10-markers"
mkdir -p "$c10"
{
  printf '# tasks\n\n'
  printf -- '- [x] `T1` — done\n'
  printf -- '- [ ] `T2` — pending\n'
  printf -- '- [!] `T3` — failed\n'
  printf -- '- [~] `T4` — in progress\n\n'
  printf 'Template:\n\n```\n'
  printf -- '- [ ] `T99` — fenced example\n'
  printf '```\n'
} > "$c10/tasks.md"
assert_eq "10d all four markers, fence excluded" "1 4 1 0" \
  "$("$PARSE_TASKS" --count "$c10/tasks.md" 2>/dev/null)"

# A `### Wave` heading inside a fence must not bump the wave counter.
c10w="$WORK/changes/c10-wave"
mkdir -p "$c10w"
{
  printf '# tasks\n\n### Wave 1\n\n'
  printf -- '- [ ] `T1` — real\n\n'
  printf '```\n### Wave 9\n- [ ] `T50` — example\n```\n'
} > "$c10w/tasks.md"
w10="$("$PARSE_TASKS" "$c10w/tasks.md" 2>/dev/null | grep -o '"wave":[0-9]*' | sort -u | tr '\n' ' ')"
assert_eq "10e fenced Wave heading does not shift waves" '"wave":1 ' "$w10"

# --count reports the whole file; combining it with a filter would let a caller
# read "3/3 done" off one wave and call the change finished.
if "$PARSE_TASKS" --count --wave 1 "$FENCED" >/dev/null 2>&1; then
  fail "10f --count rejects --wave"
else
  pass "10f --count rejects --wave"
fi

# Regression guard: the naive counter must not come back. Four copies of the
# fence rule is what put three call sites out of sync in the first place.
# A checkbox with a bare `T1` (no backticks) is not a task, and reading "0/0
# done" off a whole file of them must not be silent — the count goes to stdout,
# one summary warning to stderr. Callers deliberately do not suppress it.
c10b="$WORK/changes/c10-bare"
mkdir -p "$c10b"
printf -- '# tasks\n\n- [x] T1 one\n- [x] T2 two\n' > "$c10b/tasks.md"
assert_eq "10h bare ids are not counted" "0 0 0 0" \
  "$("$PARSE_TASKS" --count "$c10b/tasks.md" 2>/dev/null)"
bare_warn="$("$PARSE_TASKS" --count "$c10b/tasks.md" 2>&1 >/dev/null)"
if grep -q 'not counted' <<<"$bare_warn"; then
  pass "10h skipped checkboxes warn on stderr (= '$bare_warn')"
else
  fail "10h skipped checkboxes warn on stderr (got '$bare_warn')"
fi
# One summary, not one line per task.
assert_eq "10h warning is a single summary line" "1" "$(grep -c . <<<"$bare_warn")"
# A clean file stays silent.
assert_eq "10h well-formed file emits no warning" "" \
  "$("$PARSE_TASKS" --count "$c10/tasks.md" 2>&1 >/dev/null)"

naive="$(grep -rln "grep -c '\^\\\\- \\\\\[" "$BIN_DIR" 2>/dev/null | tr '\n' ' ')"
assert_eq "10g no bin script counts tasks with grep" "" "$naive"
for caller in specclaw-reconcile specclaw-build specclaw-update-status specclaw-validate-change specclaw-bootstrap-snapshot; do
  if grep -q -- '--count' "$BIN_DIR/$caller"; then
    pass "10g $caller delegates to parse-tasks --count"
  else
    fail "10g $caller delegates to parse-tasks --count"
  fi
done
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 10i — deferred task state (change 038): a fifth marker, `[>]`, that is
# counted but excluded from the incomplete gate. Covers AC7/AC8/AC9.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 10i: deferred task state ---"
c10d="$WORK/changes/c10-deferred"
mkdir -p "$c10d"
{
  printf '# tasks\n\n### Wave 1\n\n'
  printf -- '- [x] `T1` — done\n\n'
  printf -- '- [>] `T2` — deferred with reason\n'
  printf -- '  - Deferred-Reason: waiting on a sibling change\n'
  printf -- '  - Deferred-Blocked-On: 099-sibling\n\n'
  printf -- '- [>] `T3` — deferred without reason\n\n'
  printf -- '- [ ] `T4` — pending\n'
} > "$c10d/tasks.md"

assert_eq "10i --count reports 2 deferred (4th field)" "1 4 0 2" \
  "$("$PARSE_TASKS" --count "$c10d/tasks.md" 2>/dev/null)"

deferred_json="$("$PARSE_TASKS" --status deferred "$c10d/tasks.md" 2>/dev/null)"
assert_eq "10i --status deferred returns exactly T2 and T3" "2" \
  "$(grep -c '"id":' <<<"$deferred_json")"
if grep -q '"deferred_reason":"waiting on a sibling change"' <<<"$deferred_json"; then
  pass "10i T2's Deferred-Reason lands in the JSON"
else
  fail "10i T2's Deferred-Reason missing from JSON (got: $deferred_json)"
fi
if grep -q '"deferred_blocked_on":"099-sibling"' <<<"$deferred_json"; then
  pass "10i T2's Deferred-Blocked-On lands in the JSON"
else
  fail "10i T2's Deferred-Blocked-On missing from JSON"
fi

# T3 has no Deferred-Reason. In JSON/filter mode the warning names the task
# (already exercised by the --status deferred call above); in --count mode it
# is one summary line, matching the existing n_skipped precedent.
per_task_warn="$("$PARSE_TASKS" --status deferred "$c10d/tasks.md" 2>&1 >/dev/null)"
if grep -q '`T3` is deferred with no Deferred-Reason' <<<"$per_task_warn"; then
  pass "10i T3 (no reason) warns by name in JSON mode (= '$per_task_warn')"
else
  fail "10i T3 (no reason) should warn by name in JSON mode (got: '$per_task_warn')"
fi

count_warn="$("$PARSE_TASKS" --count "$c10d/tasks.md" 2>&1 >/dev/null)"
if grep -q 'WARNING: 1 deferred task(s) missing Deferred-Reason' <<<"$count_warn"; then
  pass "10i --count mode gives one summary line (= '$count_warn')"
else
  fail "10i --count mode should give one summary line (got: '$count_warn')"
fi

echo

# ─────────────────────────────────────────────────────────────────────────────
# Case A (Workstream A) — analyze-codebase collect: enumeration inside a git
# worktree now unions tracked files with untracked-but-not-ignored files
# ({ git ls-files; git ls-files --others --exclude-standard; } | sort -u), so a
# legacy source drop extracted into a freshly `git init`'d repo (no commit yet)
# is still enumerated. Ignored files stay out; .specclaw stays out; [path]
# scoping is unchanged; no path is double-counted. jq-free, LOC-by-extension is
# the observable: each fixture file carries a unique extension so its presence
# and exact line count are unambiguous.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case A: analyze-codebase collect — untracked/non-ignored enumeration (Workstream A) ---"
if [[ ! -f "$BF_BIN_DIR/specclaw-bf-analyze-codebase" ]]; then
  fail "specclaw-bf-analyze-codebase missing"
else
  WSA="$WORK/wsA-proj"
  mkdir -p "$WSA/.specclaw" "$WSA/wsa" "$WSA/outside"
  printf 'context:\n  discovery: true\n' > "$WSA/.specclaw/config.yaml"
  printf 'a\nb\nc\n'   > "$WSA/wsa/keep_tracked.wsatr"     # 3 lines, tracked
  printf 'a\nb\n'      > "$WSA/wsa/keep_untracked.wsaun"   # 2 lines, untracked, not ignored
  printf 'a\nb\nc\nd\ne\n' > "$WSA/wsa/keep_ignored.wsaig" # 5 lines, ignored
  printf 'a\nb\nc\nd\n' > "$WSA/outside/out.wsaout"        # 4 lines, for scoping
  printf 'x\n'         > "$WSA/.specclaw/state.wsasp"      # inside .specclaw, must never appear
  printf '*.wsaig\n'   > "$WSA/.gitignore"
  (
    cd "$WSA"
    git init -q .
    git config user.email t@t && git config user.name t
    # Track only keep_tracked + .gitignore; leave keep_untracked/out untracked.
    git add wsa/keep_tracked.wsatr .gitignore && git commit -qm init
  ) >/dev/null 2>&1

  wsa_out="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSA/.specclaw" 2>/dev/null)"

  # A1 — tracked file collected.
  tr_loc="$(grep -o '"wsatr": [0-9]*' <<<"$wsa_out" | grep -o '[0-9]*')"
  assert_eq "A1 tracked file collected (loc_by_extension[wsatr])" "3" "$tr_loc"

  # A2 — untracked, non-ignored file collected (the core fix).
  un_loc="$(grep -o '"wsaun": [0-9]*' <<<"$wsa_out" | grep -o '[0-9]*')"
  assert_eq "A2 untracked non-ignored file collected (loc_by_extension[wsaun])" "2" "$un_loc"

  # A3 — ignored file NOT collected.
  if grep -q '"wsaig"' <<<"$wsa_out"; then
    fail "A3 ignored file excluded (found wsaig)"
  else
    pass "A3 ignored file excluded"
  fi

  # A4 — no duplicate paths: the tracked file's LOC equals its exact wc -l once,
  # not doubled (a union without sort -u, or a file appearing in both lists,
  # would double-count it).
  hand_tr="$(wc -l < "$WSA/wsa/keep_tracked.wsatr" | tr -d ' ')"
  assert_eq "A4 no duplicate paths (wsatr counted once, = wc -l)" "$hand_tr" "$tr_loc"

  # A6 — .specclaw's own state never appears.
  if grep -q '"wsasp"' <<<"$wsa_out"; then
    fail "A6 .specclaw excluded (found wsasp)"
  else
    pass "A6 .specclaw excluded"
  fi

  # A5 — [path] scoping unchanged: scoping to wsa/ excludes outside/, and scoping
  # to outside/ excludes wsa/'s files while still collecting its own.
  wsa_scoped="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSA/.specclaw" wsa 2>/dev/null)"
  if grep -q '"wsaout"' <<<"$wsa_scoped"; then
    fail "A5a wsa/ scoping excludes outside/ (found wsaout)"
  else
    pass "A5a wsa/ scoping excludes outside/"
  fi
  out_scoped="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSA/.specclaw" outside 2>/dev/null)"
  if grep -q '"wsatr"' <<<"$out_scoped" || grep -q '"wsaun"' <<<"$out_scoped"; then
    fail "A5b outside/ scoping excludes wsa/ files (found wsatr/wsaun)"
  elif grep -q '"wsaout": 4' <<<"$out_scoped"; then
    pass "A5b outside/ scoping excludes wsa/ files, keeps its own"
  else
    fail "A5b outside/ scoping should keep its own file (wsaout: 4)"
  fi

  # A7 — a repo with zero commits but untracked files returns those files.
  WSA0="$WORK/wsA-nocommit"
  mkdir -p "$WSA0/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSA0/.specclaw/config.yaml"
  printf 'a\nb\nc\n' > "$WSA0/only.wsazero"   # 3 lines, untracked, never committed
  printf '*.wsaig\n' > "$WSA0/.gitignore"
  printf 'x\ny\n'    > "$WSA0/drop.wsaig"      # ignored, must not appear
  ( cd "$WSA0" && git init -q . ) >/dev/null 2>&1
  wsa0_out="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSA0/.specclaw" 2>/dev/null)"
  z_loc="$(grep -o '"wsazero": [0-9]*' <<<"$wsa0_out" | grep -o '[0-9]*')"
  assert_eq "A7 zero-commit repo returns untracked files (loc_by_extension[wsazero])" "3" "$z_loc"
  if grep -q '"wsaig"' <<<"$wsa0_out"; then
    fail "A7b zero-commit repo still excludes ignored files (found wsaig)"
  else
    pass "A7b zero-commit repo still excludes ignored files"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case B (Workstream B) — analyze-codebase collect: binary-safe LOC. Files whose
# extension is a binary category stay in the inventory (counted per extension in
# the additive binary_artifacts_by_extension / binary_artifact_count keys) but
# are never passed to the wc -l pass, so they cannot inflate loc_by_extension nor
# be read as text. Text/source LOC is unchanged; a binary-only repo succeeds with
# an empty loc_by_extension; and the new keys keep a stable schema ({} / 0) even
# when no binaries exist. jq-free — output format is the deterministic heredoc
# layout, so the two objects are extracted by sed for precise per-object checks.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case B: analyze-codebase collect — binary-safe LOC + inventory (Workstream B) ---"
if [[ ! -f "$BF_BIN_DIR/specclaw-bf-analyze-codebase" ]]; then
  fail "specclaw-bf-analyze-codebase missing"
else
  WSB="$WORK/wsB-proj"
  mkdir -p "$WSB/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSB/.specclaw/config.yaml"
  printf 'a\nb\nc\n' > "$WSB/keep.wsbtx"   # 3 text lines, ordinary source
  printf 'x\n'       > "$WSB/lib.jar"      # binary
  printf 'x\n'       > "$WSB/app.jar"      # binary (2nd .jar -> count 2)
  printf 'x\n'       > "$WSB/tool.fmb"     # binary (legacy Forms)
  printf 'x\n'       > "$WSB/img.png"      # binary (image)
  bout="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSB/.specclaw" 2>/dev/null)"

  # Extract the two objects from the deterministic heredoc layout.
  loc_block="$(printf '%s\n' "$bout" | sed -n '/"loc_by_extension": {/,/^  },/p')"
  bin_block="$(printf '%s\n' "$bout" | sed -n '/"binary_artifacts_by_extension": {/,/^  },/p')"

  # B1 — normal text/source LOC is present and equals a hand-computed wc -l.
  b_tx="$(grep -o '"wsbtx": [0-9]*' <<<"$loc_block" | grep -o '[0-9]*')"
  b_hand="$(wc -l < "$WSB/keep.wsbtx" | tr -d ' ')"
  assert_eq "B1 text/source LOC counted and unchanged (loc_by_extension[wsbtx])" "$b_hand" "$b_tx"

  # B2 — binary extensions never appear in loc_by_extension.
  if grep -qE '"(jar|fmb|png)":' <<<"$loc_block"; then
    fail "B2 binaries excluded from loc_by_extension (found one in loc block)"
  else
    pass "B2 binaries excluded from loc_by_extension"
  fi

  # B3 — binaries remain inventoried, per extension, with correct counts.
  if grep -q '"jar": 2' <<<"$bin_block" \
     && grep -q '"fmb": 1' <<<"$bin_block" \
     && grep -q '"png": 1' <<<"$bin_block"; then
    pass "B3 binaries inventoried per extension (jar:2, fmb:1, png:1)"
  else
    fail "B3 binaries inventoried per extension (bin block: $bin_block)"
  fi

  # B4 — binary_artifact_count is the total number of binary files (4 here).
  b_cnt="$(grep -o '"binary_artifact_count": [0-9]*' <<<"$bout" | grep -o '[0-9]*')"
  assert_eq "B4 binary_artifact_count totals all binary files" "4" "$b_cnt"

  # B5 — stable types: binary_artifacts_by_extension is a JSON object, and
  # binary_artifact_count is a bare (unquoted) number.
  if grep -q '"binary_artifacts_by_extension": {' <<<"$bout" \
     && grep -qE '"binary_artifact_count": [0-9]+,?$' <<<"$bout"; then
    pass "B5 new keys have stable types (object + bare number)"
  else
    fail "B5 new keys have stable types (object + bare number)"
  fi

  # B6 — a binary-only repository succeeds, emits an empty loc_by_extension, and
  # is still well-formed JSON.
  WSB0="$WORK/wsB-bin-only"
  mkdir -p "$WSB0/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSB0/.specclaw/config.yaml"
  printf 'x\n' > "$WSB0/a.jar"; printf 'x\n' > "$WSB0/b.class"; printf 'x\n' > "$WSB0/c.fmb"
  b0="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSB0/.specclaw" 2>/dev/null)"
  b0_exit=$?
  loc0="$(printf '%s\n' "$b0" | sed -n '/"loc_by_extension": {/,/^  },/p')"
  b0_open="$(grep -o '{' <<<"$b0" | wc -l | tr -d ' ')"
  b0_close="$(grep -o '}' <<<"$b0" | wc -l | tr -d ' ')"
  if [[ "$b0_exit" -eq 0 ]] && ! grep -qE '": [0-9]' <<<"$loc0" \
     && [[ "${b0:0:1}" == "{" && "${b0: -1}" == "}" && "$b0_open" == "$b0_close" ]]; then
    pass "B6 binary-only repo: exit 0, empty loc_by_extension, well-formed JSON"
  else
    fail "B6 binary-only repo: exit 0, empty loc_by_extension, well-formed JSON (exit=$b0_exit loc0=$loc0)"
  fi
  b0_cnt="$(grep -o '"binary_artifact_count": [0-9]*' <<<"$b0" | grep -o '[0-9]*')"
  assert_eq "B6b binary-only repo: binary_artifact_count = 3" "3" "$b0_cnt"

  # B7 — stable schema when NO binaries exist: empty object and a 0 count.
  WSB1="$WORK/wsB-text-only"
  mkdir -p "$WSB1/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSB1/.specclaw/config.yaml"
  printf 'a\nb\n' > "$WSB1/only.wsbtx"
  b1="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSB1/.specclaw" 2>/dev/null)"
  bin1_block="$(printf '%s\n' "$b1" | sed -n '/"binary_artifacts_by_extension": {/,/^  },/p')"
  b1_cnt="$(grep -o '"binary_artifact_count": [0-9]*' <<<"$b1" | grep -o '[0-9]*')"
  if grep -q '"binary_artifacts_by_extension": {' <<<"$b1" \
     && ! grep -qE '": [0-9]' <<<"$bin1_block" && [[ "$b1_cnt" == "0" ]]; then
    pass "B7 no-binary repo: stable schema (empty {} object, count 0)"
  else
    fail "B7 no-binary repo: stable schema (empty {} object, count 0) (count=$b1_cnt bin1=$bin1_block)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case C (Workstream C) — analyze-codebase collect: generic legacy database /
# Oracle-era artifact awareness through the SAME classify_extension table. Text
# categories (database_source: pkh/pks/pkb/sql/pls/plb/trg/vw/prc/fnc/typ/tps/
# tpb; loader_control: ctl) contribute to loc_by_extension as normal; the
# Forms/Reports binary subset (fmb/rdf/mmb/pll/olb) obeys Workstream B's LOC
# rules (never read, excluded from LOC, inventoried). The additive
# artifact_categories object rolls every classified file up by category with a
# count and a per-extension breakdown; a category with zero files is omitted, so
# the object is {} when nothing matches. Classification is case-insensitive; the
# original-case extension is preserved in the keys. jq-free (sed block extract).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case C: analyze-codebase collect — legacy DB / Oracle-era categories (Workstream C) ---"
if [[ ! -f "$BF_BIN_DIR/specclaw-bf-analyze-codebase" ]]; then
  fail "specclaw-bf-analyze-codebase missing"
else
  WSC="$WORK/wsC-proj"
  mkdir -p "$WSC/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSC/.specclaw/config.yaml"
  printf 'a\nb\nc\n' > "$WSC/pkg.pkb"     # database_source (text, 3 lines)
  printf 'a\nb\n'    > "$WSC/spec.pks"     # database_source (text, 2 lines)
  printf 'q\n'       > "$WSC/query.SQL"    # database_source, UPPERCASE ext
  printf 'l\n'       > "$WSC/load.ctl"     # loader_control (text)
  printf 'f\n'       > "$WSC/form.fmb"     # forms_reports_binary
  printf 'r\n'       > "$WSC/rep.RDF"      # forms_reports_binary, UPPERCASE
  printf 'j\n'       > "$WSC/lib.jar"      # plain binary
  printf 'p\n'       > "$WSC/app.py"       # ordinary source
  printf 'z\n'       > "$WSC/weird.zzq"    # unknown extension -> ordinary source
  cout="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSC/.specclaw" 2>/dev/null)"

  loc_block="$(printf '%s\n' "$cout" | sed -n '/"loc_by_extension": {/,/^  },/p')"
  cat_block="$(printf '%s\n' "$cout" | sed -n '/"artifact_categories": {/,/^  },/p')"
  bin_block="$(printf '%s\n' "$cout" | sed -n '/"binary_artifacts_by_extension": {/,/^  },/p')"

  # C1 — representative mappings: database_source and loader_control extensions
  # are text and DO appear in loc_by_extension; Forms/Reports and plain binary
  # do NOT.
  if grep -q '"pkb": 3' <<<"$loc_block" && grep -q '"pks": 2' <<<"$loc_block" \
     && grep -q '"ctl": 1' <<<"$loc_block" && grep -q '"SQL": 1' <<<"$loc_block"; then
    pass "C1 database_source + loader_control are text and counted in loc_by_extension"
  else
    fail "C1 database_source/loader_control counted in loc (loc block: $loc_block)"
  fi

  # C2 — Forms/Reports binaries never hit LOC (Workstream B rule preserved).
  if grep -qE '"(fmb|RDF|jar)":' <<<"$loc_block"; then
    fail "C2 Forms/Reports + binary excluded from loc_by_extension (found one in loc)"
  else
    pass "C2 Forms/Reports + binary excluded from loc_by_extension"
  fi

  # C3 — unknown extension is handled safely: counted as ordinary source in LOC,
  # never assigned a category.
  if grep -q '"zzq": 1' <<<"$loc_block" && ! grep -q 'zzq' <<<"$cat_block"; then
    pass "C3 unknown extension counted as source, not categorized"
  else
    fail "C3 unknown extension handling (loc: $loc_block / cat: $cat_block)"
  fi

  # C4 — artifact_categories populated with correct per-category counts.
  if grep -q '"database_source": {"count": 3,' <<<"$cout" \
     && grep -q '"loader_control": {"count": 1,' <<<"$cout" \
     && grep -q '"forms_reports_binary": {"count": 2,' <<<"$cout" \
     && grep -q '"binary": {"count": 1,' <<<"$cout"; then
    pass "C4 artifact_categories counts correct (db:3, loader:1, forms:2, binary:1)"
  else
    fail "C4 artifact_categories counts correct (cat block: $cat_block)"
  fi

  # C5 — case-normalisation: UPPERCASE extensions classify correctly, and the
  # original case is preserved in the by_extension keys.
  if grep -q '"SQL": 1' <<<"$cat_block" && grep -q '"RDF": 1' <<<"$cat_block"; then
    pass "C5 case-insensitive classification, original-case keys preserved (SQL, RDF)"
  else
    fail "C5 case-normalisation (cat block: $cat_block)"
  fi

  # C6 — Workstream B still holds: Forms/Reports binaries are inventoried, and
  # binary_artifact_count includes forms + plain binary (fmb, RDF, jar = 3).
  c_bincnt="$(grep -o '"binary_artifact_count": [0-9]*' <<<"$cout" | grep -o '[0-9]*')"
  if grep -q '"fmb": 1' <<<"$bin_block" && grep -q '"jar": 1' <<<"$bin_block" \
     && [[ "$c_bincnt" == "3" ]]; then
    pass "C6 Forms/Reports inventoried as binary; binary_artifact_count = 3"
  else
    fail "C6 binary inventory (bin block: $bin_block, count=$c_bincnt)"
  fi

  # C7 — empty/no-match repository: artifact_categories is {} (documented:
  # categories with zero files are omitted), and it is still valid JSON.
  WSC0="$WORK/wsC-nomatch"
  mkdir -p "$WSC0/.specclaw"
  printf 'context:\n  discovery: true\n' > "$WSC0/.specclaw/config.yaml"
  printf 'only\nsource\n' > "$WSC0/main.py"
  c0="$(bash "$BF_BIN_DIR/specclaw-bf-analyze-codebase" collect "$WSC0/.specclaw" 2>/dev/null)"
  cat0_block="$(printf '%s\n' "$c0" | sed -n '/"artifact_categories": {/,/^  },/p')"
  c0_open="$(grep -o '{' <<<"$c0" | wc -l | tr -d ' ')"
  c0_close="$(grep -o '}' <<<"$c0" | wc -l | tr -d ' ')"
  if grep -q '"artifact_categories": {' <<<"$c0" \
     && ! grep -qE '"(count|binary|database_source|loader_control|forms_reports_binary)"' <<<"$cat0_block" \
     && [[ "${c0:0:1}" == "{" && "${c0: -1}" == "}" && "$c0_open" == "$c0_close" ]]; then
    pass "C7 no-match repo: artifact_categories is empty {}, well-formed JSON"
  else
    fail "C7 no-match repo: artifact_categories empty (cat0: $cat0_block)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case D (Workstream D) — evidence-discipline rules in the bf-codebase-analyst
# prompt. The prompt has no snapshot/lint test, so these are grep assertions that
# the required rule headings and their governing wording are present, and that the
# report structure (the six fixed sections) is untouched — the rules constrain
# the analyst's reasoning, they do not add report sections.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case D: bf-codebase-analyst evidence-discipline rules (Workstream D) ---"
AGENT_PROMPT="$BF_PLUGIN_ROOT/agents/bf-codebase-analyst.md"
REPORT_TEMPLATE="$BF_PLUGIN_ROOT/templates/codebase-report.md"
if [[ ! -f "$AGENT_PROMPT" ]]; then
  fail "bf-codebase-analyst.md missing at $AGENT_PROMPT"
else
  # D1 — generated analysis output is not independent evidence.
  if grep -qF '## Evidence Source (D1)' "$AGENT_PROMPT" \
     && grep -qF '`.specclaw/` generated outputs' "$AGENT_PROMPT" \
     && grep -qF 'never be treated as independent evidence for another generated conclusion' "$AGENT_PROMPT" \
     && grep -qF 'engagement-specific discovery reports' "$AGENT_PROMPT"; then
    pass "D1 evidence-source rule: generated/.specclaw/discovery output is not independent evidence"
  else
    fail "D1 evidence-source rule missing or incomplete"
  fi

  # D2 — binaries support only existence/path/type/count/location; no behaviour.
  if grep -qF '## Binary Evidence (D2)' "$AGENT_PROMPT" \
     && grep -qF 'existence, path, extension, size, count and location' "$AGENT_PROMPT" \
     && grep -qF 'Never open, decompile, unpack, or infer functionality' "$AGENT_PROMPT" \
     && grep -qF '`.jar`' "$AGENT_PROMPT" && grep -qF '`.fmb`' "$AGENT_PROMPT" \
     && grep -qF '`.class`' "$AGENT_PROMPT" && grep -qF '`.olb`' "$AGENT_PROMPT"; then
    pass "D2 binary-evidence rule: no behaviour/decompile from binaries; extensions enumerated"
  else
    fail "D2 binary-evidence rule missing or incomplete"
  fi

  # D3 — insufficient evidence is stated as a limitation, not guessed.
  if grep -qF '## Insufficient Evidence' "$AGENT_PROMPT" \
     && grep -qF 'state the limitation explicitly' "$AGENT_PROMPT" \
     && grep -qiF 'rather than guessing' "$AGENT_PROMPT"; then
    pass "D3 insufficient-evidence rule: state limitation rather than guess"
  else
    fail "D3 insufficient-evidence rule missing or incomplete"
  fi

  # D4 — sensitive-output guardrail.
  if grep -qF '## Sensitive Values' "$AGENT_PROMPT" \
     && grep -qF 'credentials, connection strings, private keys, tokens' "$AGENT_PROMPT" \
     && grep -qiF 'hostnames' "$AGENT_PROMPT" && grep -qiF 'redact' "$AGENT_PROMPT"; then
    pass "D4 sensitive-values guardrail: credentials/keys/tokens/hostnames redacted, not reproduced"
  else
    fail "D4 sensitive-values guardrail missing or incomplete"
  fi

  # D5 — report structure unchanged: the six fixed report sections still appear
  # in the analyst prompt's Output contract and in the template, and the template
  # still exposes exactly its six placeholders (no new top-level section added).
  six_ok=1
  for h in "## Tech Stack" "## Dependencies" "## Structure/Architecture" \
           "## Domain" "## Risks/Tech-Debt" "## Suggested First Changes"; do
    grep -qF "$h" "$AGENT_PROMPT" || six_ok=0
    grep -qF "$h" "$REPORT_TEMPLATE" || six_ok=0
  done
  # The template carries 9 placeholders: title, path, date, plus one body per
  # section (tech_stack, dependencies, architecture, domain, risks,
  # suggested_first_changes). Workstream D touches none of them.
  tmpl_placeholders="$(grep -cE '\{\{[a-z_]+\}\}' "$REPORT_TEMPLATE")"
  if [[ "$six_ok" -eq 1 && "$tmpl_placeholders" -eq 9 ]]; then
    pass "D5 report structure compatible: six fixed sections intact, template placeholders unchanged (=9)"
  else
    fail "D5 report structure changed (six_ok=$six_ok placeholders=$tmpl_placeholders)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case E (Workstream E) — the `## Suggested First Changes` section is hardened to
# evidence-grounded investigation entry points only. The heading is unchanged
# (downstream-compatible); the analyst prompt's Suggested First Changes Discipline
# prohibits modernization/technology/effort advice, permits investigation targets,
# and forbids unsupported churn/coverage/criticality claims. grep assertions.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case E: Suggested First Changes hardening (Workstream E) ---"
AGENT_PROMPT="$BF_PLUGIN_ROOT/agents/bf-codebase-analyst.md"
REPORT_TEMPLATE="$BF_PLUGIN_ROOT/templates/codebase-report.md"
if [[ ! -f "$AGENT_PROMPT" || ! -f "$REPORT_TEMPLATE" ]]; then
  fail "analyst prompt or report template missing"
else
  # E1 — heading is unchanged, exactly, in BOTH the analyst Output contract and
  # the template (downstream parsers depend on it).
  if grep -qF '## Suggested First Changes' "$AGENT_PROMPT" \
     && grep -qF '## Suggested First Changes' "$REPORT_TEMPLATE"; then
    pass "E1 heading remains exactly '## Suggested First Changes' in prompt and template"
  else
    fail "E1 heading '## Suggested First Changes' missing from prompt or template"
  fi

  # E2 — modernization / technology / effort recommendations are prohibited.
  if grep -qF 'Do not propose target technologies, rewrite order, sequencing or effort in `codebase-report.md`' "$AGENT_PROMPT" \
     && grep -qF 'replacement technologies, frameworks, databases, cloud platforms, rewrites, migrations, or microservices' "$AGENT_PROMPT" \
     && grep -qiF 'estimate effort, duration, team size, or migration complexity' "$AGENT_PROMPT" \
     && grep -qiF 'not** modernization or implementation advice' "$AGENT_PROMPT"; then
    pass "E2 modernization/technology/effort recommendations prohibited"
  else
    fail "E2 modernization/technology/effort prohibition missing or incomplete"
  fi

  # E3 — evidence-grounded investigation targets ARE permitted, each with a WHY.
  if grep -qF 'investigation / characterization entry points' "$AGENT_PROMPT" \
     && grep -qiF 'high-coupling or central modules' "$AGENT_PROMPT" \
     && grep -qiF 'untested business-critical areas that need behaviour capture' "$AGENT_PROMPT" \
     && grep -qiF 'cross-system or database boundaries that need tracing' "$AGENT_PROMPT" \
     && grep -qiF 'binary-only areas that need readable exports' "$AGENT_PROMPT" \
     && grep -qiF 'insufficient evidence that need targeted inspection' "$AGENT_PROMPT" \
     && grep -qiF 'strong dependency evidence that should be investigated before' "$AGENT_PROMPT" \
     && grep -qiF 'justify WHY' "$AGENT_PROMPT"; then
    pass "E3 evidence-grounded investigation targets permitted, each requiring a WHY"
  else
    fail "E3 permitted investigation-target list missing or incomplete"
  fi

  # E4 — unsupported churn/coverage/criticality/binary-behaviour/file-type claims
  # are explicitly disallowed unless evidenced.
  if grep -qiF 'no churn claims unless actual churn evidence exists' "$AGENT_PROMPT" \
     && grep -qiF 'no test-coverage percentages unless measured' "$AGENT_PROMPT" \
     && grep -qiF 'no business-criticality unless evidenced' "$AGENT_PROMPT" \
     && grep -qiF 'no runtime behaviour inferred from binaries' "$AGENT_PROMPT" \
     && grep -qiF 'no architecture recommendation inferred from a file type alone' "$AGENT_PROMPT"; then
    pass "E4 unsupported churn/coverage/criticality/binary/file-type claims disallowed"
  else
    fail "E4 unsupported-claims guardrail missing or incomplete"
  fi

  # E5 — no new top-level report section: the analyst prompt and template each
  # carry exactly the six fixed report sections, no more.
  agent_sections="$(grep -cE '^## (Tech Stack|Dependencies|Structure/Architecture|Domain|Risks/Tech-Debt|Suggested First Changes)$' "$AGENT_PROMPT")"
  tmpl_sections="$(grep -cE '^## ' "$REPORT_TEMPLATE")"
  if [[ "$agent_sections" -eq 6 && "$tmpl_sections" -eq 6 ]]; then
    pass "E5 no new top-level report section (exactly six sections in prompt and template)"
  else
    fail "E5 report-section count changed (agent=$agent_sections template=$tmpl_sections)"
  fi

  # E6 — the template's Suggested First Changes body carries no baked-in
  # recommendation phrasing (it is a placeholder the analyst fills under the
  # discipline; guard against future drift).
  sfc_body="$(sed -n '/## Suggested First Changes/,$p' "$REPORT_TEMPLATE")"
  if grep -qiE 'should migrate|recommend|replace with|migrate to' <<<"$sfc_body"; then
    fail "E6 template Suggested First Changes body contains recommendation phrasing"
  else
    pass "E6 template Suggested First Changes body has no baked-in recommendation phrasing"
  fi
fi
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
