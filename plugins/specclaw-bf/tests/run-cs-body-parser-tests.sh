#!/usr/bin/env bash
# run-cs-body-parser-tests.sh — regression suite for specclaw-bf-domain-collect's
# validation-routine body parsing, per language.
#
# The defect this locks down: gather_validation_candidates() matched BOTH .pas
# and .cs method signatures, but parsed every matched body with one Pascal
# grammar — a forward search for `begin`, depth-counted to `end;`. A C# method
# body (`{ ... }`) never satisfies that search, so `found_begin` stayed false
# and the method was SILENTLY SKIPPED. A C# project full of validation methods
# could therefore produce an empty validation_routine_candidates[].
#
# Cases:
#   1  C# simple braced body             → captured, includes the return stmt
#   2  C# nested {} (if inside foreach)   → ends at the METHOD's closing brace
#   3  C# consecutive methods             → first body does not swallow the second
#   4  C# brace on the signature line     → captured
#   5  C# expression-bodied (`=> x;`)     → captured through the `;`
#   6  Pascal regression                  → byte-identical to the PRE-FIX parser
#                                           (golden fixture captured before the
#                                           fix landed; see REGEN_GOLDEN below)
#   7  Mixed repo (.pas + .cs together)   → both appear in the same output
#
# Plain bash only — no bats/npm. Run from anywhere:
#   bash plugins/specclaw/tests/run-cs-body-parser-tests.sh
# Exits non-zero if any case fails.
#
# REGEN_GOLDEN=1 rewrites the Case 6 golden from whatever binary is currently
# on disk. It exists so the golden could be captured from the pre-fix parser;
# do NOT run it to "fix" a failing Case 6 — a Case 6 failure means the Pascal
# branch changed behavior, which is the exact thing this case forbids.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$(cd "$SCRIPT_DIR/../bin" && pwd)"
FIXTURES_DIR="$SCRIPT_DIR/fixtures/domain-cs"
DOMAIN_BIN="$BIN_DIR/specclaw-bf-domain-collect"
GOLDEN="$FIXTURES_DIR/pascal-validation-golden.json"

# jq on Windows emits CRLF, and .gitattributes normalizes committed files to
# LF — so the golden's line endings depend on where it was written. Every
# golden comparison strips CR from both sides so Case 6 compares parser
# output, not platform line endings.
CR=$'\r'

if [[ ! -f "$DOMAIN_BIN" ]]; then
  echo "FATAL: missing bin script: $DOMAIN_BIN" >&2
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── Fixture writers ─────────────────────────────────────────────────────────
# Tiny synthetic sources, written by the tests themselves — no committed
# source fixtures to drift out of sync with the assertions.

# write_cs_fixtures <dir>
write_cs_fixtures() {
  local d="$1"
  mkdir -p "$d"

  # Case 1 — the minimal braced body that the pre-fix parser dropped entirely.
  cat > "$d/Simple.cs" <<'CSEOF'
namespace Demo
{
    public class PriceService
    {
        public bool ValidatePrice(decimal price)
        {
            return price > 0;
        }
    }
}
CSEOF

  # Case 2 — nested blocks: an `if` inside a `foreach`. The captured body must
  # run to the METHOD's closing brace, not stop at the first inner `}`.
  cat > "$d/Nested.cs" <<'CSEOF'
namespace Demo
{
    public class OrderService
    {
        public bool ValidateAllLines(List<int> quantities)
        {
            foreach (var q in quantities)
            {
                if (q < 0)
                {
                    return false;
                }
            }
            return true;
        }
    }
}
CSEOF

  # Case 3 — two Valid* methods back to back.
  cat > "$d/Consecutive.cs" <<'CSEOF'
namespace Demo
{
    public class StockService
    {
        public bool ValidateFirstItem(int qty)
        {
            return qty >= 1;
        }

        public bool ValidateSecondItem(int qty)
        {
            return qty <= 999;
        }
    }
}
CSEOF

  # Case 4 — opening brace on the signature line.
  cat > "$d/BraceOnSig.cs" <<'CSEOF'
namespace Demo
{
    public class ShippingService
    {
        public bool CanShip(Order o) {
            return o.Weight < 30;
        }
    }
}
CSEOF

  # Case 5 — expression-bodied member.
  cat > "$d/ExprBodied.cs" <<'CSEOF'
namespace Demo
{
    public class TaxService
    {
        public bool CheckRate(decimal rate) => rate >= 0 && rate <= 1;
    }
}
CSEOF
}

