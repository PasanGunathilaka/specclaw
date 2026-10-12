#!/usr/bin/env bash
# run-preset-check-tests.sh — change 042, Stage 3: one case per acceptance criterion (AC-10, AC-11).
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

# AC-10: six presets, each ≤60 lines; init proposes nextjs for a Next.js package.json.
bad=""
for p in base python nextjs node dotnet react-spa; do
  f="$PLUGIN_DIR/presets/$p.md"
  [ -f "$f" ] && [ "$(wc -l < "$f")" -le 60 ] || bad="$bad $p"
done
mkdir -p "$TMP/n" && printf '{"dependencies":{"next":"15.0.0"}}\n' > "$TMP/n/package.json"
"$BIN/specclaw-init" "$TMP/n" demo d >/dev/null
check "AC-10 presets exist ≤60 lines and init proposes nextjs:${bad:- ok}" '[ -z "$bad" ] && grep -q "^presets: \[nextjs\]" "$TMP/n/.specclaw/config.yaml"'

# AC-11: exit 1 on an 81-line file, a comment line and Domain→Infrastructure; 0 when clean.
fixture() { rm -rf "$TMP/c" && mkdir -p "$TMP/c/src" && printf 'export const ok = 1\n' > "$TMP/c/src/ok.ts"; }
rc() { "$BIN/specclaw-preset-check" "$TMP/c" >/dev/null 2>&1; echo $?; }
fixture
check "AC-11 clean tree exits 0" '[ "$(rc)" = 0 ]'
seq 81 | sed 's/^/x = /' > "$TMP/c/src/long.py"
check "AC-11 81-line file exits 1" '[ "$(rc)" = 1 ]'
fixture; printf '// explains the next line\nexport const b = 2\n' > "$TMP/c/src/b.ts"
check "AC-11 comment line exits 1" '[ "$(rc)" = 1 ]'
fixture; printf '<Project><ItemGroup><ProjectReference Include="../App.Infrastructure/App.Infrastructure.csproj" /></ItemGroup></Project>\n' > "$TMP/c/src/App.Domain.csproj"
check "AC-11 Domain→Infrastructure reference exits 1" '[ "$(rc)" = 1 ]'

echo
[ "$FAILS" -eq 0 ] && echo "All preset-check tests passed." || echo "$FAILS failure(s)."
exit $((FAILS > 0))
