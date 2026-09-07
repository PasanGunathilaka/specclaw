#!/usr/bin/env bash
# run-bf-status-tests.sh — regression suite for specclaw-bf-status, the
# read-only per-phase dashboard for the brownfield workstream.
#
# What this suite protects, and why each one is here:
#
#   - IT WRITES NOTHING. The whole justification for this command not being
#     archived like every other .specclaw/ document is that it produces no
#     artifact at all. A future edit that starts caching its output would
#     quietly acquire a staleness problem this design does not have, so the
#     no-write property is asserted directly against the file tree.
#
#   - A PHASE IS "not run" ONLY FROM ITS OWN ARTIFACT. Never inferred from a
#     sibling document that happens to mention it.
#
#   - THE REPLAY ROW REPORTS LATEST-PER-TARGET, NOT LATEST OVERALL. This is
#     the defect the suite exists for: with a plain newest-run read, a change
#     whose own most recent verdict is FAIL disappears behind an unrelated
#     module that passed a day later. The dashboard would then render DONE
#     over an outstanding failure, which is the one thing a status view must
#     never do.
#
#   - STUB TAINT IS NEVER A FALSE POSITIVE. A clean verdict must never be
#     reported as resting on a placeholder. Asserted for both a tainted and an
#     untainted run. (The CRLF hazard behind this is documented at the
#     assertion itself, along with what that check does and does not prove.)
#
#   - AN ANSWER ON THE LINE BELOW ITS TAG IS AN ANSWER. specclaw-bf-clarify's
#     own block_answer_text reads multi-line answers, so counting them as
#     unanswered here would manufacture blocking questions that do not exist.
#
#   - MISSING OPTIONAL TOOLING DEGRADES, NEVER FAILS. A dashboard that exits
#     non-zero because jq is absent is worse than one that renders honestly
#     with less detail.
#
# Bash + coreutils. jq is exercised where present and deliberately hidden for
# the degradation test.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STATUS_BIN="$PLUGIN_ROOT/bin/specclaw-bf-status"

PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); echo "  ok   — $1"; }
bad() { FAIL=$((FAIL+1)); echo "  FAIL — $1"; [ $# -gt 1 ] && echo "         $2"; }

assert_eq() {
  local expected="$1" actual="$2" label="$3"
  if [ "$expected" = "$actual" ]; then ok "$label"
  else bad "$label" "expected [$expected], got [$actual]"; fi
}
assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in *"$needle"*) ok "$label" ;;
    *) bad "$label" "missing [$needle]" ;; esac
}
assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  case "$haystack" in *"$needle"*) bad "$label" "unexpectedly found [$needle]" ;;
    *) ok "$label" ;; esac
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixtures ─────────────────────────────────────────────────────────────────

# A bare initialized project: .specclaw/ exists, no brownfield artifact does.
new_empty() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis"
  printf 'project:\n  name: "Fixture"\n' > "$root/.specclaw/config.yaml"
}

# The five analysis documents, so phases downstream of them are reachable.
seed_analysis() {
  local root="$1" map_status="${2:-PROPOSED}"
  mkdir -p "$root/.specclaw/analysis"
  local f
  for f in codebase-report architecture domain-model functional-spec; do
    printf '**Date generated:** 2026-08-01\n' > "$root/.specclaw/analysis/$f.md"
  done
  cat > "$root/.specclaw/analysis/module-map.md" <<EOF
# Module Map

**Status:** ${map_status}

### MOD-001 — Core
- **Depends on:** None

### MOD-002 — Reporting
- **Depends on:** MOD-001

### MOD-003 — WITHDRAWN — folded into MOD-001
- **Depends on:** None
EOF
}

# One retained replay run, in whichever evidence pool the caller names.
seed_run() { # <root> <pool-relative-dir> <run_id> <target> <verdict> <date> <tainted:true|false>
  local root="$1" pool="$2" run_id="$3" target="$4" verdict="$5" date="$6" taint="$7"
  local d="$root/.specclaw/$pool/run-$run_id"
  mkdir -p "$d"
  cat > "$d/run-metadata.json" <<EOF
{
  "run_id": "${run_id}",
  "target": "${target}",
  "module": null,
  "date": "${date}",
  "overall_verdict": "${verdict}",
  "stub_tainted": ${taint},
  "bl_items_covered": []
}
EOF
}

# The rest of the phase artifacts, so a fixture can be walked forward one phase
# at a time and the recommendation checked at each stop.
seed_clarify_done() { # <root> — one blocking question, answered, plus decisions.md
  mkdir -p "$1/.specclaw/analysis"
  cat > "$1/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-001 — Target platform
- **Blocking:** yes — the stack
- **Answer:** .NET 9
- **Decided by:** H, 2026-08-05
EOF
  printf '# Decisions\n\n### SQ-001 — Target platform\n**Decision:** .NET 9\n' \
    > "$1/.specclaw/analysis/decisions.md"
}

seed_backlog() { # <root>
  printf '### BL-001 — Thing\n**Gate:** CLEAR\n**Verification:** VERIFIABLE — fixtures: GM-001\n' \
    > "$1/.specclaw/analysis/rebuild-backlog.md"
}

seed_baseline_recorded() { # <root>
  mkdir -p "$1/.specclaw/baseline"
  printf '# Seams\n' > "$1/.specclaw/baseline/seams.md"
  printf '{"total_scenarios":1,"fixtures":[{"id":"GM-001"}],"missing_scenarios":[]}\n' \
    > "$1/.specclaw/baseline/manifest.json"
}

seed_blueprint() { # <root>
  printf '# Target Architecture\n\n**Blueprint status:** COMPLETE\n' \
    > "$1/.specclaw/analysis/target-architecture.md"
}

seed_boot() { # <root> [not_applicable_reason]
  mkdir -p "$1/.specclaw/bootstrap"
  if [ -n "${2:-}" ]; then
    printf '{"not_applicable":{"reason":"%s"},"foundation_ready":false}\n' "$2" \
      > "$1/.specclaw/bootstrap/bootstrap-manifest.json"
  else
    printf '{"not_applicable":null,"foundation_ready":true,"stack":{"api":"Go"}}\n' \
      > "$1/.specclaw/bootstrap/bootstrap-manifest.json"
  fi
}

run_status() { bash "$STATUS_BIN" "$1/.specclaw" 2>&1; }

# The compact guidance block — the same computation, rendered short. Every
# lifecycle bf-* skill appends this, so what it says IS the end-of-command
# guidance and is asserted here rather than in any skill.
run_next() { bash "$STATUS_BIN" "$1/.specclaw" --next 2>&1; }

# The '## Next' section of the dashboard, alone.
next_section_of() { printf '%s\n' "$1" | awk '/^## Next$/{f=1;next} /^---$/{f=0} f'; }

# sha256 of the whole tree — names AND contents, so neither a new file nor an
# edit to an existing one can pass.
tree_hash() { find "$1" -type f -exec sha256sum {} + 2>/dev/null | LC_ALL=C sort | sha256sum; }

echo "=================================================="
echo "specclaw-bf-status regression suite"
echo "=================================================="

# ── 1. The no-write invariant ────────────────────────────────────────────────
echo
echo "-- writes nothing --"

