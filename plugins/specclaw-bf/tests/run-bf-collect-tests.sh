#!/usr/bin/env bash
# run-bf-collect-tests.sh — regression suite for the brownfield collectors.
#
# Moved out of specclaw core's run-parser-tests.sh (Cases 9-12) so core tests
# no longer reach into specclaw-bf/bin, and the analyze/ and rebuild-plan/
# fixtures live with the plugin that owns them.
#
# Case 9-10 (architecture-command): specclaw-bf-analyze-codebase collect —
#   manifests, LOC, test-locations, discovered_docs parity with core's
#   specclaw-discover-context, scoping, and dependency_graph extraction.
# Case 11 (domain-command): specclaw-bf-domain-collect collect — .dfm forms,
#   handlers, Pascal types/consts/validation candidates, main_form_hint,
#   .xaml capture, .cshtml marking, scoping (AC1-AC13).
# Case 12 (rebuild-plan-bridge): specclaw-bf-rebuild-collect collect —
#   existence check, line counts, module roster, missing-doc errors.
#
# Plain bash only — no bats/npm. Run from anywhere:
#   bash plugins/specclaw-bf/tests/run-bf-collect-tests.sh
# Exits non-zero if any case fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"
BF_BIN="$(cd "$SCRIPT_DIR/../bin" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../../specclaw/bin" && pwd)"

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

echo "=== specclaw-bf collector regression suite ==="
echo "bin:      $BF_BIN"
echo "fixtures: $FIXTURES_DIR"
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
ANALYZE_BIN="$BF_BIN/specclaw-bf-analyze-codebase"
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
DOMAIN_BIN="$BF_BIN/specclaw-bf-domain-collect"
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
REBUILD_BIN="$BF_BIN/specclaw-bf-rebuild-collect"
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
  if grep -q 'domain-model.md (run /specclaw-bf:bf-domain)' <<<"$partial_err" \
     && grep -q 'functional-spec.md (run /specclaw-bf:bf-domain)' <<<"$partial_err"; then
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

echo
echo "=================================================="
echo "$PASS passed, $FAIL failed"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
exit 0
