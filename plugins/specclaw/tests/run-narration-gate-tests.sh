#!/usr/bin/env bash
# run-narration-gate-tests.sh — regression suite for the model-invocation
# opt-out (change 039): the config switch that turns bf-quality's narration
# agent off, the deterministic renderer that replaces it, and the T8 fix for
# the lint that checks the renderer's output.
#
# WHAT WOULD HURT IF THIS BROKE.
#
#   1. Config reading. `bf.narration` is read with the shared, dotted-path
#      `yaml_val` (bin/specclaw-build), which reduces a key to <section>.<field>
#      and scopes the field lookup to that section only. This repo has already
#      shipped the OTHER kind of yaml reader — `yaml_val` in specclaw-loop /
#      specclaw-party's pre-fix state — that reduces a dotted key to its LAST
#      component and greps the whole file, so a decoy `narration:` in an
#      earlier, unrelated block silently wins (the "party lesson": see
#      plugins/specclaw/CLAUDE.md, "Party config reads"). If `bf.narration`
#      regressed to that shape, a project with `workflow.narration: true`
#      declared above its `bf:` block would never be able to switch narration
#      off, and nothing would say why.
#
#   2. The switch's failure direction. Only the literal string `false` may
#      disable narration; every typo, alias (`off`/`no`/`0`), or absent key
#      must leave it ON. A model spawn is expensive but recoverable; a report
#      nobody knows was left unwritten is not.
#
#   3. The renderer. When narration is off, `specclaw-bf-quality-render` must
#      still hand back a report that passes the SAME lint the narrated path is
#      held to — three sections pasted byte-identical from the artifact, no
#      leftover `{{placeholder}}`, no template instruction comment bleeding
#      into a client-facing document.
#
#   4. The T8 regression: `lint-report` reading a QI-### registry that
#      legitimately holds zero entries (any repo with no metric tools
#      installed, e.g. this CI machine) used to abort SILENTLY — rc=1, no
#      stdout, no stderr — because `set -euo pipefail` killed the script on a
#      `grep` that correctly found nothing. The exit code alone would not have
#      caught this: a script that dies for the RIGHT reason and one that dies
#      because its own tooling choked both exit 1. Only "did it print
#      anything" tells them apart.
#
# jq-free, per the repo's rule for test suites (tests/*.sh stay jq-free;
# run-parser-tests.sh is the one shell-out exception). JSON fields are read
# with python3; the anchored-region extraction is copied verbatim from
# specclaw-bf-quality-collect's own `report_block_region` — reusing the repo's
# own helper rather than re-deriving it.
#
# Run from anywhere:
#   bash plugins/specclaw/tests/run-narration-gate-tests.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_DIR/bin"

BUILD_BIN="$BIN_DIR/specclaw-build"
RENDER_BIN="$BIN_DIR/specclaw-bf-quality-render"
COLLECT_BIN="$BIN_DIR/specclaw-bf-quality-collect"
INIT_BIN="$BIN_DIR/specclaw-init"

for f in "$BUILD_BIN" "$RENDER_BIN" "$COLLECT_BIN" "$INIT_BIN"; do
  if [[ ! -f "$f" ]]; then
    echo "FATAL: missing bin script: $f" >&2
    exit 2
  fi
done

WORK="$(mktemp -d "${TMPDIR:-/tmp}/narration-gate-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
SKIP=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP + 1)); }

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

# ═══════════════════════════════════════════════════════════════════════════
# GROUP A — config reading: yaml_val on the bf: block (AC-7, AC-8)
# ═══════════════════════════════════════════════════════════════════════════
#
# yaml_val is duplicated between specclaw-build and specclaw-bf-quality-render
# (not byte-identical today — a pre-existing gap outside this task's scope).
# This suite exercises the copy in specclaw-build, since that is the "existing
# yaml_val convention" skills/bf-quality/SKILL.md Step 2 names, and the file
# this task points at.
YAML_VAL_SRC="$WORK/yaml_val.sh"
sed -n '/^yaml_val() {/,/^}/p' "$BUILD_BIN" > "$YAML_VAL_SRC"
if [[ ! -s "$YAML_VAL_SRC" ]]; then
  echo "FATAL: could not extract yaml_val() from $BUILD_BIN" >&2
  exit 2