R="$WORK/nowrite"; new_empty "$R"; seed_analysis "$R"
seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
BEFORE="$(find "$R/.specclaw" | LC_ALL=C sort | cksum)"
BEFORE_CONTENT="$(find "$R/.specclaw" -type f -exec cat {} + | cksum)"
run_status "$R" >/dev/null
AFTER="$(find "$R/.specclaw" | LC_ALL=C sort | cksum)"
AFTER_CONTENT="$(find "$R/.specclaw" -type f -exec cat {} + | cksum)"
assert_eq "$BEFORE" "$AFTER" "creates and removes no file"
assert_eq "$BEFORE_CONTENT" "$AFTER_CONTENT" "modifies no existing file"

# ── 2. Absence is reported as absence ────────────────────────────────────────
echo
echo "-- a phase is 'not run' only from its own artifact --"

R="$WORK/empty"; new_empty "$R"
OUT="$(run_status "$R")"; RC=$?
assert_eq "0" "$RC" "an untouched project is not an error"
assert_contains "$OUT" "codebase-report.md not written" "bf-analyze reads as not run"
assert_contains "$OUT" "Run \`/specclaw:bf-analyze\`" "and is recommended as the next command"

# A backlog naming a module map does NOT make the map exist.
R="$WORK/noinfer"; new_empty "$R"
printf '### BL-001 — Thing\n- **Module:** MOD-001\n' > "$R/.specclaw/analysis/rebuild-backlog.md"
OUT="$(run_status "$R")"
assert_contains "$OUT" "missing: domain-model.md functional-spec.md module-map.md" \
  "a backlog citing MOD-001 never implies bf-domain has run"

# ── 3. The module-map confirmation gate ──────────────────────────────────────
echo
echo "-- module map confirmation --"

R="$WORK/proposed"; new_empty "$R"; seed_analysis "$R" "PROPOSED"
OUT="$(run_status "$R")"
assert_contains "$OUT" "Module map is not confirmed" "PROPOSED raises an attention item"
assert_contains "$OUT" "2 module(s)" "WITHDRAWN modules are excluded from the count"

R="$WORK/confirmed"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by Hafsa, 2026-08-07"
OUT="$(run_status "$R")"
assert_not_contains "$OUT" "Module map is not confirmed" "CONFIRMED raises nothing"

# ── 4. Answered-vs-unanswered, including multi-line answers ──────────────────
echo
echo "-- clarification counting --"

R="$WORK/clarify"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

## Standard bank

### SQ-001 — Answered inline, blocking
- **Blocking:** yes — the stack
- **Answer:** .NET 9
- **Decided by:** H, 2026-08-05

### SQ-014 — Unanswered, blocking
- **Blocking:** yes — every fixture
- **Answer:**
- **Decided by:**

## Extracted questions

### CQ-001 — Answered on the NEXT line, blocking
- **Blocking:** yes — MOD-002
- **Answer:**
  Preserve the legacy behaviour.
- **Decided by:** H, 2026-08-06

### CQ-002 — Unanswered, NOT blocking
- **Blocking:** no
- **Answer:**
- **Decided by:**
EOF
cat > "$R/.specclaw/analysis/pending-questions.md" <<'EOF'
# Pending Questions

### PQ-001 — Open one
- **Status:** OPEN

### PQ-002 — Already promoted
- **Status:** PROMOTED → CQ-002

### PQ-003 — Another open one
- **Status:** OPEN
EOF
OUT="$(run_status "$R")"
assert_contains "$OUT" "4 question(s), 2 unanswered (1 blocking)" \
  "a multi-line answer counts as answered, and only blocking gaps are called blocking"
assert_contains "$OUT" "PQ buffer: 2 OPEN" "PROMOTED entries are not open work"

# ── 5. Backlog item states ───────────────────────────────────────────────────
echo
echo "-- backlog counting --"

R="$WORK/backlog"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/rebuild-backlog.md" <<'EOF'
# Rebuild Backlog

### BL-001 — Active and verifiable
**Gate:** CLEAR
**Verification:** VERIFIABLE — fixtures: GM-001

### BL-002 — Active, pending capture
**Gate:** CLEAR
**Verification:** PENDING CAPTURE — scenarios designed, no recorded fixture yet: GM-002

### BL-003 — Deferred
**Status:** Deferred — awaiting CQ-002
**Gate:** BLOCKED — blocked by BL-001
**Verification:** PENDING CAPTURE — scenarios designed, no recorded fixture yet: GM-003

### BL-004 — STRUCK — superseded by BL-001
EOF
OUT="$(run_status "$R")"
assert_contains "$OUT" "2 active item(s) (2 gate CLEAR, 1 VERIFIABLE); 1 struck, 1 deferred" \
  "struck and deferred items are counted apart from active ones"

# ── 6. THE REGRESSION: latest per target, not latest overall ─────────────────
echo
echo "-- replay: latest PER TARGET --"

R="$WORK/replay"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
# An older FAIL on one target, a newer PASS on a DIFFERENT target. Reading only
# the newest run would render this DONE and lose the FAIL entirely.
seed_run "$R" "changes/trial-balance/replay-evidence" "20260818-090000" "trial-balance" "FAIL" "2026-08-18" "false"
seed_run "$R" "replay/evidence"                      "20260820-101500" "MOD-001"       "PASS" "2026-08-20" "false"
OUT="$(run_status "$R")"
if command -v jq >/dev/null 2>&1; then
  assert_contains "$OUT" "2 run(s) over 2 target(s)" "both targets are counted"
  assert_contains "$OUT" "latest per target: 1 PASS, 1 not" "the newer PASS does not absorb the older FAIL"
  assert_contains "$OUT" "Replay target **trial-balance**" "the failing target is named, not just counted"
  assert_contains "$OUT" "is **FAIL** (2026-08-18)" "with its own verdict and date"
  # And the row must not read DONE while a target is outstanding.
  ROW="$(printf '%s\n' "$OUT" | grep 'Replay acceptance' || true)"
  assert_contains "$ROW" "ATTN" "the row reads ATTN, never DONE, while a target's latest run failed"

  # Two runs on the SAME target: the newer one does supersede.
  R2="$WORK/replay-same"; new_empty "$R2"; seed_analysis "$R2" "CONFIRMED by H, 2026-08-07"
  seed_run "$R2" "replay/evidence" "20260818-090000" "MOD-001" "FAIL" "2026-08-18" "false"
  seed_run "$R2" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  OUT2="$(run_status "$R2")"
  assert_contains "$OUT2" "2 run(s) over 1 target(s)" "same-target runs collapse to one target"
  assert_contains "$OUT2" "latest per target: 1 PASS, 0 not" "a re-run on the same target supersedes its own earlier verdict"
  assert_not_contains "$OUT2" "is **FAIL**" "the superseded FAIL is not resurfaced"
else
  echo "  (skipped — jq not installed)"
fi

# ── 7. Stub taint is never a false positive ──────────────────────────────────
echo
echo "-- stub taint --"

