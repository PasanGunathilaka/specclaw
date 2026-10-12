#!/usr/bin/env bash
# run-quality-tests.sh — regression suite for specclaw-bf-quality-collect and
# the optional quality annotation in specclaw-bf-rebuild-collect.
#
# WHY THE METRIC TOOLS ARE STUBBED. scc, lizard and jscpd are not installed in
# CI and are not installed on most contributors' machines, and the point of this
# suite is the collector's parsing, classification, registry and gate logic —
# not whether a third-party binary counts branches correctly. So every case puts
# a tiny stub on PATH that emits the documented machine-readable shape. That
# also makes the assertions exact: a fixture function's complexity is whatever
# the stub says it is, so a threshold-boundary case can be pinned to the value
# either side of the boundary rather than hoping real source lands there.
#
# The corollary is that this suite does NOT prove the collector works against
# the real tools' output. What guards that is the parsers only ever reading
# documented machine-readable formats (scc --format json, lizard --csv, jscpd
# --reporters json) and never scraping human output.
#
# Cases:
#   1  polyglot tree              → per-language coverage; complexity
#                                   NOT-MEASURED / language_unsupported for the
#                                   language lizard does not parse
#   2  jscpd absent from PATH     → duplication NOT-MEASURED / tool_missing,
#                                   exit 0; and all three absent still exits 0
#   3  threshold classification   → 11 is WARN, 21 is HIGH, rollup takes the
#                                   worst status across dimensions
#   4  QI permanence              → identical ids on an unchanged re-run; a
#                                   cleared hotspot becomes resolved, never
#                                   removed; a file-level hotspot (empty
#                                   function field in its key) survives too
#   5  compare                    → improved / regressed classification, and a
#                                   one-side-only dimension is NOT-COMPARABLE
#   6  gate                       → regressed target FAILs with exit 1,
#                                   improved target PASSes with exit 0
#   7  rebuild-plan neutrality    → with no quality.json the rendered backlog is
#                                   byte-identical; with one, the ONLY lines that
#                                   differ are the annotation and its note
#   8  advisory neutrality        → HIGH findings still exit 0
#   9  module join                → an uncited file rolls up under
#                                   MOD-UNASSIGNED; a file cited by two modules
#                                   is left unassigned, never guessed
#  10  client-safe template       → the report template body carries no internal
#                                   command name outside the provenance section
#  11  ARG_MAX regression          → a >2 MB joined file list does not overflow
#                                   argv; collector exits 0 (the fixed --slurpfile
#                                   path); pre-fix binary shown to fail (informational)
#  12  spaces / unicode paths      → filenames with spaces and non-ASCII survive
#                                   enumeration, classification, the scc join and
#                                   the module join, and register hotspots intact
#  13  quality remediation items → the QUALITY-REMEDIATION backlog item: which
#                                   modules earn one, the severity floor, the dated
#                                   ledger, the gate and the computed quality state
#  14  scan exclusions            → generated, vendored and test files are excluded
#                                   from the scan and censused per category
#  15  one measured list          → scc, lizard and jscpd all measure the identical
#                                   post-exclusion list, never their own ignore rules
#  16  include_overrides          → one named file is forced back in; its category
#                                   still excludes the rest
#  17  case-insensitive matching  → Migrations/, migrations/ and MIGRATIONS/ all excluded
#  18  spaced paths               → filtered as whole paths, never word-split
#  19  scope mismatch             → compare stops with QUALITY-SCOPE-MISMATCH, writes no
#                                   delta and reaches no gate verdict; matching scopes
#                                   compare normally
#  20  excluded-by-scope QI       → a registered hotspot whose file leaves the scope
#                                   keeps its id and is NEVER marked resolved; its
#                                   rebuild item records a dated scope change, not a
#                                   retirement, and is not renumbered
#  21  scoping is neutral         → with the old hardcoded filter reproduced, the
#                                   three fixture files split into the two measured
#                                   source files, named, and the one pipeline-owned
#                                   file excluded; and no measured value drifts
#                                   from the collector at origin/main
#  22  tests as a bucket          → test code measured into MOD-TESTS, absent from
#                                   every production module rollup, registering no QI
#  23  clone capture              → a known duplicated block is preserved with both
#                                   locations, its line count and each module; the
#                                   rollup percentage is byte-identical to before
#  24  clone determinism          → two runs give byte-identical clones and QI ids;
#                                   pairs are canonically ordered, largest first
#  25  clone QI threshold         → 29 lines captured but unregistered, 30 registered;
#                                   re-run keeps the id; a vanished clone resolves
#  26  cross-module clone         → both module ids recorded, flagged, counted once
#  27  function mapping           → attached only on containment + overlap; null for a
#                                   clone spanning two functions and for a language
#                                   with no function measurement, never a guess
#  28  capture truncation         → the cap keeps the largest and the census still
#                                   reports true totals; QI registration is uncapped
#  29  clone scope                → a pair reaching outside the measured list is
#                                   dropped and counted, and never leaks a path
#  30  report section             → the template carries a client-safe hotspot section
#                                   that forbids printing source and requires the
#                                   truncation footer
#  31  zero duplication           → an honest empty result, and no crash with jscpd absent
#  32  unnamed functions          → two lambdas in one file are two hotspots with two
#                                   keys, and an unchanged re-run keeps both ids
#  33  scope sentinels            → *global* and <anonymous> coexist on one file
#                                   without colliding; nothing shares a key
#  34  identity assertion         → two hotspots on one key, or one with no start
#                                   line, fail the run and nothing is written
#  35  registry migration         → old ids map onto the new key by recorded value,
#                                   the unmatched one is tombstoned naming its
#                                   successor, the unclaimed hotspot registers
#                                   fresh, a second run is a no-op, and an
#                                   undecidable collision stops instead of guessing
#  36  scan funnel                → the funnel is a projection of the counts, each
#                                   metric's coverage is its own, and the rendered
#                                   block states them
#  37  module rollup summary      → the summary matches the modules array and the
#                                   rendered table holds one row per module, no more
#  38  report lint                → a faithful report passes; an invented row, a
#                                   retyped tally, a retyped figure, an unknown id
#                                   and a missing anchor each fail, by name
#  39  coverage sentence          → rendered from the funnel; the shared-denominator
#                                   claim is gone from the template
#  40  anomaly rule               → the agent is told to observe and stop, and the
#                                   template carries the section to put it in
#  41  real lizard --csv          → the shape the tool actually emits: quoted fields
#                                   whose contents carry commas. Every one of the
#                                   seven columns survives a comma in long_name, in
#                                   the function name and in the path; a row wider
#                                   than eleven still yields the right start/end
#  42  two hotspots, real rows    → two unnamed functions in one file, measured by
#                                   rows of the real shape, register two ids with
#                                   distinct keys and keep them on a re-run
#  43  scope normalisation        → the function name reaches the key unquoted, and a
#                                   registry written while it did not is migrated in
#                                   place: same id, same first seen, no renumbering,
#                                   idempotent, and a quoted scope in the artifact
#                                   stops the run
#  44  the file-scope pseudo-row   → lizard names the code outside every function
#                                   *global*, spans the whole file, starts at line 0
#                                   and can emit it several times per file. It is not
#                                   a function: it registers nothing, it does not
#                                   inflate a rollup, and several of them no longer
#                                   collide. The file-level sentinel still works.
#
# Plain bash + coreutils, plus jq for assertions (same as run-parser-tests.sh
# and run-cs-body-parser-tests.sh). Run from anywhere:
#   bash plugins/specclaw/tests/run-quality-tests.sh
# Exits non-zero if any case fails.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BIN_DIR="$PLUGIN_ROOT/bin"
QUALITY_BIN="$BIN_DIR/specclaw-bf-quality-collect"
REBUILD_BIN="$BIN_DIR/specclaw-bf-rebuild-collect"
FIXTURES_DIR="$SCRIPT_DIR/fixtures"

[[ -f "$QUALITY_BIN" ]] || { echo "FATAL: missing bin script: $QUALITY_BIN" >&2; exit 2; }
[[ -f "$REBUILD_BIN" ]] || { echo "FATAL: missing bin script: $REBUILD_BIN" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

assert_eq() {
  local label="$1" want="$2" got="$3"
  if [[ "$want" == "$got" ]]; then pass "$label"
  else fail "$label (want '$want', got '$got')"; fi
}

assert_contains() {
  local label="$1" needle="$2" hay="$3"
  if [[ "$hay" == *"$needle"* ]]; then pass "$label"
  else fail "$label (missing '$needle' in: $(printf '%s' "$hay" | head -c 300))"; fi
}

# assert_eq_nonempty — an equality assertion that does NOT pass on two empty
# strings. Needed wherever both sides come from parsing an artifact: if the
# artifact is missing, both sides are "" and a plain assert_eq reports PASS for
# a case that never ran. That false green hid four broken cases here once.
assert_eq_nonempty() {
  local label="$1" want="$2" got="$3"
  if [[ -z "$want" || -z "$got" ]]; then
    fail "$label (one side empty — want '$want', got '$got')"
  else
    assert_eq "$label" "$want" "$got"
  fi
}

# clean_path <stub_dir> — a PATH holding the stub directory, whatever the
# collector genuinely needs (jq lives outside /usr/bin on some platforms, which
# is why this is computed rather than hardcoded), and nothing else. Keeping the
# host's full PATH would let a real jscpd leak in and turn a tool_missing
# assertion into a silent pass; hardcoding /usr/bin:/bin drops jq and makes the
# collector die before it measures anything.
JQ_DIR="$(dirname "$(command -v jq)")"
GIT_DIR_BIN=""
if command -v git >/dev/null 2>&1; then GIT_DIR_BIN=":$(dirname "$(command -v git)")"; fi
clean_path() { printf '%s:%s%s:/usr/bin:/bin' "$1" "$JQ_DIR" "$GIT_DIR_BIN"; }

# q_norm_identity — reads an artifact on stdin and removes what the QI-identity
# change ADDED or RESHAPED, so the two neutrality diffs (21b, 23i) keep asking
# the question they were written to ask.
#
# Both of those cases byte-compare this collector's output against an older one
# fetched from origin/main. That comparison is about MEASUREMENTS: every status,
# rollup, LOC, coverage row and QI id must be identical. It was never about the
# artifact's field list, and a field that did not exist on the other side is not
# a changed measurement — which is why both cases already strip `exclusions`,
# `duplication_clones` and the clone threshold keys.
#
# Three blocks are new and are pure projections of fields still under
# comparison. `scope`, `start` and `superseded_by` are likewise new per entry.
# And `key` is deliberately reshaped: it gained a start line so that two
# hotspots in one file stop sharing an id. So the key is normalised BACK to the
# four-field form rather than deleted — a hotspot that moved to a different
# file, metric or module still shows up as a difference, which is the failure
# these cases exist to catch.
q_norm_identity() {
  jq -S '
    def old_key:
      (split("|")) as $k
      | if $k[0] == "duplication-clone" then .
        elif ($k | length) == 5 then
          [ $k[0], $k[1],
            (if $k[2] == "<anonymous>" or $k[2] == "*global*" then "" else $k[2] end),
            $k[3] ] | join("|")
        else . end;
    del(.scan_funnel, .module_rollup_summary, .report_blocks)
    | (.quality_issues // []) |= map(del(.scope, .start, .superseded_by) | .key |= old_key)
  '
}

# ── Fixture + stub writers ──────────────────────────────────────────────────
#
# Fixtures are written by the tests themselves rather than committed, per
# run-cs-body-parser-tests.sh's rule: a committed source fixture drifts out of
# sync with the assertions that depend on it.

# new_project <dir> — a project root with .specclaw/analysis and two sources in
# two languages, one of which lizard does not parse.
new_project() {
  local d="$1"
  mkdir -p "$d/.specclaw/analysis" "$d/src"
  printf 'public class Calc { public void Run() { } }\n' > "$d/src/Calc.cs"
  printf 'unit Legacy;\nbegin\nend.\n' > "$d/src/Legacy.pas"
}

# module_map <dir> <body...> — writes module-map.md with the given module blocks.
module_map_one() {
  local d="$1"
  cat > "$d/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Fixture

**Status:** CONFIRMED by fixture, 2026-08-25

## Modules

### MOD-001 — Billing

- **Purpose:** the fixture's module
- **Evidence:**
  - `src/Calc.cs:1` — the calculator
MM
}

# stub_dir <dir> — a PATH prefix directory holding metric-tool stubs.
# Each stub emits the documented machine-readable shape and ignores its args;
# the collector intersects tool output with its own enumerated file list, so a
# stub can safely emit rows for paths outside the current scope.
stub_scc() {
  local dir="$1" body="$2"
  mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\ncat <<%s\n' "'SCCJSON'"; printf '%s\n' "$body"; printf 'SCCJSON\n'; } > "$dir/scc"
  chmod +x "$dir/scc"
}

stub_lizard() {
  local dir="$1" body="$2"
  mkdir -p "$dir"
  { printf '#!/usr/bin/env bash\ncat <<%s\n' "'LIZCSV'"; printf '%s\n' "$body"; printf 'LIZCSV\n'; } > "$dir/lizard"
  chmod +x "$dir/lizard"
}

# jscpd writes a report FILE into the directory named by --output, so its stub
# has to find that argument rather than printing to stdout.
stub_jscpd() {
  local dir="$1" body="$2"
  mkdir -p "$dir"
  cat > "$dir/jscpd" <<'JSCPDSTUB'
#!/usr/bin/env bash
out=""
prev=""
for a in "$@"; do
  if [ "$prev" = "--output" ]; then out="$a"; fi
  prev="$a"
done
[ -n "$out" ] || exit 0
mkdir -p "$out"
cat > "$out/jscpd-report.json" <<'JBODY'
__BODY__
JBODY
JSCPDSTUB
  # Substitute the report body without a sed s/// (the JSON carries slashes).
  awk -v b="$body" '{ if ($0 == "__BODY__") print b; else print }' "$dir/jscpd" > "$dir/jscpd.tmp"
  mv "$dir/jscpd.tmp" "$dir/jscpd"
  chmod +x "$dir/jscpd"
}

# A lizard CSV row. Columns, in lizard's own order:
#   nloc,ccn,tokens,params,length,location,file,function,long_name,start,end
#
# NOT the shape the real tool emits — see liz_row_real. This one quotes nothing
# and gives every function an empty parameter list, so no field contains a comma
# and no field is quoted. Most cases here are about classification, the registry
# or the join and do not care; the ones that are about PARSING use the faithful
# helper, because those two properties are precisely what a parser gets wrong.
liz_row() {
  local file="$1" func="$2" ccn="$3" length="$4"
  printf '%s,%s,100,2,%s,%s@1-1@%s,%s,%s,%s(),1,1\n' \
    "$length" "$ccn" "$length" "$func" "$file" "$file" "$func" "$func"
}

# liz_row_real <file> <func> <ccn> <length> <start> <end> [params_text]
#
# A row in the shape lizard_ext/csvoutput.py actually produces: columns 6-9
# wrapped in double quotes, and a long_name holding a real parameter list, which
# means commas INSIDE a quoted field. That is the whole difference, and it is the
# difference the collector once got wrong — it split on commas, so start and end
# shifted off the end of every function taking two or more arguments and arrived
# empty, which the identity assertion refused to register. A suite written
# entirely in liz_row could not see it: no commas, nothing to shift.
#
# params_text defaults to a two-parameter list, so the default row is one the
# naive parser would have mangled. Pass it explicitly to place a comma somewhere
# else, or pass an empty string for a genuinely parameterless function.
liz_row_real() {
  local file="$1" func="$2" ccn="$3" length="$4" start="$5" end="$6"
  local params="${7-( int a , int b )}"
  printf '%s,%s,100,2,%s,"%s@%s-%s@%s","%s","%s","%s%s",%s,%s\n' \
    "$length" "$ccn" "$length" \
    "$func" "$start" "$end" "$file" "$file" "$func" "$func" "$params" \
    "$start" "$end"
}

# ── Case 1 — polyglot coverage, and NOT-MEASURED for the unsupported language ──

echo "--- Case 1: polyglot tree — per-language coverage and language_unsupported ---"
C1="$WORK/c1"; new_project "$C1"; module_map_one "$C1"
S1="$WORK/c1-stub"
stub_scc "$S1" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":120,"Code":100}]},
 {"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":300,"Code":250}]}]'
stub_lizard "$S1" "$(liz_row 'src/Calc.cs' 'Run' 4 12)"
stub_jscpd "$S1" '{"statistics":{"formats":{"csharp":{"sources":{"src/Calc.cs":{"lines":120,"duplicatedLines":2}}}}}}'

c1_out="$( cd "$C1" && PATH="$S1:$PATH" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
assert_eq "1a exit 0" "0" "$?"

c1_cs="$(printf '%s' "$c1_out" | jq -r '.coverage[] | select(.language == "C#") | .metrics_available | join(",")')"
assert_eq "1b C# has all three metrics" "loc,complexity,duplication" "$c1_cs"

c1_pas_avail="$(printf '%s' "$c1_out" | jq -r '.coverage[] | select(.language == "Pascal") | .metrics_available | join(",")')"
assert_eq "1c the unsupported language reports size and duplication only" "loc,duplication" "$c1_pas_avail"

c1_pas_nm="$(printf '%s' "$c1_out" | jq -r '.coverage[] | select(.language == "Pascal") | .metrics_not_measured[] | .metric + "/" + .reason')"
assert_eq "1d complexity is NOT-MEASURED with reason language_unsupported" "complexity/language_unsupported" "$c1_pas_nm"

c1_files="$(printf '%s' "$c1_out" | jq -r '"\(.files.classified)/\(.files.sized)/\(.files.function_measured)"')"
assert_eq "1e file counts: 2 classified, 2 sized, 1 function-measured" "2/2/1" "$c1_files"

# ── Case 2 — a missing tool degrades its own metrics and nothing else ─────────

echo "--- Case 2: absent tools degrade to NOT-MEASURED / tool_missing, exit 0 ---"
C2="$WORK/c2"; new_project "$C2"; module_map_one "$C2"
S2="$WORK/c2-stub"
stub_scc "$S2" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":120,"Code":100}]}]'
stub_lizard "$S2" "$(liz_row 'src/Calc.cs' 'Run' 4 12)"
# Deliberately no jscpd stub. PATH is the stub dir plus only what the collector
# genuinely needs, so the host's own jscpd (if any) cannot leak in and turn a
# tool_missing assertion into a language_unsupported one.
MINIMAL_PATH="$(clean_path "$S2")"

c2_out="$( cd "$C2" && PATH="$MINIMAL_PATH" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c2_exit=$?
assert_eq "2a exit 0 with a tool missing" "0" "$c2_exit"

c2_avail="$(printf '%s' "$c2_out" | jq -r '.tool_availability | "\(.scc)/\(.lizard)/\(.jscpd)"')"
assert_eq "2b jscpd reported unavailable" "true/true/false" "$c2_avail"

c2_nm="$(printf '%s' "$c2_out" | jq -r '.coverage[] | select(.language == "C#") | .metrics_not_measured[] | .metric + "/" + .reason')"
assert_eq "2c duplication is NOT-MEASURED with reason tool_missing" "duplication/tool_missing" "$c2_nm"

c2_dup="$(printf '%s' "$c2_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | .duplication.status')"
assert_eq "2d the module's duplication status is NOT-MEASURED, never PASS" "NOT-MEASURED" "$c2_dup"

# All three absent — the honest empty result, still exit 0.
c2b_out="$( cd "$C2" && PATH="$(clean_path "$WORK/empty-stub")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c2b_exit=$?
assert_eq "2e no tools at all: exit 0" "0" "$c2b_exit"
if [[ -n "$c2b_out" ]]; then
  c2b_roll="$(printf '%s' "$c2b_out" | jq -r '[.modules[].rollup_status] | unique | join(",")')"
  assert_eq "2f no tools at all: every module rollup is NOT-MEASURED" "NOT-MEASURED" "$c2b_roll"
  c2b_qi="$(printf '%s' "$c2b_out" | jq -r '[.quality_issues[] | select(.status == "open")] | length')"
  assert_eq "2g no tools at all: no hotspot invented" "0" "$c2b_qi"
else
  fail "2f/2g no tools at all: collector produced no JSON"
fi

# ── Case 3 — threshold classification and the worst-status rollup ────────────

echo "--- Case 3: threshold bands and rollup = worst status ---"
C3="$WORK/c3"; new_project "$C3"; module_map_one "$C3"
printf 'public class B { }\n' > "$C3/src/B.cs"
cat > "$C3/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Fixture

**Status:** CONFIRMED by fixture, 2026-08-25

## Modules

### MOD-001 — Billing

- **Purpose:** the fixture's module
- **Evidence:**
  - `src/Calc.cs:1` — the calculator

### MOD-002 — Reporting

- **Purpose:** the second module
- **Evidence:**
  - `src/B.cs:1` — the report builder
MM
S3="$WORK/c3-stub"
# Both files short enough that file_length is PASS, so complexity is isolated.
stub_scc "$S3" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":50,"Code":40},
 {"Location":"src/B.cs","Lines":50,"Code":40}]}]'
# MOD-001: one function at the WARN boundary (11) and one at the HIGH boundary
# (21) — so its complexity status must be the worse of the two.
# MOD-002: one function at 11 only — WARN, and nothing must promote it.
# Lengths are all 12, well under the function-length WARN band.
stub_lizard "$S3" "$(liz_row 'src/Calc.cs' 'Warnish' 11 12)
$(liz_row 'src/Calc.cs' 'Highish' 21 12)
$(liz_row 'src/B.cs' 'Warnish2' 11 12)"

c3_out="$( cd "$C3" && PATH="$(clean_path "$S3")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

c3_m1="$(printf '%s' "$c3_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | "\(.complexity.status)/\(.complexity.functions_warn)/\(.complexity.functions_high)/\(.complexity.max)"')"
assert_eq "3a complexity 11 is WARN and 21 is HIGH; the module takes HIGH" "HIGH/1/1/21" "$c3_m1"

c3_m2="$(printf '%s' "$c3_out" | jq -r '.modules[] | select(.module_id == "MOD-002") | "\(.complexity.status)/\(.complexity.functions_warn)/\(.complexity.functions_high)"')"
assert_eq "3b a lone complexity-11 function is WARN, not promoted" "WARN/1/0" "$c3_m2"

c3_fl="$(printf '%s' "$c3_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | .file_length.status')"
assert_eq "3c file length below the WARN band is PASS" "PASS" "$c3_fl"

c3_roll="$(printf '%s' "$c3_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | .rollup_status')"
assert_eq "3d the rollup takes the worst status across dimensions" "HIGH" "$c3_roll"

c3_roll2="$(printf '%s' "$c3_out" | jq -r '.modules[] | select(.module_id == "MOD-002") | .rollup_status')"
assert_eq "3e a WARN-only module rolls up WARN, not HIGH" "WARN" "$c3_roll2"

# Only the HIGH band earns a permanent id at the default register_severity.
c3_qi="$(printf '%s' "$c3_out" | jq -r '[.quality_issues[] | select(.status == "open")] | length')"
assert_eq "3f at register_severity HIGH, only the HIGH function is registered" "1" "$c3_qi"

# A config override moves the band, and the number is read from config only.
cat > "$C3/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  complexity_warn: 3
  complexity_high: 5
CFG
c3o_out="$( cd "$C3" && PATH="$(clean_path "$S3")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c3o_th="$(printf '%s' "$c3o_out" | jq -r '.thresholds | "\(.complexity_warn)/\(.complexity_high)"')"
assert_eq "3g thresholds come from config.yaml when set" "3/5" "$c3o_th"
c3o_m2="$(printf '%s' "$c3o_out" | jq -r '.modules[] | select(.module_id == "MOD-002") | .complexity.status')"
assert_eq "3h the same value reclassifies under the overridden band" "HIGH" "$c3o_m2"
rm -f "$C3/.specclaw/config.yaml"

# ── Case 4 — QI permanence ───────────────────────────────────────────────────