fi

yv() {
  local file="$1" key="$2"
  # shellcheck disable=SC1090  # dynamically extracted into $WORK at runtime
  ( source "$YAML_VAL_SRC"; yaml_val "$file" "$key" )
}

# ── A config carrying THREE decoy `narration:` keys, each in an unrelated
# top-level section, all placed BEFORE the real `bf:` block. A last-component,
# whole-file grep (the defect this repo already fixed once, for party_val)
# would return the first one it meets — "true" — instead of refusing all
# three and reading the one inside `bf:`.
CFG_MAIN="$WORK/config-main.yaml"
cat > "$CFG_MAIN" <<'EOF'
project:
  name: "demo"

workflow:
  strict: true
  narration: true

party:
  enabled: true
  narration: yes

quality:
  complexity_warn: 10
  narration: 0

bf:
  narration: false   # save tokens
  target_dir: "legacy"
  compare_gate: true
EOF

assert_eq "A1 bf.narration reads exactly 'false' — three decoys above it and its own inline comment stripped" \
  "false" "$(yv "$CFG_MAIN" bf.narration)"
assert_eq "A2 a neighbouring bf key still reads correctly (target_dir)" \
  "legacy" "$(yv "$CFG_MAIN" bf.target_dir)"
assert_eq "A3 and another neighbouring bf key (compare_gate)" \
  "true" "$(yv "$CFG_MAIN" bf.compare_gate)"
assert_eq "A4 the workflow decoy is a real value in its own section" \
  "true" "$(yv "$CFG_MAIN" workflow.narration)"
assert_eq "A5 the party decoy is a real value in its own section" \
  "yes" "$(yv "$CFG_MAIN" party.narration)"
assert_eq "A6 the quality decoy is a real value in its own section" \
  "0" "$(yv "$CFG_MAIN" quality.narration)"

# ── the switch semantics: only the literal string "false" disables ─────────
narration_on() {
  # Test-local re-implementation of SKILL.md Step 2's one-line rule — "Only
  # the literal string 'false' takes the deterministic path" — not a copy of
  # the skill's logic. Pins the RULE, independent of how the skill is worded.
  local v="$1"
  if [[ "$v" == "false" ]]; then
    echo "off"
  else
    echo "on"
  fi
}

mk_bf_cfg() {  # mk_bf_cfg <path> <value|ABSENT>
  local path="$1" val="$2"
  if [[ "$val" == "ABSENT" ]]; then
    printf 'project:\n  name: "demo"\n\nbf:\n  target_dir: "legacy"\n' > "$path"
  else
    printf 'project:\n  name: "demo"\n\nbf:\n  narration: %s\n' "$val" > "$path"
  fi
}

CFG_OFF="$WORK/cfg-off.yaml";       mk_bf_cfg "$CFG_OFF" "off"
CFG_NO="$WORK/cfg-no.yaml";         mk_bf_cfg "$CFG_NO" "no"
CFG_ZERO="$WORK/cfg-zero.yaml";     mk_bf_cfg "$CFG_ZERO" "0"
CFG_EMPTY="$WORK/cfg-empty.yaml";   mk_bf_cfg "$CFG_EMPTY" ""
CFG_ABSENT="$WORK/cfg-absent.yaml"; mk_bf_cfg "$CFG_ABSENT" "ABSENT"
CFG_FALSE="$WORK/cfg-false.yaml";   mk_bf_cfg "$CFG_FALSE" "false"
CFG_TRUE="$WORK/cfg-true.yaml";     mk_bf_cfg "$CFG_TRUE" "true"

assert_eq "A7 bf.narration: off leaves narration ON"            "on"  "$(narration_on "$(yv "$CFG_OFF" bf.narration)")"
assert_eq "A8 bf.narration: no leaves narration ON"             "on"  "$(narration_on "$(yv "$CFG_NO" bf.narration)")"
assert_eq "A9 bf.narration: 0 leaves narration ON"              "on"  "$(narration_on "$(yv "$CFG_ZERO" bf.narration)")"
assert_eq "A10 bf.narration: (empty) leaves narration ON"       "on"  "$(narration_on "$(yv "$CFG_EMPTY" bf.narration)")"
assert_eq "A11 an absent bf.narration key leaves narration ON"  "on"  "$(narration_on "$(yv "$CFG_ABSENT" bf.narration)")"
assert_eq "A12 bf.narration: true leaves narration ON (sanity)" "on"  "$(narration_on "$(yv "$CFG_TRUE" bf.narration)")"
assert_eq "A13 only the literal false disables narration"      "off" "$(narration_on "$(yv "$CFG_FALSE" bf.narration)")"