if command -v jq >/dev/null 2>&1; then
  R="$WORK/clean"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  OUT="$(run_status "$R")"
  assert_not_contains "$OUT" "dependency-bypass stub" \
    "an untainted run is never reported as resting on a stub (the CRLF trap)"

  R="$WORK/tainted"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "true"
  OUT="$(run_status "$R")"
  assert_contains "$OUT" "dependency-bypass stub" "a tainted run is reported"
  assert_contains "$OUT" '`PASS*`' "and its verdict is marked, never presented as a bare PASS"

  # A PROPERTY CHECK, NOT A PROOF OF THE GUARD — stated plainly because the
  # difference matters to whoever edits this next.
  #
  # A native Windows jq writes CRLF, and the stray \r lands in the LAST field
  # it printed — which for the replay TSV is the stub-taint flag, so an
  # untainted run would come back carrying "\r", read as non-empty, and be
  # accused of resting on a placeholder. Two things stop that: the literal
  # "-" sentinel (an empty trailing TSV field is also indistinguishable from a
  # truncated line, so this one is worth having regardless of platform), and
  # `| tr -d '\r'` inside jqr.
  #
  # Neither is currently mutation-detectable: bash's own command substitution
  # strips a trailing CR along with the newline, so on every platform tested
  # the CR is gone before either guard sees it. Removing them both still
  # passes. They stay as cheap insurance — matching the same discipline
  # specclaw-bf-rebuild-collect already applies to its metadata reads — and
  # this asserts the property they exist to preserve, so a future refactor
  # that reads jq output some other way (a temp file, a process substitution,
  # a `read -r` loop) is caught here rather than in a user's dashboard.
  R="$WORK/nocr"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  mkdir -p "$R/.specclaw/bootstrap"
  printf '{"not_applicable":null,"foundation_ready":true,"stack":{"api":"Go"}}\n' \
    > "$R/.specclaw/bootstrap/bootstrap-manifest.json"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  CR_COUNT="$(run_status "$R" | tr -dc '\r' | wc -c | tr -d '[:space:]')"
  assert_eq "0" "$CR_COUNT" "no carriage return reaches the output from any jq read"
else
  echo "  (skipped — jq not installed)"
fi

# ── 8. Degradation without jq ────────────────────────────────────────────────
echo
echo "-- degrades without jq, never fails --"

R="$WORK/nojq"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
mkdir -p "$R/.specclaw/baseline" "$R/.specclaw/bootstrap"
printf '# Seams\n'  > "$R/.specclaw/baseline/seams.md"
printf '{"total_scenarios":1,"fixtures":[],"missing_scenarios":["GM-001"]}\n' > "$R/.specclaw/baseline/manifest.json"
printf '{"not_applicable":null,"foundation_ready":true,"stack":{"api":"Go"}}\n' > "$R/.specclaw/bootstrap/bootstrap-manifest.json"
seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"

# An empty PATH entry ahead of the real one is not enough — hide jq by
# stripping whichever directory it actually resolves from (on most Linux
# distros, including GitHub Actions runners, that IS /usr/bin — so a fixed
# "/usr/bin:/bin" allowlist does not hide it there).
JQ_DIR="$(command -v jq >/dev/null 2>&1 && dirname "$(command -v jq)" || true)"
NOJQ_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -vFx "$JQ_DIR" | paste -sd: -)"
NOJQ_OUT="$(env PATH="$NOJQ_PATH" bash "$STATUS_BIN" "$R/.specclaw" 2>&1)"; NOJQ_RC=$?
if env PATH="$NOJQ_PATH" bash -c 'command -v jq' >/dev/null 2>&1; then
  echo "  (skipped — jq is on the restricted PATH too, cannot simulate its absence)"
else
  assert_eq "0" "$NOJQ_RC" "exits 0 with no jq"
  assert_contains "$NOJQ_OUT" "jq\` is not on PATH" "and says so on its own face"
  assert_contains "$NOJQ_OUT" "install jq" "pointing at what would sharpen the detail"
  assert_contains "$NOJQ_OUT" "2 module(s)" "every markdown-derived count stays exact"
fi

# ── 9. Argument handling ─────────────────────────────────────────────────────
echo
echo "-- argument handling --"

OUT="$(bash "$STATUS_BIN" --help 2>&1)"; RC=$?
assert_eq "0" "$RC" "--help exits 0"
assert_contains "$OUT" "Usage: specclaw-bf-status" "and prints usage"

OUT="$(bash "$STATUS_BIN" 2>&1)"; RC=$?
assert_eq "2" "$RC" "a missing argument exits 2"
assert_contains "$OUT" "<specclaw_dir> is required" "naming what is missing"

OUT="$(bash "$STATUS_BIN" "$WORK/does-not-exist" 2>&1)"; RC=$?
assert_eq "2" "$RC" "a missing .specclaw dir exits 2"
assert_contains "$OUT" "/specclaw:init" "pointing at the command that creates it"

# ── 10. The compact interface writes nothing either ──────────────────────────
#
# The no-write invariant is the whole reason this command is exempt from the
# archive-then-replace discipline every other .specclaw/ document follows, and
# adding a second entry point is exactly how a script quietly acquires a cache.
# Asserted against names AND contents, for both modes, and for the whole
# project tree rather than just .specclaw/ — a stray file dropped in the repo
# root would be just as much of a bug.
echo
echo "-- --next writes nothing, anywhere --"

R="$WORK/nowrite2"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_backlog "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
BEFORE_TREE="$(tree_hash "$R")"
run_next "$R"   >/dev/null
run_status "$R" >/dev/null
run_next "$R"   >/dev/null
AFTER_TREE="$(tree_hash "$R")"
assert_eq "$BEFORE_TREE" "$AFTER_TREE" "neither mode creates, edits or removes any file in the project"

# ── 11. One computation, two renderings ──────────────────────────────────────
#
# The point of putting --next in this script rather than a sibling: there is no
# second copy of the ordering to drift. Asserted directly — whatever command the
# dashboard recommends, the compact block must name the same one.
echo
echo "-- single source of truth: dashboard and --next never disagree --"

for STATE in empty analysis clarified baselined backlogged; do
  R="$WORK/sot-$STATE"; new_empty "$R"
  case "$STATE" in
    analysis)   seed_analysis "$R" "CONFIRMED by H, 2026-08-07" ;;
    clarified)  seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R" ;;
    baselined)  seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                seed_baseline_recorded "$R" ;;
    backlogged) seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                seed_baseline_recorded "$R"; seed_backlog "$R"; seed_blueprint "$R" ;;
  esac
  DASH_NEXT="$(next_section_of "$(run_status "$R")")"
  COMPACT="$(run_next "$R")"
  # Pull the recommended command out of each rendering and compare the tokens.
  D_CMD="$(printf '%s\n' "$DASH_NEXT"  | grep -oE '/specclaw:[a-z-]+( --[a-z-]+)?' | head -1 || true)"
  C_CMD="$(printf '%s\n' "$COMPACT"    | grep -oE '^\*\*Next command:\*\* `[^`]+`' | sed -E 's/.*`(.*)`/\1/' || true)"
  assert_eq "$D_CMD" "$C_CMD" "state '$STATE': dashboard and --next name the same command"
done

# ── 12. Progression: each completed phase yields the next one ────────────────
echo
echo "-- basic progression --"

