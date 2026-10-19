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

# Change 045: specclaw-presets resolves project-local presets over built-ins.
P="$(cd "$PLUGIN_DIR/presets" && pwd -P)"
proj() { rm -rf "$TMP/p" && mkdir -p "$TMP/p/presets" && printf 'presets: [%s]\n' "$1" > "$TMP/p/config.yaml"; L="$(cd "$TMP/p/presets" && pwd -P)"; }
res() { "$BIN/specclaw-presets" "$TMP/p" 2>/dev/null | tr '\n' ' '; }
proj dotnet; rmdir "$TMP/p/presets"
check "AC-1 no local dir prints built-in base then dotnet" '[ "$(res)" = "$P/base.md $P/dotnet.md " ]'
proj dotnet; printf '# Preset: dotnet (ours)\n' > "$L/dotnet.md"
check "AC-2 local dotnet replaces built-in" '[ "$(res)" = "$P/base.md $L/dotnet.md " ]'
printf '\nExtends: dotnet\n# more rules\n' > "$L/dotnet.md"
check "AC-3 Extends: dotnet prints built-in then local" '[ "$(res)" = "$P/base.md $P/dotnet.md $L/dotnet.md " ]'
proj "acme, nope"; printf '# acme\n' > "$L/acme.md"
"$BIN/specclaw-presets" "$TMP/p" >"$TMP/o" 2>"$TMP/e"; r=$?
check "AC-4 local acme printed, unknown nope warns and exits 1" '[ $r = 1 ] && [ "$(tr "\n" " " < "$TMP/o")" = "$P/base.md $L/acme.md " ] && grep -q "unknown preset .nope." "$TMP/e"'
proj "../x"
check "AC-5 path-like name is unknown" '! "$BIN/specclaw-presets" "$TMP/p" >/dev/null 2>&1'

# Variants of the presets: forms, Extends placement and the trust boundary. Each row:
# label | config.yaml body | local files (name=body;...) | expected rc | expected names (in order)
cfgcase() {
  local label="$1" cfg="$2" files="$3" want_rc="$4" want="$5" got r f
  rm -rf "$TMP/v" && mkdir -p "$TMP/v/presets"
  [ "$cfg" = "-" ] || printf '%b' "$cfg" > "$TMP/v/config.yaml"
  IFS=';' read -ra fs <<<"$files"
  for f in "${fs[@]}"; do [ -n "$f" ] && printf '%b' "${f#*=}" > "$TMP/v/presets/${f%%=*}.md"; done
  got="$("$BIN/specclaw-presets" "$TMP/v" 2>/dev/null | sed -E 's|.*/([^/]+)/presets/([^/]+)\.md$|\1:\2|' | tr '\n' ' ')"
  "$BIN/specclaw-presets" "$TMP/v" >/dev/null 2>&1; r=$?
  check "045 variant: $label" '[ "$r" = "$want_rc" ] && [ "$got" = "$want" ]'
}
cfgcase "block list"                 'presets:\n  - dotnet\n  - python\n' ''                         0 "specclaw:base specclaw:dotnet specclaw:python "
cfgcase "trailing comment on key"    'presets:  # ours\n  - dotnet\n'      ''                         0 "specclaw:base specclaw:dotnet "
cfgcase "comment between items"      'presets:\n  # web\n  - nextjs\n'     ''                         0 "specclaw:base specclaw:nextjs "
cfgcase "column-0 dashes"            'presets:\n- node\nother: 1\n'        ''                         0 "specclaw:base specclaw:node "
cfgcase "CRLF flow form"             'presets: [python]\r\n'               ''                         0 "specclaw:base specclaw:python "
cfgcase "flow form with comment"     'presets: [node] # x\n'               ''                         0 "specclaw:base specclaw:node "
cfgcase "empty flow"                 'presets: []\n'                       ''                         0 "specclaw:base "
cfgcase "scalar is malformed"        'presets: python\n'                   ''                         1 "specclaw:base "
cfgcase "missing config"             '-'                                   ''                         1 "specclaw:base "
cfgcase "Extends after a heading"    'presets: [dotnet]\n'                 'dotnet=# Ours\nextends: dotnet\n' 0 "specclaw:base specclaw:dotnet v:dotnet "
cfgcase "Extends another local"      'presets: [b]\n'                      'a=# a\n;b=Extends: a\n'   0 "specclaw:base v:a v:b "
cfgcase "local base replaces"        'presets: []\n'                       'base=# ours\n'            0 "v:base "
cfgcase "Extends: base keeps it"     'presets: []\n'                       'base=Extends: base\n'     0 "specclaw:base v:base "
cfgcase "unknown Extends parent"     'presets: [a]\n'                      'a=Extends: zzz\n'         1 "specclaw:base v:a "
cfgcase "dedupe repeated names"      'presets: [python, python, base]\n'  ''                         0 "specclaw:base specclaw:python "
cfgcase "Extends after prose"        'presets: [a]\n'                      'a=Our rules.\nExtends: node\n' 1 "specclaw:base v:a "
cfgcase "Extends with trailing text" 'presets: [a]\n'                      'a=Extends: node please\n' 1 "specclaw:base v:a "
cfgcase "block: indented scalar"     'presets:\n  - node\n  python\n'    ''                         1 "specclaw:base specclaw:node "
cfgcase "block: bare dash"           'presets:\n  -\n  - node\n'         ''                         1 "specclaw:base specclaw:node "
cfgcase "block: dash without space"  'presets:\n  -python\n'              ''                         1 "specclaw:base "
cfgcase "path-like names"            'presets: [../x, ../../etc/hosts]\n' ''                         1 "specclaw:base "
rm -rf "$TMP/v" && mkdir -p "$TMP/v/presets" && printf 'presets: [dotnet]\n' > "$TMP/v/config.yaml"
printf 'secret\n' > "$TMP/outside.md" && ln -s "$TMP/outside.md" "$TMP/v/presets/dotnet.md"
check "045 variant: symlink out of presets/ is refused" '! "$BIN/specclaw-presets" "$TMP/v" 2>/dev/null | grep -q outside.md && ! "$BIN/specclaw-presets" "$TMP/v" >/dev/null 2>&1'
rm "$TMP/v/presets/dotnet.md" && printf 'presets: [a]\n' > "$TMP/v/config.yaml" && printf 'Extends: b\n' > "$TMP/v/presets/a.md"
ln -s "$TMP/outside.md" "$TMP/v/presets/b.md"
check "045 variant: symlinked Extends parent is refused" '! "$BIN/specclaw-presets" "$TMP/v" 2>/dev/null | grep -q outside.md'
mkdir -p "$TMP/i" && "$BIN/specclaw-init" "$TMP/i" demo d >/dev/null
check "AC-6 init scaffolds .specclaw/presets/README.md from the template" 'cmp -s "$TMP/i/.specclaw/presets/README.md" "$PLUGIN_DIR/templates/presets-README.md"'
check "AC-7 lean build reads presets via specclaw-presets" 'grep -q "specclaw-presets .specclaw" "$PLUGIN_DIR/skills/build/SKILL.md" && ! grep -q "presets/base.md" "$PLUGIN_DIR/skills/build/SKILL.md"'

echo
[ "$FAILS" -eq 0 ] && echo "All preset-check tests passed." || echo "$FAILS failure(s)."
exit $((FAILS > 0))