# write_pas_fixture <dir> — existing-style Pascal, one nested begin/end; pair.
write_pas_fixture() {
  local d="$1"
  mkdir -p "$d"
  cat > "$d/Rules.pas" <<'PASEOF'
unit Rules;

interface

function ValidateReading(Value: Integer): Boolean;
function CanUndo: Boolean;

implementation

function ValidateReading(Value: Integer): Boolean;
begin
  Result := True;
  if Value < 0 then
  begin
    Result := False;
    Exit;
  end;
  if Value > 100 then
    Result := False;
end;

function CanUndo: Boolean;
begin
  Result := False;
end;

function ComputeAverage(A, B: Integer): Integer;
begin
  Result := (A + B) div 2;
end;

end.
PASEOF
}

# make_project <name> — build a .specclaw project skeleton, echo its dir.
make_project() {
  local name="$1"
  local root="$WORK/$name"
  mkdir -p "$root/.specclaw"
  printf 'context:\n  discovery: true\n' > "$root/.specclaw/config.yaml"
  echo "$root"
}

# candidates <project_root> — collect and emit validation_routine_candidates.
candidates() {
  local root="$1"
  bash "$DOMAIN_BIN" collect "$root/.specclaw" 2>/dev/null \
    | jq -c '.validation_routine_candidates'
}

# body_of <candidates_json> <name> — the captured body for one candidate.
body_of() {
  jq -r --arg n "$2" 'map(select(.name == $n)) | .[0].body // ""' <<<"$1"
}

echo "=== specclaw C#/Pascal validation-body parser suite ==="
echo "bin: $BIN_DIR"
echo

# ─────────────────────────────────────────────────────────────────────────────
# Golden regeneration (Case 6 support). Captured from the pre-fix parser.
# ─────────────────────────────────────────────────────────────────────────────
if [[ "${REGEN_GOLDEN:-0}" == "1" ]]; then
  gp="$(make_project regen)"
  write_pas_fixture "$gp/src"
  mkdir -p "$FIXTURES_DIR"
  candidates "$gp" | tr -d "$CR" > "$GOLDEN"
  echo "Wrote golden: $GOLDEN"
  cat "$GOLDEN"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# Cases 1-5 — C# bodies, one project holding every C# fixture.
# ─────────────────────────────────────────────────────────────────────────────
csproj="$(make_project cs-only)"
write_cs_fixtures "$csproj/src"
cs="$(candidates "$csproj")"

echo "--- Case 1: C# simple braced body is captured (the core defect) ---"
if [[ "$(jq -r 'length' <<<"$cs")" == "0" ]]; then
  fail "1a C# methods produce candidates at all (got an empty array — the defect)"
else
  pass "1a C# methods produce candidates at all"
fi
b1="$(body_of "$cs" ValidatePrice)"
if grep -qF 'return price > 0;' <<<"$b1"; then
  pass "1b ValidatePrice body includes its return statement"
else
  fail "1b ValidatePrice body includes its return statement (got: $b1)"
fi

echo "--- Case 2: C# nested {} ends at the method's closing brace ---"
b2="$(body_of "$cs" ValidateAllLines)"
if grep -qF 'return false;' <<<"$b2" && grep -qF 'return true;' <<<"$b2"; then
  pass "2a ValidateAllLines body spans both nested blocks (no early stop at the inner })"
else
  fail "2a ValidateAllLines body spans both nested blocks (got: $b2)"
fi
# The method's own closing brace terminates capture: nothing past it (the class
# and namespace closers) may appear. The exact invariant is closes == opens + 1
# — the body excludes the method's opening `{` (it contributes nothing when the
# brace sits on its own line) but includes the method's closing `}`, mirroring
# the Pascal path, which excludes `begin` and includes `end;`. Capture running
# on into the class/namespace closers would push the surplus above 1.
opens="$(tr -cd '{' <<<"$b2" | wc -c | tr -d ' ')"
closes="$(tr -cd '}' <<<"$b2" | wc -c | tr -d ' ')"
if [[ "$opens" -gt 0 && "$closes" -eq $((opens + 1)) ]]; then
  pass "2b ValidateAllLines body closes exactly one brace more than it opens ($opens open / $closes close) — capture stopped at the method brace"
else
  fail "2b ValidateAllLines body closes exactly one brace more than it opens (got $opens open / $closes close: $b2)"
fi

echo "--- Case 3: consecutive C# methods do not swallow each other ---"
b3="$(body_of "$cs" ValidateFirstItem)"
b3b="$(body_of "$cs" ValidateSecondItem)"
if grep -qF 'return qty >= 1;' <<<"$b3" && ! grep -q 'ValidateSecondItem' <<<"$b3" \
   && ! grep -qF 'return qty <= 999;' <<<"$b3"; then
  pass "3a ValidateFirstItem body stops before ValidateSecondItem's signature and body"