R="$WORK/prog"; new_empty "$R"
assert_contains "$(run_next "$R")" '`/specclaw:bf-analyze`' "an untouched project starts at bf-analyze"

printf '**Date generated:** 2026-08-01\n' > "$R/.specclaw/analysis/codebase-report.md"
assert_contains "$(run_next "$R")" '`/specclaw:bf-architecture`' "with a codebase report, architecture is next"

printf '**Date generated:** 2026-08-01\n' > "$R/.specclaw/analysis/architecture.md"
assert_contains "$(run_next "$R")" '`/specclaw:bf-domain`' "with an architecture, domain is next"

seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
assert_contains "$(run_next "$R")" '`/specclaw:bf-clarify`' "with the domain documents, clarify is next"

seed_clarify_done "$R"
assert_contains "$(run_next "$R")" '`/specclaw:bf-baseline`' "with a resolved question set, the baseline is next"

seed_baseline_recorded "$R"
assert_contains "$(run_next "$R")" '`/specclaw:bf-rebuild-plan`' "with a recorded baseline, the backlog is next"

seed_backlog "$R"
assert_contains "$(run_next "$R")" '`/specclaw:bf-blueprint`' "with a backlog, the target blueprint is next"

seed_blueprint "$R"
assert_contains "$(run_next "$R")" "copy the Phase A artifacts" \
  "with Phase A complete, the next step is a human one — bootstrap runs in the OTHER repo"
assert_not_contains "$(run_next "$R")" '**Next command:** `/specclaw:bf-bootstrap`' \
  "and bf-bootstrap is never recommended as a command, because a backlog exists in BOTH repos"

seed_boot "$R"
assert_contains "$(run_next "$R")" '`/specclaw:propose`' "with a ready foundation, an ordinary backlog item is next"

# ── 13. --resolve is ranked by what actually refuses without it ──────────────
#
# decisions.md is what /specclaw:bf-blueprint and /specclaw:bf-bootstrap hard-
# refuse without. The baseline and the backlog never read it, so a project that
# has answered a question but not resolved it is not held back from either.
echo
echo "-- clarify --resolve ranking --"

R="$WORK/resolve"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-001 — Answered
- **Blocking:** yes — the stack
- **Answer:** .NET 9
- **Decided by:** H, 2026-08-05
EOF
assert_contains "$(run_next "$R")" '`/specclaw:bf-baseline`' \
  "an answered-but-unresolved question set does not hold the baseline back"

seed_baseline_recorded "$R"; seed_backlog "$R"
# Assert against the RECOMMENDATION line specifically, not the whole block: the
# "no decisions.md" attention item names --resolve too, so a substring match on
# the whole output would pass whether or not it was ever recommended.
NEXT_CMD_LINE="$({ run_next "$R" | grep '^\*\*Next command:' || true; })"
assert_contains "$NEXT_CMD_LINE" '`/specclaw:bf-clarify --resolve`' \
  "but once the backlog exists, --resolve is next — blueprint and bootstrap both refuse without decisions.md"

# Nothing answered at all: --resolve would refuse, so it is never recommended.
R="$WORK/resolve-none"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-001 — Unanswered
- **Blocking:** no
- **Answer:**
- **Decided by:**
EOF
seed_baseline_recorded "$R"; seed_backlog "$R"
NEXT_CMD_LINE="$({ run_next "$R" | grep '^\*\*Next command:' || true; })"
assert_not_contains "$NEXT_CMD_LINE" '/specclaw:bf-clarify --resolve' \
  "with nothing answered, --resolve is never recommended — resolve-collect would refuse it"
# It is still named in the attention list, as the thing to run once someone has
# answered — a conditional pointer, which is not the same as a recommendation.
assert_contains "$(run_next "$R")" 'No `decisions.md`' \
  "though the absent decisions.md is still reported as outstanding"

# ── 14. Human work is named as human work ────────────────────────────────────
#
# The distinction the compact block exists for: a Next action is something no
# command can clear. Getting this wrong in either direction is the failure —
# telling someone to run a command that cannot help, or burying the edit that
# actually unblocks them in a list they skim.
echo
echo "-- Next action vs Next command --"

R="$WORK/act-map"; new_empty "$R"; seed_analysis "$R" "PROPOSED"
OUT="$(run_next "$R")"
assert_contains "$OUT" "**Next action:** Confirm the module map" "an unconfirmed map is a Next action"
assert_contains "$OUT" '`**Status:**` line' "naming the edit that clears it"
assert_contains "$OUT" "nothing is blocked by this" "and saying plainly that it gates nothing"
assert_contains "$OUT" "**Next command:**" "while the phase command is still recommended alongside it"

R="$WORK/act-cq"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-014 — Unanswered, blocking
- **Blocking:** yes — every fixture
- **Answer:**
- **Decided by:**

### CQ-001 — Unanswered, NOT blocking
- **Blocking:** no
- **Answer:**
- **Decided by:**

### CQ-002 — Answered on the NEXT line, blocking
- **Blocking:** yes — MOD-002
- **Answer:**
  Preserve the legacy behaviour.
- **Decided by:** H, 2026-08-06
EOF
printf '# Decisions\n' > "$R/.specclaw/analysis/decisions.md"
OUT="$(run_next "$R")"
assert_contains "$OUT" "**Next action:** Answer 1 blocking question(s)" \
  "an unanswered blocking question is a Next action, counted without the multi-line answer"
assert_contains "$OUT" '`/specclaw:bf-clarify --resolve`' "with the command that follows the human's part named"
# THE EDGE CASE: the action must come first, before the command it does not block.
ACTION_LINE="$(printf '%s\n' "$OUT" | grep -n '^\*\*Next action:' | cut -d: -f1)"
CMD_LINE="$(printf '%s\n' "$OUT" | grep -n '^\*\*Next command:' | cut -d: -f1)"
if [ -n "$ACTION_LINE" ] && [ -n "$CMD_LINE" ] && [ "$ACTION_LINE" -lt "$CMD_LINE" ]; then
  ok "the human action is rendered BEFORE the command, never after it"
else
  bad "the human action is rendered BEFORE the command, never after it" \
      "action at line ${ACTION_LINE:-none}, command at line ${CMD_LINE:-none}"
fi
# And it must not also appear in the list below — one problem, stated once.
assert_not_contains "$(printf '%s\n' "$OUT" | sed -n '/Needs attention/,$p')" \
  "Answer 1 blocking question(s)" "the promoted action is not repeated in the attention list"

# ── 15. Absence still implies nothing, in the compact rendering too ──────────
echo
echo "-- --next infers a phase only from that phase's own artifact --"

R="$WORK/noinfer2"; new_empty "$R"
printf '### BL-001 — Thing\n- **Module:** MOD-001\n' > "$R/.specclaw/analysis/rebuild-backlog.md"
printf '{"total_scenarios":1,"fixtures":[],"missing_scenarios":["GM-001"]}\n' > "$R/.specclaw/analysis/ignored.json"
OUT="$(run_next "$R")"
assert_contains "$OUT" '`/specclaw:bf-analyze`' \
  "a backlog naming MOD-001 never implies bf-analyze, bf-domain or the baseline have run"