# ── --no-model in ARGUMENTS: forces off; never forces back on ──────────────
should_narrate() {
  # Test-local re-implementation of SKILL.md Step 2's second rule: a
  # --no-model token anywhere in ARGUMENTS forces the deterministic path
  # regardless of config, and no token forces narration back ON against
  # bf.narration: false — an opt-out may be tightened for a single run, never
  # loosened back on.
  local cfg_val="$1" arguments="$2"
  if [[ "$arguments" == *"--no-model"* ]]; then
    echo "off"
    return
  fi
  narration_on "$cfg_val"
}

assert_eq "A14 --no-model forces the deterministic path even when config says narrate" \
  "off" "$(should_narrate "true" "--no-model")"
assert_eq "A15 no ARGUMENTS token turns narration back on against bf.narration: false (the asymmetry)" \
  "off" "$(should_narrate "false" "--model --narrate --force-narration")"
assert_eq "A16 --no-model on an already-false config changes nothing (still off)" \
  "off" "$(should_narrate "false" "--no-model")"
assert_eq "A17 with no --no-model and narration on, the config value alone decides (sanity)" \
  "on" "$(should_narrate "true" "")"
assert_eq "A18 full path: real config (false) + no ARGUMENTS token → deterministic" \
  "off" "$(should_narrate "$(yv "$CFG_FALSE" bf.narration)" "")"
assert_eq "A19 full path: real config (true) + --no-model → deterministic anyway" \
  "off" "$(should_narrate "$(yv "$CFG_TRUE" bf.narration)" "--no-model")"

# ═══════════════════════════════════════════════════════════════════════════
# GROUPS B–D — the renderer, the lint, and the T8 zero-entry-registry
# regression (AC-5, AC-6, AC-11). Skipped, loudly, if a genuine dependency
# (jq / python3 / git) is unavailable — never silently.
# ═══════════════════════════════════════════════════════════════════════════
MISSING=""
command -v jq      >/dev/null 2>&1 || MISSING="${MISSING}jq "
command -v python3 >/dev/null 2>&1 || MISSING="${MISSING}python3 "
command -v git      >/dev/null 2>&1 || MISSING="${MISSING}git "

if [[ -n "$MISSING" ]]; then
  skip "Groups B-D (renderer, lint, T8 registry regression) — missing on PATH: ${MISSING}"
