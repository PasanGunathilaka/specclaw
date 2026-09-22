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
# Plus FR3 (architecture-command, Case 10): analyze-codebase collect's
#   dependency_graph extraction — Delphi `uses` resolution (and RTL-name
#   non-resolution), Node/JS relative `require`/`import` resolution, .NET
#   `<ProjectReference>` resolution kept distinct from `<PackageReference>`
#   manifest deps, silence for uncovered ecosystems (go.mod), and
#   path-scoping exclusion (AC1-AC7).
# Plus FR16 (domain-command, Case 11): specclaw-bf-domain-collect collect's
#   merged output (delegated fields + new fields), .dfm form parsing
#   (well-formed + malformed), handler-to-implementation resolution,
#   Pascal type/const/validation-candidate extraction, main_form_hint,
#   .xaml element capture, .cshtml detection-only marking, zero-eligible-
#   file scoping, and subdirectory scoping exclusion (AC1-AC13).
# Plus rebuild-plan-bridge (Case 12): specclaw-bf-rebuild-collect collect's
#   existence-check + line-count JSON emission for the five
#   .specclaw/analysis/*.md documents (module-map.md joined the original four
#   as a prerequisite when the MOD-### hierarchy landed), the module roster it
#   parses out of module-map.md, and its missing-document error path naming
#   exactly which doc(s) are missing plus the producing command
#   (AC1-AC2).
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
# Case 9 — analyze-codebase collect: manifest detection (Node/Go/Delphi), the
# single-line `engines.node` version_signal regression, LOC-by-extension,
# test-location detection, path-scoping exclusion, and discovered_docs parity
# with a standalone specclaw-discover-context run (all jq-free; the plain
# fixture copy exercises the `find` fallback, the git-initialized copy
# exercises the `git ls-files` path).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 9: analyze-codebase collect — manifests, LOC, test-locations, docs, scoping ---"
ANALYZE_BIN="$BIN_DIR/specclaw-bf-analyze-codebase"
DISCOVER="$BIN_DIR/specclaw-discover-context"
if [[ ! -f "$ANALYZE_BIN" ]]; then
  fail "specclaw-bf-analyze-codebase missing"