# ── 16. UI is optional and never becomes a gate ──────────────────────────────
echo
echo "-- UI: uncaptured screenshots are human work, never a blocked command --"

R="$WORK/ui"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
mkdir -p "$R/.specclaw/ui"
printf '# UI Inventory\n\n### SCR-001 — Login\n' > "$R/.specclaw/ui/ui-inventory.md"
printf '# Screenshot checklist\n' > "$R/.specclaw/ui/screenshot-checklist.md"
OUT="$(run_next "$R")"
assert_contains "$OUT" "**Next action:** Capture the checklist screenshots" \
  "a designed-but-unrecorded checklist is a Next action"
assert_contains "$OUT" '`/specclaw:bf-ui --record`' "pointing at what turns the captures into evidence"

if command -v jq >/dev/null 2>&1; then
  printf '{"screenshots":["SCR-001"],"missing":["SCR-002","SCR-003"]}\n' > "$R/.specclaw/ui/ui-manifest.json"
  OUT="$(run_next "$R")"
  assert_contains "$OUT" "Capture 2 missing screenshot(s)" "a partial capture names the outstanding count"
  printf '{"screenshots":["SCR-001"],"missing":[]}\n' > "$R/.specclaw/ui/ui-manifest.json"
  assert_not_contains "$(run_next "$R")" "missing screenshot" "a complete capture raises nothing"
fi
# The whole workstream is optional, so it is never a recommended command.
assert_not_contains "$(run_next "$R")" '**Next command:** `/specclaw:bf-ui`' \
  "/specclaw:bf-ui is never recommended as a next command — the workstream is optional"

# ── 17. Baseline capture is a human action at every stage ────────────────────
echo
echo "-- baseline: design → harness → capture --"

R="$WORK/bl"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
mkdir -p "$R/.specclaw/baseline"
printf '# Seams\n' > "$R/.specclaw/baseline/seams.md"
printf '# Scenarios\n\n### GM-001 — A rule\n' > "$R/.specclaw/baseline/scenarios.md"
OUT="$(run_next "$R")"
assert_contains "$OUT" '`/specclaw:bf-baseline --harness`' "a design with no harness recommends --harness"

mkdir -p "$R/.specclaw/baseline/harness"
printf '# Error map\n\n### SOME_CODE\n' > "$R/.specclaw/baseline/error-map.md"
OUT="$(run_next "$R")"
assert_contains "$OUT" "**Next action:** Harness generated but no \`manifest.json\`" \
  "a harness with no manifest is a human action, not a command to re-run blindly"
assert_contains "$OUT" "refuses to write one at all if any fixture fails validation" \
  "and says why an absent manifest is not simply an uncaptured baseline"

if command -v jq >/dev/null 2>&1; then
  printf '{"total_scenarios":3,"fixtures":[{"id":"GM-001"}],"missing_scenarios":["GM-002","GM-003"]}\n' \
    > "$R/.specclaw/baseline/manifest.json"
  OUT="$(run_next "$R")"
  assert_contains "$OUT" "**Next action:** Capture 2 missing fixture(s)" \
    "uncaptured fixtures are a human action — no specclaw command runs the harness"
  assert_contains "$OUT" '`/specclaw:bf-baseline --record`' "with the command that validates them named"
fi

# ── 18. THE REGRESSION: a foundation is not something to replay ──────────────
#
# This recommendation used to read /specclaw:bf-replay, which compares the
# REBUILT application against the fixtures. On a foundation that has just been
# scaffolded there is nothing built to compare, so that run reports INCOMPLETE
# or FAIL and means neither — and it contradicted bf-bootstrap's own summary,
# which has always named /specclaw:propose. They must not diverge again.
echo
echo "-- post-bootstrap: propose, never replay --"

R="$WORK/postboot"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
OUT="$(run_next "$R")"
assert_contains "$OUT" '**Next command:** `/specclaw:propose`' \
  "a ready foundation with nothing built recommends an ordinary backlog item"
assert_contains "$OUT" '**After that:** `/specclaw:bf-replay <change>`' \
  "and names replay as what follows, so the ordering is stated rather than lost"
assert_not_contains "$OUT" '**Next command:** `/specclaw:bf-replay`' \
  "never replay: there is nothing built to compare against the fixtures yet"

BOOTSTRAP_SKILL="$PLUGIN_ROOT/skills/bf-bootstrap/SKILL.md"
assert_contains "$(cat "$BOOTSTRAP_SKILL")" '`/specclaw:propose "<the backlog'"'"'s recommended next item>"`' \
  "and bf-bootstrap's own summary still names the same command it always did"

# A repo that declared itself NOT the rebuild target still carries a manifest.
# Its presence must not be read as a foundation standing here.
if command -v jq >/dev/null 2>&1; then
  R="$WORK/notapplicable"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"
  seed_boot "$R" "this repo is the legacy source"
  assert_not_contains "$(run_next "$R")" '`/specclaw:propose`' \
    "a --not-applicable declaration is not a foundation, and is never told to propose backlog work"
fi

# ── 19. Replay: an outstanding FAIL is stated, and never as progress ─────────
echo
echo "-- replay in the compact block --"

if command -v jq >/dev/null 2>&1; then
  R="$WORK/replay-next"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
  seed_run "$R" "changes/trial-balance/replay-evidence" "20260818-090000" "trial-balance" "FAIL" "2026-08-18" "false"
  seed_run "$R" "replay/evidence"                      "20260820-101500" "MOD-001"       "PASS" "2026-08-20" "false"
  OUT="$(run_next "$R")"
  assert_contains "$OUT" "Replay target **trial-balance** is **FAIL**" \
    "a target whose own latest run failed is named, not hidden behind a newer unrelated PASS"
  assert_contains "$OUT" '`20260818-090000`' "with the run id to go and read"
  # PD-07: a FAIL must never be dressed as the phase having advanced.
  assert_not_contains "$OUT" "**Next command:**" \
    "and no command is recommended alongside it — nothing here may read as the phase advancing"
  assert_not_contains "$OUT" "nothing outstanding" "nor may the run be reported as clean"

  # Same target replayed again, clean: the superseded FAIL does not resurface.
  seed_run "$R" "changes/trial-balance/replay-evidence" "20260821-090000" "trial-balance" "PASS" "2026-08-21" "false"
  assert_not_contains "$(run_next "$R")" "is **FAIL**" \
    "a re-run on the same target supersedes its own earlier verdict here too"

  # Stub taint: a marker on a verdict's standing, never a verdict of its own.
  R="$WORK/taint-next"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "true"
  OUT="$(run_next "$R")"
  assert_contains "$OUT" "ACTIVE dependency-bypass stub" "a tainted verdict is surfaced as human work"
  assert_contains "$OUT" '`PASS*`' "marked PASS*, never presented as a bare PASS"
  # The verdict itself is untouched — taint qualifies standing, not correctness.
  assert_contains "$(run_status "$R")" "latest per target: 1 PASS, 0 not" \
    "while the verdict it qualifies is still counted as the PASS it is"

  R="$WORK/clean-next"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  OUT="$(run_next "$R")"
  assert_not_contains "$OUT" "dependency-bypass stub" "an untainted run is never accused of resting on a stub"
  assert_contains "$OUT" "nothing outstanding" "and a genuinely clean project is told so plainly"