else
  PROJECT="$WORK/render-proj"
  mkdir -p "$PROJECT"
  (
    cd "$PROJECT" || exit 1
    git init -q
    git config user.email "narration-gate-tests@example.com"
    git config user.name "narration-gate-tests"
    printf 'def f():\n    return 1\n' > main.py
    printf 'print("hi")\n' > util.py
    git add -A
    git commit -qm init -q
  ) >/dev/null 2>&1

  # specclaw-init takes the PROJECT dir, not the .specclaw dir — the trap the
  # orchestrator already hit once.
  "$INIT_BIN" "$PROJECT" >"$WORK/init.out" 2>"$WORK/init.err"
  assert_eq "B1 specclaw-init succeeds on the scratch project" "0" "$?"

  COLLECT_ERR="$WORK/collect.err"
  ( cd "$PROJECT" && "$COLLECT_BIN" collect .specclaw . ) >"$WORK/collect.out" 2>"$COLLECT_ERR"
  assert_eq "B2 collect exits 0 with no metric tools on PATH (advisory, never fails on that)" "0" "$?"

  QJSON="$PROJECT/.specclaw/analysis/quality.json"
  if [[ -f "$QJSON" ]]; then pass "B3 quality.json was written"; else fail "B3 quality.json was written"; fi

  ( cd "$PROJECT" && "$RENDER_BIN" .specclaw --mode legacy ) >"$WORK/render.out" 2>"$WORK/render.err"
  assert_eq "B4 specclaw-bf-quality-render exits 0" "0" "$?"

  REPORT="$PROJECT/.specclaw/analysis/quality-report.md"
  if [[ -f "$REPORT" ]]; then pass "B5 quality-report.md was written"; else fail "B5 quality-report.md was written"; fi

  # report_block_region — copied verbatim from specclaw-bf-quality-collect,
  # the repo's own helper, so the extraction semantics here are exactly the
  # lint's own (including its trailing-blank-line trim).
  report_block_region() {
    local report="$1" name="$2"
    awk -v b="<!-- quality-report:${name}:begin -->" -v e="<!-- quality-report:${name}:end -->" '
      index($0, b) == 1 { inb = 1; next }
      index($0, e) == 1 { inb = 0; next }
      inb { print }
    ' "$report" | tr -d '\r' | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}'
  }

  json_field() {  # json_field <quality.json> <report_blocks field>
    python3 -c '
import json, sys
with open(sys.argv[1]) as fh:
    data = json.load(fh)
sys.stdout.write((data.get("report_blocks") or {}).get(sys.argv[2], ""))
' "$1" "$2"
  }

  trim_trailing_blank() {
    printf '%s' "$1" | sed -e :a -e '/^[[:space:]]*$/{$d;N;ba' -e '}'
  }

  for pair in "scan-funnel:scan_funnel_md" "module-rollup:module_rollup_md" "coverage-sentence:coverage_sentence_md"; do
    anchor="${pair%%:*}"; field="${pair##*:}"
    got="$(report_block_region "$REPORT" "$anchor")"
    want="$(trim_trailing_blank "$(json_field "$QJSON" "$field")")"
    assert_eq "B6 the ${anchor} region is byte-identical to report_blocks.${field}" "$want" "$got"
  done

  REPORT_TEXT="$(cat "$REPORT")"
  assert_contains "B7 the deterministic marker appears in the rendered report" \
    '_Not narrated — deterministic mode. Facts below are collector output._' "$REPORT_TEXT"

  if grep -qE '\{\{[A-Za-z_]+\}\}' "$REPORT"; then
    fail "B8 no {{placeholder}} remains in the rendered report"
  else
    pass "B8 no {{placeholder}} remains in the rendered report"
  fi

  if grep -qE '^[[:space:]]*<!--[[:space:]]*$' "$REPORT"; then
    fail "B9 no template instruction comment survives rendering"
  else
    pass "B9 no template instruction comment survives rendering"
  fi

  # ── C: the acceptance test for the renderer's own output ─────────────────
  LINT_OUT="$( "$COLLECT_BIN" lint-report "$PROJECT/.specclaw" "$REPORT" "$QJSON" 2>&1 )"
  LINT_RC=$?
  assert_eq "C1 lint-report exits 0 on the rendered report" "0" "$LINT_RC"
  assert_contains "C2 lint-report prints a PASS verdict" "REPORT-LINT: PASS" "$LINT_OUT"

  # ── D: the T8 regression — zero-entry registry must not abort silently ──
  REGISTRY="$PROJECT/.specclaw/analysis/quality-issues.md"
  QI_COUNT="$(grep -c '^### QI-' "$REGISTRY" 2>/dev/null || true)"
  QI_COUNT="${QI_COUNT:-0}"
  assert_eq "D1 the fresh registry legitimately holds zero QI-### entries (no metric tools installed)" \
    "0" "$QI_COUNT"

  D_OUT="$( "$COLLECT_BIN" lint-report "$PROJECT/.specclaw" "$REPORT" "$QJSON" 2>&1 )"
  D_RC=$?
  assert_eq "D2 lint-report against a zero-entry registry exits 0 (pre-T8: silent rc=1)" "0" "$D_RC"
  if [[ -n "$D_OUT" ]]; then
    pass "D3 lint-report against a zero-entry registry prints output (pre-T8: no stdout, no stderr at all)"
  else
    fail "D3 lint-report against a zero-entry registry prints output (pre-T8: no stdout, no stderr at all)"
  fi
  assert_contains "D4 and the verdict is PASS" "REPORT-LINT: PASS" "$D_OUT"

  # A one-entry registry must still pass — the fix must not have traded one
  # failure (silent abort on zero) for another (breaking the normal case).
  cp "$REGISTRY" "$WORK/registry.orig"
  python3 - "$REGISTRY" <<'PYEOF'