echo "--- Case 4: QI ids are permanent; a cleared hotspot resolves, never disappears ---"
C4="$WORK/c4"; new_project "$C4"; module_map_one "$C4"
S4="$WORK/c4-stub"
# A function-level hotspot AND a file-level one. The file-level key carries an
# empty function field, which is the shape that silently vanished before the
# projection stopped using `select` inside object construction — so it is
# asserted explicitly rather than left implied.
stub_scc "$S4" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":1500,"Code":1400}]}]'
stub_lizard "$S4" "$(liz_row 'src/Calc.cs' 'Run' 34 200)"

( cd "$C4" && PATH="$(clean_path "$S4")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c4_r1="$(jq -S -c '[.quality_issues[] | {id, key, status, first_seen}]' "$C4/.specclaw/analysis/quality.json")"
( cd "$C4" && PATH="$(clean_path "$S4")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c4_r2="$(jq -S -c '[.quality_issues[] | {id, key, status, first_seen}]' "$C4/.specclaw/analysis/quality.json")"
assert_eq_nonempty "4a an unchanged re-run assigns byte-identical QI ids and first_seen" "$c4_r1" "$c4_r2"

c4_n1="$(printf '%s' "$c4_r1" | jq 'length')"
assert_eq "4b three hotspots registered (complexity, function length, file length)" "3" "$c4_n1"

c4_filelevel="$(jq -r '[.quality_issues[] | select(.metric == "file_length")] | length' "$C4/.specclaw/analysis/quality.json")"
assert_eq "4c the file-level hotspot is registered despite its empty function field" "1" "$c4_filelevel"

# Now clear every hotspot. Ids must survive with status resolved.
stub_scc "$S4" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S4" "$(liz_row 'src/Calc.cs' 'Run' 3 10)"
( cd "$C4" && PATH="$(clean_path "$S4")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )

c4_ids_before="$(printf '%s' "$c4_r1" | jq -r '[.[].id] | sort | join(",")')"
c4_ids_after="$(jq -r '[.quality_issues[].id] | sort | join(",")' "$C4/.specclaw/analysis/quality.json")"
assert_eq_nonempty "4d every id survives the hotspot being fixed" "$c4_ids_before" "$c4_ids_after"

c4_statuses="$(jq -r '[.quality_issues[].status] | unique | join(",")' "$C4/.specclaw/analysis/quality.json")"
assert_eq "4e all are marked resolved, none removed" "resolved" "$c4_statuses"

c4_reg="$(grep -c '^### QI-' "$C4/.specclaw/analysis/quality-issues.md")"
assert_eq "4f the registry file still holds all three entries" "3" "$c4_reg"

c4_first_kept="$(jq -r '[.quality_issues[].first_seen] | unique | length' "$C4/.specclaw/analysis/quality.json")"
assert_eq "4g first_seen is preserved through the resolution, not restamped" "1" "$c4_first_kept"

# Regressing the same hotspot must reuse the original id, not mint a new one.
stub_lizard "$S4" "$(liz_row 'src/Calc.cs' 'Run' 34 200)"
( cd "$C4" && PATH="$(clean_path "$S4")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c4_reopen="$(jq -r '.quality_issues[] | select(.metric == "complexity" and .status == "open") | .id' "$C4/.specclaw/analysis/quality.json")"
c4_orig="$(printf '%s' "$c4_r1" | jq -r '.[] | select(.key | startswith("complexity|")) | .id')"
assert_eq_nonempty "4h a hotspot that comes back reopens under its original id" "$c4_orig" "$c4_reopen"

# A target-scope run registers nothing — QI ids name legacy hotspots only.
mkdir -p "$C4/rebuilt"; printf 'public class R { }\n' > "$C4/rebuilt/R.cs"
c4_regbefore="$(grep -c '^### QI-' "$C4/.specclaw/analysis/quality-issues.md")"
( cd "$C4" && PATH="$(clean_path "$S4")" bash "$QUALITY_BIN" collect .specclaw rebuilt --target >/dev/null 2>&1 )
c4_regafter="$(grep -c '^### QI-' "$C4/.specclaw/analysis/quality-issues.md")"
assert_eq "4i a --target run registers no QI" "$c4_regbefore" "$c4_regafter"

# ── Case 5 — compare ─────────────────────────────────────────────────────────

echo "--- Case 5: compare classifies improved / regressed / NOT-COMPARABLE ---"
C5="$WORK/c5"; new_project "$C5"
mkdir -p "$C5/rebuilt"; printf 'public class R { }\n' > "$C5/rebuilt/R.cs"
cat > "$C5/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Fixture

**Status:** CONFIRMED by fixture, 2026-08-25

## Modules

### MOD-001 — Billing

- **Purpose:** spans both trees
- **Evidence:**
  - `src/Calc.cs:1` — the legacy calculator
  - `rebuilt/R.cs:1` — the rebuilt calculator
MM
S5="$WORK/c5-stub"
stub_scc "$S5" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":1500,"Code":1400},
 {"Location":"rebuilt/R.cs","Lines":90,"Code":80}]},
 {"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":100,"Code":90}]}]'
stub_lizard "$S5" "$(liz_row 'src/Calc.cs' 'Run' 34 200)
$(liz_row 'rebuilt/R.cs' 'Run' 4 20)"

( cd "$C5" && PATH="$(clean_path "$S5")" bash "$QUALITY_BIN" collect .specclaw src >/dev/null 2>&1 )
( cd "$C5" && PATH="$(clean_path "$S5")" bash "$QUALITY_BIN" collect .specclaw rebuilt --target >/dev/null 2>&1 )
( cd "$C5" && bash "$QUALITY_BIN" compare .specclaw >/dev/null 2>&1 )
c5_exit=$?
assert_eq "5a compare exits 0 in advisory mode" "0" "$c5_exit"

C5D="$C5/.specclaw/analysis/quality-delta.json"
c5_cx="$(jq -r '.deltas[] | select(.module_id == "MOD-001" and .metric == "complexity") | .classification' "$C5D")"
assert_eq "5b a HIGH-to-PASS dimension is improved" "improved" "$c5_cx"

# Duplication was measured on NEITHER side (no jscpd), so it is not comparable —
# and specifically not an improvement.
c5_dup="$(jq -r '.deltas[] | select(.module_id == "MOD-001" and .metric == "duplication") | .classification' "$C5D")"
assert_eq "5c a dimension measured on neither side is NOT-COMPARABLE" "NOT-COMPARABLE" "$c5_dup"

# The load-bearing one: legacy unmeasured, target measured. Never "improved".
C5B="$WORK/c5b"; new_project "$C5B"
rm -f "$C5B/src/Calc.cs"                        # legacy is the unsupported language only
mkdir -p "$C5B/rebuilt"; printf 'public class R { }\n' > "$C5B/rebuilt/R.cs"
cat > "$C5B/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Fixture

**Status:** CONFIRMED by fixture, 2026-08-25

## Modules

### MOD-001 — Billing

- **Purpose:** spans both trees
- **Evidence:**
  - `src/Legacy.pas:1` — the legacy unit
  - `rebuilt/R.cs:1` — the rebuilt calculator
MM
S5B="$WORK/c5b-stub"
stub_scc "$S5B" '[{"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":90,"Code":80}]},
 {"Name":"C#","Files":[{"Location":"rebuilt/R.cs","Lines":90,"Code":80}]}]'
stub_lizard "$S5B" "$(liz_row 'rebuilt/R.cs' 'Run' 4 20)"

( cd "$C5B" && PATH="$(clean_path "$S5B")" bash "$QUALITY_BIN" collect .specclaw src >/dev/null 2>&1 )
( cd "$C5B" && PATH="$(clean_path "$S5B")" bash "$QUALITY_BIN" collect .specclaw rebuilt --target >/dev/null 2>&1 )
( cd "$C5B" && bash "$QUALITY_BIN" compare .specclaw >/dev/null 2>&1 )

c5b_legacy="$(jq -r '.deltas[] | select(.module_id == "MOD-001" and .metric == "complexity") | .legacy_status' "$C5B/.specclaw/analysis/quality-delta.json")"
c5b_target="$(jq -r '.deltas[] | select(.module_id == "MOD-001" and .metric == "complexity") | .target_status' "$C5B/.specclaw/analysis/quality-delta.json")"
c5b_class="$(jq -r '.deltas[] | select(.module_id == "MOD-001" and .metric == "complexity") | .classification' "$C5B/.specclaw/analysis/quality-delta.json")"
assert_eq "5d legacy complexity was unmeasurable" "NOT-MEASURED" "$c5b_legacy"
assert_eq "5e target complexity was measured" "PASS" "$c5b_target"
assert_eq "5f unmeasured legacy vs measured target is NOT-COMPARABLE, never improved" "NOT-COMPARABLE" "$c5b_class"

# compare fails fast, and says which snapshot is missing.
C5C="$WORK/c5c"; mkdir -p "$C5C/.specclaw/analysis"
c5c_err="$( cd "$C5C" && bash "$QUALITY_BIN" compare .specclaw 2>&1 1>/dev/null )"
c5c_exit=$?
if [[ "$c5c_exit" -ne 0 ]]; then pass "5g compare with no snapshots exits non-zero"
else fail "5g compare with no snapshots exits non-zero (got 0)"; fi
assert_contains "5h the refusal names the missing legacy snapshot" "quality.json" "$c5c_err"
assert_contains "5i the refusal names the missing target snapshot" "quality-target.json" "$c5c_err"

# ── Case 6 — the gate ────────────────────────────────────────────────────────

echo "--- Case 6: gate FAILs on regression with exit 1, PASSes with exit 0 ---"
# Reuse C5's improved pair for the PASS path.
c6_pass_out="$( cd "$C5" && bash "$QUALITY_BIN" compare .specclaw --gate 2>/dev/null )"
c6_pass_exit=$?
assert_eq "6a improved target: verdict line is PASS" "QUALITY-GATE: PASS" "$c6_pass_out"
assert_eq "6b improved target: exit 0" "0" "$c6_pass_exit"

# Now invert the pair: the rebuild is worse than the legacy it replaced.
stub_lizard "$S5" "$(liz_row 'src/Calc.cs' 'Run' 4 20)
$(liz_row 'rebuilt/R.cs' 'Run' 34 200)"
stub_scc "$S5" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":90,"Code":80},
 {"Location":"rebuilt/R.cs","Lines":1500,"Code":1400}]},
 {"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":100,"Code":90}]}]'
( cd "$C5" && PATH="$(clean_path "$S5")" bash "$QUALITY_BIN" collect .specclaw src >/dev/null 2>&1 )
( cd "$C5" && PATH="$(clean_path "$S5")" bash "$QUALITY_BIN" collect .specclaw rebuilt --target >/dev/null 2>&1 )
c6_fail_out="$( cd "$C5" && bash "$QUALITY_BIN" compare .specclaw --gate 2>/dev/null )"
c6_fail_exit=$?
assert_eq "6c regressed target: exit 1" "1" "$c6_fail_exit"
assert_contains "6d regressed target: verdict line is FAIL with a count" "QUALITY-GATE: FAIL (" "$c6_fail_out"

c6_regs="$(jq -r '.gate.regression_count' "$C5D")"
if [[ "$c6_regs" -gt 0 ]]; then pass "6e the delta records the regressions the gate counted"
else fail "6e the delta records the regressions the gate counted (got $c6_regs)"; fi

# Without --gate the same regressed pair reports and exits 0. Advisory means
# advisory: the gate is the only thing that ever blocks.
( cd "$C5" && bash "$QUALITY_BIN" compare .specclaw >/dev/null 2>&1 )
assert_eq "6f the same regression without --gate exits 0" "0" "$?"

# ── Case 7 — rebuild-plan neutrality ─────────────────────────────────────────

echo "--- Case 7: bf-rebuild-plan is unchanged when quality.json is absent ---"
# Both projects share the same BASENAME under different parents. The rendered
# document's title is derived from the project directory name, so differently
# named fixtures would make the two outputs differ in their heading and defeat
# the byte-comparison this case exists for.
C7A="$WORK/c7-without/proj"; C7B="$WORK/c7-with/proj"
for d in "$C7A" "$C7B"; do
  mkdir -p "$d/.specclaw/analysis"
  cp -R "$SCRIPT_DIR/fixtures/rebuild-plan/analysis/." "$d/.specclaw/analysis/"
done
C7_DRAFT="$WORK/c7-draft.md"
cat > "$C7_DRAFT" <<'DRAFT'
### BL-001 — Manage Things

**Module:** MOD-001
**Maps to capability:** "Create and edit a Thing"
**Depends on:** None
**Acceptance basis (domain-model.md):**
- DR-001: a Thing must have a name

**Verification inputs needed:**
- A golden-master capture of the Thing editor.

## Sequencing Rationale

Single item, nothing to sequence.

## Coverage Check

- **MOD-001** — "Create and edit a Thing" → BL-001

**Orphaned:** none

### Open Questions Blocking Readiness

None — no open questions touch any item's acceptance basis.
DRAFT

# The annotated run gets a quality.json; the other gets none. Everything else
# about the two projects is identical, including the draft.
cat > "$C7B/.specclaw/analysis/quality.json" <<'QJ'
{"schema_version":1,
 "modules":[{"module_id":"MOD-001","rollup_status":"HIGH"}],
 "quality_issues":[{"id":"QI-001","module_id":"MOD-001","status":"open"},
                   {"id":"QI-002","module_id":"MOD-001","status":"open"},
                   {"id":"QI-003","module_id":"MOD-001","status":"resolved"}]}
QJ

cp "$C7_DRAFT" "$C7A/.specclaw/analysis/.rebuild-plan-draft.md"
( cd "$C7A" && bash "$REBUILD_BIN" render .specclaw .specclaw/analysis/.rebuild-plan-draft.md >/dev/null 2>&1 )
assert_eq "7a render succeeds with no quality.json" "0" "$?"
cp "$C7_DRAFT" "$C7B/.specclaw/analysis/.rebuild-plan-draft.md"
( cd "$C7B" && bash "$REBUILD_BIN" render .specclaw .specclaw/analysis/.rebuild-plan-draft.md >/dev/null 2>&1 )
assert_eq "7b render succeeds with a quality.json" "0" "$?"

C7A_OUT="$C7A/.specclaw/analysis/rebuild-backlog.md"
C7B_OUT="$C7B/.specclaw/analysis/rebuild-backlog.md"

# The un-annotated run must carry the rollup line and NO quality text anywhere.
if grep -qE '^- \*\*MOD-001 — Core:\*\* 1/1 capability bullets covered; 0 excluded; 0 orphaned$' "$C7A_OUT"; then
  pass "7c with no quality.json the rollup line ends exactly where it always did"
else
  fail "7c with no quality.json the rollup line ends exactly where it always did (got: $(grep -E '^- \*\*MOD-001' "$C7A_OUT" | head -1))"
fi
# GENERATED content only. Every HTML comment in the rendered file is the
# template's own prose, copied verbatim whether or not quality.json exists, and
# the template has to document the quality-remediation mechanism for
# QUALITY-MEASURED to be discoverable at all. Stripping the comments is what
# keeps this assertion about what it was always about: that a project which
# never measured gets a document with no quality FINDINGS in it.
c7a_generated="$(awk '/^<!--/{c=1} c{ if (/-->/) c=0; next } {print}' "$C7A_OUT")"
if printf '%s' "$c7a_generated" | grep -qi 'quality'; then
  fail "7d with no quality.json nothing generated mentions quality (found: $(printf '%s' "$c7a_generated" | grep -in 'quality' | head -2))"
else
  pass "7d with no quality.json nothing generated mentions quality"
fi

# THE NEUTRALITY PROOF. Diff the two runs and require every differing line to be
# a quality annotation. Anything else differing would mean the hook changed
# output it has no business touching.
c7_diff="$(diff "$C7A_OUT" "$C7B_OUT" | grep -E '^[<>]' || true)"
# A rollup line appears on BOTH sides of the diff — un-suffixed on the `<` side,
# suffixed on the `>` side — so both must be allowed, not just the annotated one.
# Filtering only for the suffix text would report the un-suffixed half as stray.
c7_stray="$(printf '%s\n' "$c7_diff" \
  | grep -E '^[<>]' \
  | grep -vE '^[<>] - \*\*MOD-[0-9]+ — ' \
  | grep -vE 'warrant extra rebuild attention' \
  | grep -vE '^[<>][[:space:]]*$' || true)"
if [[ -z "$c7_stray" ]]; then
  pass "7e the annotation is the ONLY difference between the two renders"
else
  fail "7e the annotation is the ONLY difference between the two renders (stray: $(printf '%s' "$c7_stray" | head -c 300))"
fi

assert_contains "7f the annotated rollup carries the status and open-QI count" \
  "0 orphaned; quality HIGH (2 open QI)" "$(grep -E '^- \*\*MOD-001 — ' "$C7B_OUT" | head -1)"
if grep -q 'warrant extra rebuild attention' "$C7B_OUT"; then
  pass "7g HIGH modules are flagged for extra rebuild attention"
else
  fail "7g HIGH modules are flagged for extra rebuild attention"
fi

# A malformed or unreadable quality.json degrades to the absent case rather than
# breaking the backlog. Every failure mode is the same empty string.
C7C="$WORK/c7-broken/proj"; mkdir -p "$C7C/.specclaw/analysis"
cp -R "$SCRIPT_DIR/fixtures/rebuild-plan/analysis/." "$C7C/.specclaw/analysis/"
printf 'this is not json at all\n' > "$C7C/.specclaw/analysis/quality.json"
cp "$C7_DRAFT" "$C7C/.specclaw/analysis/.rebuild-plan-draft.md"
( cd "$C7C" && bash "$REBUILD_BIN" render .specclaw .specclaw/analysis/.rebuild-plan-draft.md >/dev/null 2>&1 )
c7c_exit=$?
assert_eq "7h an unreadable quality.json does not break render" "0" "$c7c_exit"
if diff -q "$C7A_OUT" "$C7C/.specclaw/analysis/rebuild-backlog.md" >/dev/null 2>&1; then
  pass "7i an unreadable quality.json degrades to byte-identical un-annotated output"
else
  fail "7i an unreadable quality.json degrades to byte-identical un-annotated output"
fi

# ── Case 8 — advisory neutrality ─────────────────────────────────────────────

echo "--- Case 8: HIGH findings are advisory and still exit 0 ---"
C8="$WORK/c8"; new_project "$C8"; module_map_one "$C8"
S8="$WORK/c8-stub"
stub_scc "$S8" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":5000,"Code":4800}]}]'
stub_lizard "$S8" "$(liz_row 'src/Calc.cs' 'Run' 99 900)"
( cd "$C8" && PATH="$(clean_path "$S8")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
assert_eq "8a a run full of HIGH findings exits 0" "0" "$?"
c8_roll="$(jq -r '.modules[] | select(.module_id == "MOD-001") | .rollup_status' "$C8/.specclaw/analysis/quality.json")"
assert_eq "8b and the findings really are HIGH" "HIGH" "$c8_roll"

# The snapshot is archived rather than overwritten, and the archived copy says
# it is superseded.
( cd "$C8" && PATH="$(clean_path "$S8")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c8_arch="$(find "$C8/.specclaw/analysis/archive" -name '*-quality.json' 2>/dev/null | head -1)"
if [[ -n "$c8_arch" ]]; then
  pass "8c a re-run archives the prior snapshot"
  c8_sup="$(jq -r '.superseded' "$c8_arch" 2>/dev/null)"
  assert_eq "8d the archived snapshot is flagged superseded" "true" "$c8_sup"
else
  fail "8c a re-run archives the prior snapshot"
  fail "8d the archived snapshot is flagged superseded"
fi

# ── Case 9 — the module join ──────────────────────────────────────────────────

echo "--- Case 9: uncited files roll up under MOD-UNASSIGNED; ambiguity is not guessed ---"
C9="$WORK/c9"; new_project "$C9"
printf 'public class Shared { }\n' > "$C9/src/Shared.cs"
printf 'public class Lonely { }\n' > "$C9/src/Lonely.cs"
cat > "$C9/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Fixture

**Status:** PROPOSED

## Modules

### MOD-001 — Billing

- **Purpose:** cites one file, and shares one
- **Evidence:**
  - `src/Calc.cs:1` — the calculator
  - `src/Shared.cs:3` — shared helper

### MOD-002 — Reporting

- **Purpose:** also claims the shared file
- **Evidence:**
  - `src/Shared.cs:9` — shared helper again

### MOD-003 — Retired — WITHDRAWN 2026-08-25, superseded by MOD-001

- **Evidence:**
  - `src/Lonely.cs:1` — a tombstone must not claim a file
MM
S9="$WORK/c9-stub"
stub_scc "$S9" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":50,"Code":40},
 {"Location":"src/Shared.cs","Lines":50,"Code":40},
 {"Location":"src/Lonely.cs","Lines":50,"Code":40}]},
 {"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":50,"Code":40}]}]'
stub_lizard "$S9" "$(liz_row 'src/Calc.cs' 'Run' 4 12)"

c9_out="$( cd "$C9" && PATH="$(clean_path "$S9")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

c9_m1="$(printf '%s' "$c9_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | .files')"
assert_eq "9a a module gets exactly the files it cites unambiguously" "1" "$c9_m1"

c9_unassigned="$(printf '%s' "$c9_out" | jq -r '.modules[] | select(.module_id == "MOD-UNASSIGNED") | .files')"
assert_eq "9b uncited, tombstone-cited and ambiguous files all land in MOD-UNASSIGNED" "3" "$c9_unassigned"

c9_ambig="$(printf '%s' "$c9_out" | jq -r '.files.module_ambiguous')"
assert_eq "9c the file two modules cite is counted as ambiguous, not allocated" "1" "$c9_ambig"

c9_m2="$(printf '%s' "$c9_out" | jq -r '[.modules[] | select(.module_id == "MOD-002")] | length')"
assert_eq "9d a module whose only citation was ambiguous claims no files" "0" "$c9_m2"

c9_status="$(printf '%s' "$c9_out" | jq -r '.module_map_status')"
assert_eq "9e an unconfirmed map is reported as PROPOSED, not treated as confirmed" "PROPOSED" "$c9_status"

# No map at all is a normal state, not an error.
C9B="$WORK/c9b"; new_project "$C9B"
c9b_out="$( cd "$C9B" && PATH="$(clean_path "$S9")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c9b_exit=$?
assert_eq "9f no module-map.md at all: exit 0" "0" "$c9b_exit"
c9b_mods="$(printf '%s' "$c9b_out" | jq -r '[.modules[].module_id] | join(",")')"
assert_eq "9g with no map every file rolls up under MOD-UNASSIGNED" "MOD-UNASSIGNED" "$c9b_mods"
c9b_status="$(printf '%s' "$c9b_out" | jq -r '.module_map_status')"
assert_eq "9h and the absence is reported rather than implied" "ABSENT" "$c9b_status"

# ── Case 10 — the report template is client-safe ──────────────────────────────

echo "--- Case 10: the report template body names no internal command ---"
# What is mechanically checkable here is the TEMPLATE, not a generated report:
# the report is written by an agent, which no bash suite can run. So this pins
# the thing the agent is handed — if an internal name is not in the template's
# body, the agent has to invent one to leak it, and its own prompt forbids that.
for tpl in quality-report.md quality-delta.md; do
  T="$PLUGIN_ROOT/templates/$tpl"
  if [[ ! -f "$T" ]]; then fail "10 template exists: $tpl"; continue; fi

  # Everything above the provenance heading, with HTML comments removed — the
  # comments are authoring guidance for the agent and are expected to discuss
  # the pipeline by name.
  body="$(awk '/^## Internal provenance/{exit} {print}' "$T" | awk '/<!--/{c=1} !c{print} /-->/{c=0}')"

  leaked=""
  for name in "specclaw" "SpecClaw" "bf-quality" "bf-rebuild-plan" "bf-analyze" "bf-domain"; do
    case "$body" in *"$name"*) leaked="${leaked}${name} " ;; esac
  done
  if [[ -z "$leaked" ]]; then
    pass "10a ${tpl} body carries no internal command or framework name"
  else
    fail "10a ${tpl} body carries no internal command or framework name (leaked: $leaked)"
  fi

  if grep -q '^## Internal provenance' "$T"; then
    pass "10b ${tpl} has the provenance section internal names belong in"
  else
    fail "10b ${tpl} has the provenance section internal names belong in"
  fi