else
  echo "  (skipped — jq not installed)"
fi

# ── 19b. The repo role never contradicts the table under it ──────────────────
#
# REPO_ROLE had two independent writers and they could disagree on one rendered
# page. Both halves are pinned here, because a status view whose header argues
# with its own rows is not a status view.
echo
echo "-- repo role: one page, one answer --"

if command -v jq >/dev/null 2>&1; then
  # (a) A --not-applicable manifest DECLARES the role. Replay evidence beside it
  #     used to flip the header to "rebuild target" — contradicting the row.
  R="$WORK/role-na"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_boot "$R" "this repo is the legacy source"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  OUT="$(run_status "$R")"
  assert_contains "$OUT" "legacy source (bootstrap declared not applicable)" \
    "a --not-applicable declaration is not overruled by a replay run beside it"
  assert_not_contains "$OUT" "**Repo role (inferred):** rebuild target" \
    "and the header never asserts the opposite of what the manifest declared"

  # (b) Replay evidence with nothing to corroborate it: the Target foundation row
  #     reads "not a rebuild target", so the header must not read "rebuild
  #     target". Neither signal is discarded — the disagreement is reported.
  R="$WORK/role-orphan"; new_empty "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  OUT="$(run_status "$R")"
  assert_contains "$OUT" "not a rebuild target" "the Target foundation row still says what it always said"
  assert_not_contains "$OUT" "**Repo role (inferred):** rebuild target" \
    "and the header no longer contradicts it on the same page"
  assert_contains "$OUT" "indeterminate" "the disagreement is named rather than silently resolved"

  # (c) The ordinary rebuild repo is unaffected — this is the case that matters.
  R="$WORK/role-normal"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  assert_contains "$(run_status "$R")" "**Repo role (inferred):** rebuild target" \
    "a real rebuild target still reads as one"

  # (d) And replay evidence still fills in where no manifest has been copied yet.
  R="$WORK/role-nobootstrap"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_backlog "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  assert_contains "$(run_status "$R")" "**Repo role (inferred):** rebuild target" \
    "replay evidence plus a backlog still infers a rebuild target with no manifest present"
else
  echo "  (skipped — jq not installed)"
fi

# ── 20. The failure path emits no guidance at all ────────────────────────────
#
# PD-07, at the two levels it lives at. In the script: a refused invocation
# prints no recommendation. In the skills: every guidance step carries the
# instruction not to run it after a stop — because a `Next:` line printed after
# a refusal reads as though the phase advanced.
echo
echo "-- a run that did not complete emits no next step --"

OUT="$(bash "$STATUS_BIN" "$WORK/does-not-exist" --next 2>&1)"; RC=$?
assert_eq "2" "$RC" "--next on a missing directory exits 2"
assert_not_contains "$OUT" "Next command" "and prints no recommendation"
assert_not_contains "$OUT" "Next action" "and no action either"
assert_contains "$OUT" "/specclaw:init" "only the message naming what would fix it"

OUT="$(bash "$STATUS_BIN" --next 2>&1)"; RC=$?
assert_eq "2" "$RC" "--next with no directory at all exits 2"

# ── 21. The ordering exists in exactly one place ─────────────────────────────
#
# PD-01 as a structural assertion rather than a promise. Every lifecycle skill
# reaches the recommendation through this script, and the three that are not
# lifecycle commands do not carry one at all: bf-status IS this output,
# bf-quality has no phase row, and bf-e2e declares no .specclaw/ artifact.
echo
echo "-- single source of truth, across the skills --"

LIFECYCLE="bf-analyze bf-architecture bf-domain bf-clarify bf-ui bf-baseline
bf-rebuild-plan bf-blueprint bf-bootstrap bf-replay"
for S in $LIFECYCLE; do
  F="$PLUGIN_ROOT/skills/$S/SKILL.md"
  N="$({ grep -cF 'specclaw-bf-status .specclaw --next' "$F" || true; })"
  assert_eq "1" "$N" "$S invokes the shared guidance exactly once"
  assert_contains "$(cat "$F")" "Never work the next step out yourself" \
    "$S is told not to compute an ordering of its own"
  assert_contains "$(cat "$F")" "Only if this run completed" \
    "$S gates its guidance on the run having finished"
done

for S in bf-status bf-quality bf-e2e; do
  F="$PLUGIN_ROOT/skills/$S/SKILL.md"
  N="$({ grep -cF 'specclaw-bf-status .specclaw --next' "$F" || true; })"
  assert_eq "0" "$N" "$S carries no guidance step (not a lifecycle phase)"
done

# ── 22. --next --json: the same computation, as a document ───────────────────
#
# `--json` exists so a caller can BRANCH on this computation instead of reading
# it. Everything here is therefore about two properties:
#
#   - IT ADDS, IT DOES NOT ALTER. The plain block is byte-identical with the
#     flag present or absent, and the JSON's `next.command` is the same string
#     the plain block names. Two renderings, one ordering, no drift — the same
#     invariant section 11 asserts between the dashboard and --next.
#
#   - EVERY REACHABLE STATE IS REPRESENTABLE. A status document that cannot
#     express "a phase is runnable AND a human still owes an answer" would push
#     the caller into guessing, which is exactly what this flag exists to stop.
#     `blocked_by` carries work no command clears; `advisories` carries pointers
#     to a command; `complete` is true only when the plain block says nothing is
#     outstanding at all.
#
# jq is not used here, in either direction: the suite is bash + coreutils, and
# the emitter itself must work without jq, so the assertions read the document
# with grep/sed and validity is checked by whichever of python3/python/jq the
# host happens to have.
echo
echo "-- --next --json --"

run_json() { bash "$STATUS_BIN" "$1/.specclaw" --next --json 2>/dev/null; }

# One top-level scalar/array field, verbatim, from the emitter's fixed one-key-
# per-line layout. Deliberately not a JSON parser: the shape is produced by
# printf in this repo and a parser would hide a layout change rather than fail.
json_field() { # <json> <key>
  # A string value comes back without its quotes so assertions read
  # naturally; an object or a bare literal (null / true / 1) is returned
  # exactly as written.
  printf '%s\n' "$1" | grep -m1 "^  \"$2\": " | sed -E "s/^  \"$2\": //; s/,$//; s/^\"(.*)\"$/\1/"
}
# The first "command" value inside whatever object follows <key>.
json_next_command() { printf '%s\n' "$1" | grep -m1 '^  "next": ' | grep -o '"command": "[^"]*"' | head -1 | sed -E 's/^"command": "//; s/"$//'; }
json_next_key() { printf '%s\n' "$1" | grep -m1 '^  "next": ' | grep -o "\"$2\": [^,}]*" | head -1 | sed -E "s/^\"$2\": //; s/\"//g"; }
# Count of {..} objects in a named array line.
json_count() { printf '%s\n' "$1" | grep -m1 "^  \"$2\": " | grep -o '"kind":' | grep -c . ; }
json_kind1() { printf '%s\n' "$1" | grep -m1 "^  \"$2\": " | grep -o '"kind": "[^"]*"' | head -1 | sed -E 's/^"kind": "//; s/"$//'; }