import sys
path = sys.argv[1]
marker = "_No hotspot has ever reached the registering severity band for this codebase._"
entry = (
    "### QI-001\n\n"
    "- **Key:** file_length|main.py|*global*|MOD-UNASSIGNED|1\n"
    "- **Module:** MOD-UNASSIGNED\n"
    "- **File:** main.py\n"
    "- **Function:** —\n"
    "- **Line:** 1\n"
    "- **Metric:** file_length\n"
    "- **Value:** 1200\n"
    "- **Severity:** HIGH\n"
    "- **Status:** open\n"
    "- **First seen:** 2026-01-01T00:00:00Z\n"
    "- **Last checked:** 2026-01-01T00:00:00Z\n"
)
with open(path) as fh:
    text = fh.read()
if marker not in text:
    sys.exit("marker not found in registry fixture")
text = text.replace(marker, entry, 1)
with open(path, "w") as fh:
    fh.write(text)
PYEOF
  assert_eq "D5 synthetic one-entry registry fixture built" "0" "$?"

  D2_OUT="$( "$COLLECT_BIN" lint-report "$PROJECT/.specclaw" "$REPORT" "$QJSON" 2>&1 )"
  D2_RC=$?
  assert_eq "D6 lint-report against a one-entry registry still exits 0" "0" "$D2_RC"
  assert_contains "D7 and still PASSes" "REPORT-LINT: PASS" "$D2_OUT"

  cp "$WORK/registry.orig" "$REGISTRY"
fi

# ═══════════════════════════════════════════════════════════════════════════
# GROUP E — repo-wide invariant: no bf-*/SKILL.md tells the agent to read the
# collector's stdout / the "collected JSON" instead of the on-disk artifact
# (AC-1).
# ═══════════════════════════════════════════════════════════════════════════
E_MATCHES="$(grep -rl 'collected JSON\|stdout of Step' "$PLUGIN_DIR"/skills/bf-*/SKILL.md 2>/dev/null || true)"
if [[ -z "$E_MATCHES" ]]; then
  pass "E1 no bf-*/SKILL.md tells the agent to read the collector's stdout / the collected JSON"
else
  fail "E1 the following files still say it: ${E_MATCHES}"
fi

# ═══════════════════════════════════════════════════════════════════════════
# GROUP F — specclaw-init's .collect/ gitignore block is idempotent (AC-10).
# ═══════════════════════════════════════════════════════════════════════════
IDEM_PROJECT="$WORK/idem-proj"
mkdir -p "$IDEM_PROJECT"
{
  printf '\n# specclaw: bf-* collector handoff files. Regenerated every run.\n'
  printf '.specclaw/analysis/.collect/\n'
} > "$IDEM_PROJECT/.gitignore"

"$INIT_BIN" "$IDEM_PROJECT" >"$WORK/idem-init.out" 2>"$WORK/idem-init.err"
assert_eq "F1 specclaw-init still succeeds when the .collect/ ignore block pre-exists" "0" "$?"

IDEM_COUNT="$(grep -c '\.specclaw/analysis/\.collect/' "$IDEM_PROJECT/.gitignore" 2>/dev/null || true)"
IDEM_COUNT="${IDEM_COUNT:-0}"
assert_eq "F2 the .collect/ ignore line appears exactly once — init added nothing" "1" "$IDEM_COUNT"

# ═══════════════════════════════════════════════════════════════════════════
# GROUP G — the duplicated helpers stay byte-identical.
#
# This repo deliberately copies helper functions between standalone executables
# (there is no sourcing convention between them) and keeps the copies identical
# so a fix in one is a visible, greppable fix in all. specclaw-bf-quality-render
# carries two such copies: `substitute` from specclaw-bf-quality-collect and
# `yaml_val` from specclaw-build.
#
# This is pinned because the drift already happened once, during this very
# change: the first cut of the renderer "tidied" its yaml_val copy — dropped the
# comments, swapped `echo` for `printf '%s'`, collapsed the quote-stripping onto
# one line — while its own comment still claimed it was copied verbatim. Nothing
# would have caught that. The function bodies are compared, not the SC2295
# disable directive that sits ABOVE the definition and is deliberately local.
# ═══════════════════════════════════════════════════════════════════════════
extract_fn() { sed -n "/^$1() {/,/^}/p" "$2"; }