else
  # Plain copy of the fixture tree, no .git anywhere above it -> exercises the
  # `find` fallback enumeration path.
  AFIX="$WORK/analyze-proj"
  mkdir -p "$AFIX/.specclaw"
  cp -R "$FIXTURES_DIR/analyze/." "$AFIX/"
  printf 'context:\n  discovery: true\n' > "$AFIX/.specclaw/config.yaml"

  out="$(bash "$ANALYZE_BIN" collect "$AFIX/.specclaw" 2>/dev/null)"

  # 9a (AC1) — output is a well-formed JSON object: balanced braces, starts
  # with `{`/ends with `}`, and every documented top-level field is present.
  # (jq is not installed in this environment, so this is the grep/awk
  # fallback equivalent of `jq -e '.'`.)
  open_braces="$(grep -o '{' <<<"$out" | wc -l | tr -d ' ')"
  close_braces="$(grep -o '}' <<<"$out" | wc -l | tr -d ' ')"
  if [[ "${out:0:1}" == "{" && "${out: -1}" == "}" && "$open_braces" == "$close_braces" ]] \
     && grep -q '"path":' <<<"$out" && grep -q '"project_root":' <<<"$out" \
     && grep -q '"top_level_dirs":' <<<"$out" && grep -q '"manifests":' <<<"$out" \
     && grep -q '"loc_by_extension":' <<<"$out" && grep -q '"test_locations":' <<<"$out" \
     && grep -q '"discovered_docs":' <<<"$out"; then
    pass "9a collect output is a well-formed JSON object with all documented fields"
  else
    fail "9a collect output is a well-formed JSON object with all documented fields"
  fi

  # 9b (AC3) — package.json manifest: type=node, both real dependencies, and
  # the single-line `"engines": { "node": ">=18.0.0" },` version_signal
  # correctly captured (this exact single-line style was a real bug found and
  # fixed in the script — regression lock-in).
  node_line="$(grep -o '{"path": "package.json".*}' <<<"$out")"
  if grep -q '"type": "node"' <<<"$node_line" \
     && grep -q '"dependencies": \["express", "lodash"\]' <<<"$node_line" \
     && grep -q '"version_signal": ">=18.0.0"' <<<"$node_line"; then
    pass "9b package.json manifest: type=node, deps, single-line engines.node version_signal"
  else
    fail "9b package.json manifest: type=node, deps, single-line engines.node version_signal (got: $node_line)"
  fi

  # 9c (AC3) — go.mod manifest: type=go, both modules from the require( )
  # block, and the `go 1.21` directive as version_signal.
  go_line="$(grep -o '{"path": "go.mod".*}' <<<"$out")"
  if grep -q '"type": "go"' <<<"$go_line" \
     && grep -q '"dependencies": \["github.com/pkg/errors", "github.com/stretchr/testify"\]' <<<"$go_line" \
     && grep -q '"version_signal": "1.21"' <<<"$go_line"; then
    pass "9c go.mod manifest: type=go, deps from require() block, version_signal"
  else
    fail "9c go.mod manifest: type=go, deps from require() block, version_signal (got: $go_line)"
  fi

  # 9d (AC3, NFR1) — the Delphi .dproj manifest: type=delphi and dependencies
  # extracted from <DCCReference Include="..."> entries. This is the
  # language-agnostic differentiator the feature exists for.
  dproj_line="$(grep -o '{"path": "AnalyzeFixture.dproj".*}' <<<"$out")"
  if grep -q '"type": "delphi"' <<<"$dproj_line" \
     && grep -q '"dependencies": \["AnalyzeFixture.pas", "Unit1.pas"\]' <<<"$dproj_line"; then
    pass "9d .dproj manifest: type=delphi, deps from DCCReference entries"
  else
    fail "9d .dproj manifest: type=delphi, deps from DCCReference entries (got: $dproj_line)"
  fi

  # 9e (AC4) — loc_by_extension matches a hand-computed `wc -l` count for the
  # fixture's known 5-line file (sample.qux, a distinctive extension so the
  # assertion is unambiguous).
  qux_loc="$(grep -o '"qux": [0-9]*' <<<"$out" | grep -o '[0-9]*')"
  hand_count="$(wc -l < "$FIXTURES_DIR/analyze/sample.qux" | tr -d ' ')"
  assert_eq "9e loc_by_extension[qux] matches wc -l" "$hand_count" "$qux_loc"

  # 9f (AC5) — test_locations includes the fixture's tests/ directory.
  if grep -q '"test_locations": \["tests"' <<<"$out"; then
    pass "9f test_locations includes tests/"
  else
    fail "9f test_locations includes tests/ (got: $(grep '"test_locations":' <<<"$out"))"
  fi

  # 9g (AC6) — discovered_docs is identical to what `specclaw-discover-context
  # <dir> emit` produces standalone against the same directory (same script
  # invoked, no reimplementation). Compare by applying the same json_escape
  # transform to the standalone output and diffing against the embedded
  # field, rather than reverse-unescaping — escaping is the one-way step both
  # sides actually perform.
  direct_docs="$(bash "$DISCOVER" "$AFIX/.specclaw" emit 2>/dev/null)"
  json_escape_9g() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
  }
  expected_escaped="$(json_escape_9g "$direct_docs")"
  embedded_escaped="$(grep -o '"discovered_docs": ".*"$' <<<"$out" | sed -E 's/^"discovered_docs": "(.*)"$/\1/')"
  assert_eq "9g discovered_docs identical to standalone discover-context emit" "$expected_escaped" "$embedded_escaped"

  # 9h (AC2) — scoping to sub/ excludes every root-level manifest, and (AC5
  # edge case) test_locations is empty since sub/ has no test-like directory.
  sub_out="$(bash "$ANALYZE_BIN" collect "$AFIX/.specclaw" sub 2>/dev/null)"
  if grep -q '"path": "package.json"' <<<"$sub_out" \
     || grep -q '"path": "go.mod"' <<<"$sub_out" \
     || grep -q '"path": "AnalyzeFixture.dproj"' <<<"$sub_out"; then
    fail "9h sub/ scoping excludes root-level manifests (found one)"
  else
    pass "9h sub/ scoping excludes root-level manifests"
  fi
  sub_test_loc_line="$(grep '"test_locations":' <<<"$sub_out")"
  if grep -q '"tests"' <<<"$sub_test_loc_line"; then
    fail "9i sub/ scoping: test_locations empty (no test-like dir under sub/) (got: $sub_test_loc_line)"
  else
    pass "9i sub/ scoping: test_locations empty (no test-like dir under sub/)"
  fi

  # 9j (AC2) — scoping to tests/ excludes sub/'s file, every root manifest,
  # and the root-level sample.qux LOC entry, while still reporting its own
  # file and test_locations entry.
  tests_out="$(bash "$ANALYZE_BIN" collect "$AFIX/.specclaw" tests 2>/dev/null)"
  if grep -q '"path": "package.json"' <<<"$tests_out" \
     || grep -q 'sub/extra.txt' <<<"$tests_out" \
     || grep -q '"qux"' <<<"$tests_out"; then
    fail "9j tests/ scoping excludes files outside it (root manifests, sub/, sample.qux)"
  else
    pass "9j tests/ scoping excludes files outside it (root manifests, sub/, sample.qux)"
  fi
  if grep -q 'tests/sample.txt' <<<"$tests_out" && grep -q '"test_locations": \["tests"' <<<"$tests_out"; then
    pass "9k tests/ scoping still reports its own file and test_locations entry"
  else
    fail "9k tests/ scoping still reports its own file and test_locations entry"
  fi

  # 9l — same fixture, git-initialized copy: exercises the `git ls-files`
  # enumeration path (the plain, non-git copy above exercises the `find`
  # fallback). Confirms parity on the regression-sensitive facts: node
  # manifest + version_signal, and LOC.
  AFIX_GIT="$WORK/analyze-proj-git"
  mkdir -p "$AFIX_GIT/.specclaw"
  cp -R "$FIXTURES_DIR/analyze/." "$AFIX_GIT/"
  printf 'context:\n  discovery: true\n' > "$AFIX_GIT/.specclaw/config.yaml"
  (
    cd "$AFIX_GIT"
    git init -q .
    git config user.email t@t && git config user.name t
    git add -A && git commit -qm init
  ) >/dev/null 2>&1
  git_out="$(bash "$ANALYZE_BIN" collect "$AFIX_GIT/.specclaw" 2>/dev/null)"
  node_line_git="$(grep -o '{"path": "package.json".*}' <<<"$git_out")"
  qux_loc_git="$(grep -o '"qux": [0-9]*' <<<"$git_out" | grep -o '[0-9]*')"
  if grep -q '"type": "node"' <<<"$node_line_git" \
     && grep -q '"version_signal": ">=18.0.0"' <<<"$node_line_git" \
     && [[ "$qux_loc_git" == "$hand_count" ]]; then
    pass "9l git ls-files enumeration path matches find-fallback facts (node manifest + LOC)"
  else
    fail "9l git ls-files enumeration path matches find-fallback facts (got node_line=$node_line_git qux_loc=$qux_loc_git)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 10 — analyze-codebase collect: dependency_graph extraction (FR3/FR4,
