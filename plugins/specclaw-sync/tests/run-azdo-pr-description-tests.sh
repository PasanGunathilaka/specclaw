#!/usr/bin/env bash
# run-azdo-pr-description-tests.sh — regression suite for the character budget
# on specclaw-azdo-pr's PR description (change 041).
#
# Azure DevOps rejects a PR whose `description` exceeds 4,000 characters, and
# it does so at the very last step of the lifecycle, after every gate passed.
# This suite pins:
#
#   AC1  oversized artifacts yield a description <= the default budget (3900)
#   AC2  the verdict line and footer survive; truncation pointers name real files
#   AC3  small inputs are byte-identical to the pre-change output (golden)
#   AC4  azdo.pr_description_max overrides the budget
#   AC5  one enormous line still fits, with a stderr WARNING
#   AC6  low-value sections shrink before Summary is touched
#
# The functions are extracted from bin/specclaw-azdo-pr and run against fixture
# change dirs — no network, no auth, no lock.
#
# Plain bash + coreutils only. Run from anywhere:
#   bash plugins/specclaw/tests/run-azdo-pr-description-tests.sh
# Exits non-zero if any case fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
AZDO_PR_BIN="$BIN_DIR/specclaw-azdo-pr"
GOLDEN="$SCRIPT_DIR/fixtures/azdo-pr-description/small.golden"

for f in "$AZDO_PR_BIN" "$GOLDEN"; do
  if [[ ! -f "$f" ]]; then
    echo "FATAL: missing file: $f" >&2
    exit 2
  fi
done

# Count characters, not bytes, wherever a UTF-8 locale exists.
for loc in C.UTF-8 en_US.UTF-8; do
  if [[ "$(LC_ALL=$loc bash -c 'v=é; echo ${#v}' 2>/dev/null)" == 1 ]]; then export LC_ALL="$loc"; break; fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

FNS="$WORK/fns.sh"
extract_fn() { sed -n "/^$1() {/,/^}/p" "$2"; }
for fn in yaml_val extract_section assemble_description fit_description build_pr_description; do
  extract_fn "$fn" "$AZDO_PR_BIN" >> "$FNS"
done
grep -q '^build_pr_description() {' "$FNS" || { echo "FATAL: could not extract build_pr_description()" >&2; exit 2; }

# render <specclaw_dir> <change> <policy> — prints the description on stdout,
# stderr to $WORK/stderr.
render() {
  (
    SPECCLAW_DIR="$1"; CHANGE_NAME="$2"
    CHANGE_DIR="$SPECCLAW_DIR/changes/$CHANGE_NAME"
    CONFIG_FILE="$SPECCLAW_DIR/config.yaml"
    SCRIPT_DIR="$WORK/no-bin"   # no specclaw-timer here: timeline.md is read as-is
    warn() { echo "WARNING: $*" >&2; }
    # shellcheck disable=SC1090  # dynamically extracted into $WORK at runtime
    source "$FNS"
    build_pr_description "$3"
  ) 2> "$WORK/stderr"
}

# para <n> <word> — n lines of ~100 chars each
para() {
  local i
  for ((i = 1; i <= $1; i++)); do
    printf -- '- %s line %03d: lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor.\n' "$2" "$i"
  done
}

# ── Small fixture (AC3) ─────────────────────────────────────────────────────
SMALL="$WORK/small/.specclaw"
mkdir -p "$SMALL/changes/007-small"
printf 'project:\n  name: t\n' > "$SMALL/config.yaml"
cat > "$SMALL/changes/007-small/proposal.md" <<'EOF'
# Proposal: Small thing

## Problem

The widget is slow.

## Proposed Solution

Cache the widget.

## Scope
EOF
cat > "$SMALL/changes/007-small/spec.md" <<'EOF'
# Spec

## Acceptance Criteria

- AC1 — widget is cached
- AC2 — cache invalidates on write

## Edge Cases
EOF
cat > "$SMALL/changes/007-small/verify-report.md" <<'EOF'
# Verify Report

**Verdict:** PASS

All 2 acceptance criteria met. unit tests passed.
EOF

echo "--- Case AC3: small input is byte-identical to the pre-change golden ---"
render "$SMALL" 007-small unit > "$WORK/small.out"
if cmp -s "$WORK/small.out" "$GOLDEN"; then
  pass "AC3 small description unchanged"