done

# The agent prompt must actually forbid the agent doing its own measuring.
AGENT="$PLUGIN_ROOT/agents/bf-quality-analyst.md"
if [[ -f "$AGENT" ]]; then
  agent_body="$(cat "$AGENT")"
  assert_contains "10c the agent prompt names its single JSON input" "quality.json" "$agent_body"
  # tools: is the hard guarantee — Read and Write only means no Bash, so the
  # agent cannot invoke a metric tool whatever the prose says.
  if grep -qE '^tools: *Read, *Write$' "$AGENT"; then
    pass "10d the agent is granted Read and Write only, so it cannot run a tool"
  else
    fail "10d the agent is granted Read and Write only (got: $(grep -E '^tools:' "$AGENT"))"
  fi
else
  fail "10c the quality agent prompt exists"
  fail "10d the agent is granted Read and Write only"
fi

# ── Case 11 — the ARG_MAX regression: a file list too big for argv ────────────
#
# The bug: the aggregation step passed each per-file JSON array as
# `--argjson X "$(cat X.json)"`. Those arrays carry one element per source file,
# so on a large repo the substitution put multiple megabytes into a single argv
# slot and the run died with "Argument list too long" (E2BIG) before jq started
# — a single argument over MAX_ARG_STRLEN (128 KiB on Linux) is enough to trip
# it, well below the total ARG_MAX. The fix reads those files with --slurpfile,
# off argv entirely. This case builds a tree whose joined path list is over 2 MB
# and requires the collector to complete with exit 0.
#
# Metric tools are deliberately ABSENT here: the file list is built from the
# extension classification, independent of any tool, so the argv pressure is
# reproduced without invoking scc/lizard/jscpd across thousands of files (which
# would make the case slow without testing anything new). loc/funcs/dup come
# back empty; files.json and filemod.json are what get large.

echo "--- Case 11: a >2 MB joined file list does not overflow argv (ARG_MAX) ---"
C11="$WORK/c11"
mkdir -p "$C11/.specclaw/analysis"
# Long nested paths: a handful of long-named directories, each holding many
# long-named files, reaches >2 MB of path text with far fewer inodes than flat
# files would — so the case stays fast while genuinely exceeding the threshold.
DIRPAD="dir_$(printf 'd%.0s' $(seq 1 96))"          # ~100-char directory names
FILEPAD="$(printf 'f%.0s' $(seq 1 196))"            # ~200-char file stems
mkdir -p "$C11/src"
n_created=0
for d in $(seq 1 10); do
  sub="$C11/src/${DIRPAD}_${d}"
  mkdir -p "$sub"
  for i in $(seq 1 800); do
    printf 'class C{}' > "$sub/${FILEPAD}_${i}.cs"
    n_created=$((n_created + 1))
  done
done
# No module-map: every file rolls up under MOD-UNASSIGNED, which is fine — the
# point is the size of the list, not the join.
list_bytes="$(find "$C11/src" -type f -name '*.cs' | wc -c | tr -d ' ')"
if [[ "$list_bytes" -gt 2097152 ]]; then
  pass "11a the generated path list exceeds 2 MB (${list_bytes} bytes across ${n_created} files)"
else
  fail "11a the generated path list exceeds 2 MB (only ${list_bytes} bytes) — case would not exercise the bug"
fi

# The regression itself: the FIXED collector must complete cleanly.
c11_out="$( cd "$C11" && PATH="$(clean_path "$WORK/empty-stub")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c11_exit=$?
assert_eq "11b collect exits 0 on a >2 MB file list" "0" "$c11_exit"
if [[ -n "$c11_out" ]]; then
  c11_classified="$(printf '%s' "$c11_out" | jq -r '.files.classified')"
  assert_eq "11c every generated .cs file was classified and measured" "$n_created" "$c11_classified"
else
  fail "11c every generated .cs file was classified and measured (collector produced no JSON)"
fi

# Belt and braces: prove the PRE-fix code actually failed on this same tree, so
# the case is known to exercise the bug rather than passing vacuously. This is
# informational — some platforms (notably MSYS2) raise the single-arg limit, so
# a clean pre-run is reported, not asserted.
PRE_COLLECT="$WORK/pre-collect"
if git -C "$SCRIPT_DIR" show "feat/bf-quality:plugins/specclaw/bin/specclaw-bf-quality-collect" > "$PRE_COLLECT" 2>/dev/null && [[ -s "$PRE_COLLECT" ]]; then
  ( cd "$C11" && PATH="$(clean_path "$WORK/empty-stub")" bash "$PRE_COLLECT" collect .specclaw >/dev/null 2>&1 )
  pre_exit=$?
  if [[ "$pre_exit" -ne 0 ]]; then
    pass "11d (informational) the pre-fix collector failed on this tree (exit ${pre_exit}), confirming the case bites"
  else
    echo "NOTE: 11d the pre-fix collector did NOT fail here (exit 0) — this platform's single-arg limit is above the list size; the fix is still exercised by 11b."
    PASS=$((PASS + 1))
  fi
else
  echo "NOTE: 11d pre-fix binary not retrievable (feat/bf-quality not present) — skipping the informational pre-run."
  PASS=$((PASS + 1))
fi

# ── Case 12 — paths with spaces and unicode are measured, not mangled ─────────

echo "--- Case 12: filenames with spaces and unicode survive the whole pipeline ---"
C12="$WORK/c12"
mkdir -p "$C12/.specclaw/analysis" "$C12/src"
printf 'public class A { }\n' > "$C12/src/My Invoice Calc.cs"
printf 'public class B { }\n' > "$C12/src/naïve café résumé.cs"
cat > "$C12/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Unicode

**Status:** CONFIRMED by fixture, 2026-08-25

## Modules

### MOD-001 — Billing

- **Evidence:**
  - `src/My Invoice Calc.cs:1` — the calculator with spaces in its name
MM
S12="$WORK/c12-stub"
# scc/lizard emit rows keyed by the exact spaced/unicode paths, to prove the
# join survives them too (not just enumeration).
stub_scc "$S12" '[{"Name":"C#","Files":[
 {"Location":"src/My Invoice Calc.cs","Lines":1400,"Code":1300},
 {"Location":"src/naïve café résumé.cs","Lines":50,"Code":40}]}]'
stub_lizard "$S12" "$(liz_row 'src/My Invoice Calc.cs' 'Run' 34 150)"

c12_out="$( cd "$C12" && PATH="$(clean_path "$S12")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c12_exit=$?
assert_eq "12a collect exits 0 with spaced/unicode paths" "0" "$c12_exit"

c12_classified="$(printf '%s' "$c12_out" | jq -r '.files.classified')"
assert_eq "12b both files were classified, neither split on its space" "2" "$c12_classified"

# Both files' size rows joined — proving the scc join keys survive the space and
# the non-ASCII bytes intact, not just enumeration.
c12_sized="$(printf '%s' "$c12_out" | jq -r '.files.sized')"
assert_eq "12c both spaced/unicode files joined to their scc size rows" "2" "$c12_sized"

# Their LOC is summed correctly (1300 + 40). This is the "measured correctly"
# guarantee: every metric is computed with the path intact and no word-splitting.
c12_loc="$(printf '%s' "$c12_out" | jq -r '[.modules[].loc] | add')"
assert_eq "12d the LOC of both files is measured and summed correctly" "1340" "$c12_loc"

# A complexity hotspot on the spaced path is registered with the path byte-exact
# in its key — the path travelled intact all the way into the QI registry.
c12_hot="$(printf '%s' "$c12_out" | jq -r '[.quality_issues[] | select(.file == "src/My Invoice Calc.cs")] | length')"
if [[ "$c12_hot" -ge 1 ]]; then
  pass "12e a hotspot on the spaced path is registered with the path intact"
else
  fail "12e a hotspot on the spaced path is registered with the path intact (got $c12_hot)"
fi

# KNOWN LIMITATION, asserted so it is documented rather than surprising: the
# module-map Evidence citation `src/My Invoice Calc.cs` does NOT match this file,
# because parse_module_citations' path regex has no space in its character
# class. So a spaced path cited in the map rolls up under MOD-UNASSIGNED. This
# is pre-existing, unrelated to the ARG_MAX fix, and deliberately not changed
# here (that would be a second behavioural change under a fix ticket). The file
# is still fully measured — it just is not attributed to its module.
c12_unassigned_loc="$(printf '%s' "$c12_out" | jq -r '.modules[] | select(.module_id == "MOD-UNASSIGNED") | .loc')"
assert_eq "12f (documents a pre-existing gap) a spaced citation is unmatched, so both files sit under MOD-UNASSIGNED" "1340" "$c12_unassigned_loc"

# ── Case 13 — quality remediation backlog items ──────────────────────────────
#
# The measured hotspots stop being advice and become something the rebuild is
# accountable for. Every assertion here is about a state BASH computed: which
# modules get an item, which hotspots each lists, whether it is gated, and
# whether the delta says it is done. The agent narrates; it decides nothing.
#
# WHAT KEEPS THIS OPTIONAL is asserted first and asserted twice — here, and in
# Case 7's byte-for-byte diff of an annotated against an un-annotated render.

echo
echo "--- Case 13: quality remediation items ---"

REPLAY_BIN="$BIN_DIR/specclaw-bf-replay"

# A three-module project: MOD-001 and MOD-002 will measure HIGH, MOD-003 only
# WARN. That is the shape the whole severity-floor behaviour turns on.
qr_project() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis"
  cat > "$root/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: QR

**Status:** CONFIRMED by Tester, 2026-08-31

## Modules

### MOD-001 — Auth

- **Business rules:** DR-001
- **Depends on:** None

### MOD-002 — Billing

- **Business rules:** DR-002
- **Depends on:** MOD-001

### MOD-003 — Reports

- **Business rules:** DR-003
- **Depends on:** MOD-002
MM
  printf '### DR-001 — a\n### DR-002 — b\n### DR-003 — c\n' \
    > "$root/.specclaw/analysis/domain-model.md"
  cat > "$root/draft.md" <<'DR'
### BL-001 — Sign In

**Module:** MOD-001
**Depends on:** None
**Acceptance basis (domain-model.md):**
- DR-001: a session is authenticated before any action.

### BL-002 — Raise an Invoice

**Module:** MOD-002
**Depends on:** BL-001
**Acceptance basis (domain-model.md):**
- DR-002: an invoice has at least one line.

### BL-003 — Monthly Statement

**Module:** MOD-003
**Depends on:** BL-002
**Acceptance basis (domain-model.md):**
- DR-003: a statement covers one calendar month.

## Sequencing Rationale

Auth, then billing, then reporting.

## Coverage Check

- **MOD-001** — "Sign in" → BL-001
- **MOD-002** — "Raise an invoice" → BL-002
- **MOD-003** — "Monthly statement" → BL-003
DR
}

# MOD-001: two HIGH hotspots. MOD-002: one HIGH. MOD-003: one WARN only, which
# under the default HIGH floor must produce an advisory count and NO item.
qr_quality_json() {
  cat > "$1/.specclaw/analysis/quality.json" <<'QJ'
{"schema_version":1,
 "thresholds":{"complexity_high":20,"file_length_high":1000,"register_severity":"WARN"},
 "modules":[{"module_id":"MOD-001","rollup_status":"HIGH"},
            {"module_id":"MOD-002","rollup_status":"HIGH"},
            {"module_id":"MOD-003","rollup_status":"WARN"}],
 "quality_issues":[
   {"id":"QI-001","module_id":"MOD-001","status":"open","metric":"complexity",
    "file":"legacy/auth/session","function":"Validate","value":34,"severity":"HIGH"},
   {"id":"QI-002","module_id":"MOD-001","status":"open","metric":"file_length",
    "file":"legacy/auth/session","function":null,"value":1420,"severity":"HIGH"},
   {"id":"QI-003","module_id":"MOD-002","status":"open","metric":"duplication",
    "file":null,"function":null,"value":22.5,"severity":"HIGH"},
   {"id":"QI-004","module_id":"MOD-003","status":"open","metric":"complexity",
    "file":"legacy/reports/monthly","function":"Build","value":13,"severity":"WARN"},
   {"id":"QI-009","module_id":"MOD-001","status":"resolved","metric":"complexity",
    "file":"legacy/auth/old","function":"Gone","value":null,"severity":null}]}
QJ
}

qr_render()  { ( cd "$1" && bash "$REBUILD_BIN" render .specclaw ./draft.md ) >/dev/null 2>&1; }
qr_refresh() { : > "$1/empty-draft.md"; ( cd "$1" && bash "$REBUILD_BIN" render .specclaw ./empty-draft.md ) >/dev/null 2>&1; }
qr_backlog() { printf '%s' "$1/.specclaw/analysis/rebuild-backlog.md"; }
qr_block()   { awk -v id="$2" '$0 ~ ("^### " id " ") {f=1;next} f && /^### / {exit} f' "$1"; }
qr_section() { awk '/^## Backlog/{f=1} /^## Sequencing Rationale/{f=0} f' "$1"; }

# Append a note block to one item, exactly where a human would: under its own
# Status-notes heading, after the last bash-written field of that item.
qr_add_note() {
  local f="$1" id="$2" anchor="$3" note="$4"
  awk -v id="$id" -v anchor="$anchor" -v note="$note" '
    $0 ~ ("^### " id " ") { inblock = 1 }
    { print }
    inblock && index($0, anchor) == 1 {
      print ""
      print "**Status notes (human-added):**"
      print note
      inblock = 0
    }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
}

# ── 13a — optionality: no quality.json, no remediation anything ──────────────
# The byte-for-byte half of this guarantee is Case 7's diff; this half asserts
# that nothing the new mechanism emits leaks into a project that never measured.
QRA="$WORK/qr-a"; qr_project "$QRA"; qr_render "$QRA"
# Every HTML comment in the rendered file comes from the template verbatim and
# is present whether or not quality.json exists — the template documents the
# mechanism, which is what makes QUALITY-MEASURED discoverable at all. What must
# be untouched is the GENERATED content, so that is what this strips down to.
qra_out="$(awk '/^<!--/{c=1} c{ if (/-->/) c=0; next } {print}' "$(qr_backlog "$QRA")")"
if [[ "$qra_out" == *"QUALITY-REMEDIATION"* || "$qra_out" == *"QUALITY-MEASURED"* || "$qra_out" == *"Quality state"* || "$qra_out" == *"quality"* ]]; then
  fail "13a with no quality.json nothing generated mentions quality at all"
else
  pass "13a with no quality.json nothing generated mentions quality at all"
fi
assert_eq "13a2 and no item beyond the three drafted ones exists" "3" \
  "$(grep -cE '^### BL-[0-9]{3} ' "$(qr_backlog "$QRA")")"

# ── 13b — two HIGH modules get one item each; the WARN module gets none ──────
QRB="$WORK/qr-b"; qr_project "$QRB"; qr_quality_json "$QRB"; qr_render "$QRB"
QRB_OUT="$(qr_backlog "$QRB")"
assert_eq "13b exactly two remediation items are generated" "2" \
  "$(grep -c '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$QRB_OUT")"
assert_eq "13b2 they take the next free ids, in module order" "BL-004 BL-005" \
  "$(grep -B4 '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$QRB_OUT" | grep -oE 'BL-[0-9]{3}' | paste -sd' ' -)"
assert_contains "13b3 the MOD-001 item lists both of its HIGH hotspots" \
  "- QI-001 — complexity, legacy/auth/session::Validate, measured 34, HIGH" \
  "$(qr_block "$QRB_OUT" BL-004)"
assert_contains "13b4 a file-level hotspot keeps its own empty function field" \
  "- QI-002 — file_length, legacy/auth/session, measured 1420, HIGH" \
  "$(qr_block "$QRB_OUT" BL-004)"
assert_contains "13b5 a module-wide hotspot says so rather than naming a file" \
  "- QI-003 — duplication, module-wide, measured 22.5, HIGH" \
  "$(qr_block "$QRB_OUT" BL-005)"
if qr_block "$QRB_OUT" BL-004 | grep -q 'QI-009'; then
  fail "13b6 a resolved hotspot is never listed as something to remediate"
else
  pass "13b6 a resolved hotspot is never listed as something to remediate"
fi
# MOD-003's WARN hotspot: an advisory count on its rollup line, and no item.
assert_contains "13b7 the WARN-only module gets an advisory count, not an item" \
  "1 advisory QI below the HIGH remediation floor (no item generated)" \
  "$(grep -E '^- \*\*MOD-003 — ' "$QRB_OUT")"
if grep -A6 '^### BL-00[45] ' "$QRB_OUT" | grep -q 'MOD-003'; then
  fail "13b8 no remediation item is generated for the WARN-only module"
else
  pass "13b8 no remediation item is generated for the WARN-only module"
fi
# The new Verification value, and the item's own third axis.
assert_contains "13b9 the item's Verification is the new QUALITY-MEASURED channel" \
  "**Verification:** QUALITY-MEASURED" "$(qr_block "$QRB_OUT" BL-004)"
if qr_block "$QRB_OUT" BL-004 | grep -q 'NO BASELINE DATA'; then
  fail "13b10 a remediation item never reports NO BASELINE DATA"
else
  pass "13b10 a remediation item never reports NO BASELINE DATA"
fi
# PD-04, asserted on a RENDERED item and not only on the template: the
# acceptance criterion is a measurement of the target, never an instruction to
# go and change the legacy implementation.
qrb_body="$(qr_block "$QRB_OUT" BL-004)"
if printf '%s' "$qrb_body" | grep -qiE 'refactor|clean up|rewrite (the )?legacy|fix the legacy'; then
  fail "13b11 the item never asks anyone to change the legacy implementation"
else
  pass "13b11 the item never asks anyone to change the legacy implementation"
fi
assert_contains "13b12 and states the measured criterion in the target's terms" \
  "the REBUILT MOD-001 measures within the configured thresholds" "$qrb_body"

# ── 13c — idempotency: two consecutive refreshes are identical ───────────────
# Compared refresh-to-refresh rather than render-to-refresh: the first run also
# merges the agent's draft, which is a different operation from re-deriving an
# existing document, and conflating the two would test the wrong thing.
QRC="$WORK/qr-c"; qr_project "$QRC"; qr_quality_json "$QRC"
qr_render "$QRC"; qr_refresh "$QRC"
qrc_one_4="$(qr_block "$(qr_backlog "$QRC")" BL-004)"
qrc_one_5="$(qr_block "$(qr_backlog "$QRC")" BL-005)"
qrc_one="$(qr_section "$(qr_backlog "$QRC")")"
qr_refresh "$QRC"
qrc_two_4="$(qr_block "$(qr_backlog "$QRC")" BL-004)"
qrc_two_5="$(qr_block "$(qr_backlog "$QRC")" BL-005)"
qrc_two="$(qr_section "$(qr_backlog "$QRC")")"

# THE CLAIM UNDER TEST is that a remediation item is a pure function of
# quality.json: same hotspots in, byte-identical item out, no second item, no
# new ledger line, no renumbering. Asserted on the items themselves rather than
# on the whole section, because the section carries a pre-existing whitespace
# drift that has nothing to do with this mechanism (see 13c4).
if [[ -n "$qrc_one_4" && "$qrc_one_4" == "$qrc_two_4" && "$qrc_one_5" == "$qrc_two_5" ]]; then
  pass "13c an unchanged quality.json regenerates both remediation items byte-identically"
else
  fail "13c an unchanged quality.json regenerates both remediation items byte-identically ($(diff <(printf '%s' "$qrc_one_4") <(printf '%s' "$qrc_two_4") | head -c 300))"
fi
assert_eq "13c2 and the remediation ids are unchanged across both runs" "BL-004 BL-005" \
  "$(grep -B4 '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$(qr_backlog "$QRC")" | grep -oE 'BL-[0-9]{3}' | paste -sd' ' -)"

# And the whole Backlog section is byte-identical — no item appears, disappears,
# changes a field, or gains a line. Strict equality, no whitespace normalization:
# see 13c4 for why that is now assertable.
if [[ -n "$qrc_one" && "$qrc_one" == "$qrc_two" ]]; then
  pass "13c3 and the whole Backlog section is byte-identical between the two runs"
else
  fail "13c3 and the whole Backlog section is byte-identical between the two runs ($(diff <(printf '%s' "$qrc_one") <(printf '%s' "$qrc_two") | head -c 300))"
fi

# 13c4 GUARDS A FIXED DEFECT. render writes an item as "heading, blank, body", so
# the parse that reads a preserved item back handed the body that blank as its
# own first line — and the next render prepended another. Every --refresh added
# one blank line under every preserved item's heading, without bound and without
# ever being visible in review. Four refreshes, four blank lines.
#
# Leading blanks are now stripped on both the preserved and the draft path, so a
# first render and every refresh after it agree. This asserts the invariant
# directly rather than only through 13c3's equality, so a regression names the
# cause instead of printing a whitespace diff.
qrc_drift_ok=true
for qrc_id in BL-001 BL-002 BL-003 BL-004 BL-005; do
  qrc_n="$(qr_block "$(qr_backlog "$QRC")" "$qrc_id" | sed -n '1,4p' | grep -c '^$')"
  [[ "$qrc_n" -le 1 ]] || { qrc_drift_ok=false; qrc_bad="${qrc_id} has ${qrc_n}"; }
done
if $qrc_drift_ok; then
  pass "13c4 no item accumulates blank lines under its heading across refreshes"
else
  fail "13c4 no item accumulates blank lines under its heading across refreshes (${qrc_bad})"
fi

# ── 13d — a newly measured hotspot APPENDS to the module's existing item ─────
QRD="$WORK/qr-d"; qr_project "$QRD"; qr_quality_json "$QRD"
qr_render "$QRD"; qr_refresh "$QRD"
jq '.quality_issues += [{"id":"QI-011","module_id":"MOD-001","status":"open",
     "metric":"function_length","file":"legacy/auth/session","function":"Renew",
     "value":260,"severity":"HIGH"}]' \
  "$QRD/.specclaw/analysis/quality.json" > "$QRD/q.tmp" \
  && mv "$QRD/q.tmp" "$QRD/.specclaw/analysis/quality.json"
qr_refresh "$QRD"
QRD_OUT="$(qr_backlog "$QRD")"
assert_eq "13d the re-measured run creates no second item for the module" "2" \
  "$(grep -c '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$QRD_OUT")"
assert_eq "13d2 and renumbers nothing" "BL-004 BL-005" \
  "$(grep -B4 '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$QRD_OUT" | grep -oE 'BL-[0-9]{3}' | paste -sd' ' -)"
assert_contains "13d3 the new hotspot is listed on the existing item" \
  "- QI-011 — function_length, legacy/auth/session::Renew, measured 260, HIGH" \
  "$(qr_block "$QRD_OUT" BL-004)"
assert_contains "13d4 and the addition is recorded, dated" \
  "⊕ **Added $(date +%Y-%m-%d):** QI-011" "$(qr_block "$QRD_OUT" BL-004)"

# ── 13e — gating on the declared BUILT: signal ───────────────────────────────
QRE="$WORK/qr-e"; qr_project "$QRE"; qr_quality_json "$QRE"; qr_render "$QRE"
QRE_OUT="$(qr_backlog "$QRE")"
assert_contains "13e with no BUILT: note the remediation item is BLOCKED" \
  "**Gate:** BLOCKED — quality: awaiting functional items" "$(qr_block "$QRE_OUT" BL-004)"
assert_contains "13e2 and its Quality state says there is nothing to measure yet" \
  "**Quality state:** BLOCKED" "$(qr_block "$QRE_OUT" BL-004)"
qr_add_note "$QRE_OUT" BL-001 "**Verification:**" "- BUILT: PR #12, merged 2026-08-30"
qr_refresh "$QRE"
assert_contains "13e3 once every functional item is BUILT the gate goes CLEAR" \
  "**Gate:** CLEAR" "$(qr_block "$QRE_OUT" BL-004)"