# AC1-AC7) — Delphi `uses` resolution (incl. RTL-name non-resolution),
# Node/JS relative `require` resolution, .NET `<ProjectReference>` resolution
# kept distinct from `<PackageReference>` manifest deps, silence for
# uncovered ecosystems (go.mod with no .go source), and path-scoping
# exclusion (same discipline as Case 9's manifest/LOC scoping).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 10: analyze-codebase collect — dependency_graph ---"
if [[ ! -f "$ANALYZE_BIN" ]]; then
  fail "specclaw-bf-analyze-codebase missing"
else
  DFIX="$WORK/analyze-depgraph-proj"
  mkdir -p "$DFIX/.specclaw"
  cp -R "$FIXTURES_DIR/analyze/." "$DFIX/"
  printf 'context:\n  discovery: true\n' > "$DFIX/.specclaw/config.yaml"

  dout="$(bash "$ANALYZE_BIN" collect "$DFIX/.specclaw" 2>/dev/null)"
  edge_lines="$(grep -E '"from": "[^"]*"' <<<"$dout")"

  # 10a (AC1) — dependency_graph field present alongside every pre-existing
  # field, on the extended fixture (additive, no regression).
  if grep -q '"path":' <<<"$dout" && grep -q '"project_root":' <<<"$dout" \
     && grep -q '"top_level_dirs":' <<<"$dout" && grep -q '"manifests":' <<<"$dout" \
     && grep -q '"loc_by_extension":' <<<"$dout" && grep -q '"test_locations":' <<<"$dout" \
     && grep -q '"dependency_graph":' <<<"$dout" && grep -q '"discovered_docs":' <<<"$dout"; then
    pass "10a dependency_graph present alongside every pre-existing field"
  else
    fail "10a dependency_graph present alongside every pre-existing field"
  fi

  # 10b (AC2) — UnitA.pas's `uses` clause reference to UnitB.pas (in scope)
  # resolves to a "uses" edge.
  if grep -qF '{"from": "UnitA.pas", "to": "UnitB.pas", "kind": "uses"}' <<<"$dout"; then
    pass "10b UnitA.pas -> UnitB.pas uses edge"
  else
    fail "10b UnitA.pas -> UnitB.pas uses edge (edges: $edge_lines)"
  fi

  # 10c (AC3) — the RTL-style `SysUtils` reference in the same `uses` clause
  # has no corresponding file in the fixture, so it produces no edge.
  if grep -q "SysUtils" <<<"$edge_lines"; then
    fail "10c unresolved SysUtils reference produces no edge (found SysUtils in an edge)"
  else
    pass "10c unresolved SysUtils reference produces no edge"
  fi

  # 10d (AC4) — a.js's relative `require('./b')` resolves to b.js with kind
  # "import".
  if grep -qF '{"from": "a.js", "to": "b.js", "kind": "import"}' <<<"$dout"; then
    pass "10d a.js -> b.js import edge"
  else
    fail "10d a.js -> b.js import edge (edges: $edge_lines)"
  fi

  # 10e (AC5) — App.csproj's <ProjectReference Include="Other/Other.csproj">
  # produces a project_reference edge...
  if grep -qF '{"from": "App.csproj", "to": "Other/Other.csproj", "kind": "project_reference"}' <<<"$dout"; then
    pass "10e App.csproj -> Other/Other.csproj project_reference edge"
  else
    fail "10e App.csproj -> Other/Other.csproj project_reference edge (edges: $edge_lines)"
  fi

  # ...and that same path does NOT leak into App.csproj's own manifest
  # `dependencies` list, which must contain only the <PackageReference>
  # (Newtonsoft.Json) — <ProjectReference> stays a distinct field.
  app_manifest_line="$(grep -o '{"path": "App.csproj".*}' <<<"$dout")"
  app_deps="$(grep -o '"dependencies": \[[^]]*\]' <<<"$app_manifest_line")"
  assert_eq "10f App.csproj manifest dependencies is [Newtonsoft.Json] only (no ProjectReference leak)" \
    '"dependencies": ["Newtonsoft.Json"]' "$app_deps"

  # 10g (AC6) — the go.mod fixture (no .go source file) contributes zero
  # dependency_graph entries: no edge mentions go.mod or any .go path.
  if grep -qE 'go\.mod|\.go"' <<<"$edge_lines"; then
    fail "10g go.mod contributes zero dependency_graph entries (found a go reference in an edge)"
  else
    pass "10g go.mod contributes zero dependency_graph entries"
  fi

  # 10h (AC7) — scoping: collect .specclaw Other isolates a subdir containing
  # only one of the new files (Other/Other.csproj); the App.csproj ->
  # Other/Other.csproj edge must be excluded since its `from` endpoint
  # (App.csproj) falls outside the scoped subdir — same discipline as Case
  # 9's manifest/LOC scoping (9h-9j).
  scoped_out="$(bash "$ANALYZE_BIN" collect "$DFIX/.specclaw" Other 2>/dev/null)"
  if grep -q '"dependency_graph":' <<<"$scoped_out" \
     && ! grep -qF '{"from": "App.csproj", "to": "Other/Other.csproj", "kind": "project_reference"}' <<<"$scoped_out"; then
    pass "10h Other/ scoping excludes the project_reference edge whose 'from' endpoint is outside scope"
  else
    fail "10h Other/ scoping excludes the project_reference edge whose 'from' endpoint is outside scope (got: $(grep -E '\"from\":' <<<"$scoped_out"))"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 11 — specclaw-bf-domain-collect collect: merged output (delegated fields
# plus new domain fields), .dfm form parsing (well-formed + malformed),
# handler-to-implementation resolution, Pascal type/const/validation-
# candidate extraction, main_form_hint, .xaml element capture, .cshtml
# detection-only marking, zero-eligible-file scoping, and subdirectory
# scoping exclusion (FR16, AC1-AC13). Fixtures live under
# tests/fixtures/analyze/domain/ — extending the existing analyze/ fixture
# tree, not a parallel one (domain/MainApp.dpr, domain/ui/*).
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 11: specclaw-bf-domain-collect collect — forms, handlers, types, consts, validation candidates, main_form_hint, xaml, cshtml, scoping ---"
DOMAIN_BIN="$BIN_DIR/specclaw-bf-domain-collect"
if [[ ! -f "$DOMAIN_BIN" ]]; then
  fail "specclaw-bf-domain-collect missing"
else
  DOMFIX="$WORK/domain-proj"
  mkdir -p "$DOMFIX/.specclaw"
  cp -R "$FIXTURES_DIR/analyze/." "$DOMFIX/"
  printf 'context:\n  discovery: true\n' > "$DOMFIX/.specclaw/config.yaml"

  out="$(bash "$DOMAIN_BIN" collect "$DOMFIX/.specclaw" 2>/dev/null)"

  # 11a (AC1) — merged output includes every delegated field
  # (specclaw-bf-analyze-codebase's own fields) plus every new domain field,
  # flat (not nested under a sub-key).
  missing=""
  for field in '"path":' '"project_root":' '"top_level_dirs":' '"manifests":' \
               '"loc_by_extension":' '"test_locations":' '"dependency_graph":' \
               '"discovered_docs":' '"forms":' '"xaml_forms":' '"other_ui_files":' \
               '"handler_implementations":' '"main_form_hint":' '"type_declarations":' \
               '"const_declarations":' '"validation_routine_candidates":'; do
    grep -q "$field" <<<"$out" || missing="$missing $field"
  done
  if [[ -z "$missing" ]]; then
    pass "11a merged output has every delegated field plus every new domain field"
  else
    fail "11a merged output has every delegated field plus every new domain field (missing:$missing)"
  fi

  # 11b (AC2) — the well-formed MainForm.dfm: correct root_name/root_class/
  # root_caption, header line up through the start of its controls[] array.
  if grep -qF '{"file": "domain/ui/MainForm.dfm", "parseable": true, "root_name": "MainForm", "root_class": "TMainForm", "root_caption": "Main Form", "controls": [' <<<"$out"; then
    pass "11b MainForm.dfm: parseable, correct root_name/root_class/root_caption"
  else
    fail "11b MainForm.dfm: parseable, correct root_name/root_class/root_caption"
  fi

  # 11c (AC2) — the top-level TButton control carries its Caption.
  if grep -qF '{"name": "OKButton", "class": "TButton", "caption": "OK"}' <<<"$out"; then
    pass "11c MainForm.dfm: top-level control caption (OKButton = 'OK')"
  else
    fail "11c MainForm.dfm: top-level control caption (OKButton = 'OK')"
  fi

  # 11d (AC2) — THE critical assertion: the deepest menu item (root form ->
  # TMainMenu -> FileMenu -> RecentFilesItem, 4 objects / 3 levels below the
  # root) still has its OnClick handler captured in handlers[], proving
  # handler capture is not depth-capped the way controls[] is.
  if grep -qF '{"object_name": "RecentFilesItem", "object_class": "TMenuItem", "event": "OnClick", "handler_name": "RecentFileClick"}' <<<"$out"; then
    pass "11d MainForm.dfm: deep (3+ levels) menu item's OnClick handler captured in handlers[]"
  else
    fail "11d MainForm.dfm: deep (3+ levels) menu item's OnClick handler captured in handlers[]"
  fi

  # 11e (AC3) — the malformed Broken.dfm is marked parseable:false with a
  # reason string — no crash, no silent omission.
  if grep -qF '{"file": "domain/ui/Broken.dfm", "parseable": false, "reason": "binary DFM format (or unrecognized text structure)"}' <<<"$out"; then
    pass "11e Broken.dfm: parseable:false with reason, no crash"
  else
    fail "11e Broken.dfm: parseable:false with reason, no crash"
  fi

  # 11f (AC4) — OKButtonClick has a matching `procedure TMainForm.OKButtonClick`
  # implementation in MainForm.pas; handler_implementations[] resolves it to
  # the correct file and the correct line (computed dynamically from the
  # fixture file itself, not hardcoded).
  expected_line="$(grep -n '^procedure TMainForm\.OKButtonClick' "$FIXTURES_DIR/analyze/domain/ui/MainForm.pas" | head -1 | cut -d: -f1)"
  if [[ -n "$expected_line" ]] && grep -qF "{\"handler_name\": \"OKButtonClick\", \"file\": \"domain/ui/MainForm.pas\", \"line\": ${expected_line}}" <<<"$out"; then
    pass "11f handler_implementations: OKButtonClick resolves to MainForm.pas:$expected_line"
  else
    fail "11f handler_implementations: OKButtonClick resolves to MainForm.pas:$expected_line (got: $(grep -o '{"handler_name": "OKButtonClick".*}' <<<"$out"))"
  fi

  # 11g (AC4) — RecentFileClick has NO implementation anywhere in the
  # fixture; handler_implementations[] must NOT contain an entry for it
  # (omitted, not guessed). Note: "handler_name": "RecentFileClick" DOES
  # legitimately appear inside forms[].handlers[] (confirmed by 11d) — this
  # checks the distinct handler_implementations[] entry shape
  # (`{"handler_name": ..., "file": ...}`, no "object_name"/"object_class"/
  # "event" keys), not a bare substring search across the whole output.
  if grep -q '{"handler_name": "RecentFileClick", "file":' <<<"$out"; then
    fail "11g handler_implementations: RecentFileClick (no impl in fixture) correctly absent (found an entry)"
  else
    pass "11g handler_implementations: RecentFileClick (no impl in fixture) correctly absent"
  fi

  # 11h (AC5) — the TWaterQuality enum: full, correctly-ordered values[].
  if grep -qF '{"name": "TWaterQuality", "kind": "enum", "values": ["wqNone", "wqChem", "wqTrace", "wqAge"], "file": "domain/ui/Types.pas"' <<<"$out"; then
    pass "11h type_declarations: TWaterQuality enum with full, ordered values[]"
  else
    fail "11h type_declarations: TWaterQuality enum with full, ordered values[]"
  fi

  # 11i (AC6) — the TReading record: name/kind only, no fabricated field
  # list (the JSON shape itself has no field-list key for record/class).
  if grep -qF '{"name": "TReading", "kind": "record", "file": "domain/ui/Types.pas"' <<<"$out"; then
    pass "11i type_declarations: TReading record, name/kind only (no fabricated fields)"
  else
    fail "11i type_declarations: TReading record, name/kind only (no fabricated fields)"
  fi

  # 11j (AC7) — the const block: correct name/value pairs for both simple
  # scalar values (a number and a quoted string).
  if grep -qF '{"name": "MaxReadings", "value": "100", "file": "domain/ui/Types.pas"' <<<"$out" \
     && grep -qF "{\"name\": \"DefaultUnit\", \"value\": \"'ppm'\", \"file\": \"domain/ui/Types.pas\"" <<<"$out"; then
    pass "11j const_declarations: MaxReadings=100 and DefaultUnit='ppm' correctly captured"
  else
    fail "11j const_declarations: MaxReadings=100 and DefaultUnit='ppm' correctly captured"
  fi

  # 11k (AC8) — the ValidateReading candidate's captured body includes its
  # guard clause text, correctly bounded: it must NOT bleed into the
  # following ComputeAverage routine's code.
  validate_entry="$(grep -o '{"name": "ValidateReading".*}' <<<"$out")"
  if grep -qF 'if Value < 0 then' <<<"$validate_entry" && ! grep -q 'ComputeAverage' <<<"$validate_entry"; then
    pass "11k validation_routine_candidates: ValidateReading body includes guard clause, bounded (no bleed into ComputeAverage)"
  else
    fail "11k validation_routine_candidates: ValidateReading body includes guard clause, bounded (got: $validate_entry)"
  fi

  # 11l (AC8 edge case) — CanRedo is NOT actually a validation routine, but
  # still surfaced as a candidate (the name heuristic alone decides
  # inclusion; the agent decides relevance later, not this bash layer).
  if grep -q '"name": "CanRedo"' <<<"$out"; then
    pass "11l validation_routine_candidates: CanRedo (false positive) still surfaced as a candidate"
  else
    fail "11l validation_routine_candidates: CanRedo (false positive) still surfaced as a candidate"
  fi

  # 11m (AC9) — MainApp.dpr's first Application.CreateForm call produces the
  # correct main_form_hint when it is in scope.
  if grep -qF '"main_form_hint": "TMainForm"' <<<"$out"; then
    pass "11m main_form_hint: TMainForm detected from MainApp.dpr's Application.CreateForm call"
  else
    fail "11m main_form_hint: TMainForm detected from MainApp.dpr's Application.CreateForm call"
  fi

  # 11n (AC9) — scoping to domain/ui (excludes domain/MainApp.dpr, the only
  # .dpr in the fixture) leaves main_form_hint null while forms[] still
  # contains every detected form (both MainForm and Broken).
  ui_out="$(bash "$DOMAIN_BIN" collect "$DOMFIX/.specclaw" domain/ui 2>/dev/null)"
  if grep -qF '"main_form_hint": null' <<<"$ui_out" \
     && grep -qF '{"file": "domain/ui/MainForm.dfm", "parseable": true, "root_name": "MainForm", "root_class": "TMainForm"' <<<"$ui_out" \
     && grep -qF '{"file": "domain/ui/Broken.dfm", "parseable": false' <<<"$ui_out"; then
    pass "11n main_form_hint absent when .dpr excluded from scope; forms[] still fully populated"
  else
    fail "11n main_form_hint absent when .dpr excluded from scope; forms[] still fully populated (got main_form_hint: $(grep -o '"main_form_hint": [^,]*' <<<"$ui_out"))"
  fi

  # 11o (AC10) — the .xaml file's direct-child-of-root element (one level of
  # nesting, per FR5) with x:Name and a Content attribute is captured.
  if grep -qF '{"name": "Button", "x_name": "SubmitButton", "content": "Submit"}' <<<"$out"; then
    pass "11o xaml_forms: direct-child element x:Name + Content captured at the specified depth"
  else
    fail "11o xaml_forms: direct-child element x:Name + Content captured at the specified depth"
  fi

  # 11p (AC11) — the .cshtml file is marked detection-only, never silently
  # absent, never deep-parsed.
  if grep -qF '{"file": "domain/ui/Index.cshtml", "parseable": false, "reason": "not deep-parsed in v1 — detection only"}' <<<"$out"; then
    pass "11p other_ui_files: Index.cshtml marked detection-only"
  else
    fail "11p other_ui_files: Index.cshtml marked detection-only"
  fi

  # 11q (AC12, NFR1) — a zero-eligible-file scope (the pre-existing sub/
  # directory, which has no .dfm/.xaml/.pas/.cs/.dpr content) yields empty
  # arrays for every new field, not a crash. Whitespace-stripped comparison
  # sidesteps incidental pretty-printing differences across the nested
  # array fields.
  sub_out="$(bash "$DOMAIN_BIN" collect "$DOMFIX/.specclaw" sub 2>/dev/null)"
  sub_compact="$(tr -d '[:space:]' <<<"$sub_out")"
  if grep -qF '"forms":[]' <<<"$sub_compact" && grep -qF '"xaml_forms":[]' <<<"$sub_compact" \
     && grep -qF '"other_ui_files":[]' <<<"$sub_compact" && grep -qF '"handler_implementations":[]' <<<"$sub_compact" \
     && grep -qF '"type_declarations":[]' <<<"$sub_compact" && grep -qF '"const_declarations":[]' <<<"$sub_compact" \
     && grep -qF '"validation_routine_candidates":[]' <<<"$sub_compact" && grep -qF '"main_form_hint":null' <<<"$sub_compact"; then
    pass "11q sub/ scoping (zero eligible files): every new field is an empty array/null, no crash"
  else
    fail "11q sub/ scoping (zero eligible files): every new field is an empty array/null, no crash (got: $sub_compact)"
  fi

  # 11r (AC13) — subdirectory scoping excludes out-of-scope entities from
  # every new field, same discipline manifests/dependency_graph already
  # have: scoping to domain/ui excludes UnitA.pas's TUnitA class (fixture
  # root, outside domain/ui) from type_declarations[], while domain/ui's own
  # TWaterQuality and the OKButtonClick handler resolution remain present.
  if grep -q '"name": "TUnitA"' <<<"$ui_out"; then
    fail "11r domain/ui scoping excludes out-of-scope TUnitA (found it)"
  else
    pass "11r domain/ui scoping excludes out-of-scope TUnitA (fixture root, outside domain/ui)"
  fi
  if grep -qF '"name": "TWaterQuality"' <<<"$ui_out" \
     && grep -qF '{"handler_name": "OKButtonClick", "file": "domain/ui/MainForm.pas"' <<<"$ui_out"; then
    pass "11r domain/ui scoping still includes in-scope entities (TWaterQuality, OKButtonClick resolution)"
  else
    fail "11r domain/ui scoping still includes in-scope entities (TWaterQuality, OKButtonClick resolution)"
  fi
fi
echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 12 — rebuild-collect: existence-check + line-count JSON emission for
# the five .specclaw/analysis/*.md documents (rebuild-plan-bridge, AC1-AC2),
# the module roster parsed from module-map.md, and the missing-document error
# path naming exactly which doc(s) are missing and which command produces
# each.
#
# module-map.md is the fifth prerequisite, not an optional input: every
# backlog item is grouped under a MOD-### module and that document declares
# them, so collect refuses rather than inventing a grouping — the same
# contract skills/bf-rebuild-plan/SKILL.md states, and the same one `render`
# and `module-status` enforce independently.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 12: specclaw-bf-rebuild-collect collect — existence, line counts, module roster, missing-doc errors ---"
REBUILD_BIN="$BIN_DIR/specclaw-bf-rebuild-collect"
if [[ ! -f "$REBUILD_BIN" ]]; then
  fail "specclaw-bf-rebuild-collect missing"
else
  # 12a-12b — all five fixture docs present: JSON lists all five paths with
  # line counts matching a hand-computed `wc -l` (same discipline as 9e).
  RFIX="$WORK/rebuild-proj"
  mkdir -p "$RFIX/.specclaw/analysis"
  cp -R "$FIXTURES_DIR/rebuild-plan/analysis/." "$RFIX/.specclaw/analysis/"

  rebuild_out="$(bash "$REBUILD_BIN" collect "$RFIX/.specclaw" 2>/dev/null)"
  rebuild_exit=$?
  assert_eq "12a all-present: exit 0" "0" "$rebuild_exit"

  for doc in codebase-report.md architecture.md domain-model.md functional-spec.md module-map.md; do
    hand_count="$(wc -l < "$FIXTURES_DIR/rebuild-plan/analysis/$doc" | tr -d ' ')"
    doc_line="$(grep -o "\"path\": \"\.specclaw/analysis/${doc}\", \"lines\": [0-9]*" <<<"$rebuild_out")"
    if grep -q "\"lines\": ${hand_count}\$" <<<"$doc_line"; then
      pass "12b ${doc} line count matches wc -l ($hand_count)"
    else
      fail "12b ${doc} line count matches wc -l (got: $doc_line, expected lines: $hand_count)"
    fi
  done

  # 12c — project_root points at the fixture project, not the real repo.
  if grep -q "\"project_root\": \"$RFIX\"" <<<"$rebuild_out"; then
    pass "12c project_root reflects the collected project"
  else
    fail "12c project_root reflects the collected project (got: $(grep '"project_root":' <<<"$rebuild_out"))"
  fi

  # 12g — the module roster is actually emitted. This is the field whose
  # absence turned 12a-12c from "wrong value" into "empty output" when
  # module-map.md became a prerequisite, so it gets its own assertion rather
  # than being implied by the line count above.
  if grep -q '"mod_id": "MOD-001"' <<<"$rebuild_out" \
     && grep -q '"confirmed": true' <<<"$rebuild_out"; then
    pass "12g module roster and confirmation state reported from module-map.md"
  else
    fail "12g module roster and confirmation state reported from module-map.md (got: $(grep -o '"module_map".\{0,140\}' <<<"$rebuild_out"))"
  fi

  # 12d-12f — partial docs (3 of 5 missing): non-zero exit, and stderr names
  # exactly the missing files plus the command that produces each. The partial
  # fixture copies only codebase-report.md and architecture.md, so
  # module-map.md is missing here too and is named alongside the other two —
  # which 12e and 12f are both indifferent to by construction.
  RFIX_PARTIAL="$WORK/rebuild-proj-partial"
  mkdir -p "$RFIX_PARTIAL/.specclaw/analysis"
  cp "$FIXTURES_DIR/rebuild-plan/analysis/codebase-report.md" "$RFIX_PARTIAL/.specclaw/analysis/"
  cp "$FIXTURES_DIR/rebuild-plan/analysis/architecture.md" "$RFIX_PARTIAL/.specclaw/analysis/"

  partial_err="$(bash "$REBUILD_BIN" collect "$RFIX_PARTIAL/.specclaw" 2>&1 1>/dev/null)"
  partial_exit=$?
  if [[ "$partial_exit" -ne 0 ]]; then
    pass "12d partial docs (3 of 5 missing): non-zero exit"
  else
    fail "12d partial docs (3 of 5 missing): non-zero exit (got exit 0)"
  fi
  if grep -q 'domain-model.md (run /specclaw:bf-domain)' <<<"$partial_err" \
     && grep -q 'functional-spec.md (run /specclaw:bf-domain)' <<<"$partial_err"; then
    pass "12e partial docs: stderr names both missing files + producing command"
  else
    fail "12e partial docs: stderr names both missing files + producing command (got: $partial_err)"
  fi
  if grep -q 'codebase-report.md' <<<"$partial_err" || grep -q 'architecture.md' <<<"$partial_err"; then
    fail "12f partial docs: stderr does not name present files as missing (found one)"
  else
    pass "12f partial docs: stderr does not name present files as missing"
  fi
fi
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
# Summary
# ─────────────────────────────────────────────────────────────────────────────
echo "=================================================="
echo "$PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