else
  fail "AC3 small description differs from golden"
  diff "$GOLDEN" "$WORK/small.out" | head -20
fi
[[ -s "$WORK/stderr" ]] && fail "AC3 small input warned: $(cat "$WORK/stderr")" || pass "AC3 no warning under budget"

# ── Oversized fixture (AC1, AC2, AC6) ────────────────────────────────────────
BIG="$WORK/big/.specclaw"
BD="$BIG/changes/008-big"
mkdir -p "$BD"
printf 'project:\n  name: t\n' > "$BIG/config.yaml"
{ echo "# Proposal: Big thing"; echo; echo "## Problem"; echo; para 10 problem
  echo; echo "## Proposed Solution"; echo; para 10 solution; echo; echo "## Scope"; } > "$BD/proposal.md"
{ echo "# Spec"; echo; echo "## Acceptance Criteria"; echo; para 40 criterion; echo; echo "## Edge Cases"; } > "$BD/spec.md"
{ echo "# Verify Report"; echo; echo "**Verdict:** PASS"; echo; para 18 "verify test"; } > "$BD/verify-report.md"
{ echo "# Staged files"; para 19 staged; } > "$BD/staged-files-report.md"
{ echo "# Timeline"; echo; echo "**Total measured:** 42m"; para 15 span; echo "## Spans"; } > "$BD/timeline.md"

echo "--- Case AC1/AC2/AC6: oversized artifacts ---"
render "$BIG" 008-big unit > "$WORK/big.out"
len=$(wc -m < "$WORK/big.out" | tr -d ' ')
raw=$(( $(wc -m < "$BD/proposal.md") + $(wc -m < "$BD/spec.md") + $(wc -m < "$BD/verify-report.md") ))
if (( raw > 8000 )); then pass "AC1 fixture is genuinely oversized ($raw chars of source)"; else fail "AC1 fixture too small ($raw)"; fi
if (( len <= 3900 )); then pass "AC1 description fits default budget ($len <= 3900)"; else fail "AC1 description is $len chars (> 3900)"; fi
grep -q '^WARNING:.*truncated' "$WORK/stderr" && pass "AC2 truncation reported on stderr" || fail "AC2 no stderr WARNING on truncation"
grep -q '^\*\*Verdict:\*\* PASS' "$WORK/big.out" && pass "AC2 verdict line present" || fail "AC2 verdict line missing"
grep -q '🤖 Generated by SpecClaw' "$WORK/big.out" && pass "AC2 footer present" || fail "AC2 footer missing"
ptrs=$(grep -o 'full text in `.specclaw/changes/008-big/[^`]*`' "$WORK/big.out" | sed 's/.*008-big\///; s/`$//' | sort -u)
if [[ -n "$ptrs" ]]; then
  pass "AC2 truncation pointer(s) present: $(echo "$ptrs" | tr '\n' ' ')"
  while IFS= read -r p; do
    [[ -f "$BD/$p" ]] && pass "AC2 pointer names a real file ($p)" || fail "AC2 pointer names missing file ($p)"
  done <<< "$ptrs"
else
  fail "AC2 no truncation pointer"
fi
grep -q '^## Summary' "$WORK/big.out" && grep -q 'solution line 009' "$WORK/big.out" \
  && pass "AC6 Summary intact (lower sections absorbed the cut)" \
  || fail "AC6 Summary was truncated although lower sections could absorb the cut"
grep -q 'span line 015' "$WORK/big.out" \
  && fail "AC6 Time accounting survived intact while the description was over budget" \
  || pass "AC6 Time accounting shrunk first"

# ── Config override (AC4) ────────────────────────────────────────────────────
echo "--- Case AC4: azdo.pr_description_max overrides the budget ---"
printf 'project:\n  name: t\nazdo:\n  enabled: true\n  pr_description_max: 1500   # tighter\n' > "$BIG/config.yaml"
render "$BIG" 008-big unit > "$WORK/big1500.out"
len=$(wc -m < "$WORK/big1500.out" | tr -d ' ')
(( len <= 1500 )) && pass "AC4 description fits 1500 ($len)" || fail "AC4 description is $len chars (> 1500)"
grep -q '^\*\*Verdict:\*\* PASS' "$WORK/big1500.out" && pass "AC4 verdict survives a tight budget" || fail "AC4 verdict missing"
grep -q '🤖 Generated by SpecClaw' "$WORK/big1500.out" && pass "AC4 footer survives a tight budget" || fail "AC4 footer missing"