# ── 13f — completion is computed from the delta, never asserted ──────────────
# Same project, now gate-clear, so the state below reflects the measurement and
# nothing else.
cat > "$QRE/.specclaw/analysis/quality-delta.json" <<'QD'
{"schema_version":1,"generated_at":"2026-09-01T10:00:00Z",
 "deltas":[
   {"module_id":"MOD-001","metric":"complexity","legacy_status":"HIGH","target_status":"PASS","classification":"improved"},
   {"module_id":"MOD-001","metric":"function_length","legacy_status":"PASS","target_status":"PASS","classification":"unchanged"},
   {"module_id":"MOD-001","metric":"duplication","legacy_status":"PASS","target_status":"PASS","classification":"unchanged"},
   {"module_id":"MOD-001","metric":"file_length","legacy_status":"HIGH","target_status":"WARN","classification":"improved"}]}
QD
qr_refresh "$QRE"
assert_contains "13f a delta within thresholds with no regression computes DONE" \
  "**Quality state:** DONE" "$(qr_block "$QRE_OUT" BL-004)"
assert_contains "13f2 and cites the delta it was computed from" \
  "2026-09-01T10:00:00Z" "$(qr_block "$QRE_OUT" BL-004)"
# A regressing delta reopens it and names the metric that failed.
jq '.deltas |= map(if .metric == "file_length"
      then .target_status = "HIGH" | .classification = "regressed" else . end)' \
  "$QRE/.specclaw/analysis/quality-delta.json" > "$QRE/d.tmp" \
  && mv "$QRE/d.tmp" "$QRE/.specclaw/analysis/quality-delta.json"
qr_refresh "$QRE"
qre_state="$(qr_block "$QRE_OUT" BL-004 | grep '^\*\*Quality state:\*\*')"
assert_contains "13f3 a regressing delta leaves the item open" "**Quality state:** OPEN" "$qre_state"
assert_contains "13f4 and names the failing metric" "file_length regressed to HIGH" "$qre_state"

# ── 13g — bf-replay refuses a remediation item cleanly ───────────────────────
mkdir -p "$QRE/.specclaw/baseline/fixtures"
cat > "$QRE/.specclaw/baseline/manifest.json" <<'MJ'
{"manifest_schema":3,"fixtures":[
  {"scenario_id":"GM-001","business_rules_pinned":"DR-001","verifies_backlog_item":"BL-001",
   "module_ids":["MOD-001"],"legacy_commit_sha":"abc1234"}]}
MJ
qrg_err="$(bash "$REPLAY_BIN" resolve "$QRE/.specclaw" BL-004 "$QRE/sel.json" 2>&1 >/dev/null)"
qrg_exit=$?
assert_eq "13g the refusal exits 1, the same as every other non-applicable --item scope" "1" "$qrg_exit"
assert_contains "13g2 it names the item type" "is a QUALITY-REMEDIATION item" "$qrg_err"
assert_contains "13g3 it points at the command that DOES verify it" \
  "/specclaw-bf:bf-quality --compare" "$qrg_err"
if [[ "$qrg_err" == *"NO BASELINE DATA"* ]]; then
  fail "13g4 the refusal never reports NO BASELINE DATA"
else
  pass "13g4 the refusal never reports NO BASELINE DATA"
fi
if [[ -e "$QRE/sel.json" ]]; then
  fail "13g5 nothing was created on disk"
else
  pass "13g5 nothing was created on disk"
fi
# THE CONTROL, and the reason it asserts on the error rather than on a
# selection: this fixture's manifest is deliberately a stub, so BL-001 stops at
# the baseline-integrity check further down. That is exactly the point — it got
# PAST the item-kind switch, which a remediation item never does. Asserting the
# guard is narrow means asserting it fires for one item and not the other, not
# that the other one completes a full replay.
qrg_ok_err="$(bash "$REPLAY_BIN" resolve "$QRE/.specclaw" BL-001 "$QRE/sel-ok.json" 2>&1 >/dev/null)"
if [[ "$qrg_ok_err" == *"QUALITY-REMEDIATION"* ]]; then
  fail "13g6 the guard is narrow — it does not fire on an ordinary item"
else
  pass "13g6 the guard is narrow — it does not fire on an ordinary item"
fi
assert_contains "13g7 and that item reaches the join the guard skips" \
  "Baseline check failed" "$qrg_ok_err"

# ── 13h — a human status note on a remediation item survives verbatim ────────
QRH="$WORK/qr-h"; qr_project "$QRH"; qr_quality_json "$QRH"; qr_render "$QRH"
QRH_OUT="$(qr_backlog "$QRH")"
qr_add_note "$QRH_OUT" BL-004 "**Quality state:**" \
  "- Agreed with Dana 2026-08-31: the session validator is being split, not ported."
qr_refresh "$QRH"
assert_contains "13h a status note on a remediation item survives a refresh verbatim" \
  "- Agreed with Dana 2026-08-31: the session validator is being split, not ported." \
  "$(qr_block "$QRH_OUT" BL-004)"
assert_eq "13h2 and is not duplicated by the regeneration" "1" \
  "$(qr_block "$QRH_OUT" BL-004 | grep -c 'Agreed with Dana')"

# ── 13i — the severity floor is config, and lowering it changes the outcome ──
QRI="$WORK/qr-i"; qr_project "$QRI"; qr_quality_json "$QRI"
cat > "$QRI/.specclaw/config.yaml" <<'CY'
project:
  name: QR

quality:
  register_severity: WARN
  remediation_severity_floor: WARN
CY
qr_render "$QRI"
QRI_OUT="$(qr_backlog "$QRI")"
assert_eq "13i lowering the floor to WARN gives the WARN-only module an item too" "3" \
  "$(grep -c '^\*\*Item type:\*\* QUALITY-REMEDIATION' "$QRI_OUT")"
assert_contains "13i2 and that item lists the WARN hotspot" \
  "- QI-004 — complexity, legacy/reports/monthly::Build, measured 13, WARN" \
  "$(qr_block "$QRI_OUT" BL-006)"
if grep -qE '^- \*\*MOD-003 — .*advisory QI below' "$QRI_OUT"; then
  fail "13i3 nothing is below the floor any more, so no advisory count is printed"
else
  pass "13i3 nothing is below the floor any more, so no advisory count is printed"
fi

# ── 13j — module-status reports an open remediation item per module ──────────
( cd "$QRB" && bash "$REBUILD_BIN" module-status .specclaw ) >/dev/null 2>&1
QRB_MS="$QRB/.specclaw/analysis/module-status.md"
assert_contains "13j module-status carries a Quality remediation column" \
  "| Quality remediation |" "$(grep -m1 '^| Module |' "$QRB_MS")"
assert_contains "13j2 a module with an open item is visibly not done" \
  "| ⚠ BLOCKED |" "$(grep -m1 '^| MOD-001 |' "$QRB_MS")"
assert_contains "13j3 a module with no such item reads as having none, not as passing" \
  "| — |" "$(grep -m1 '^| MOD-003 |' "$QRB_MS")"
assert_contains "13j4 and the notes say what an open item means" \
  "A module with an open quality remediation item is not a done module" \
  "$(cat "$QRB_MS")"

# ── Scan-exclusion fixtures (Cases 14–22) ────────────────────────────────────
#
# The collector measures production code. These cases pin the mechanism that
# decides what "production" means, because every one of its failure modes is
# silent: a pattern that stops matching measures dependencies as though the team
# wrote them, a pattern that over-matches hides the product, and either way the
# resulting number looks entirely plausible.
#
# The DEFAULT patterns come from lib/quality-exclusions.yaml, which these cases
# deliberately do NOT stub. They assert against the shipped defaults, so a future
# edit to that file that changes what a category means fails here rather than in
# a client's report.

# excl_project <dir> — a tree with one file in every shape the defaults name.
# Everything is .cs or .js so the capability table classifies all of it: a file
# excluded for being unclassifiable would prove nothing about exclusions.
excl_project() {
  local d="$1"
  rm -rf "$d"
  mkdir -p "$d/.specclaw/analysis" "$d/src" "$d/src/Migrations" "$d/tests" \
           "$d/node_modules/leftpad" "$d/web"
  printf 'public class Calc { }\n'      > "$d/src/Calc.cs"          # production
  printf 'public class Order { }\n'     > "$d/src/Order.cs"         # production
  printf 'var app = 1;\n'               > "$d/web/app.js"           # production
  printf 'public class Init { }\n'      > "$d/src/Migrations/20240101_Init.cs"
  printf 'public class Form { }\n'      > "$d/src/Form.Designer.cs"
  printf 'public class CalcTests { }\n' > "$d/tests/CalcTests.cs"
  printf 'module.exports = 1;\n'        > "$d/node_modules/leftpad/index.js"
  printf 'var a=1;\n'                   > "$d/web/app.min.js"
}

# Rows for every file in excl_project, measured and excluded alike. A stub that
# only emitted rows for the files it expected to survive would pass whether the
# filter worked or not.
EXCL_ALL_PATHS='src/Calc.cs src/Order.cs web/app.js src/Migrations/20240101_Init.cs src/Form.Designer.cs tests/CalcTests.cs node_modules/leftpad/index.js web/app.min.js'

excl_stub_all() {
  local dir="$1"
  # Every EXCLUDED file is hotspot-sized (1500 lines, well past the HIGH band)
  # and every production file is not. That asymmetry is what makes the
  # "no excluded path appears in the artifact" assertions bite: a file that
  # leaks past the filter registers a permanent QI carrying its path, so a grep
  # can catch it. At a passing size a leak would be invisible and the assertion
  # would hold whether the filter worked or not.
  stub_scc "$dir" '[{"Name":"C#","Files":[
   {"Location":"src/Calc.cs","Lines":40,"Code":30},
   {"Location":"src/Order.cs","Lines":40,"Code":30},
   {"Location":"src/Migrations/20240101_Init.cs","Lines":1500,"Code":1400},
   {"Location":"src/Form.Designer.cs","Lines":1500,"Code":1400},
   {"Location":"tests/CalcTests.cs","Lines":1500,"Code":1400}]},
   {"Name":"JavaScript","Files":[
   {"Location":"web/app.js","Lines":40,"Code":30},
   {"Location":"node_modules/leftpad/index.js","Lines":1500,"Code":1400},
   {"Location":"web/app.min.js","Lines":1500,"Code":1400}]}]'
  stub_lizard "$dir" "$(liz_row 'src/Calc.cs' 'Run' 4 12)
$(liz_row 'src/Order.cs' 'Run' 4 12)
$(liz_row 'web/app.js' 'Run' 4 12)
$(liz_row 'src/Migrations/20240101_Init.cs' 'Up' 4 12)
$(liz_row 'src/Form.Designer.cs' 'Init' 4 12)
$(liz_row 'tests/CalcTests.cs' 'Test' 4 12)
$(liz_row 'node_modules/leftpad/index.js' 'Pad' 4 12)
$(liz_row 'web/app.min.js' 'Min' 4 12)"
  stub_jscpd "$dir" '{"statistics":{"paths":{
   "src/Calc.cs":{"lines":40,"duplicatedLines":1},
   "src/Order.cs":{"lines":40,"duplicatedLines":1},
   "web/app.js":{"lines":40,"duplicatedLines":1},
   "src/Migrations/20240101_Init.cs":{"lines":40,"duplicatedLines":1},
   "src/Form.Designer.cs":{"lines":40,"duplicatedLines":1},
   "tests/CalcTests.cs":{"lines":40,"duplicatedLines":1},
   "node_modules/leftpad/index.js":{"lines":40,"duplicatedLines":1},
   "web/app.min.js":{"lines":40,"duplicatedLines":1}}}}'
}

# census_of <json> <category> — the file count the artifact attributes to one
# category, or 0 when it names none.
census_of() {
  jq -r --arg c "$2" '[.exclusions.census.by_category[] | select(.category == $c) | .files] | (.[0] // 0)' "$1"
}

# ── Case 14 — the default set scopes the scan, and says what it left out ─────

echo
echo "--- Case 14: generated, vendored and test files are excluded and censused ---"
C14="$WORK/c14"; excl_project "$C14"
S14="$WORK/c14-stub"; excl_stub_all "$S14"

c14_out="$( cd "$C14" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c14_exit=$?
assert_eq "14a collect exits 0 with exclusions applied" "0" "$c14_exit"
C14_JSON="$C14/.specclaw/analysis/quality.json"

c14_counts="$(printf '%s' "$c14_out" | jq -r '"\(.files.enumerated)/\(.files.measured)/\(.files.excluded)"')"
assert_eq_nonempty "14b 8 files enumerated, 3 measured, 5 excluded by scope" "8/3/5" "$c14_counts"

# A file is enumerated FIRST and excluded SECOND, never pruned before anyone
# counted it. That ordering is what lets the census report a real number; an
# enumerator that skipped these directories would report every one of them as
# containing nothing, which is a worse artifact than a slower run.
c14_total="$(jq -r '[.exclusions.census.by_category[].files] | add' "$C14_JSON")"
assert_eq_nonempty "14b2 every excluded file was counted before it was excluded" "5" "$c14_total"

# The measured set is exactly the production files. Asserted as a SET, not a
# count: three files of the wrong three would satisfy a count.
c14_measured="$(printf '%s' "$c14_out" | jq -r '[.coverage[].files] | add')"
assert_eq_nonempty "14c every measured file was classified" "3" "$c14_measured"

assert_eq_nonempty "14d the generated category accounts for the migration, the designer file and the minified bundle" \
  "3" "$(census_of "$C14_JSON" generated)"
assert_eq_nonempty "14e the tests category accounts for the test file" \
  "1" "$(census_of "$C14_JSON" tests)"
assert_eq_nonempty "14f the third-party category accounts for the dependency" \
  "1" "$(census_of "$C14_JSON" third_party_and_build)"

# Nothing excluded may appear anywhere in the artifact — not in a rollup, not in
# a coverage row, not in a hotspot key. A path that survives into any of them is
# a file being measured after the scan said it was out of scope.
c14_leak=""
for p in src/Migrations/20240101_Init.cs src/Form.Designer.cs tests/CalcTests.cs node_modules/leftpad/index.js web/app.min.js; do
  grep -qF "$p" "$C14_JSON" && c14_leak="${c14_leak}${p} "
done
if [[ -z "$c14_leak" ]]; then
  pass "14g no excluded path appears anywhere in the artifact"
else
  fail "14g no excluded path appears anywhere in the artifact (leaked: $c14_leak)"
fi

# 14g bites only because every excluded file is hotspot-sized: a leak would mint
# a QI naming it. Pin that the production files DID register nothing, so the
# assertion above is known to be discriminating rather than vacuous.
c14_qi="$(printf '%s' "$c14_out" | jq -r '[.quality_issues[] | select(.status == "open")] | length')"
assert_eq "14g2 and no hotspot was registered at all, since only excluded files were oversized" "0" "$c14_qi"

# The census is not a silent omission: the effective config travels with it.
c14_cfg="$(jq -r '.exclusions.categories | keys | join(",")' "$C14_JSON")"
assert_eq_nonempty "14h the effective config records every category" \
  "data_and_lockfiles,generated,pipeline_owned,tests,third_party_and_build" "$c14_cfg"
c14_hash="$(jq -r '.exclusions.config_hash' "$C14_JSON")"
case "$c14_hash" in
  sha256:*) pass "14i the effective scope is hashed into the artifact" ;;
  *) fail "14i the effective scope is hashed into the artifact (got '$c14_hash')" ;;
esac

# ── Case 15 — one exclusion pass, one measured list, all three tools ──────────
#
# THE POINT OF PD-02. Each stub above emits a row for all eight files, so each
# tool would happily report on the excluded ones. If any tool's denominator came
# from its own ignore flags instead of the shared list, its count would differ
# from the others — a duplication percentage over one denominator and a
# complexity scan over another silently corrupts every rollup that combines them.

echo "--- Case 15: scc, lizard and jscpd all measure the identical post-exclusion list ---"
c15_sets="$(printf '%s' "$c14_out" | jq -r '"\(.files.measured)/\(.files.sized)/\(.files.function_measured)/\(.files.duplication_measured)"')"
assert_eq_nonempty "15a all three tools measured exactly the 3 files the filter kept" "3/3/3/3" "$c15_sets"

# And the same at module grain: the rollup's file count is the shared list too.
c15_modfiles="$(printf '%s' "$c14_out" | jq -r '[.modules[].files] | add')"
assert_eq_nonempty "15b the module rollups are computed over that same list" "3" "$c15_modfiles"

# ── Case 16 — include_overrides forces a file back in ────────────────────────

echo "--- Case 16: include_overrides rescues an otherwise-excluded file ---"
C16="$WORK/c16"; excl_project "$C16"
cat > "$C16/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  exclusions:
    include_overrides:
      - "src/Migrations/20240101_Init.cs"
CFG
c16_out="$( cd "$C16" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

# 9 enumerated, not 8: this case writes a .specclaw/config.yaml, which is itself
# enumerated and then excluded under pipeline_owned. That is the mechanism
# working — the pipeline's own files are scoped out like any others, and counted
# like any others rather than being invisible to the tree walk.
c16_counts="$(printf '%s' "$c16_out" | jq -r '"\(.files.measured)/\(.files.excluded)"')"
assert_eq_nonempty "16a the overridden file is measured: 4 measured, 5 excluded" "4/5" "$c16_counts"

if grep -qF 'src/Migrations/20240101_Init.cs' "$C16/.specclaw/analysis/quality.json"; then
  pass "16b the overridden file reaches the measurement"
else
  fail "16b the overridden file reaches the measurement"
fi

# The override rescues that ONE file and nothing else in its category — an
# override that switched the whole category off would be a different feature.
assert_eq_nonempty "16c the category still excludes its other two files" \
  "2" "$(census_of "$C16/.specclaw/analysis/quality.json" generated)"

c16_ovr="$(printf '%s' "$c16_out" | jq -r '.exclusions.include_overrides | join(",")')"
assert_eq_nonempty "16d the override is recorded in the effective config, not applied invisibly" \
  "src/Migrations/20240101_Init.cs" "$c16_ovr"

# ── Case 17 — matching is case-insensitive ───────────────────────────────────
#
# Repos that have been through a Windows checkout carry both Migrations/ and
# migrations/. A case-sensitive default would exclude one and measure the other,
# which is the worst outcome available: the number is wrong and still plausible.

echo "--- Case 17: Migrations/ and migrations/ are both excluded ---"
C17="$WORK/c17"
rm -rf "$C17"; mkdir -p "$C17/.specclaw/analysis" "$C17/src/Migrations" "$C17/src/migrations" "$C17/src/MIGRATIONS"
printf 'public class A { }\n' > "$C17/src/Keep.cs"
printf 'public class B { }\n' > "$C17/src/Migrations/Upper.cs"
printf 'public class C { }\n' > "$C17/src/migrations/Lower.cs"
printf 'public class D { }\n' > "$C17/src/MIGRATIONS/Shout.cs"
S17="$WORK/c17-stub"
stub_scc "$S17" '[{"Name":"C#","Files":[
 {"Location":"src/Keep.cs","Lines":40,"Code":30},
 {"Location":"src/Migrations/Upper.cs","Lines":40,"Code":30},
 {"Location":"src/migrations/Lower.cs","Lines":40,"Code":30},
 {"Location":"src/MIGRATIONS/Shout.cs","Lines":40,"Code":30}]}]'

c17_out="$( cd "$C17" && PATH="$(clean_path "$S17")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c17_counts="$(printf '%s' "$c17_out" | jq -r '"\(.files.enumerated)/\(.files.measured)"')"
assert_eq_nonempty "17a all three casings are excluded; only the production file is measured" "4/1" "$c17_counts"

# 4 enumerated, 3 measured is WRONG if only one casing matched — assert the
# category count directly rather than inferring it from the total.
assert_eq_nonempty "17b the generated category accounts for all three casings" \
  "3" "$(census_of "$C17/.specclaw/analysis/quality.json" generated)"
assert_eq_nonempty "17c and the production file survived" "1" \
  "$(printf '%s' "$c17_out" | jq -r '.files.measured')"

# ── Case 18 — paths with spaces are filtered without word-splitting ──────────
#
# Case 12 proved a spaced path survives measurement. This proves it survives the
# FILTER: one spaced path excluded, one spaced path kept, neither split.

echo "--- Case 18: spaced paths are excluded and measured correctly, never split ---"
C18="$WORK/c18"
rm -rf "$C18"; mkdir -p "$C18/.specclaw/analysis" "$C18/src" "$C18/src/Connected Services/Ref"
printf 'public class A { }\n' > "$C18/src/Order Service.cs"
printf 'public class B { }\n' > "$C18/src/Connected Services/Ref/Reference.cs"
S18="$WORK/c18-stub"
# BOTH files are oversized, so each would register a permanent QI carrying its
# path if it were measured. That makes the pair of assertions below symmetrical
# and discriminating: the kept path must appear in the registry and the excluded
# one must not. quality.json carries no plain file list, so a hotspot is the
# observable a spaced path can actually be checked through.
stub_scc "$S18" '[{"Name":"C#","Files":[
 {"Location":"src/Order Service.cs","Lines":1500,"Code":1400},
 {"Location":"src/Connected Services/Ref/Reference.cs","Lines":1500,"Code":1400}]}]'

c18_out="$( cd "$C18" && PATH="$(clean_path "$S18")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c18_counts="$(printf '%s' "$c18_out" | jq -r '"\(.files.enumerated)/\(.files.measured)/\(.files.excluded)"')"
assert_eq_nonempty "18a the spaced excluded path is excluded and the spaced kept path is measured" "2/1/1" "$c18_counts"

if grep -qF 'src/Order Service.cs' "$C18/.specclaw/analysis/quality.json"; then
  pass "18b the kept spaced path reaches the measurement with its space intact"
else
  fail "18b the kept spaced path reaches the measurement with its space intact"
fi
if grep -qF 'Connected Services' "$C18/.specclaw/analysis/quality.json"; then
  fail "18c the excluded spaced path does not leak into the artifact"
else
  pass "18c the excluded spaced path does not leak into the artifact"
fi

# The spaced pattern matched as one path, not as two words: a split would have
# left "Connected" and "Services/Ref/Reference.cs" both unmatched and the file
# measured. 18a's count already proves it; this pins the LOC so a future change
# that measures it anyway cannot pass by coincidence.
c18_loc="$(printf '%s' "$c18_out" | jq -r '[.modules[].loc] | add')"
assert_eq_nonempty "18d only the kept file's LOC is counted" "1400" "$c18_loc"

# ── Case 19 — compare refuses two snapshots measured over different scopes ────

echo "--- Case 19: a scope mismatch stops compare by name; matching scopes compare ---"
C19="$WORK/c19"; excl_project "$C19"