extract_fn yaml_val "$BIN_DIR/specclaw-build"             > "$WORK/yv-canonical.sh"
extract_fn yaml_val "$BIN_DIR/specclaw-bf-quality-render" > "$WORK/yv-render.sh"
if diff -q "$WORK/yv-canonical.sh" "$WORK/yv-render.sh" >/dev/null 2>&1; then
  pass "G1 yaml_val in specclaw-bf-quality-render is byte-identical to specclaw-build's"
else
  fail "G1 yaml_val in specclaw-bf-quality-render has drifted from specclaw-build's"
  diff "$WORK/yv-canonical.sh" "$WORK/yv-render.sh" | head -20
fi

extract_fn substitute "$BIN_DIR/specclaw-bf-quality-collect" > "$WORK/sub-canonical.sh"
extract_fn substitute "$BIN_DIR/specclaw-bf-quality-render"  > "$WORK/sub-render.sh"
if diff -q "$WORK/sub-canonical.sh" "$WORK/sub-render.sh" >/dev/null 2>&1; then
  pass "G2 substitute in specclaw-bf-quality-render is byte-identical to the collector's"
else
  fail "G2 substitute in specclaw-bf-quality-render has drifted from the collector's"
  diff "$WORK/sub-canonical.sh" "$WORK/sub-render.sh" | head -20
fi

# The canonical copy must be non-empty, or a typo'd function name would make
# both sides empty and the comparison would pass by matching nothing.
if [[ -s "$WORK/yv-canonical.sh" && -s "$WORK/sub-canonical.sh" ]]; then
  pass "G3 both canonical helper extractions are non-empty (the comparison is real)"
else
  fail "G3 a canonical helper extraction came back empty — G1/G2 proved nothing"
fi

# ═══════════════════════════════════════════════════════════════════════════
# GROUP H — the audit's line citations still point at real spawn sites.
#
# references/model-invocation-map.md cites a SKILL.md:<line> per row. Those
# numbers went stale inside the change that created the table: T4 inserted an
# `mkdir -p` line and an exit-status sentence at each of fifteen sites, moving
# every citation below them by one to three lines, and nothing noticed until a
# reviewer checked by hand. The quoted evidence is the real anchor, but a wrong
# line number sends the next reader to a blank line and costs their trust in
# the whole table.
# ═══════════════════════════════════════════════════════════════════════════
MAP="$PLUGIN_DIR/references/model-invocation-map.md"
if [[ -f "$MAP" ]]; then
  # Only the SPAWN-COLUMN citations, which are written without the `skills/`
  # prefix. Prose evidence citations carry that prefix and no line number: their
  # anchor is the quoted sentence, which no edit can silently move.
  cites="$(grep -oE '(^|[^/])bf-[a-z0-9-]+/SKILL\.md:[0-9]+' "$MAP" | grep -oE 'bf-[a-z0-9-]+/SKILL\.md:[0-9]+' | sort -u)"
  cite_n="$(printf '%s\n' "$cites" | grep -c . || true)"
  bad=""
  while IFS= read -r c; do
    [[ -n "$c" ]] || continue
    f="$PLUGIN_DIR/skills/${c%%:*}"
    l="${c##*:}"
    if [[ ! -f "$f" ]] || ! sed -n "${l}p" "$f" 2>/dev/null | grep -q 'subagent_type'; then
      bad="$bad $c"
    fi
  done <<< "$cites"

  if [[ "$cite_n" -lt 19 ]]; then
    fail "H1 the audit cites all 19 spawn sites (found $cite_n — did the table shrink, or did a name with a digit slip a [a-z-] class again?)"
  elif [[ -z "$bad" ]]; then
    pass "H1 all $cite_n cited SKILL.md lines still hold a subagent_type spawn"
  else
    fail "H1 stale citation(s) in model-invocation-map.md:$bad"
  fi
else
  fail "H1 references/model-invocation-map.md is missing"
fi

echo
echo "─────────────────────────────"
echo "PASS: $PASS   FAIL: $FAIL   SKIP: $SKIP"
[[ "$FAIL" -eq 0 ]] || exit 1