printf 'azdo:\n  pr_description_max: banana\n' > "$BIG/config.yaml"
render "$BIG" 008-big unit > "$WORK/bigbad.out"
len=$(wc -m < "$WORK/bigbad.out" | tr -d ' ')
(( len <= 3900 && len > 1500 )) && pass "AC4 non-numeric override falls back to 3900 ($len)" || fail "AC4 non-numeric override: $len chars"
printf 'project:\n  name: t\n' > "$BIG/config.yaml"

# ── Floor on the configured budget (FR5 under a tiny config) ────────────────
echo "--- Case FR5: a tiny azdo.pr_description_max is floored at 1000 ---"
printf 'azdo:\n  pr_description_max: 150\n' > "$BIG/config.yaml"
render "$BIG" 008-big unit > "$WORK/big150.out"
len=$(wc -m < "$WORK/big150.out" | tr -d ' ')
(( len <= 1000 )) && pass "FR5 floored description fits 1000 ($len)" || fail "FR5 floored description is $len chars"
grep -q '^\*\*Verdict:\*\* PASS' "$WORK/big150.out" && pass "FR5 verdict survives a tiny config" || fail "FR5 verdict dropped under a tiny config"
grep -q '🤖 Generated by SpecClaw' "$WORK/big150.out" && pass "FR5 footer survives a tiny config" || fail "FR5 footer damaged under a tiny config"
grep -q 'below the 1000-char floor' "$WORK/stderr" && pass "FR5 floor is reported" || fail "FR5 floor not reported"
printf 'project:\n  name: t\n' > "$BIG/config.yaml"

# ── Byte locale + multi-byte text: output stays valid UTF-8 (FR7) ────────────
echo "--- Case FR7: C locale never splits a multi-byte character ---"
MB="$WORK/mb/.specclaw"
MD="$MB/changes/010-mb"
mkdir -p "$MD"
printf 'project:\n  name: t\n' > "$MB/config.yaml"
cp "$SMALL/changes/007-small/proposal.md" "$SMALL/changes/007-small/verify-report.md" "$MD/"
{ echo "# Spec"; echo; echo "## Acceptance Criteria"; echo
  for i in $(seq 1 40); do printf -- '- 仕様 %02d — ünïcödé 🤖🦞 criterion text that is long enough to matter here ✓✓✓\n' "$i"; done
  echo; echo "## Edge Cases"; } > "$MD/spec.md"
( export LC_ALL=C; render "$MB" 010-mb none ) > "$WORK/mb.out"
if iconv -f UTF-8 -t UTF-8 < "$WORK/mb.out" > /dev/null 2>&1; then pass "FR7 output is valid UTF-8 under LC_ALL=C"; else fail "FR7 output is invalid UTF-8 under LC_ALL=C"; fi
bytes=$(wc -c < "$WORK/mb.out" | tr -d ' ')
(( bytes <= 3901 )) && pass "FR7 byte count also within budget under C locale ($bytes)" || fail "FR7 $bytes bytes under C locale"

# ── One enormous line (AC5) ──────────────────────────────────────────────────
echo "--- Case AC5: a single 10,000-char line ---"
HUGE="$WORK/huge/.specclaw"
HD="$HUGE/changes/009-huge"
mkdir -p "$HD"
printf 'project:\n  name: t\n' > "$HUGE/config.yaml"
{ echo "# Proposal: Huge"; echo; echo "## Problem"; echo; printf 'x%.0s' $(seq 1 10000); echo; echo "## Scope"; } > "$HD/proposal.md"
cp "$SMALL/changes/007-small/spec.md" "$SMALL/changes/007-small/verify-report.md" "$HD/"
render "$HUGE" 009-huge none > "$WORK/huge.out"
len=$(wc -m < "$WORK/huge.out" | tr -d ' ')
(( len <= 3900 )) && pass "AC5 description fits ($len)" || fail "AC5 description is $len chars"
grep -q '^\*\*Verdict:\*\* PASS' "$WORK/huge.out" && pass "AC5 verdict present" || fail "AC5 verdict missing"
grep -q '🤖 Generated by SpecClaw' "$WORK/huge.out" && pass "AC5 footer present" || fail "AC5 footer missing"
grep -q '^WARNING:' "$WORK/stderr" && pass "AC5 stderr WARNING emitted" || fail "AC5 no stderr WARNING"

echo
echo "=== $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