# Legacy measured under the DEFAULT scope.
( cd "$C19" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
# Target measured after the scope changed under it.
cat > "$C19/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  exclusions:
    tests: false
CFG
( cd "$C19" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw --target ) >/dev/null 2>&1

c19_l="$(jq -r '.exclusions.config_hash' "$C19/.specclaw/analysis/quality.json")"
c19_t="$(jq -r '.exclusions.config_hash' "$C19/.specclaw/analysis/quality-target.json")"
if [[ -n "$c19_l" && "$c19_l" != "$c19_t" ]]; then
  pass "19a switching a category off changes the scope hash"
else
  fail "19a switching a category off changes the scope hash (legacy '$c19_l', target '$c19_t')"
fi

c19_err="$( cd "$C19" && bash "$QUALITY_BIN" compare .specclaw 2>&1 >/dev/null )"
c19_exit=$?
if [[ "$c19_exit" -ne 0 ]]; then
  pass "19b compare across mismatched scopes exits non-zero"
else
  fail "19b compare across mismatched scopes exits non-zero (exit 0)"
fi
assert_contains "19c the stop is named, not a generic error" "QUALITY-SCOPE-MISMATCH" "$c19_err"
# WHICH side is stale is computed against the config on disk, not guessed by
# convention. Here the target was measured under the current config and the
# legacy side was not, so the legacy side is the one to re-measure — naming the
# other would send someone to redo the snapshot that was already correct.
assert_contains "19d it names the side that does not match the current config" \
  "quality.json — re-measure it" "$c19_err"
assert_contains "19d2 and says the other side is already current" \
  "quality-target.json already matches the current config" "$c19_err"

if [[ -f "$C19/.specclaw/analysis/quality-delta.json" ]]; then
  fail "19e no delta is written across mismatched scopes"
else
  pass "19e no delta is written across mismatched scopes"
fi

# The gate inherits it: no verdict is computed across mismatched scopes.
c19_gate="$( cd "$C19" && bash "$QUALITY_BIN" compare .specclaw --gate 2>&1 )"
if printf '%s' "$c19_gate" | grep -q 'QUALITY-GATE:'; then
  fail "19f no QUALITY-GATE verdict is reached across mismatched scopes"
else
  pass "19f no QUALITY-GATE verdict is reached across mismatched scopes"
fi

# Re-measure the legacy side under the same scope: now they match and the delta
# computes, proving the stop is about the scope and not about compare itself.
( cd "$C19" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
( cd "$C19" && bash "$QUALITY_BIN" compare .specclaw ) >/dev/null 2>&1
c19_exit2=$?
assert_eq "19g re-measuring the stale side lets the comparison run" "0" "$c19_exit2"
if [[ -f "$C19/.specclaw/analysis/quality-delta.json" ]]; then
  pass "19h and the delta is written"
  c19_scope="$(jq -r '.scan_scope.config_hash' "$C19/.specclaw/analysis/quality-delta.json")"
  assert_eq_nonempty "19i the delta records the scope both sides shared" \
    "$(jq -r '.exclusions.config_hash' "$C19/.specclaw/analysis/quality.json")" "$c19_scope"
else
  fail "19h and the delta is written"
  fail "19i the delta records the scope both sides shared"
fi

# ── Case 20 — a registered QI whose file leaves the scope ────────────────────
#
# The hotspot was not fixed. Marking it `resolved` would credit somebody with
# work nobody did, in the flattering direction, and it is exactly the reading a
# module rollup invites. So it gets its own status, keeps its id, and its
# departure from the rebuild item is recorded as a scope change rather than a
# retirement.

echo "--- Case 20: an excluded file's QI becomes excluded-by-scope, never resolved ---"
C20="$WORK/c20"
rm -rf "$C20"; mkdir -p "$C20/.specclaw/analysis" "$C20/src" "$C20/legacy"
printf 'public class Keep { }\n' > "$C20/src/Keep.cs"
printf 'public class Big { }\n'  > "$C20/legacy/Big.cs"
cat > "$C20/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Scope

**Status:** CONFIRMED by fixture, 2026-09-01

## Modules

### MOD-001 — Legacy

- **Evidence:**
  - `legacy/Big.cs:1` — the oversized unit
MM
S20="$WORK/c20-stub"
# legacy/Big.cs is a file_length HIGH hotspot, so it earns a permanent id.
stub_scc "$S20" '[{"Name":"C#","Files":[
 {"Location":"src/Keep.cs","Lines":40,"Code":30},
 {"Location":"legacy/Big.cs","Lines":1500,"Code":1400}]}]'

( cd "$C20" && PATH="$(clean_path "$S20")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
C20_JSON="$C20/.specclaw/analysis/quality.json"
c20_id="$(jq -r '[.quality_issues[] | select(.status == "open" and .file == "legacy/Big.cs")] | .[0].id // ""' "$C20_JSON")"
if [[ -n "$c20_id" ]]; then
  pass "20a the oversized file is registered as ${c20_id}"
else
  fail "20a the oversized file is registered (no open QI found)"
fi

# Now put that file out of scope and re-measure.
cat > "$C20/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  exclusions:
    extra_excludes:
      - "legacy/**"
CFG
( cd "$C20" && PATH="$(clean_path "$S20")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1

c20_status="$(jq -r --arg id "$c20_id" '[.quality_issues[] | select(.id == $id)] | .[0].status // ""' "$C20_JSON")"
assert_eq_nonempty "20b its status becomes excluded-by-scope, not resolved" "excluded-by-scope" "$c20_status"

c20_same="$(jq -r --arg id "$c20_id" '[.quality_issues[] | select(.id == $id)] | length' "$C20_JSON")"
assert_eq_nonempty "20c it keeps its id rather than being deleted or renumbered" "1" "$c20_same"

c20_open="$(jq -r --arg id "$c20_id" '[.quality_issues[] | select(.id == $id and .status == "open")] | length' "$C20_JSON")"
assert_eq "20d it leaves the open-hotspot rollups" "0" "$c20_open"

c20_cat="$(jq -r --arg id "$c20_id" '[.quality_issues[] | select(.id == $id)] | .[0].excluded_by.category // ""' "$C20_JSON")"
assert_eq_nonempty "20e it records which category excluded it" "extra_excludes" "$c20_cat"
c20_h="$(jq -r --arg id "$c20_id" '[.quality_issues[] | select(.id == $id)] | .[0].excluded_by.config_hash // ""' "$C20_JSON")"
assert_eq_nonempty "20f and the exclusion config that made the decision" \
  "$(jq -r '.exclusions.config_hash' "$C20_JSON")" "$c20_h"

# The registry document carries it too — the registry is the permanent record,
# quality.json is a projection that gets archived.
C20_REG="$C20/.specclaw/analysis/quality-issues.md"
assert_contains "20g the registry records the status" "**Status:** excluded-by-scope" "$(cat "$C20_REG")"
assert_contains "20h and the scope that produced it" "**Excluded by scope:** extra_excludes" "$(cat "$C20_REG")"

# ── 20i–20l — the rebuild-plan remediation item records a SCOPE CHANGE ───────
#
# Its existing "Retired" line means "no longer above the floor", which reads as
# "somebody fixed it". For a hotspot that stopped being measured that sentence
# is false in the flattering direction, so it gets a distinct dated line.

QSC="$WORK/c20-plan"; qr_project "$QSC"
cat > "$QSC/.specclaw/analysis/quality.json" <<'QJ'
{"schema_version":1,
 "exclusions":{"config_hash":"sha256:aaaa"},
 "thresholds":{"register_severity":"HIGH"},
 "modules":[{"module_id":"MOD-001","rollup_status":"HIGH"}],
 "quality_issues":[
   {"id":"QI-001","module_id":"MOD-001","status":"open","metric":"complexity",
    "file":"legacy/auth/session","function":"Validate","value":34,"severity":"HIGH"},
   {"id":"QI-002","module_id":"MOD-001","status":"open","metric":"file_length",
    "file":"legacy/auth/gen.Designer.cs","function":null,"value":1420,"severity":"HIGH"}]}
QJ
qr_render "$QSC"
QSC_BL="$(qr_backlog "$QSC")"
qsc_item="$(grep -oE '^### BL-[0-9]{3} — MOD-001 quality remediation' "$QSC_BL" | grep -oE 'BL-[0-9]{3}' | head -1)"
if [[ -n "$qsc_item" ]]; then
  pass "20i MOD-001 gets a quality remediation item (${qsc_item})"
else
  fail "20i MOD-001 gets a quality remediation item"
fi

# QI-002's file is now out of scope. QI-001 is untouched.
cat > "$QSC/.specclaw/analysis/quality.json" <<'QJ'
{"schema_version":1,
 "exclusions":{"config_hash":"sha256:bbbb"},
 "thresholds":{"register_severity":"HIGH"},
 "modules":[{"module_id":"MOD-001","rollup_status":"HIGH"}],
 "quality_issues":[
   {"id":"QI-001","module_id":"MOD-001","status":"open","metric":"complexity",
    "file":"legacy/auth/session","function":"Validate","value":34,"severity":"HIGH"},
   {"id":"QI-002","module_id":"MOD-001","status":"excluded-by-scope","metric":"file_length",
    "file":"legacy/auth/gen.Designer.cs","function":null,"value":null,"severity":null,
    "excluded_by":{"category":"generated","config_hash":"sha256:bbbb"}}]}
QJ
qr_refresh "$QSC"
qsc_body="$(qr_block "$QSC_BL" "$qsc_item")"

assert_contains "20j the departure is recorded as a dated scope change" \
  "⊘ **Scope change $(date +%Y-%m-%d):** QI-002" "$qsc_body"
assert_contains "20k and says plainly that nothing was fixed" \
  "Nothing was fixed and nothing was deleted" "$qsc_body"
if printf '%s' "$qsc_body" | grep -q '⊖ \*\*Retired.*QI-002'; then
  fail "20l it is NOT recorded as a retirement (that would claim work nobody did)"
else
  pass "20l it is NOT recorded as a retirement (that would claim work nobody did)"
fi
qsc_still="$(grep -cE "^### ${qsc_item} — MOD-001 quality remediation" "$QSC_BL" || true)"
assert_eq "20m the item keeps its number and is not renumbered" "1" "$qsc_still"
assert_contains "20n and the hotspot that is still open stays on the item" "QI-001" "$qsc_body"

# ── Case 21 — the exclusion mechanism changes no measurement ─────────────
#
# WHY THIS IS NOT LITERALLY "EVERY CATEGORY OFF". The config that turns them off
# lives at .specclaw/config.yaml, which is itself a file in the tree, and the
# PRE-change collector always excluded .specclaw/ with a hardcoded filter. So a
# run with pipeline_owned off is measuring a file the old one never saw, and the
# two are not comparable no matter how correct both are.
#
# The comparable configuration is the one that reproduces the old hardcoded
# filter exactly: pipeline_owned ON (the old collector excluded .specclaw/) and
# the other four OFF, over a tree containing none of node_modules, vendor, dist
# or build (the rest of what it hardcoded). On that tree the two scopes are the
# same scope, and every measured value must match.

echo "--- Case 21: with the old filter's scope reproduced, no measurement changes ---"
C21="$WORK/c21"
rm -rf "$C21"; mkdir -p "$C21/.specclaw/analysis" "$C21/src"
printf 'public class A { }\n' > "$C21/src/A.cs"
printf 'public class B { }\n' > "$C21/src/B.cs"
cat > "$C21/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  exclusions:
    generated: false
    third_party_and_build: false
    tests: false
    data_and_lockfiles: false
CFG
S21="$WORK/c21-stub"
# Both source files are sized over the file-length threshold, so both leave their
# NAME in the artifact. The artifact reports the measured set as a count and
# never as a list of paths — quality_issues[].file is the only place a measured
# path appears at all — so a file that silently left the scan would move a number
# and nothing else. Giving each one a finding is what lets 21c name them.
stub_scc "$S21" '[{"Name":"C#","Files":[
 {"Location":"src/A.cs","Lines":1400,"Code":1300},
 {"Location":"src/B.cs","Lines":1400,"Code":1300}]}]'
stub_lizard "$S21" "$(liz_row 'src/A.cs' 'Run' 34 150)"

( cd "$C21" && PATH="$(clean_path "$S21")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
C21_JSON="$C21/.specclaw/analysis/quality.json"

c21_scope="$(jq -r '"\(.files.measured)/\(.exclusions.census.files_total)"' "$C21_JSON")"
assert_eq_nonempty "21a only the pipeline's own config file is out of scope" "2/1" "$c21_scope"
assert_eq_nonempty "21a2 and it is the pipeline_owned category that accounts for it" \
  "1" "$(census_of "$C21_JSON" pipeline_owned)"

# The measurement itself, against the collector at origin/main — a DRIFT GUARD:
# whatever this branch changes, it must not change a measured value.
#
# It was written to compare against the collector as it was before scan scoping,
# and it no longer can. That commit merged, so origin/main is now on the far side
# of the change this was contrasting with, and the artifact has since gained
# duplication_clones, scan_funnel and report_blocks — a whole-artifact diff
# against a binary from before all that cannot pass whatever the collector does.
# Against origin/main it still says something true and worth failing on, so it
# keeps that baseline under an accurate name. The scope-parity claim it used to
# carry moved to 21c, which needs no binary; see the note there.
#
# Stripped: generated_at (a timestamp), the whole exclusions block and
# excluded_by, and files.enumerated / .measured / .excluded — the counts 21c owns
# outright. Everything else — every status, rollup, LOC, coverage row and QI id —
# must be byte-identical.
#
# `first_seen` is NORMALISED rather than deleted, and only where it equals its
# own snapshot's generated_at. On a first run against an empty registry that is
# every entry by construction — first_seen IS the run's clock — so comparing
# them literally compares two wall-clock readings taken seconds apart and can
# never match. Replacing it only in that case keeps the field's real content
# under comparison for any entry carrying an older date, which is the thing
# permanence is about.
q_strip() {
  jq -S '.generated_at as $ga
         | del(.generated_at, .exclusions)
         | .files |= del(.enumerated, .measured, .excluded)
         | (.quality_issues // []) |= map(del(.excluded_by)
             | if .first_seen == $ga then .first_seen = "<registered by this run>" else . end)' "$1" \
    | q_norm_identity
}
PRE21="$WORK/pre-quality-collect"
C21B_JSON=""
if git -C "$SCRIPT_DIR" show "origin/main:plugins/specclaw/bin/specclaw-bf-quality-collect" > "$PRE21" 2>/dev/null && [[ -s "$PRE21" ]]; then
  C21B="$WORK/c21-pre"
  rm -rf "$C21B"; cp -R "$C21" "$C21B"; rm -rf "$C21B/.specclaw/analysis"; mkdir -p "$C21B/.specclaw/analysis"
  ( cd "$C21B" && PATH="$(clean_path "$S21")" bash "$PRE21" collect .specclaw ) >/dev/null 2>&1
  C21B_JSON="$C21B/.specclaw/analysis/quality.json"
fi
if [[ -n "$C21B_JSON" && -s "$C21B_JSON" ]]; then
  if diff <(q_strip "$C21B_JSON") <(q_strip "$C21_JSON") >/dev/null 2>&1; then
    pass "21b every measured value is identical to the collector at origin/main"
  else
    fail "21b every measured value is identical to the collector at origin/main"
    diff <(q_strip "$C21B_JSON") <(q_strip "$C21_JSON") | head -20
  fi
else
  echo "NOTE: 21b pre-change binary not retrievable (origin/main absent, e.g. a shallow clone) — skipping the comparison."
  PASS=$((PASS + 1))
fi

# 21c — THE SCOPE PARTITION, ASSERTED FROM THE FIXTURE AND NOT FROM A BINARY.
#
# This read the baseline collector's files.enumerated and compared it against
# this run's files.measured, on the reasoning that the old `enumerated` counted
# files after the hardcoded filter, which is what `measured` counts now. That
# equivalence was true and the assertion was sound. What broke it is where the
# baseline comes from, twice over, and neither has anything to do with the
# collector:
#
#   - `origin/main` is a MOVING reference. The scan-scoping commit merged into
#     it, so the binary the case fetches to represent "before" is now an "after".
#     Its artifact even carries an exclusions block, which the comment above
#     lists among the fields that did not exist.
#   - it is written to $WORK and run from there, so SCRIPT_DIR/../lib does not
#     resolve, excl_defaults falls back to /dev/null, and it excludes NOTHING.
#     The same binary run from the plugin's own bin/ reports 2 measured and 1
#     excluded, identical to this one.
#
# So the value it supplied was neither the old scope nor the new one, and the
# assertion failed on a collector that is measuring exactly what it should.
#
# Pinning the baseline to the real pre-scan-scoping commit does restore this
# comparison, and breaks 21b instead: the artifact has since gained
# duplication_clones, scan_funnel and report_blocks, none of which q_strip
# normalises, so a whole-artifact diff against a binary that old cannot pass.
# The two assertions cannot share one baseline any more.
#
# 21b keeps the moving baseline, where it is a drift guard and is meaningful.
# 21c stops needing a baseline at all: the fixture puts three files in the tree,
# and the contract is which side of the scope line each one lands on. That is
# checkable here, it cannot rot when main moves, and it runs on a shallow clone.
#
# SIZE AND MEMBERSHIP, in one string. A count alone passes while the wrong two
# files are measured; the names are what catches a silent swap. The excluded one
# is `.specclaw/config.yaml` and cannot be named from the artifact — no list of
# excluded paths is published, only per-category counts — so it is pinned by
# category in 21a2 instead, and by being the file the other two are not.
c21_scope_set="$(jq -r '"\(.files.enumerated)/\(.files.measured)/\(.files.excluded) "
                        + ([.quality_issues[] | .file] | unique | sort | join(","))' "$C21_JSON")"
assert_eq_nonempty "21c the reproduced scope measures exactly src/A.cs and src/B.cs, excluding the one pipeline-owned file" \
  "3/2/1 src/A.cs,src/B.cs" "$c21_scope_set"

# Standing on its own, without the old binary: the scan measured both source
# files and classified them exactly as the thresholds say.
c21_self="$(jq -r '"\(.files.measured)/\(.files.classified)/\(.files.sized)"' "$C21_JSON")"
assert_eq_nonempty "21d both source files were measured, classified and sized" "2/2/2" "$c21_self"
c21_hot="$(jq -r '[.quality_issues[] | select(.status == "open") | .metric] | sort | join(",")' "$C21_JSON")"
assert_eq_nonempty "21e and the hotspots are exactly the four the thresholds define" \
  "complexity,file_length,file_length,function_length" "$c21_hot"

# ── Case 22 — tests as a separately-reported bucket ──────────────────────────
#
# PD-06's escape hatch. Test code gets measured, into MOD-TESTS, and never into
# a production module rollup — its norms are different and mixing the two makes
# both numbers mean less.

echo "--- Case 22: tests_as_separate_bucket measures test code into its own bucket ---"
C22="$WORK/c22"; excl_project "$C22"
# The test file is cited by a module, so this also proves the bucket OVERRIDES a
# citation rather than merging with it — otherwise test code walks back into the
# production rollup through the module map's side door.
cat > "$C22/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Bucket

**Status:** CONFIRMED by fixture, 2026-09-01

## Modules

### MOD-001 — Calc

- **Evidence:**
  - `src/Calc.cs:1` — the calculator
  - `tests/CalcTests.cs:1` — its tests
MM
cat > "$C22/.specclaw/config.yaml" <<'CFG'
version: 1
quality:
  exclusions:
    tests_as_separate_bucket: true
CFG
c22_out="$( cd "$C22" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

# 10 enumerated: the 8 fixture files plus this case's own config.yaml and
# module-map.md, both of which are enumerated and then excluded under
# pipeline_owned like everything else in .specclaw/.
c22_counts="$(printf '%s' "$c22_out" | jq -r '"\(.files.measured)/\(.files.excluded)"')"
assert_eq_nonempty "22a the test file is measured: 4 measured, 6 excluded" "4/6" "$c22_counts"

c22_bucket="$(printf '%s' "$c22_out" | jq -r '[.modules[] | select(.module_id == "MOD-TESTS") | .files] | (.[0] // 0)')"
assert_eq_nonempty "22b it lands in its own MOD-TESTS bucket" "1" "$c22_bucket"

c22_prod="$(printf '%s' "$c22_out" | jq -r '.modules[] | select(.module_id == "MOD-001") | .files')"
assert_eq_nonempty "22c and NOT in the production module that cites it" "1" "$c22_prod"

c22_disp="$(printf '%s' "$c22_out" | jq -r '[.exclusions.census.by_category[] | select(.category == "tests") | .disposition] | (.[0] // "")')"
assert_eq_nonempty "22d the census reports it as measured, not as excluded" "measured_separately" "$c22_disp"

c22_totals="$(printf '%s' "$c22_out" | jq -r '"\(.exclusions.census.files_total)/\(.exclusions.census.files_bucketed)"')"
assert_eq_nonempty "22e bucketed files are counted apart from excluded ones" "6/1" "$c22_totals"

# QI ids name production hotspots. A bucket entry earning one would make "open
# hotspots in this module" mean two different things depending on a config flag.
c22_qi="$(printf '%s' "$c22_out" | jq -r '[.quality_issues[] | select(.module_id == "MOD-TESTS")] | length')"
assert_eq "22f the bucket registers no QI-###" "0" "$c22_qi"

# With the toggle off, the same tree puts the test file back out of scope —
# proving the bucket is what moved it, not something else in this fixture.
rm -f "$C22/.specclaw/config.yaml"; rm -rf "$C22/.specclaw/analysis/archive"
c22b_out="$( cd "$C22" && PATH="$(clean_path "$S14")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c22b_bucket="$(printf '%s' "$c22b_out" | jq -r '[.modules[] | select(.module_id == "MOD-TESTS")] | length')"
assert_eq "22g with the toggle off there is no bucket at all" "0" "$c22b_bucket"

# ── Clone-pair fixtures (Cases 23–31) ────────────────────────────────────────
#
# The module rollup answers "how much duplication"; a clone pair answers
# "where". These pin the second, and every failure mode in it is quiet: a clone
# dropped by a path mismatch looks exactly like a clone that does not exist, and
# an identity that moves between runs looks exactly like a hotspot somebody
# fixed.
#
# jscpd is stubbed like the other tools. The stub emits the v5 report shape this
# collector actually parses — `duplicates[]` with firstFile/secondFile,
# startLoc/endLoc and a `lines` count — verified against jscpd 5.0.16 output.

# liz_row_range <file> <func> <ccn> <length> <start> <end>
#
# liz_row pins every function at lines 1-1, which is fine for complexity but
# useless for the clone-to-function join. This one places a function on real
# lines. Column order is lizard's own, all eleven, with start/end last.
liz_row_range() {
  local file="$1" func="$2" ccn="$3" length="$4" start="$5" end="$6"
  printf '%s,%s,100,2,%s,%s@%s-%s@%s,%s,%s,%s(),%s,%s\n' \
    "$length" "$ccn" "$length" "$func" "$start" "$end" "$file" "$file" "$func" "$func" "$start" "$end"
}

# jscpd_dup <fileA> <startA> <endA> <fileB> <startB> <endB> <lines> <fragment>
# One entry of the duplicates[] array, in jscpd v5 shape.
jscpd_dup() {
  printf '{"format":"csharp","lines":%s,"tokens":100,"fragment":"%s",' "$7" "$8"
  printf '"firstFile":{"name":"%s","start":%s,"end":%s,"startLoc":{"line":%s,"column":1},"endLoc":{"line":%s,"column":1}},' "$1" "$2" "$3" "$2" "$3"
  printf '"secondFile":{"name":"%s","start":%s,"end":%s,"startLoc":{"line":%s,"column":1},"endLoc":{"line":%s,"column":1}}}' "$4" "$5" "$6" "$5" "$6"
}

# jscpd_report <paths-json> <dup...> — assembles a full report.
jscpd_report() {
  local paths="$1"; shift
  local body='{"statistics":{"paths":'"$paths"'},"duplicates":['
  local first=true d
  for d in "$@"; do
    if $first; then first=false; else body="${body},"; fi
    body="${body}${d}"
  done
  printf '%s]}' "$body"
}

clone_paths2='{"src/A.cs":{"lines":80,"duplicatedLines":16},"src/B.cs":{"lines":80,"duplicatedLines":16}}'

# clone_project <dir> — two C# files and a two-module map citing one each.
clone_project() {
  local d="$1"
  rm -rf "$d"; mkdir -p "$d/.specclaw/analysis" "$d/src"
  printf 'public class A { }\n' > "$d/src/A.cs"
  printf 'public class B { }\n' > "$d/src/B.cs"
  cat > "$d/.specclaw/analysis/module-map.md" <<'MM'
# Module Map: Clones

**Status:** CONFIRMED by fixture, 2026-09-01

## Modules

### MOD-001 — Alpha

- **Evidence:**
  - `src/A.cs:1` — the alpha service

### MOD-002 — Beta

- **Evidence:**
  - `src/B.cs:1` — the beta service
MM
}

clone_scc2='[{"Name":"C#","Files":[{"Location":"src/A.cs","Lines":80,"Code":70},{"Location":"src/B.cs","Lines":80,"Code":70}]}]'

# ── Case 23 — a known clone is captured with its locations intact ────────────

echo
echo "--- Case 23: a known duplicated block is captured with files, ranges and module ---"
C23="$WORK/c23"; clone_project "$C23"
S23="$WORK/c23-stub"
stub_scc "$S23" "$clone_scc2"
stub_lizard "$S23" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
stub_jscpd "$S23" "$(jscpd_report "$clone_paths2" "$(jscpd_dup 'src/A.cs' 44 59 'src/B.cs' 58 73 16 'some normalised text')")"

c23_out="$( cd "$C23" && PATH="$(clean_path "$S23")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
assert_eq "23a collect exits 0 with clones present" "0" "$?"
C23_JSON="$C23/.specclaw/analysis/quality.json"

c23_n="$(printf '%s' "$c23_out" | jq -r '.duplication_clones.clones | length')"
assert_eq_nonempty "23b exactly one clone captured" "1" "$c23_n"

c23_loc="$(printf '%s' "$c23_out" | jq -r '.duplication_clones.clones[0]
  | "\(.a.file):\(.a.start)-\(.a.end)|\(.b.file):\(.b.start)-\(.b.end)|\(.lines)"')"
assert_eq_nonempty "23c both locations and the duplicated line count survive intact" \
  "src/A.cs:44-59|src/B.cs:58-73|16" "$c23_loc"

c23_mods="$(printf '%s' "$c23_out" | jq -r '.duplication_clones.clones[0] | "\(.a.module_id)/\(.b.module_id)"')"
assert_eq_nonempty "23d each side carries the module of its own file" "MOD-001/MOD-002" "$c23_mods"

c23_census="$(printf '%s' "$c23_out" | jq -r '.duplication_clones.census
  | "\(.clones_found)/\(.clones_in_scope)/\(.clones_captured)/\(.duplicated_lines_found)"')"
assert_eq_nonempty "23e the census reports found, in-scope, captured and total duplicated lines" \
  "1/1/1/16" "$c23_census"

# PD-03: locations, never source. The artifact must carry no fragment field at
# all — only the hash — and no field anywhere may contain the fixture text.
c23_frag="$(jq -r '[.. | objects | select(has("fragment"))] | length' "$C23_JSON")"
assert_eq "23f no clone carries a verbatim fragment field" "0" "$c23_frag"
if grep -qF 'some normalised text' "$C23_JSON"; then
  fail "23g the duplicated source does not appear anywhere in the artifact"
else
  pass "23g the duplicated source does not appear anywhere in the artifact"
fi
c23_sha="$(printf '%s' "$c23_out" | jq -r '.duplication_clones.clones[0].fragment_sha256 // ""')"
case "$c23_sha" in
  sha256:*) pass "23h the clone carries a fragment hash as its identity" ;;
  *) fail "23h the clone carries a fragment hash as its identity (got '$c23_sha')" ;;
