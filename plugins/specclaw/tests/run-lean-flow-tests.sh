#!/usr/bin/env bash
# run-lean-flow-tests.sh — change 042, Stage 1: one case per acceptance criterion (AC-1..AC-5).
# shellcheck disable=SC2016,SC2329  # check() evals its single-quoted condition later, by design
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="$PLUGIN_DIR/bin"
FAILS=0
ok() { echo "PASS: $1"; }
ko() { echo "FAIL: $1"; FAILS=$((FAILS + 1)); }
check() { if eval "$2"; then ok "$1"; else ko "$1"; fi; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# AC-1: flow defaults to full; lean when set.
mkdir -p "$TMP/a/.specclaw" && printf 'version: 1\n' > "$TMP/a/.specclaw/config.yaml"
check "AC-1 no flow key reads full" '[ "$("$BIN/specclaw-flow" "$TMP/a/.specclaw")" = full ]'
printf 'flow: lean\n' >> "$TMP/a/.specclaw/config.yaml"
check "AC-1 flow: lean reads lean" '[ "$("$BIN/specclaw-flow" "$TMP/a/.specclaw")" = lean ]'

# AC-2: init writes lean defaults and an offline mock.
"$BIN/specclaw-init" "$TMP/b" demo "d" >/dev/null
CFG="$TMP/b/.specclaw/config.yaml"
section_val() { awk -v s="$1:" -v k="  $2:" '/^[a-z]/ { cur = $1 } cur == s && index($0, k) == 1 { print $2; exit }' "$CFG"; }
check "AC-2 init writes lean defaults" '[ "$("$BIN/specclaw-flow" "$TMP/b/.specclaw")" = lean ] && [ "$(section_val party enabled)" = false ] && [ "$(section_val workflow code_review)" = false ] && [ "$(section_val loop max_iterations)" = 2 ]'
check "AC-2 mock exists with no external URLs" '[ -f "$TMP/b/.specclaw/mock/index.html" ] && ! grep -qE "(src|href)=\"(https?:)?//" "$TMP/b/.specclaw/mock/index.html"'

# AC-3: a change.md-only change passes build validation and its tasks parse.
D="$TMP/b/.specclaw/changes/001-x"
mkdir -p "$D"
printf '# X\n\n## Tasks\n\n- [ ] `T1` — Draw the mock (AC-1)\n  - Files: .specclaw/mock/index.html\n\n## Verify\n' > "$D/change.md"
check "AC-3 lean change validates for build and parses" '(cd "$TMP/b" && "$BIN/specclaw-validate-change" .specclaw 001-x build >/dev/null) && [ "$("$BIN/specclaw-parse-tasks" "$D/change.md" | grep -c "\"id\":\"T1\"")" = 1 ]'

# AC-4: screenshot exits 3 when Playwright cannot be reached.
check "AC-4 screenshot exits 3 without npx" 'PATH="/usr/bin:/bin" "$BIN/specclaw-screenshot" "$TMP/b/.specclaw/mock/index.html" "$TMP/s.png" 2>/dev/null; [ $? -eq 3 ]'

# AC-5: lifecycle skills are lean (≤300 words) and dispatch to an existing full reference.
bad=""
for p in propose plan build verify pr status archive; do
  f="$PLUGIN_DIR/skills/$p/SKILL.md"
  words="$(awk '/^---$/ { c++; next } c >= 2' "$f" | grep -v '^\*\*Flow check:\*\*' | wc -w | tr -d ' ')"
  [ "$words" -le 300 ] && grep -q "references/full/$p.md" "$f" && [ -f "$PLUGIN_DIR/references/full/$p.md" ] || bad="$bad $p($words)"
done
words="$(awk '/^---$/ { c++; next } c >= 2' "$PLUGIN_DIR/skills/init/SKILL.md" | wc -w | tr -d ' ')"
[ "$words" -le 300 ] && grep -q "references/full/init.md" "$PLUGIN_DIR/skills/init/SKILL.md" && [ -f "$PLUGIN_DIR/references/full/init.md" ] || bad="$bad init($words)"
check "AC-5 lean skills ≤300 words with full references:${bad:- all}" '[ -z "$bad" ]'

echo
[ "$FAILS" -eq 0 ] && echo "All lean-flow tests passed." || echo "$FAILS failure(s)."
exit $((FAILS > 0))