else
  fail "3a ValidateFirstItem body stops before ValidateSecondItem (got: $b3)"
fi
if grep -qF 'return qty <= 999;' <<<"$b3b"; then
  pass "3b ValidateSecondItem captured as its own separate candidate"
else
  fail "3b ValidateSecondItem captured as its own separate candidate (got: $b3b)"
fi

echo "--- Case 4: brace on the signature line ---"
b4="$(body_of "$cs" CanShip)"
if grep -qF 'return o.Weight < 30;' <<<"$b4"; then
  pass "4a CanShip (brace on signature line) body captured"
else
  fail "4a CanShip (brace on signature line) body captured (got: $b4)"
fi
if grep -q 'public bool CanShip' <<<"$b4"; then
  fail "4b CanShip body excludes its own signature text (found the signature in the body)"
else
  pass "4b CanShip body excludes its own signature text"
fi

echo "--- Case 5: expression-bodied member ---"
b5="$(body_of "$cs" CheckRate)"
if grep -qF 'rate >= 0 && rate <= 1;' <<<"$b5"; then
  pass "5a CheckRate expression body captured through the terminating ;"
else
  fail "5a CheckRate expression body captured through the terminating ; (got: $b5)"
fi

echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 6 — Pascal regression. Byte-identical to the pre-fix parser's output.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 6: Pascal branch untouched (byte-identical to pre-fix golden) ---"
pasproj="$(make_project pas-only)"
write_pas_fixture "$pasproj/src"
pas="$(candidates "$pasproj")"
if [[ ! -f "$GOLDEN" ]]; then
  fail "6a pre-fix Pascal golden fixture exists at $GOLDEN"
else
  if diff -u <(tr -d "$CR" < "$GOLDEN") <(printf '%s\n' "$pas" | tr -d "$CR") >/dev/null 2>&1; then
    pass "6a Pascal validation_routine_candidates byte-identical to the pre-fix parser's output"
  else
    fail "6a Pascal validation_routine_candidates byte-identical to the pre-fix parser's output"
    diff -u <(tr -d "$CR" < "$GOLDEN") <(printf '%s\n' "$pas" | tr -d "$CR") || true
  fi
fi
# Independent of the golden: the nested begin/end; pair must not terminate the
# body early, and the body must not bleed into ComputeAverage.
pb="$(body_of "$pas" ValidateReading)"
if grep -qF 'if Value > 100 then' <<<"$pb" && ! grep -q 'ComputeAverage' <<<"$pb"; then
  pass "6b ValidateReading spans its nested begin/end; and stops before ComputeAverage"
else
  fail "6b ValidateReading spans its nested begin/end; and stops before ComputeAverage (got: $pb)"
fi

echo

# ─────────────────────────────────────────────────────────────────────────────
# Case 7 — mixed repo: one .pas and one .cs in the same run.
# ─────────────────────────────────────────────────────────────────────────────
echo "--- Case 7: mixed .pas + .cs repo — both languages in one output ---"
mixproj="$(make_project mixed)"
write_pas_fixture "$mixproj/src"
cat > "$mixproj/src/Mixed.cs" <<'CSEOF'
namespace Demo
{
    public class RoomService
    {
        public bool ValidateRoomNumber(int n)
        {
            return n > 0 && n < 500;
        }
    }
}
CSEOF
mix="$(candidates "$mixproj")"
mix_names="$(jq -r '[.[].name] | sort | join(",")' <<<"$mix")"
if grep -q 'ValidateReading' <<<"$mix_names" && grep -q 'ValidateRoomNumber' <<<"$mix_names"; then
  pass "7a both the Pascal (ValidateReading) and C# (ValidateRoomNumber) candidates present (names: $mix_names)"
else
  fail "7a both Pascal and C# candidates present (names: $mix_names)"
fi
mix_files="$(jq -r '[.[].file] | unique | sort | join(",")' <<<"$mix")"
if grep -q 'Rules.pas' <<<"$mix_files" && grep -q 'Mixed.cs' <<<"$mix_files"; then
  pass "7b candidates attributed to both source files (files: $mix_files)"
else
  fail "7b candidates attributed to both source files (files: $mix_files)"
fi

echo
echo "=== summary: $PASS passed, $FAIL failed ==="
[[ "$FAIL" -eq 0 ]] || exit 1