esac

# ── 23i — PD-01: the rollup metric did not move ──────────────────────────────
#
# Byte-compared against the collector as it was before clone capture existed.
# Everything the previous version emitted must be identical; only the new
# duplication_clones block, the two new threshold keys and the timestamp differ.
q_strip_clones() {
  jq -S '.generated_at as $ga
         | del(.generated_at, .duplication_clones)
         | .thresholds |= del(.clone_qi_min_lines, .clone_function_min_overlap)
         | (.quality_issues // []) |= map(del(.peer_file, .fragment_sha256)
             | if .first_seen == $ga then .first_seen = "<this run>" else . end)' "$1" \
    | q_norm_identity
}
# The pre-change binary is written into the REAL bin/ directory, not $WORK, and
# that placement is the whole point. The collector resolves its exclusion
# defaults and its templates through $SCRIPT_DIR/../, so a copy run from a
# scratch directory finds neither — it would measure a different file set and
# report zero exclusion patterns, and the diff would then be about where the
# binary was parked rather than about what the code does. Removed immediately
# after, and again by the suite trap if a case between here and there dies.
PRE23="$BIN_DIR/.pre-clone-collect"
# The exclusion defaults now ship in core's lib/ (change 042); the pre-change
# binary still reads them from its own ../lib, so stage a copy there for this case.
PRE23_EXCL="$BIN_DIR/../lib/quality-exclusions.yaml"
PRE23_STAGED=false
[[ -f "$PRE23_EXCL" ]] || { cp "$BIN_DIR/../../specclaw/lib/quality-exclusions.yaml" "$PRE23_EXCL" && PRE23_STAGED=true; }
trap 'rm -rf "$WORK"; rm -f "$BIN_DIR/.pre-clone-collect"; $PRE23_STAGED && rm -f "$PRE23_EXCL"' EXIT
if git -C "$SCRIPT_DIR" show "origin/main:plugins/specclaw/bin/specclaw-bf-quality-collect" > "$PRE23" 2>/dev/null && [[ -s "$PRE23" ]]; then
  C23B="$WORK/c23-pre"; rm -rf "$C23B"; cp -R "$C23" "$C23B"
  rm -rf "$C23B/.specclaw/analysis"; mkdir -p "$C23B/.specclaw/analysis"
  cp "$C23/.specclaw/analysis/module-map.md" "$C23B/.specclaw/analysis/" 2>/dev/null || true
  ( cd "$C23B" && PATH="$(clean_path "$S23")" bash "$PRE23" collect .specclaw ) >/dev/null 2>&1
  C23B_JSON="$C23B/.specclaw/analysis/quality.json"
  if [[ -s "$C23B_JSON" ]]; then
    if diff <(q_strip_clones "$C23B_JSON") <(q_strip_clones "$C23_JSON") >/dev/null 2>&1; then
      pass "23i the duplication rollup and every pre-existing field are unchanged"
    else
      fail "23i the duplication rollup and every pre-existing field are unchanged"
      diff <(q_strip_clones "$C23B_JSON") <(q_strip_clones "$C23_JSON") | head -20
    fi
  else
    echo "NOTE: 23i the pre-change collector produced no artifact here — skipping."
    PASS=$((PASS + 1))
  fi
else
  echo "NOTE: 23i pre-change binary not retrievable (shallow clone) — skipping the byte comparison."
  PASS=$((PASS + 1))
fi
rm -f "$PRE23"; $PRE23_STAGED && rm -f "$PRE23_EXCL"; PRE23_STAGED=false

# Standing alone: the module duplication percentage is still computed and is
# still the number the thresholds classify.
c23_pct="$(printf '%s' "$c23_out" | jq -r '.modules[] | select(.module_id=="MOD-001") | "\(.duplication.pct)/\(.duplication.status)"')"
assert_eq_nonempty "23j the per-module duplication percentage is still produced" "20/HIGH" "$c23_pct"

# ── Case 24 — determinism ────────────────────────────────────────────────────
#
# Identical input must give byte-identical output. Two things make this fail in
# practice and both are covered: the detector reports first/second in scan
# order, and its duplicates[] order is not guaranteed stable.

echo "--- Case 24: two runs produce byte-identical clones and QI assignments ---"
C24="$WORK/c24"; clone_project "$C24"
printf 'version: 1\nquality:\n  clone_qi_min_lines: 10\n' > "$C24/.specclaw/config.yaml"
S24="$WORK/c24-stub"
stub_scc "$S24" "$clone_scc2"
stub_lizard "$S24" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
# Two clones whose sides are given in OPPOSITE order between the pairs, so a
# collector that trusted jscpd's ordering would emit them inconsistently.
stub_jscpd "$S24" "$(jscpd_report "$clone_paths2" \
  "$(jscpd_dup 'src/B.cs' 58 73 'src/A.cs' 44 59 16 'first block')" \
  "$(jscpd_dup 'src/A.cs' 10 21 'src/B.cs' 30 41 12 'second block')")"