# A JSON validator, if the host has one. Absence skips the check rather than
# failing it — same degradation rule the script itself follows for jq.
# Each candidate is PROVED against a known-good document before it is
# trusted. On Windows `python3` is routinely a Microsoft Store stub that
# resolves on PATH and then fails on every input, which would report a
# perfectly valid document as invalid.
JSON_OK_CMD=""
for JSON_CAND in "python3 -m json.tool" "python -m json.tool" "jq ."; do
  command -v "${JSON_CAND%% *}" >/dev/null 2>&1 || continue
  if printf '{"a":1}' | $JSON_CAND >/dev/null 2>&1; then
    JSON_OK_CMD="$JSON_CAND"; break
  fi
done

# ---- usage ------------------------------------------------------------------
OUT="$(bash "$STATUS_BIN" "$WORK/does-not-exist" --next --json 2>&1)"; RC=$?
assert_eq "2" "$RC" "--next --json on a missing directory still exits 2"

R="$WORK/json-usage"; new_empty "$R"
OUT="$(bash "$STATUS_BIN" "$R/.specclaw" --json 2>/dev/null)"; RC=$?
assert_eq "2" "$RC" "--json without --next is a usage error"
assert_eq "" "$OUT" "and writes nothing at all to stdout"
ERR="$(bash "$STATUS_BIN" "$R/.specclaw" --json 2>&1 >/dev/null)"
assert_contains "$ERR" "--json requires --next" "naming what is wrong, on stderr"

# An unknown argument that is NOT --json is still ignored, exactly as before.
bash "$STATUS_BIN" "$R/.specclaw" --wat >/dev/null 2>&1
assert_eq "0" "$?" "an unknown second argument is still ignored, not an error"

# ---- the flag changes nothing about the plain rendering ----------------------
R="$WORK/json-parity"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_baseline_recorded "$R"; seed_backlog "$R"
BEFORE_PLAIN="$(run_next "$R")"
run_json "$R" >/dev/null
AFTER_PLAIN="$(run_next "$R")"
assert_eq "$BEFORE_PLAIN" "$AFTER_PLAIN" "running --json does not perturb the plain block"

BEFORE_TREE="$(tree_hash "$R")"
run_json "$R" >/dev/null
assert_eq "$BEFORE_TREE" "$(tree_hash "$R")" "--json writes nothing either"

J="$(run_json "$R")"
assert_eq "0" "$(printf '%s' "$J" | tr -dc '\r' | wc -c | tr -d '[:space:]')" \
  "no carriage return reaches the JSON document"
assert_eq "0" "$(bash "$STATUS_BIN" "$R/.specclaw" --next --json 2>&1 >/dev/null | wc -c | tr -d '[:space:]')" \
  "and nothing is written to stderr alongside it"
assert_eq "1" "$(json_field "$J" schema)" "the document declares its schema"

# ---- one ordering, two renderings ------------------------------------------
#
# The anti-drift assertion. Whatever command the plain block names, the document
# names the same string — never reworded, never re-derived. Section 11 pins the
# dashboard against --next; this pins --json against --next.
for STATE in empty analysis clarified baselined backlogged blueprinted postboot; do
  R="$WORK/json-sot-$STATE"; new_empty "$R"
  case "$STATE" in
    analysis)    seed_analysis "$R" "CONFIRMED by H, 2026-08-07" ;;
    clarified)   seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R" ;;
    baselined)   seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                 seed_baseline_recorded "$R" ;;
    backlogged)  seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                 seed_baseline_recorded "$R"; seed_backlog "$R" ;;
    blueprinted) seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                 seed_baseline_recorded "$R"; seed_backlog "$R"; seed_blueprint "$R" ;;
    postboot)    seed_analysis "$R" "CONFIRMED by H, 2026-08-07"; seed_clarify_done "$R"
                 seed_baseline_recorded "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_boot "$R" ;;
  esac
  J="$(run_json "$R")"
  P_CMD="$({ run_next "$R" | grep -m1 '^\*\*Next command:' || true; } | sed -E 's/.*`([^`]+)`.*/\1/')"
  J_CMD="$(json_next_command "$J")"
  assert_eq "$P_CMD" "$J_CMD" "state '$STATE': the document names the plain block's own command"

  if [ -n "$JSON_OK_CMD" ]; then
    if printf '%s' "$J" | $JSON_OK_CMD >/dev/null 2>&1; then ok "state '$STATE': emits valid JSON"
    else bad "state '$STATE': emits valid JSON" "$JSON_OK_CMD rejected it"; fi
  fi

  # THE EXCLUSIVITY INVARIANT: `complete` is a claim that nothing is
  # outstanding, so it may never be true beside a recommendation or a blocker.
  C="$(json_field "$J" complete)"
  if [ "$C" = "true" ]; then
    assert_eq "null" "$(json_field "$J" next)" "state '$STATE': complete never co-occurs with a next"
    assert_eq "0" "$(json_count "$J" blocked_by)" "state '$STATE': nor with a blocker"
    assert_eq "0" "$(json_count "$J" advisories)" "state '$STATE': nor with an advisory"
  fi
done

# ---- a runnable phase -------------------------------------------------------
R="$WORK/json-runnable"; new_empty "$R"
J="$(run_json "$R")"
assert_eq "/specclaw:bf-analyze" "$(json_next_command "$J")" "an untouched project names bf-analyze"
assert_eq "true"     "$(json_next_key "$J" runnable)" "a bare bf-* verb is runnable"
assert_eq "bf-phase" "$(json_next_key "$J" reason)"   "and is classified as a phase"
assert_eq "false"    "$(json_field "$J" complete)"    "and the project is not complete"
assert_eq "0" "$(json_count "$J" blocked_by)" "with nothing blocking it"
assert_contains "$J" '"why": "no codebase-report.md' "the reason the plain block gives travels with it"

# Every bf-* phase the progression walks through is runnable.
R="$WORK/json-prog"; new_empty "$R"
for STEP in analyze architecture domain clarify baseline rebuild-plan; do
  J="$(run_json "$R")"
  CMD="$(json_next_command "$J")"
  case "$CMD" in
    "/specclaw:bf-"*" "*) assert_eq "false" "$(json_next_key "$J" runnable)" "flagged '$CMD' is never runnable" ;;
    "/specclaw:bf-"*)     assert_eq "true"  "$(json_next_key "$J" runnable)" "bare '$CMD' is runnable" ;;
    *) bad "progression names a bf-* command at step $STEP" "got [$CMD]" ;;
  esac
  case "$STEP" in
    analyze)      printf '**Date generated:** 2026-08-01\n' > "$R/.specclaw/analysis/codebase-report.md" ;;
    architecture) printf '**Date generated:** 2026-08-01\n' > "$R/.specclaw/analysis/architecture.md" ;;
    domain)       seed_analysis "$R" "CONFIRMED by H, 2026-08-07" ;;
    clarify)      seed_clarify_done "$R" ;;
    baseline)     seed_baseline_recorded "$R" ;;
    rebuild-plan) seed_backlog "$R" ;;
  esac
done