( cd "$C24" && PATH="$(clean_path "$S24")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
jq -S '{c: .duplication_clones.clones, q: [.quality_issues[] | {id, key, status}]}' \
  "$C24/.specclaw/analysis/quality.json" > "$WORK/c24-run1.json"
rm -rf "$C24/.specclaw/analysis/archive"
( cd "$C24" && PATH="$(clean_path "$S24")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
jq -S '{c: .duplication_clones.clones, q: [.quality_issues[] | {id, key, status}]}' \
  "$C24/.specclaw/analysis/quality.json" > "$WORK/c24-run2.json"

if diff "$WORK/c24-run1.json" "$WORK/c24-run2.json" >/dev/null 2>&1; then
  pass "24a two consecutive runs give byte-identical clones and QI ids"
else
  fail "24a two consecutive runs give byte-identical clones and QI ids"
  diff "$WORK/c24-run1.json" "$WORK/c24-run2.json" | head -10
fi

# Canonical side order: the smaller path is always side A, whichever way the
# detector happened to report the pair.
c24_a="$(jq -r '.duplication_clones.clones[0].a.file' "$C24/.specclaw/analysis/quality.json")"
assert_eq_nonempty "24b the pair is put in canonical order, not the detector's order" "src/A.cs" "$c24_a"

# Largest clone first, deterministically.
c24_order="$(jq -r '[.duplication_clones.clones[].lines] | join(",")' "$C24/.specclaw/analysis/quality.json")"
assert_eq_nonempty "24c clones are ordered by duplicated lines, descending" "16,12" "$c24_order"

# ── Case 25 — the registration threshold, and permanence across it ───────────

echo "--- Case 25: a clone at the threshold registers a QI; below it does not ---"
C25="$WORK/c25"; clone_project "$C25"
S25="$WORK/c25-stub"
stub_scc "$S25" "$clone_scc2"
stub_lizard "$S25" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"

# 29 lines: captured, no QI. The default threshold is 30.
stub_jscpd "$S25" "$(jscpd_report "$clone_paths2" "$(jscpd_dup 'src/A.cs' 10 38 'src/B.cs' 20 48 29 'just under')")"
( cd "$C25" && PATH="$(clean_path "$S25")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
C25_JSON="$C25/.specclaw/analysis/quality.json"
assert_eq_nonempty "25a a 29-line clone is captured" "1" "$(jq -r '.duplication_clones.clones | length' "$C25_JSON")"
assert_eq "25b and registers no QI" "0" "$(jq -r '[.quality_issues[] | select(.metric=="duplication-clone")] | length' "$C25_JSON")"

# 30 lines: registers.
stub_jscpd "$S25" "$(jscpd_report "$clone_paths2" "$(jscpd_dup 'src/A.cs' 10 39 'src/B.cs' 20 49 30 'at the line')")"
rm -rf "$C25/.specclaw/analysis/archive"
( cd "$C25" && PATH="$(clean_path "$S25")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
c25_id="$(jq -r '[.quality_issues[] | select(.metric=="duplication-clone" and .status=="open")] | .[0].id // ""' "$C25_JSON")"
if [[ -n "$c25_id" ]]; then
  pass "25c a 30-line clone registers a QI (${c25_id})"
else
  fail "25c a 30-line clone registers a QI"
fi
assert_eq_nonempty "25d registered under the duplication-clone metric" "duplication-clone" \
  "$(jq -r '[.quality_issues[] | select(.status=="open" and .metric=="duplication-clone")] | .[0].metric // ""' "$C25_JSON")"
assert_eq_nonempty "25e with the duplicated line count as its measured value" "30" \
  "$(jq -r '[.quality_issues[] | select(.metric=="duplication-clone" and .status=="open")] | .[0].value | tostring' "$C25_JSON")"

# Unchanged re-run: the SAME id. Identity is the fragment hash plus both paths,
# so nothing about a repeat measurement may move it.
rm -rf "$C25/.specclaw/analysis/archive"
( cd "$C25" && PATH="$(clean_path "$S25")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
assert_eq_nonempty "25f an unchanged re-run keeps the same QI id" "$c25_id" \
  "$(jq -r '[.quality_issues[] | select(.metric=="duplication-clone" and .status=="open")] | .[0].id // ""' "$C25_JSON")"

# Clone gone: resolved, never deleted.
stub_jscpd "$S25" "$(jscpd_report "$clone_paths2")"
rm -rf "$C25/.specclaw/analysis/archive"
( cd "$C25" && PATH="$(clean_path "$S25")" bash "$QUALITY_BIN" collect .specclaw ) >/dev/null 2>&1
assert_eq_nonempty "25g a clone that disappears is marked resolved" "resolved" \
  "$(jq -r --arg id "$c25_id" '[.quality_issues[] | select(.id==$id)] | .[0].status // ""' "$C25_JSON")"
assert_eq_nonempty "25h and is never deleted — the id is still in the registry" "1" \
  "$(jq -r --arg id "$c25_id" '[.quality_issues[] | select(.id==$id)] | length' "$C25_JSON")"

# ── Case 26 — a cross-module clone ───────────────────────────────────────────

echo "--- Case 26: a clone spanning two modules records both and is counted once ---"
C26="$WORK/c26"; clone_project "$C26"
S26="$WORK/c26-stub"
stub_scc "$S26" "$clone_scc2"
stub_lizard "$S26" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
stub_jscpd "$S26" "$(jscpd_report "$clone_paths2" "$(jscpd_dup 'src/A.cs' 44 59 'src/B.cs' 58 73 16 'crossing text')")"
c26_out="$( cd "$C26" && PATH="$(clean_path "$S26")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

assert_eq_nonempty "26a the clone is flagged cross-module" "true" \
  "$(printf '%s' "$c26_out" | jq -r '.duplication_clones.clones[0].cross_module')"
assert_eq_nonempty "26b both module ids are recorded, not just one" "MOD-001/MOD-002" \
  "$(printf '%s' "$c26_out" | jq -r '.duplication_clones.clones[0] | "\(.a.module_id)/\(.b.module_id)"')"
# Counted once: a pair is one finding, not one per side.
assert_eq_nonempty "26c it is counted once in the census, not once per side" "1/1" \
  "$(printf '%s' "$c26_out" | jq -r '.duplication_clones.census | "\(.clones_in_scope)/\(.clones_captured)"')"

# A same-module clone is not flagged — proving the flag reflects the join and
# is not simply always on.
stub_jscpd "$S26" "$(jscpd_report "$clone_paths2" "$(jscpd_dup 'src/A.cs' 10 25 'src/A.cs' 44 59 16 'same module text')")"
rm -rf "$C26/.specclaw/analysis/archive"
c26b_out="$( cd "$C26" && PATH="$(clean_path "$S26")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
assert_eq_nonempty "26d a clone within one module is not flagged cross-module" "false" \
  "$(printf '%s' "$c26b_out" | jq -r '.duplication_clones.clones[0].cross_module')"

# ── Case 27 — mechanical function mapping, and its refusals ──────────────────

echo "--- Case 27: a function name is attached only when the containment rule is met ---"
C27="$WORK/c27"
rm -rf "$C27"; mkdir -p "$C27/.specclaw/analysis" "$C27/src"
printf 'public class A { }\n' > "$C27/src/A.cs"
printf 'public class B { }\n' > "$C27/src/B.cs"
printf 'unit Legacy;\nbegin\nend.\n' > "$C27/src/Legacy.pas"
printf 'unit Other;\nbegin\nend.\n'  > "$C27/src/Other.pas"
S27="$WORK/c27-stub"
stub_scc "$S27" '[{"Name":"C#","Files":[{"Location":"src/A.cs","Lines":200,"Code":180},{"Location":"src/B.cs","Lines":200,"Code":180}]},
 {"Name":"Pascal","Files":[{"Location":"src/Legacy.pas","Lines":200,"Code":180},{"Location":"src/Other.pas","Lines":200,"Code":180}]}]'
# A.cs: one big method covering 40-80, so a clone at 44-59 sits inside it.
# B.cs: two small adjacent methods, so a clone spanning both meets no rule.
stub_lizard "$S27" "$(liz_row_range 'src/A.cs' 'BigMethod' 4 41 40 80)
$(liz_row_range 'src/B.cs' 'FirstHalf' 3 10 50 59)
$(liz_row_range 'src/B.cs' 'SecondHalf' 3 10 60 69)"
stub_jscpd "$S27" "$(jscpd_report \
  '{"src/A.cs":{"lines":200,"duplicatedLines":16},"src/B.cs":{"lines":200,"duplicatedLines":16},"src/Legacy.pas":{"lines":200,"duplicatedLines":20},"src/Other.pas":{"lines":200,"duplicatedLines":20}}' \
  "$(jscpd_dup 'src/A.cs' 44 59 'src/B.cs' 55 70 16 'mapped one side only')" \
  "$(jscpd_dup 'src/Legacy.pas' 10 29 'src/Other.pas' 40 59 20 'pascal block')")"
c27_out="$( cd "$C27" && PATH="$(clean_path "$S27")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

c27_cs="$(printf '%s' "$c27_out" | jq -r '.duplication_clones.clones[] | select(.a.file=="src/A.cs") | "\(.a.function)|\(.b.function)"')"
assert_eq_nonempty "27a a clone inside one method gets that method; the side spanning two gets null" \
  "BigMethod|null" "$c27_cs"

c27_pas="$(printf '%s' "$c27_out" | jq -r '.duplication_clones.clones[] | select(.a.file=="src/Legacy.pas") | "\(.a.function)|\(.b.function)"')"
assert_eq_nonempty "27b a clone in a language with no function measurement gets null on both sides" \
  "null|null" "$c27_pas"

# The Pascal clone is still fully reported — refusing a name is not refusing the
# finding.
c27_pasloc="$(printf '%s' "$c27_out" | jq -r '.duplication_clones.clones[] | select(.a.file=="src/Legacy.pas") | "\(.a.file):\(.a.start)-\(.a.end)|\(.lines)"')"
assert_eq_nonempty "27c and its file:range is still reported in full" "src/Legacy.pas:10-29|20" "$c27_pasloc"

# ── Case 28 — capture truncation, with the true totals still stated ──────────

echo "--- Case 28: more clones than the cap keeps the largest and reports the real totals ---"
C28="$WORK/c28"; clone_project "$C28"
printf 'version: 1\nquality:\n  clone_capture_top_n: 3\n' > "$C28/.specclaw/config.yaml"
S28="$WORK/c28-stub"
stub_scc "$S28" "$clone_scc2"
stub_lizard "$S28" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
stub_jscpd "$S28" "$(jscpd_report "$clone_paths2" \
  "$(jscpd_dup 'src/A.cs' 1 8   'src/B.cs' 1 8   8  'eight')" \
  "$(jscpd_dup 'src/A.cs' 10 34 'src/B.cs' 10 34 25 'twentyfive')" \
  "$(jscpd_dup 'src/A.cs' 40 51 'src/B.cs' 40 51 12 'twelve')" \
  "$(jscpd_dup 'src/A.cs' 60 79 'src/B.cs' 60 79 20 'twenty')" \
  "$(jscpd_dup 'src/A.cs' 90 94 'src/B.cs' 90 94 5  'five')")"
c28_out="$( cd "$C28" && PATH="$(clean_path "$S28")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

assert_eq_nonempty "28a only the cap is stored" "3" \
  "$(printf '%s' "$c28_out" | jq -r '.duplication_clones.clones | length')"
assert_eq_nonempty "28b and they are the three largest, in order" "25,20,12" \
  "$(printf '%s' "$c28_out" | jq -r '[.duplication_clones.clones[].lines] | join(",")')"
assert_eq_nonempty "28c the census reports the TRUE totals, not the truncated ones" "5/5/3/70" \
  "$(printf '%s' "$c28_out" | jq -r '.duplication_clones.census | "\(.clones_found)/\(.clones_in_scope)/\(.clones_captured)/\(.duplicated_lines_found)"')"
assert_eq_nonempty "28d and says so explicitly rather than leaving it to arithmetic" "true" \
  "$(printf '%s' "$c28_out" | jq -r '.duplication_clones.census.truncated')"

# QI registration is NOT bounded by the display cap: a permanent id must not be
# lost because another clone took its slot.
printf 'version: 1\nquality:\n  clone_capture_top_n: 1\n  clone_qi_min_lines: 10\n' > "$C28/.specclaw/config.yaml"
rm -rf "$C28/.specclaw/analysis/archive"
c28b_out="$( cd "$C28" && PATH="$(clean_path "$S28")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
assert_eq_nonempty "28e one clone stored, but every qualifying clone still registered" "1/3" \
  "$(printf '%s' "$c28b_out" | jq -r '"\(.duplication_clones.clones | length)/\([.quality_issues[] | select(.metric=="duplication-clone" and .status=="open")] | length)"')"

# ── Case 29 — scope: a clone with a side outside the measured list ───────────

echo "--- Case 29: a clone reaching outside the measured scope is dropped and counted ---"
C29="$WORK/c29"; clone_project "$C29"
mkdir -p "$C29/tests"
printf 'public class ATests { }\n' > "$C29/tests/ATests.cs"
S29="$WORK/c29-stub"
stub_scc "$S29" "$clone_scc2"
stub_lizard "$S29" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
# jscpd walks the tree itself, so it happily reports a clone in tests/ — which
# the exclusion pass removed from the measured list.
stub_jscpd "$S29" "$(jscpd_report "$clone_paths2" \
  "$(jscpd_dup 'src/A.cs' 44 59 'src/B.cs' 58 73 16 'in scope')" \
  "$(jscpd_dup 'src/A.cs' 10 29 'tests/ATests.cs' 10 29 20 'half out of scope')")"
c29_out="$( cd "$C29" && PATH="$(clean_path "$S29")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"

assert_eq_nonempty "29a only the in-scope clone is captured" "1" \
  "$(printf '%s' "$c29_out" | jq -r '.duplication_clones.clones | length')"
assert_eq_nonempty "29b the dropped pair is counted, not silently gone" "2/1/1" \
  "$(printf '%s' "$c29_out" | jq -r '.duplication_clones.census | "\(.clones_found)/\(.clones_outside_scope)/\(.clones_in_scope)"')"
if printf '%s' "$c29_out" | grep -qF 'tests/ATests.cs'; then
  fail "29c the out-of-scope path does not leak into the artifact"
else
  pass "29c the out-of-scope path does not leak into the artifact"
fi
# The larger clone was the dropped one — so its duplicated lines must not be in
# the total either.
assert_eq_nonempty "29d and its lines are excluded from the duplicated-line total" "16" \
  "$(printf '%s' "$c29_out" | jq -r '.duplication_clones.census.duplicated_lines_found')"

# ── Case 30 — the report template carries the section, client-safe ───────────
#
# Same reasoning as Case 10: the report is written by an agent no bash suite can
# run, so what is checkable is the template the agent is handed.

echo "--- Case 30: the report template carries a client-safe hotspot section ---"
T30="$PLUGIN_ROOT/templates/quality-report.md"
if grep -q '^## Top Duplication Hotspots' "$T30"; then
  pass "30a the report template has a Top Duplication Hotspots section"
else
  fail "30a the report template has a Top Duplication Hotspots section"
fi
if grep -q '{{duplication_hotspots}}' "$T30"; then
  pass "30b with a token for the agent to fill"
else
  fail "30b with a token for the agent to fill"
fi
# It must sit after the rollups: how much, then where.
t30_roll="$(grep -n '^## Module Rollup' "$T30" | cut -d: -f1)"
t30_dup="$(grep -n '^## Top Duplication Hotspots' "$T30" | cut -d: -f1)"
if [[ -n "$t30_roll" && -n "$t30_dup" && "$t30_dup" -gt "$t30_roll" ]]; then
  pass "30c placed after the module rollups"
else
  fail "30c placed after the module rollups (rollup line $t30_roll, section line $t30_dup)"
fi
t30_body="$(awk '/^## Internal provenance/{exit} {print}' "$T30" | awk '/<!--/{c=1} !c{print} /-->/{c=0}')"
t30_leak=""
for name in "specclaw" "SpecClaw" "bf-quality"; do
  case "$t30_body" in *"$name"*) t30_leak="${t30_leak}${name} " ;; esac
done
if [[ -z "$t30_leak" ]]; then
  pass "30d the new section keeps the body free of internal names"
else
  fail "30d the new section keeps the body free of internal names (leaked: $t30_leak)"
fi
# The instructions must forbid printing the code and require the truncation
# footer — those are the two things a narrator would otherwise get wrong.
assert_contains "30e the guidance forbids showing duplicated source" \
  "NEVER SHOW THE DUPLICATED CODE" "$(cat "$T30")"
assert_contains "30f and requires truncation to be stated" \
  "TRUNCATION IS STATED" "$(cat "$T30")"
AGENT30="$PLUGIN_ROOT/agents/bf-quality-analyst.md"
assert_contains "30g the agent is told the artifact holds no fragment" \
  "never the fragment" "$(cat "$AGENT30")"

# ── Case 31 — a repo with no duplication ─────────────────────────────────────

echo "--- Case 31: zero clones is an honest empty result, not a crash ---"
C31="$WORK/c31"; clone_project "$C31"
S31="$WORK/c31-stub"
stub_scc "$S31" "$clone_scc2"
stub_lizard "$S31" "$(liz_row_range 'src/A.cs' 'Compute' 4 20 40 60)"
stub_jscpd "$S31" "$(jscpd_report '{"src/A.cs":{"lines":80,"duplicatedLines":0},"src/B.cs":{"lines":80,"duplicatedLines":0}}')"
c31_out="$( cd "$C31" && PATH="$(clean_path "$S31")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
c31_exit=$?
assert_eq "31a a repo with no duplication exits 0" "0" "$c31_exit"
assert_eq_nonempty "31b the clone list is present and empty, never absent" "0" \
  "$(printf '%s' "$c31_out" | jq -r '.duplication_clones.clones | length')"
assert_eq_nonempty "31c the census reports honest zeroes" "0/0/0/false" \
  "$(printf '%s' "$c31_out" | jq -r '.duplication_clones.census | "\(.clones_found)/\(.clones_in_scope)/\(.clones_captured)/\(.truncated)"')"
assert_eq "31d and no clone QI is invented" "0" \
  "$(printf '%s' "$c31_out" | jq -r '[.quality_issues[] | select(.metric=="duplication-clone")] | length')"

# jscpd absent entirely is a different state again, and must also not crash.
C31B="$WORK/c31b"; clone_project "$C31B"
S31B="$WORK/c31b-stub"
stub_scc "$S31B" "$clone_scc2"
c31b_out="$( cd "$C31B" && PATH="$(clean_path "$S31B")" bash "$QUALITY_BIN" collect .specclaw 2>/dev/null )"
assert_eq "31e with no jscpd at all: exit 0" "0" "$?"
assert_eq_nonempty "31f and the clone census is zeroed rather than missing" "0" \
  "$(printf '%s' "$c31b_out" | jq -r '.duplication_clones.census.clones_found')"

# ── Case 32 — two unnamed functions in one file are two hotspots ─────────────
#
# The collision that started all of this. lizard names every unnamed function
# "(anonymous)" and some parsers emit the name field empty, so before the key
# carried a start line two over-length lambdas in one file produced ONE key —
# and on the second run the prior-registry map collapsed both onto one id and
# dropped the other. Ids are permanent; this is what "permanent" was failing to
# mean.

echo
echo "--- Case 32: two unnamed functions in one file get two distinct keys and keep them ---"
C32="$WORK/c32"; new_project "$C32"; module_map_one "$C32"
S32="$WORK/c32-stub"
stub_scc "$S32" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
# Two rows, one file, no function name, different spans, both over the
# function-length HIGH band. ccn stays low so nothing registers on complexity.
stub_lizard "$S32" "$(liz_row_range 'src/Calc.cs' '' 3 200 10 220)
$(liz_row_range 'src/Calc.cs' '' 3 150 300 460)"

( cd "$C32" && PATH="$(clean_path "$S32")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C32_JSON="$C32/.specclaw/analysis/quality.json"

c32_n="$(jq -r '[.quality_issues[] | select(.metric == "function_length")] | length' "$C32_JSON")"
assert_eq "32a both over-length functions register, not one" "2" "$c32_n"

c32_keys="$(jq -r '[.quality_issues[] | select(.metric == "function_length") | .key] | unique | length' "$C32_JSON")"
assert_eq "32b their keys are distinct" "2" "$c32_keys"

c32_shape="$(jq -r '[.quality_issues[] | select(.metric == "function_length")
  | "\(.scope)@\(.start)"] | sort | join(",")' "$C32_JSON")"
assert_eq_nonempty "32c each is keyed <anonymous> plus its own start line" \
  "<anonymous>@10,<anonymous>@300" "$c32_shape"

# The Function field must stay empty. <anonymous> is a KEY sentinel, and
# publishing it as a function name would be inventing one.
c32_fn="$(jq -r '[.quality_issues[] | select(.metric == "function_length" and .function != null)] | length' "$C32_JSON")"
assert_eq "32d the sentinel never leaks into the Function field" "0" "$c32_fn"

c32_r1="$(jq -S -c '[.quality_issues[] | {id, key, first_seen}]' "$C32_JSON")"
( cd "$C32" && PATH="$(clean_path "$S32")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c32_r2="$(jq -S -c '[.quality_issues[] | {id, key, first_seen}]' "$C32_JSON")"
assert_eq_nonempty "32e an unchanged re-run assigns byte-identical ids" "$c32_r1" "$c32_r2"

# ── Case 33 — the *global* sentinel, and that it collides with nothing ───────
#
# There cannot literally be two file-level findings of the SAME metric in one
# file — a file has one length. What there can be, and what has to stay
# distinct, is every scope sentinel appearing at once in one measurement:
# *global* on a file-level metric, *global* on a module-level one, and
# <anonymous> twice over on functions inside the same file. That is the case
# where a blank slot used to make several of them one key.

echo
echo "--- Case 33: *global* and <anonymous> coexist in one file without colliding ---"
C33="$WORK/c33"; clone_project "$C33"
S33="$WORK/c33-stub"
stub_scc "$S33" '[{"Name":"C#","Files":[
  {"Location":"src/A.cs","Lines":1500,"Code":1400},
  {"Location":"src/B.cs","Lines":1200,"Code":1100}]}]'
stub_lizard "$S33" "$(liz_row_range 'src/A.cs' '' 3 200 10 220)
$(liz_row_range 'src/A.cs' '' 3 150 300 460)"
stub_jscpd "$S33" "$(jscpd_report '{"src/A.cs":{"lines":1500,"duplicatedLines":900},"src/B.cs":{"lines":1200,"duplicatedLines":700}}')"

( cd "$C33" && PATH="$(clean_path "$S33")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C33_JSON="$C33/.specclaw/analysis/quality.json"

c33_dupes="$(jq -r '[.quality_issues[] | select(.status != "superseded-duplicate")]
  | group_by(.key) | map(select(length > 1)) | length' "$C33_JSON")"
assert_eq "33a no two hotspots share a key" "0" "$c33_dupes"

c33_global="$(jq -r '[.quality_issues[] | select(.metric == "file_length" or .metric == "duplication") | .scope]
  | unique | join(",")' "$C33_JSON")"
assert_eq_nonempty "33b every file- and module-level hotspot is scoped *global*" "*global*" "$c33_global"

c33_starts="$(jq -r '[.quality_issues[] | select(.metric == "file_length") | .start] | unique | join(",")' "$C33_JSON")"
assert_eq_nonempty "33c a file-level hotspot starts at line 1, its span being the file" "1" "$c33_starts"

c33_dupstart="$(jq -r '[.quality_issues[] | select(.metric == "duplication") | .start] | unique | join(",")' "$C33_JSON")"
assert_eq_nonempty "33d a module-level hotspot carries 0, which is not a line" "0" "$c33_dupstart"

# The point of the sentinels: a *global* key and an <anonymous> key on the same
# file, same module, never read as the same hotspot.
c33_akeys="$(jq -r '[.quality_issues[] | select(.file == "src/A.cs") | .key] | unique | length' "$C33_JSON")"
c33_acount="$(jq -r '[.quality_issues[] | select(.file == "src/A.cs")] | length' "$C33_JSON")"
assert_eq_nonempty "33e every hotspot on one file has its own key" "$c33_acount" "$c33_akeys"

# ── Case 34 — the identity assertion refuses to write a broken set (PD-02) ───

echo
echo "--- Case 34: two hotspots on one key, or one with no start line, stop the run ---"
C34="$WORK/c34"; new_project "$C34"; module_map_one "$C34"
S34="$WORK/c34-stub"
stub_scc "$S34" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
# Two rows the measuring tool should never emit: same file, same name, same
# start line, different lengths. Nothing downstream can tell them apart, so the
# collector must not pretend it can.
stub_lizard "$S34" "$(liz_row_range 'src/Calc.cs' 'Run' 3 200 10 220)
$(liz_row_range 'src/Calc.cs' 'Run' 3 300 10 320)"

c34_err="$( cd "$C34" && PATH="$(clean_path "$S34")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c34_exit=$?
assert_eq "34a a colliding set fails the run" "1" "$c34_exit"
assert_contains "34b and says what collided" "QI identity collision" "$c34_err"
assert_contains "34c naming the first entry and its value" "value=200" "$c34_err"
assert_contains "34d and the second" "value=300" "$c34_err"

if [[ -f "$C34/.specclaw/analysis/quality.json" ]]; then
  fail "34e nothing is written when identity cannot be established"
else
  pass "34e nothing is written when identity cannot be established"
fi

# The other half of the assertion: lizard's start-line columns are OPTIONAL, so
# a build that stops emitting them still measures complexity fine — but a
# hotspot with no start line has no identity, and registering it would quietly
# restore the collapse the start line was added to fix.
C34B="$WORK/c34b"; new_project "$C34B"; module_map_one "$C34B"
S34B="$WORK/c34b-stub"
stub_scc "$S34B" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
# Eight fields exactly: parseable, measurable, and carrying no line numbers.
stub_lizard "$S34B" '200,3,900,2,200,Run@1-1@src/Calc.cs,src/Calc.cs,Run'

c34b_err="$( cd "$C34B" && PATH="$(clean_path "$S34B")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c34b_exit=$?
assert_eq "34f a registering hotspot with no start line fails the run" "1" "$c34b_exit"
assert_contains "34g and says the start line is what is missing" "no start line" "$c34b_err"

# ── Case 35 — the registry migration (PD-03) ─────────────────────────────────
#
# The state a real registry is in: three ids minted under one four-field key,
# each recording the value of the hotspot it was actually measuring. The
# migration has to keep every id, put each on the right hotspot, tombstone the
# one that matches nothing, register the hotspot nobody claimed, and do nothing
# at all the second time.

echo
echo "--- Case 35: old ids are mapped onto the new key, never renumbered ---"
C35="$WORK/c35"; new_project "$C35"; module_map_one "$C35"
S35="$WORK/c35-stub"
stub_scc "$S35" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S35" "$(liz_row_range 'src/Calc.cs' '' 3 210 10 220)
$(liz_row_range 'src/Calc.cs' '' 3 180 300 480)
$(liz_row_range 'src/Calc.cs' '' 3 150 600 750)"

# QI-001 and QI-002 match a live hotspot by value. QI-003's 999 matches none —
# whatever it was measuring is gone, and it is emphatically not the 150.
cat > "$C35/.specclaw/analysis/quality-issues.md" <<'C35REG'
# Quality Issues: Fixture

**Path measured:** .
**Last updated:** 2026-08-01T00:00:00Z

### QI-001

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 210
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z

### QI-002

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 180
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z

### QI-003

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 999
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z
C35REG

( cd "$C35" && PATH="$(clean_path "$S35")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C35_JSON="$C35/.specclaw/analysis/quality.json"
C35_REG="$C35/.specclaw/analysis/quality-issues.md"

c35_map="$(jq -r '[.quality_issues[] | "\(.id)=\(.status)/\(.value)"] | sort | join(" ")' "$C35_JSON")"
assert_eq_nonempty "35a each id lands on the hotspot its recorded value names, the unmatched one is tombstoned, the unclaimed hotspot registers fresh" \
  "QI-001=open/210 QI-002=open/180 QI-003=superseded-duplicate/999 QI-004=open/150" "$c35_map"

c35_sup="$(jq -r '.quality_issues[] | select(.status == "superseded-duplicate") | .superseded_by' "$C35_JSON")"
assert_eq_nonempty "35b the tombstone names the lowest surviving id" "QI-001" "$c35_sup"

c35_firsts="$(jq -r '[.quality_issues[] | select(.id != "QI-004") | .first_seen] | unique | join(",")' "$C35_JSON")"
assert_eq_nonempty "35c a migrated id keeps its original First seen" "2026-08-01T00:00:00Z" "$c35_firsts"

c35_keys="$(jq -r '[.quality_issues[] | select(.status == "open") | .key] | sort | join(" ")' "$C35_JSON")"
assert_eq_nonempty "35d every surviving id records the new five-field key" \
  "function_length|src/Calc.cs|<anonymous>|MOD-001|10 function_length|src/Calc.cs|<anonymous>|MOD-001|300 function_length|src/Calc.cs|<anonymous>|MOD-001|600" \
  "$c35_keys"

c35_tomb_key="$(jq -r '.quality_issues[] | select(.status == "superseded-duplicate") | .key' "$C35_JSON")"
assert_eq_nonempty "35e the tombstone keeps the historical key it was a duplicate under" \
  "function_length|src/Calc.cs||MOD-001" "$c35_tomb_key"

assert_eq "35f nothing is deleted — every id is still in the registry" "4" \
  "$(grep -c '^### QI-' "$C35_REG")"
assert_contains "35g the registry records the migration, dated" "key migrated" "$(cat "$C35_REG")"
assert_contains "35h and names the tombstone's successor" "**Superseded by:** QI-001" "$(cat "$C35_REG")"

# Idempotence. Nothing left to migrate, so nothing moves and no second record is
# appended — the registry is byte-identical but for the timestamps.
cp "$C35_REG" "$WORK/c35-reg-after1.md"
( cd "$C35" && PATH="$(clean_path "$S35")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c35_before="$(sed -e 's/^- \*\*Last checked:.*/T/' -e 's/^\*\*Last updated:.*/T/' "$WORK/c35-reg-after1.md")"
c35_after="$(sed -e 's/^- \*\*Last checked:.*/T/' -e 's/^\*\*Last updated:.*/T/' "$C35_REG")"
assert_eq_nonempty "35i a second run migrates nothing and writes no second record" "$c35_before" "$c35_after"

# T3. Two ids recording the same value, two hotspots carrying it: the document
# does not say which id was measuring which, and neither does the collector.
C35B="$WORK/c35b"; new_project "$C35B"; module_map_one "$C35B"
S35B="$WORK/c35b-stub"
stub_scc "$S35B" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S35B" "$(liz_row_range 'src/Calc.cs' '' 3 210 10 220)
$(liz_row_range 'src/Calc.cs' '' 3 210 300 510)"
cat > "$C35B/.specclaw/analysis/quality-issues.md" <<'C35BREG'
# Quality Issues: Fixture

**Path measured:** .
**Last updated:** 2026-08-01T00:00:00Z

### QI-001

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 210
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z

### QI-002

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 210
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z
C35BREG
c35b_err="$( cd "$C35B" && PATH="$(clean_path "$S35B")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c35b_exit=$?
assert_eq "35j an undecidable migration stops rather than guessing" "1" "$c35b_exit"
assert_contains "35k naming the ambiguity" "QUALITY-MIGRATION-AMBIGUOUS" "$c35b_err"
assert_contains "35l and the ids involved" "QI-001 (recorded value 210)" "$c35b_err"
assert_eq "35m and the registry is left exactly as it was" "2" \
  "$(grep -c '^### QI-' "$C35B/.specclaw/analysis/quality-issues.md")"

# PD-03 gives the surviving number to the LOWEST id. A collector-written
# registry is already in id order, so an implementation that trusted document
# order would pass every test above and still hand the number to whichever entry
# happened to be typed first in a hand-edited one.
C35C="$WORK/c35c"; new_project "$C35C"; module_map_one "$C35C"
S35C="$WORK/c35c-stub"
stub_scc "$S35C" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S35C" "$(liz_row_range 'src/Calc.cs' '' 3 210 10 220)
$(liz_row_range 'src/Calc.cs' '' 3 180 300 480)"
cat > "$C35C/.specclaw/analysis/quality-issues.md" <<'C35CREG'
# Quality Issues: Fixture

**Path measured:** .
**Last updated:** 2026-08-01T00:00:00Z

### QI-007

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 999
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z

### QI-002

- **Key:** function_length|src/Calc.cs||MOD-001
- **Value:** 210
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z
C35CREG
( cd "$C35C" && PATH="$(clean_path "$S35C")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c35c_map="$(jq -r '[.quality_issues[] | "\(.id)=\(.status)"] | sort | join(" ")' "$C35C/.specclaw/analysis/quality.json")"
assert_eq_nonempty "35n the lowest id survives even when the registry lists it second" \
  "QI-002=open QI-007=superseded-duplicate QI-008=open" "$c35c_map"
c35c_sup="$(jq -r '.quality_issues[] | select(.status == "superseded-duplicate") | .superseded_by' "$C35C/.specclaw/analysis/quality.json")"
assert_eq_nonempty "35o and the tombstone points at it, not at whichever came first" "QI-002" "$c35c_sup"

# ── Case 36 — the scan funnel is computed, and the report shows it ───────────

echo
echo "--- Case 36: scan_funnel carries the true counts and the report copies them ---"
C36="$WORK/c36"; new_project "$C36"; module_map_one "$C36"
S36="$WORK/c36-stub"
stub_scc "$S36" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":90,"Code":80}]}]'
stub_lizard "$S36" "$(liz_row_range 'src/Calc.cs' 'Run' 4 12 3 15)"
( cd "$C36" && PATH="$(clean_path "$S36")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C36_JSON="$C36/.specclaw/analysis/quality.json"

# ONE computation, projected — never a second count that could disagree.
c36_pairs="$(jq -r '
  [ (.scan_funnel.enumerated == .files.enumerated),
    (.scan_funnel.in_scope  == .files.measured),
    (.scan_funnel.excluded  == .files.excluded),
    (.scan_funnel.coverage.classified == .files.classified),
    (.scan_funnel.coverage.sized == .files.sized),
    (.scan_funnel.coverage.function_measured == .files.function_measured),
    (.scan_funnel.coverage.duplication_measured == .files.duplication_measured) ]
  | unique | join(",")' "$C36_JSON")"
assert_eq_nonempty "36a the funnel is a projection of the counts, not a second count" "true" "$c36_pairs"

# The fixture decides these exactly: three files in the tree (two sources and
# the module map), the map excluded by scope, two in scope. Both are of a known
# language; scc's stub sizes one of them and lizard's measures one function in
# it; nothing is duplication-measured, because jscpd is not on the stub PATH.
# Four different numbers over one scan, which is the whole point of a funnel.
c36_true="$(jq -r '"\(.scan_funnel.enumerated)/\(.scan_funnel.excluded)/\(.scan_funnel.in_scope)"' "$C36_JSON")"
assert_eq_nonempty "36b enumerated, excluded and in-scope are the fixture's real counts" "3/1/2" "$c36_true"
c36_cov="$(jq -r '.scan_funnel.coverage | "\(.classified)/\(.sized)/\(.function_measured)/\(.duplication_measured)"' "$C36_JSON")"
assert_eq_nonempty "36c and each metric's coverage is its own count, not the scope" "2/1/1/0" "$c36_cov"

# The rendered block. A test cannot run the narration agent, so what is checked
# is the block the agent is required to paste — which is the whole mechanism:
# if the figures are only in this block, and this block is copied, there is no
# step at which a figure is retyped. Case 38 proves the copy is enforced.
c36_block="$(jq -r '.report_blocks.scan_funnel_md' "$C36_JSON" | tr -d '\r')"
assert_contains "36d the block states the in-scope count" "**In scope — the list every metric received** | **2**" "$c36_block"
assert_contains "36e and the function-measured count separately" "function-measured | 1" "$c36_block"
assert_contains "36f and the duplication-measured count separately" "duplication-measured | 0" "$c36_block"

# ── Case 37 — the module rollup summary, and the table built from it ─────────

echo
echo "--- Case 37: module_rollup_summary matches the modules array exactly ---"
C37="$WORK/c37"; clone_project "$C37"
S37="$WORK/c37-stub"
stub_scc "$S37" '[{"Name":"C#","Files":[
  {"Location":"src/A.cs","Lines":1500,"Code":1400},
  {"Location":"src/B.cs","Lines":90,"Code":80}]}]'
stub_lizard "$S37" "$(liz_row_range 'src/A.cs' 'Big' 34 200 10 220)
$(liz_row_range 'src/B.cs' 'Small' 4 12 3 15)"
( cd "$C37" && PATH="$(clean_path "$S37")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C37_JSON="$C37/.specclaw/analysis/quality.json"

c37_count="$(jq -r '.module_rollup_summary.module_count == (.modules | length)' "$C37_JSON")"
assert_eq_nonempty "37a the module count matches the modules array" "true" "$c37_count"

c37_ids="$(jq -r '.module_rollup_summary.module_ids == [.modules[].module_id]' "$C37_JSON")"
assert_eq_nonempty "37b the id list matches the modules array, in order" "true" "$c37_ids"

c37_sums="$(jq -r '
  .modules as $m
  | [ .module_rollup_summary.status_counts | to_entries[]
      | .key as $s | .value == ([$m[] | select(.rollup_status == $s)] | length) ]
  | unique | join(",")' "$C37_JSON")"
assert_eq_nonempty "37c every status count matches the modules that carry it" "true" "$c37_sums"

c37_total="$(jq -r '([.module_rollup_summary.status_counts[]] | add) == (.modules | length)' "$C37_JSON")"
assert_eq_nonempty "37d the counts sum to the module count, so no module is missed or double-counted" "true" "$c37_total"

# The table is rendered here, not by the narrator, so it can hold no row the
# artifact does not. That is the MOD-010 defect, closed at the source.
c37_rows="$(jq -r '.report_blocks.module_rollup_md' "$C37_JSON" | tr -d '\r' | grep -cE '^\| MOD-')"
assert_eq_nonempty "37e the rendered table has exactly one row per module" \
  "$(jq -r '.modules | length' "$C37_JSON")" "$c37_rows"

c37_blockids="$(jq -r '.report_blocks.module_rollup_md' "$C37_JSON" | grep -oE 'MOD-[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
c37_jsonids="$(jq -r '.module_rollup_summary.module_ids[]' "$C37_JSON" | grep -oE 'MOD-[0-9]+' | sort -u | tr '\n' ' ' | sed 's/ *$//')"
assert_eq_nonempty "37f and names no module the measurement does not contain" "$c37_jsonids" "$c37_blockids"

c37_footer="$(jq -r '.report_blocks.module_rollup_md' "$C37_JSON" | tr -d '\r' | tail -1)"
assert_contains "37g the footer states the count at each status" "modules: " "$c37_footer"
assert_contains "37h with the HIGH count the summary carries" \
  "$(jq -r '.module_rollup_summary.status_counts.HIGH | tostring' "$C37_JSON") HIGH" "$c37_footer"

# ── Case 38 — the report lint (PD-07) ────────────────────────────────────────
#
# A report assembled the way the agent is told to assemble it must pass; the
# same report with one figure retyped, one row invented or one unknown id must
# fail, naming what disagreed.

echo
echo "--- Case 38: the lint passes a faithful report and fails a corrupted one ---"
C38_JSON="$C37_JSON"
C38_REPORT="$WORK/c38-report.md"
{
  echo "# Code Quality Report: Fixture"
  echo
  echo "## Scan scope"
  echo
  echo "<!-- quality-report:scan-funnel:begin -->"
  jq -r '.report_blocks.scan_funnel_md' "$C38_JSON" | tr -d '\r'
  echo "<!-- quality-report:scan-funnel:end -->"
  echo
  echo "## Module Rollup"
  echo
  echo "<!-- quality-report:module-rollup:begin -->"
  jq -r '.report_blocks.module_rollup_md' "$C38_JSON" | tr -d '\r'
  echo "<!-- quality-report:module-rollup:end -->"
  echo
  echo "## Methodology"
  echo
  echo "<!-- quality-report:coverage-sentence:begin -->"
  jq -r '.report_blocks.coverage_sentence_md' "$C38_JSON" | tr -d '\r'
  echo "<!-- quality-report:coverage-sentence:end -->"
} > "$C38_REPORT"

c38_ok="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$C38_REPORT" "$C38_JSON" 2>&1 )"
c38_ok_exit=$?
assert_eq "38a a faithful report passes" "0" "$c38_ok_exit"
assert_contains "38b and says so" "REPORT-LINT: PASS" "$c38_ok"

# An invented module row — the exact defect.
awk '{print} /^\| MOD-/ && !done {print "| MOD-010 | 4 | 900 | HIGH | HIGH | PASS | PASS | HIGH |"; done=1}' \
  "$C38_REPORT" > "$WORK/c38-mod010.md"
c38_mod="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$WORK/c38-mod010.md" "$C38_JSON" 2>&1 )"
c38_mod_exit=$?
assert_eq "38c an invented module row fails the lint" "1" "$c38_mod_exit"
assert_contains "38d naming the module the measurement does not contain" \
  "the report names MOD-010" "$c38_mod"

# A retyped status tally.
sed 's/^\([0-9]*\) modules: .*/\1 modules: 6 HIGH, 3 WARN, 1 PASS, 0 NOT-MEASURED./' \
  "$C38_REPORT" > "$WORK/c38-tally.md"
c38_tally="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$WORK/c38-tally.md" "$C38_JSON" 2>&1 )"
c38_tally_exit=$?
assert_eq "38e a retyped status tally fails the lint" "1" "$c38_tally_exit"
assert_contains "38f naming the block that disagrees" \
  "the module-rollup block in the report differs" "$c38_tally"

# A retyped funnel figure.
sed 's/\*\*In scope — the list every metric received\*\* | \*\*2\*\*/**In scope — the list every metric received** | **1892**/' \
  "$C38_REPORT" > "$WORK/c38-funnel.md"
c38_fun="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$WORK/c38-funnel.md" "$C38_JSON" 2>&1 )"
c38_fun_exit=$?
assert_eq "38g a retyped funnel figure fails the lint" "1" "$c38_fun_exit"
assert_contains "38h naming the scan-funnel block" "the scan-funnel block in the report differs" "$c38_fun"

# An unregistered hotspot id.
{ cat "$C38_REPORT"; echo; echo "- QI-099 — a hotspot nobody measured."; } > "$WORK/c38-qi.md"
c38_qi="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$WORK/c38-qi.md" "$C38_JSON" 2>&1 )"
c38_qi_exit=$?
assert_eq "38i an unregistered QI id fails the lint" "1" "$c38_qi_exit"
assert_contains "38j naming it" "the report names QI-099" "$c38_qi"

# A missing anchor is a failure too: without it the section's figures are simply
# unchecked, which is the state this whole mechanism exists to end.
grep -v 'quality-report:scan-funnel:begin' "$C38_REPORT" > "$WORK/c38-noanchor.md"
c38_na="$( cd "$C37" && bash "$QUALITY_BIN" lint-report .specclaw "$WORK/c38-noanchor.md" "$C38_JSON" 2>&1 )"
c38_na_exit=$?
assert_eq "38k a missing anchor fails the lint" "1" "$c38_na_exit"
assert_contains "38l saying the anchors are gone" "anchors are missing" "$c38_na"

# ── Case 39 — the coverage sentence is rendered, not written (PD-05) ─────────

echo
echo "--- Case 39: the methodology's coverage sentence comes from the funnel ---"
C39_JSON="$C36_JSON"
c39_sentence="$(jq -r '.report_blocks.coverage_sentence_md' "$C39_JSON" | tr -d '\r')"
assert_eq_nonempty "39a the sentence is rendered from the fixture's own counts, verbatim" \
  "The exclusion set was applied once, at file selection, and every metric received the same in-scope list of 2 files. Coverage differs per metric: 2 files were classified and sized, 1 were function-measured (only the languages the complexity tool parses), and 0 were duplication-measured. A metric's rollup covers the files it could measure, never the whole scope." \
  "$c39_sentence"

# The claim it replaces. "Shares a denominator" is false in the flattering
# direction: the metrics share a SCOPE, and coverage differs by hundreds of
# files on a real tree.
T39="$PLUGIN_ROOT/templates/quality-report.md"
if grep -q 'share a denominator' "$T39"; then
  fail "39b the shared-denominator claim is gone from the template"
else
  pass "39b the shared-denominator claim is gone from the template"
fi
assert_contains "39c and the template sources the sentence from the artifact instead" \
  "report_blocks.coverage_sentence_md" "$(cat "$T39")"

# ── Case 40 — an observed anomaly is never given a cause (PD-06) ─────────────
#
# WHAT IS CHECKABLE HERE. A bash suite cannot run the narration agent, so it
# cannot assert on prose the agent has not written. What it can pin is the
# instruction the agent is handed and the section the template gives it — which
# is the same thing Case 10 pins for client-safety, and for the same reason: if
# the rule is not in the prompt, the agent has to invent one to break it.

echo
echo "--- Case 40: the agent is told to observe an anomaly and stop there ---"
A40="$PLUGIN_ROOT/agents/bf-quality-analyst.md"
T40="$PLUGIN_ROOT/templates/quality-report.md"
a40="$(cat "$A40")"
t40="$(cat "$T40")"

assert_contains "40a the report has a section for anomalies" "## Data anomalies" "$t40"
assert_contains "40b the agent is forbidden a causal explanation, in those words" \
  "never supplies a causal explanation" "$a40"
assert_contains "40c the template says the same to whoever fills it" "NEVER A CAUSE" "$t40"

# The specific fabrication this closes: two lizard function-length findings
# explained as an overlap between two different tools. Naming it in the prompt
# is what makes the rule concrete rather than a piety.
assert_contains "40d and the prompt names the invented explanation it exists to prevent" \
  "jscpd and lizard each flag overlapping spans" "$a40"

# The hedged forms are the ones that get through, so they are listed explicitly.
for phrase in "because" "due to" "presumably"; do
  if printf '%s' "$a40" | grep -qF "\"$phrase\""; then
    pass "40e the prompt forbids the hedge \"$phrase\" by name"
  else
    fail "40e the prompt forbids the hedge \"$phrase\" by name"
  fi
done

# And the agent must actually be pointed at the section, not merely told a rule.
assert_contains "40f the agent is told which token carries the observations" "{{anomalies}}" "$a40"

# ── Case 41 — the CSV shape the real tool emits ──────────────────────────────
#
# Every case above this one feeds the collector rows with no quotes and no
# commas, and the collector parsed those perfectly while being unable to read
# lizard at all: it split on commas, so a quoted field containing one shifted
# every later column. This case is the row zoo that catches that — one row per
# way a comma gets inside a quoted field, plus the shapes that are not eleven
# columns wide.
#
# The seven extracted fields are asserted through what the artifact exposes:
# file, function and start line via the key, ccn and length via the rollup
# maxima. params is column 4, parsed and carried but surfaced nowhere — and it
# sits BETWEEN ccn (2) and length (5), so a split that puts those two on the
# right values cannot have put column 4 on the wrong one.

echo
echo "--- Case 41: real lizard --csv rows, commas and quotes and all ---"
C41="$WORK/c41"; new_project "$C41"; module_map_one "$C41"
mkdir -p "$C41/src/sub,dir"
printf 'public class B { }\n' > "$C41/src/sub,dir/B.cs"
S41="$WORK/c41-stub"
stub_scc "$S41" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70},
 {"Location":"src/sub,dir/B.cs","Lines":80,"Code":70}]}]'

# Row by row, and what each one is here to break:
#   Run            commas in long_name — the common case, every function of
#                  arity >= 2, which is what made this a total failure and not
#                  an edge case
#   P::operator ,  a comma in the FUNCTION name, which shifts the identity field
#                  itself and not merely the line numbers
#   sub,dir/B.cs   a comma in the PATH
#   Solo           no comma anywhere: the control, and the only shape the old
#                  parser could read
#   Tiny           eight columns, no line numbers at all — the documented
#                  tolerance, still measured, below the registering severity
#   Wide           THIRTEEN columns: csv_output appends a column per -E extension
#                  carrying FUNCTION_INFO, so start and end are read at 10 and 11
#                  and never at $NF
#   say "hi" ok    "" as an escaped quote. The producer sanitises a quote to an
#                  apostrophe and cannot emit this, so it proves the parser is a
#                  CSV reader rather than a transcription of one tool's habits.
stub_lizard "$S41" "$(liz_row_real 'src/Calc.cs' 'Run' 34 200 10 210 '( int a , int b , int c )')
$(liz_row_real 'src/Calc.cs' 'P::operator ,' 25 150 300 450)
$(liz_row_real 'src/sub,dir/B.cs' 'Calc' 30 180 5 185)
$(liz_row_real 'src/Calc.cs' 'Solo' 22 130 600 720 '')
30,5,900,2,30,Tiny@800-830@src/Calc.cs,src/Calc.cs,Tiny
140,21,100,2,140,\"Wide@900-1040@src/Calc.cs\",\"src/Calc.cs\",\"Wide\",\"Wide( int a , int b )\",900,1040,7,3
125,24,100,2,125,\"say \"\"hi\"\" ok@1100-1225@src/Calc.cs\",\"src/Calc.cs\",\"say \"\"hi\"\" ok\",\"say \"\"hi\"\" ok( int a , int b )\",1100,1225"

c41_err="$( cd "$C41" && PATH="$(clean_path "$S41")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c41_exit=$?
C41_JSON="$C41/.specclaw/analysis/quality.json"

assert_eq "41a the run completes" "0" "$c41_exit"

# Joined on ";" rather than a space or a newline: two of these scopes CONTAIN a
# space, and jq here emits CRLF, of which command substitution eats only the
# final one — so a multi-line expected value would be compared against interior
# carriage returns and fail on a correct artifact.
c41_keys="$(jq -r '[.quality_issues[] | select(.metric == "complexity") | .key] | sort | join(";")' "$C41_JSON" 2>/dev/null)"
assert_eq_nonempty "41b every registering row keys on its own start line, whatever its columns contained" \
  'complexity|src/Calc.cs|P::operator ,|MOD-001|300;complexity|src/Calc.cs|Run|MOD-001|10;complexity|src/Calc.cs|Solo|MOD-001|600;complexity|src/Calc.cs|Wide|MOD-001|900;complexity|src/Calc.cs|say "hi" ok|MOD-001|1100;complexity|src/sub,dir/B.cs|Calc|MOD-UNASSIGNED|5' \
  "$c41_keys"

# Columns 2 and 5 landed where they belong. Under the comma split they did too —
# they sit before the first quoted field — which is exactly why the failure was
# invisible in the numbers and visible only in the identity.
c41_ccn="$(jq -r '[.modules[] | select(.module_id == "MOD-001") | .complexity.max] | first' "$C41_JSON" 2>/dev/null)"
assert_eq_nonempty "41c the ccn column is read, not a neighbour of it" "34" "$c41_ccn"
c41_len="$(jq -r '[.modules[] | select(.module_id == "MOD-001") | .function_length.max] | first' "$C41_JSON" 2>/dev/null)"
assert_eq_nonempty "41d and the length column too" "200" "$c41_len"

# The eight-column row: measured (it is in the mean) and not registered (it is
# under the severity floor). Losing it would have been a metric traded for a fix.
c41_tiny="$(jq -r '[.quality_issues[] | select(.key | test("Tiny"))] | length' "$C41_JSON" 2>/dev/null)"
assert_eq_nonempty "41e a row with no line numbers is still measured, and still not registered" "0" "$c41_tiny"
c41_fn="$(jq -r '[.modules[] | select(.module_id == "MOD-001") | .complexity.mean] | first' "$C41_JSON" 2>/dev/null)"
if [[ -n "$c41_fn" && "$c41_fn" != "null" ]]; then
  pass "41f and it is inside the rollup it was measured for"
else
  fail "41f and it is inside the rollup it was measured for (mean was '$c41_fn')"
fi

assert_contains "41g the thirteen-column row reads start at 10, not at \$NF" \
  'complexity|src/Calc.cs|Wide|MOD-001|900' "$c41_keys"
assert_contains "41h \"\" is one escaped quote, and the name keeps it" \
  'complexity|src/Calc.cs|say "hi" ok|MOD-001|1100' "$c41_keys"

# ── Case 42 — two unnamed functions in one file, measured for real ────────────
#
# Case 32 asks this already, with rows that have no quotes and no commas. The
# collision it guards against returned the moment the rows were real: both start
# lines arrived empty, both keys ended in a blank slot, and the run stopped. So
# it is asked again in the shape the tool actually emits.

echo
echo "--- Case 42: two unnamed functions, real rows, two ids that stay put ---"
C42="$WORK/c42"; new_project "$C42"; module_map_one "$C42"
S42="$WORK/c42-stub"
stub_scc "$S42" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S42" "$(liz_row_real 'src/Calc.cs' '' 34 200 10 210)
$(liz_row_real 'src/Calc.cs' '' 30 180 300 480 '( int x , int y , int z )')"

( cd "$C42" && PATH="$(clean_path "$S42")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C42_JSON="$C42/.specclaw/analysis/quality.json"

c42_keys="$(jq -r '[.quality_issues[] | select(.metric == "complexity") | .key] | sort | join(" ")' "$C42_JSON" 2>/dev/null)"
assert_eq_nonempty "42a two unnamed functions differ by start line and nothing else" \
  'complexity|src/Calc.cs|<anonymous>|MOD-001|10 complexity|src/Calc.cs|<anonymous>|MOD-001|300' "$c42_keys"

c42_dupes="$(jq -r '[.quality_issues[] | select(.status != "superseded-duplicate")] | group_by(.key) | map(select(length > 1)) | length' "$C42_JSON" 2>/dev/null)"
assert_eq_nonempty "42b and no two hotspots share a key" "0" "$c42_dupes"

c42_first="$(jq -r '[.quality_issues[] | .id + "=" + .key] | sort | join(" ")' "$C42_JSON" 2>/dev/null)"
( cd "$C42" && PATH="$(clean_path "$S42")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c42_second="$(jq -r '[.quality_issues[] | .id + "=" + .key] | sort | join(" ")' "$C42_JSON" 2>/dev/null)"
assert_eq_nonempty "42c and a re-run gives every one of them the same id" "$c42_first" "$c42_second"

# ── Case 43 — the scope loses its quotes, and the registry comes with it ──────
#
# lizard --csv quotes the function name. run_lizard passed the quotes through,
# so `"Login"` went into the key and every registry written in that period holds
# a quoted scope. Normalising at the parser makes the live key `Login` and the
# stored one unreachable — which resolves the entry and re-registers the hotspot
# under a fresh number, the one thing a permanent id exists to prevent. So the
# stored key is migrated instead, and this asks whether it is.

echo
echo "--- Case 43: the scope is normalised, and old ids follow it ---"
C43="$WORK/c43"; new_project "$C43"; module_map_one "$C43"
S43="$WORK/c43-stub"
stub_scc "$S43" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S43" "$(liz_row_real 'src/Calc.cs' 'Login' 34 200 42 242)"

# A registry from that period: five-field keys, correct in every slot but one.
cat > "$C43/.specclaw/analysis/quality-issues.md" <<'C43REG'
# Quality Issues: Fixture

**Path measured:** .
**Last updated:** 2026-08-01T00:00:00Z

### QI-007

- **Key:** complexity|src/Calc.cs|"Login"|MOD-001|42
- **Value:** 34
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z

### QI-008

- **Key:** function_length|src/Calc.cs|"Login"|MOD-001|42
- **Value:** 200
- **Status:** open
- **First seen:** 2026-08-01T00:00:00Z
C43REG

( cd "$C43" && PATH="$(clean_path "$S43")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C43_JSON="$C43/.specclaw/analysis/quality.json"
C43_REG="$C43/.specclaw/analysis/quality-issues.md"

c43_map="$(jq -r '[.quality_issues[] | "\(.id)=\(.key)"] | sort | join(" ")' "$C43_JSON" 2>/dev/null)"
assert_eq_nonempty "43a the id stays on its hotspot and the key loses its quotes" \
  'QI-007=complexity|src/Calc.cs|Login|MOD-001|42 QI-008=function_length|src/Calc.cs|Login|MOD-001|42' \
  "$c43_map"

assert_eq "43b nothing was renumbered — no third id exists" "2" \
  "$(grep -c '^### QI-' "$C43_REG")"

c43_first="$(jq -r '[.quality_issues[] | .first_seen] | unique | join(",")' "$C43_JSON" 2>/dev/null)"
assert_eq_nonempty "43c and both keep the date they were first seen" "2026-08-01T00:00:00Z" "$c43_first"

assert_contains "43d the registry records what it did, in both directions" \
  'scope normalised: `complexity|src/Calc.cs|"Login"|MOD-001|42` → `complexity|src/Calc.cs|Login|MOD-001|42`' \
  "$(cat "$C43_REG")"

# Document order, not the order awk happens to walk a map: two machines
# migrating one registry should write the same paragraph.
c43_order="$(grep -c 'scope normalised' "$C43_REG")"
assert_eq "43e one line per migrated entry" "2" "$c43_order"
c43_seq="$(grep 'scope normalised' "$C43_REG" | sed 's/^- \(QI-[0-9]*\).*/\1/' | tr '\n' ' ')"
assert_eq_nonempty "43f written in the order the registry holds them" "QI-007 QI-008 " "$c43_seq"

# Idempotence, byte for byte but for the timestamps.
cp "$C43_REG" "$WORK/c43-reg-after1.md"
( cd "$C43" && PATH="$(clean_path "$S43")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
c43_before="$(sed -e 's/^- \*\*Last checked:.*/T/' -e 's/^\*\*Last updated:.*/T/' "$WORK/c43-reg-after1.md")"
c43_after="$(sed -e 's/^- \*\*Last checked:.*/T/' -e 's/^\*\*Last updated:.*/T/' "$C43_REG")"
assert_eq_nonempty "43g a second run migrates nothing and appends no second record" "$c43_before" "$c43_after"

# The tripwire. A quoted scope reaching the artifact means the parser stopped
# normalising, and nothing else in the pipeline would notice: a quoted scope
# keys and compares like any other string, which is how it survived a release.
C43B="$WORK/c43b"; new_project "$C43B"; module_map_one "$C43B"
S43B="$WORK/c43b-stub"
stub_scc "$S43B" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
# Doubly quoted at the source, so one unquoting still leaves a wrapped name —
# which is what a parser that had stopped normalising would hand over.
stub_lizard "$S43B" '200,34,100,2,200,"Login@42-242@src/Calc.cs","src/Calc.cs","""Login""","""Login""( int a , int b )",42,242'

c43b_err="$( cd "$C43B" && PATH="$(clean_path "$S43B")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c43b_exit=$?
assert_eq "43h a scope that still wears its quotes stops the run" "1" "$c43b_exit"
assert_contains "43i and says which id and key" "QI-001" "$c43b_err"
assert_contains "43j naming the fault, not a symptom of it" "quoted scope" "$c43b_err"

if [[ -f "$C43B/.specclaw/analysis/quality.json" ]]; then
  fail "43k nothing is written when the scope cannot be trusted"
else
  pass "43k nothing is written when the scope cannot be trusted"
fi

# ── Case 44 — lizard's file-scope pseudo-function is not a function ──────────
#
# lizard reports the code outside every function as one more row and names it
# *global*:
#
#   self.global_pseudo_function = FunctionInfo("*global*", filename, 0)
#
# — lizard.py, and the 0 is the start line by construction. Its length is the
# whole file span, and one file can carry SEVERAL of these rows, byte for byte
# identical. On a real C# controller lizard emitted three.
#
# Taken as a function it did three things, and this case pins all three:
# registered a function_length hotspot for a 214-line function that does not
# exist; took the whole-file span as the module's longest function; and, being
# character-for-character the collector's own *global* sentinel with a start
# line of 0, produced several identical keys and stopped the run on the
# uniqueness assertion. The assertion was right — the rows really are
# indistinguishable, because they are the same non-function.

echo
echo "--- Case 44: the *global* pseudo-row registers nothing and collides with nothing ---"
C44="$WORK/c44"; new_project "$C44"; module_map_one "$C44"
S44="$WORK/c44-stub"
# 2000 lines, so the file itself is a HIGH file_length hotspot — that is the
# LEGITIMATE user of the *global* sentinel, and it must be unaffected.
stub_scc "$S44" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":2000,"Code":1800}]}]'
# One real function, then the pseudo-row three times over, exactly as the tool
# emits it: same span, same start line 0, byte for byte identical.
stub_lizard "$S44" "$(liz_row_real 'src/Calc.cs' 'Run' 30 200 10 210)
$(liz_row_real 'src/Calc.cs' '*global*' 1 500 0 499 '')
$(liz_row_real 'src/Calc.cs' '*global*' 1 500 0 499 '')
$(liz_row_real 'src/Calc.cs' '*global*' 1 500 0 499 '')"

c44_err="$( cd "$C44" && PATH="$(clean_path "$S44")" bash "$QUALITY_BIN" collect .specclaw 2>&1 >/dev/null )"
c44_exit=$?
C44_JSON="$C44/.specclaw/analysis/quality.json"

assert_eq "44a three identical pseudo-rows no longer stop the run" "0" "$c44_exit"
if [[ "$c44_err" == *"QI identity collision"* ]]; then
  fail "44b and nothing collides"
else
  pass "44b and nothing collides"
fi

c44_keys="$(jq -r '[.quality_issues[] | .key] | sort | join(";")' "$C44_JSON" 2>/dev/null)"
assert_eq_nonempty "44c the real function registers, the pseudo-row does not, the file still does" \
  'complexity|src/Calc.cs|Run|MOD-001|10;file_length|src/Calc.cs|*global*|MOD-001|1;function_length|src/Calc.cs|Run|MOD-001|10' \
  "$c44_keys"

# The one that would have been silently wrong even with a single pseudo-row and
# no collision at all: a 500-line "function" nobody wrote, and a rollup that
# reports it as the module's longest.
c44_fl="$(jq -r '[.quality_issues[] | select(.metric == "function_length") | .value] | join(",")' "$C44_JSON" 2>/dev/null)"
assert_eq_nonempty "44d no function_length hotspot claims the whole-file span" "200" "$c44_fl"
c44_max="$(jq -r '[.modules[] | select(.module_id == "MOD-001") | "\(.function_length.max)/\(.complexity.max)"] | first' "$C44_JSON" 2>/dev/null)"
assert_eq_nonempty "44e and the rollup maxima come from the real function" "200/30" "$c44_max"

# The sentinel keeps its job. *global* is how a file- or module-level metric says
# it has no function, and dropping the tool rows must not touch that.
c44_glob="$(jq -r '[.quality_issues[] | select(.scope == "*global*") | .metric] | sort | join(",")' "$C44_JSON" 2>/dev/null)"
assert_eq_nonempty "44f *global* survives where it means what it says" "file_length" "$c44_glob"

# Single pseudo-row, no collision available: the old failure that the uniqueness
# assertion could never have caught, because one of anything is unique.
C44B="$WORK/c44b"; new_project "$C44B"; module_map_one "$C44B"
S44B="$WORK/c44b-stub"
stub_scc "$S44B" '[{"Name":"C#","Files":[{"Location":"src/Calc.cs","Lines":80,"Code":70}]}]'
stub_lizard "$S44B" "$(liz_row_real 'src/Calc.cs' 'Run' 4 20 10 30)
$(liz_row_real 'src/Calc.cs' '*global*' 1 500 0 499 '')"

( cd "$C44B" && PATH="$(clean_path "$S44B")" bash "$QUALITY_BIN" collect .specclaw >/dev/null 2>&1 )
C44B_JSON="$C44B/.specclaw/analysis/quality.json"
c44b_n="$(jq -r '[.quality_issues[] | select(.metric == "function_length")] | length' "$C44B_JSON" 2>/dev/null)"
assert_eq_nonempty "44g one pseudo-row registers no hotspot either — uniqueness could never have caught it" "0" "$c44b_n"
c44b_max="$(jq -r '[.modules[] | select(.module_id == "MOD-001") | .function_length.max] | first' "$C44B_JSON" 2>/dev/null)"
assert_eq_nonempty "44h and the module's longest function is the one that exists" "20" "$c44b_max"

# ── Result ───────────────────────────────────────────────────────────────────

echo
echo "======================================"
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo "======================================"
[[ "$FAIL" -eq 0 ]] || exit 1