# ---- a flagged command is reported, never marked runnable -------------------
#
# `--resolve` is the only flag this script ever recommends, and it encodes a
# decision a human makes. It is a real bf-* verb, so it is NOT the lifecycle
# boundary either — the two must stay distinguishable or a caller would announce
# that brownfield preparation had finished in the middle of Phase A.
R="$WORK/json-flagged"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-001 — Answered
- **Blocking:** yes — the stack
- **Answer:** .NET 9
- **Decided by:** H, 2026-08-05
EOF
seed_baseline_recorded "$R"; seed_backlog "$R"
J="$(run_json "$R")"
assert_eq "/specclaw:bf-clarify --resolve" "$(json_next_command "$J")" "the flagged form is named exactly as the plain block names it"
assert_eq "false" "$(json_next_key "$J" runnable)" "a flagged command is never runnable"
assert_eq "needs-human-flags" "$(json_next_key "$J" reason)" "and is distinguished from the lifecycle boundary"

# ---- the lifecycle boundary -------------------------------------------------
R="$WORK/json-boundary"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
J="$(run_json "$R")"
P_CMD="$({ run_next "$R" | grep -m1 '^\*\*Next command:' || true; } | sed -E 's/.*`([^`]+)`.*/\1/')"
assert_eq "$P_CMD" "$(json_next_command "$J")" "a ready foundation names whatever the plain block names there"
assert_eq "false" "$(json_next_key "$J" runnable)" "the boundary command is never runnable"
assert_eq "lifecycle-boundary" "$(json_next_key "$J" reason)" "and says why"
assert_eq "false" "$(json_field "$J" complete)" "a handoff is not completion"
assert_contains "$J" '"after": "/specclaw:bf-replay <change>"' "the After line the plain block prints is carried, not dropped"

# ---- human work is human work ----------------------------------------------
R="$WORK/json-human"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
cat > "$R/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

### SQ-014 — Unanswered, blocking
- **Blocking:** yes — every fixture
- **Answer:**
- **Decided by:**
EOF
printf '# Decisions\n' > "$R/.specclaw/analysis/decisions.md"
J="$(run_json "$R")"
assert_eq "human" "$(json_kind1 "$J" blocked_by)" "an unanswered blocking question is human work"
assert_contains "$J" 'Answer 1 blocking question(s)' "carrying the plain block's own sentence, not a new one"
assert_eq "false" "$(json_field "$J" complete)" "and the project is not complete"

# A runnable phase and an open human item COEXIST, and neither hides the other.
# This is the state the plain block has always rendered as a Next action beside
# a Next command, and section 14 asserts that co-occurrence deliberately.
R="$WORK/json-both"; new_empty "$R"; seed_analysis "$R" "PROPOSED"
J="$(run_json "$R")"
assert_eq "human" "$(json_kind1 "$J" blocked_by)" "an unconfirmed module map is human work"
assert_contains "$J" "Confirm the module map" "named as the plain block names it"
assert_eq "true" "$(json_next_key "$J" runnable)" "while the phase command beside it is still runnable"
assert_contains "$J" '"command": "/specclaw:bf-clarify"' "and is still named"

# ---- the repo boundary ------------------------------------------------------
R="$WORK/json-repo"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_baseline_recorded "$R"; seed_backlog "$R"; seed_blueprint "$R"
J="$(run_json "$R")"
assert_eq "repo-boundary" "$(json_kind1 "$J" blocked_by)" "the Phase B handoff is a repo boundary, not ordinary human work"
assert_eq "null" "$(json_field "$J" next)" "and names no command in this repo"
assert_contains "$J" "copy the Phase A artifacts" "carrying the plain block's own wording"
assert_contains "$J" '"command": "/specclaw:bf-bootstrap"' "with the command it hands off to"

# ---- a pointer to a command is not a blocker -------------------------------
#
# The state that has no Next command and no Next action at all, only a
# command-kind attention item. It is not complete, and it is not blocked on a
# human: a caller that treated it as either would be wrong in opposite
# directions, so it is reported as an advisory.
R="$WORK/json-advisory"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
seed_clarify_done "$R"; seed_baseline_recorded "$R"; seed_backlog "$R"; seed_blueprint "$R"
mkdir -p "$R/.specclaw/bootstrap"
printf '{"not_applicable":null,"foundation_ready":false}\n' > "$R/.specclaw/bootstrap/bootstrap-manifest.json"
if command -v jq >/dev/null 2>&1; then
  J="$(run_json "$R")"
  assert_eq "false" "$(json_field "$J" complete)" "an unready foundation is never reported as complete"
  assert_eq "null"  "$(json_field "$J" next)" "no command is recommended there"
  assert_eq "0"     "$(json_count "$J" blocked_by)" "and nothing is blocked on a human"
  assert_eq "command" "$(json_kind1 "$J" advisories)" "the pointer to a command is an advisory"
else
  echo "  (skipped — jq not installed)"
fi

# ---- genuine completion -----------------------------------------------------
if command -v jq >/dev/null 2>&1; then
  R="$WORK/json-complete"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_clarify_done "$R"; seed_backlog "$R"; seed_blueprint "$R"; seed_baseline_recorded "$R"; seed_boot "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  J="$(run_json "$R")"
  assert_contains "$(run_next "$R")" "nothing outstanding" "the plain block reports nothing outstanding"
  assert_eq "true" "$(json_field "$J" complete)" "and the document agrees"
  assert_eq "null" "$(json_field "$J" next)" "with no command"
  assert_eq "0" "$(json_count "$J" blocked_by)" "no blocker"
  assert_eq "0" "$(json_count "$J" advisories)" "and no advisory"

  # ---- repo_role ------------------------------------------------------------
  assert_eq "rebuild" "$(json_field "$J" repo_role)" "a scaffolded repo reads as the rebuild target"
  assert_eq "false"   "$(json_field "$J" degraded)"  "and is not degraded while jq is present"

  R="$WORK/json-role-na"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
  seed_boot "$R" "this repo is the legacy source"
  assert_eq "legacy" "$(json_field "$(run_json "$R")" repo_role)" \
    "a --not-applicable declaration reads as legacy"

  R="$WORK/json-role-orphan"; new_empty "$R"
  seed_run "$R" "replay/evidence" "20260820-101500" "MOD-001" "PASS" "2026-08-20" "false"
  assert_eq "unknown" "$(json_field "$(run_json "$R")" repo_role)" \
    "replay evidence with nothing to corroborate it stays indeterminate"
else
  echo "  (skipped — jq not installed)"
fi

# Before any Phase B artifact exists, Phase A runs against legacy source by
# construction. Once a backlog exists it does not: the backlog is COPIED into
# the rebuild repo, so the same signal describes both repos and the honest
# answer is that this one cannot tell.
R="$WORK/json-role-early"; new_empty "$R"; seed_analysis "$R" "CONFIRMED by H, 2026-08-07"
assert_eq "legacy" "$(json_field "$(run_json "$R")" repo_role)" \
  "a repo with no backlog and no Phase B artifact reads as legacy"
seed_clarify_done "$R"; seed_baseline_recorded "$R"; seed_backlog "$R"
assert_eq "unknown" "$(json_field "$(run_json "$R")" repo_role)" \
  "but once a backlog exists the same signal cannot tell the two repos apart"

echo
echo "=================================================="
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
