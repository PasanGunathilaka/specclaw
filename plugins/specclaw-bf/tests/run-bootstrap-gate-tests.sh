#!/usr/bin/env bash
# run-bootstrap-gate-tests.sh — regression suite for the target-foundation
# stage (templates/CONTRACT.md (n)):
#
#   - the propose gate: inert on a non-rebuild project, not-ready without a
#     manifest, and NAMING the command that fixes it
#   - "consumes decided architecture, never decides it": a required SQ that is
#     undecided is a loud stop naming the exact id, never a default
#   - an Outstanding-Questions bullet is not a decision; a declared
#     "not applicable" IS one
#   - the foundation-only gate: a scaffold carrying a BL capability is refused
#   - record's refusals, and that a failing record destroys nothing
#   - re-run on an existing foundation behaves as decided (no-op / gap-fill /
#     adopt-candidate), and never scaffolds over somebody's application
#   - the gate fails CLOSED on a manifest it cannot vouch for
#
# The two tests that matter most are the propose gate naming its command and
# the capability refusal. Between them they are the BL-010 incident: a
# screen-bearing item became responsible for inventing the app skeleton because
# nothing checked the skeleton existed, and nothing could have told the
# difference between a foundation and a foundation that had quietly grown a
# feature.
#
# WHAT THIS SUITE CANNOT TEST, stated rather than implied: /specclaw:propose is
# a SKILL — prose an agent follows — so no bash suite can prove it actually
# stops. What is testable, and tested here, is the mechanical half it reads:
# foundation-check's verdict and the remedy string naming the command.
#
# Bash + coreutils + jq (the manifest and declaration are nested JSON).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BOOT_BIN="$PLUGIN_ROOT/bin/specclaw-bf-bootstrap"

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

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not installed — skipping bootstrap-gate suite (exit 0)."
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# ── Fixture: a rebuild target whose seven required decisions are all made ────
DECISIONS_ALL='### SQ-001 — Target platform

- **Decision:** Web application

### SQ-002 — Database engine and hosting

- **Decision:** PostgreSQL 16, cloud-hosted

### SQ-003 — Hosting/deployment model

- **Decision:** Cloud-hosted, single-tenant

### SQ-004 — Authentication/authorization approach

- **Decision:** Add real authentication, sized to the target platform

### SQ-006 — UI framework / component library

- **Decision:** React 18

### SQ-013 — UI fidelity policy

- **Decision:** THEME-ONLY

### SQ-014 — Target backend stack

- **Decision:** ASP.NET Core 8 Web API with EF Core 8'

new_target() {
  local root="$1"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis"
  cat > "$root/.specclaw/analysis/rebuild-backlog.md" <<'EOF'
# Rebuild Backlog: Dental

## Backlog

### BL-010 — View/Search the Patient Grid

**Module:** MOD-002
**Acceptance basis (domain-model.md):**
- DR-014: the grid lists active patients.
EOF
  { echo "# Decisions"; echo; echo "## Decisions"; echo; printf '%s\n' "$DECISIONS_ALL"; } \
    > "$root/.specclaw/analysis/decisions.md"
}

# A complete, honest declaration for the fixture above.
write_declaration() {
  local root="$1"
  mkdir -p "$root/.specclaw/bootstrap" "$root/web/src" "$root/api"
  printf 'export const App = () => null\n' > "$root/web/src/App.tsx"
  printf 'app.MapGet("/health", () => "ok");\n'  > "$root/api/Program.cs"
  cat > "$root/.specclaw/bootstrap/.bootstrap-declaration.json" <<'EOF'
{"declaration_schema":1,
 "stack":{"frontend":"React 18","backend":"ASP.NET Core 8","database":"PostgreSQL 16"},
 "decisions_consumed":[
   {"id":"SQ-001","decision":"Web application","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-002","decision":"PostgreSQL 16","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-003","decision":"Cloud, single-tenant","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-004","decision":"Add real authentication","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-006","decision":"React 18","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-013","decision":"THEME-ONLY","source":".specclaw/analysis/decisions.md"},
   {"id":"SQ-014","decision":"ASP.NET Core 8","source":".specclaw/analysis/decisions.md"}],
 "pillars":[{"id":"frontend-shell","status":"present","evidence":"web/src/App.tsx:1"},
            {"id":"backend-solution","status":"present","evidence":"api/Program.cs:1"},
            {"id":"health-check","status":"present","evidence":"api/Program.cs:1"},
            {"id":"cors","status":"absent-by-decision","reason":"SQ-003 same-origin single-tenant deployment"}],
 "files_created":[{"path":"web/src/App.tsx","purpose":"shell"},
                  {"path":"api/Program.cs","purpose":"health"}],
 "route_census":[{"route":"/health","kind":"health","file":"api/Program.cs:1"},
                 {"route":"/","kind":"shell","file":"web/src/App.tsx:1"}],
 "screen_census":[{"screen":"app shell","kind":"shell","file":"web/src/App.tsx:1"}],
 "ui_tokens_imported":[],
 "smoke_checks":[{"check":"api-build","command":"true"},
                 {"check":"frontend-build","command":"true"}]}
EOF
  printf '# Target Foundation Plan\n' > "$root/.specclaw/bootstrap/bootstrap-plan.md"
}

# The whole deterministic pipeline, for a project whose declaration is already
# written: gate -> smoke -> record.
run_bootstrap() {
  local root="$1"
  bash "$BOOT_BIN" gate   "$root/.specclaw" >/dev/null 2>&1
  bash "$BOOT_BIN" smoke  "$root/.specclaw" >/dev/null 2>&1
  bash "$BOOT_BIN" record "$root/.specclaw" >/dev/null 2>&1
}

# ─────────────────────────────────────────────────────────────────────────────
echo "== the propose gate =="

P="$WORK/inert"; rm -rf "$P"; mkdir -p "$P/.specclaw/analysis"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "false" "$(jq -r '.applicable' <<< "$OUT")" \
  "a project with no rebuild backlog is inert — greenfield never sees this gate"
assert_eq "null" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "and reports no readiness at all rather than a false one"

P="$WORK/t1"; new_target "$P"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "true"  "$(jq -r '.applicable' <<< "$OUT")" "a rebuild target IS applicable"
assert_eq "false" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "with no manifest the foundation is not ready"
# THE TEST THAT WOULD HAVE PREVENTED THE INCIDENT.
assert_contains "$(jq -r '.remedy' <<< "$OUT")" "/specclaw-bf:bf-bootstrap" \
  "and the gate NAMES the command that fixes it"

# ─────────────────────────────────────────────────────────────────────────────
echo "== collect: consumes decided architecture, never decides it =="

P="$WORK/t2"; new_target "$P"
rm -f "$P/.specclaw/analysis/decisions.md"
ERR="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "collect refuses to run with no decision record"
assert_contains "$ERR" "never decides architecture" "and says why"

# An UNDECIDED required id is a stop naming that exact id — never a default.
# SQ-014 is moved OUT of ## Decisions and listed as an open question instead,
# which is exactly the shape /specclaw-bf:bf-clarify --resolve produces for an
# unanswered one. A whole-file grep for the id would still find it here; the
# read is heading-anchored precisely so it does not.
P="$WORK/t3"; new_target "$P"
awk '/^### SQ-014/{exit} {print}' "$P/.specclaw/analysis/decisions.md" > "$P/d.md"
{ echo "## Outstanding Questions"
  echo
  echo "- **SQ-014** — Target backend stack (Type: DECISION, Family: Standard bank, Blocking: yes)"
} >> "$P/d.md"
mv "$P/d.md" "$P/.specclaw/analysis/decisions.md"
ERR="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "an undecided required decision stops the run"
assert_contains "$ERR" "SQ-014" "and the stop names the exact id"
assert_contains "$ERR" "never picks a stack" "and refuses to default it"
# The subtle one: an id listed under ## Outstanding Questions is NOT a decision.
# A whole-file grep for the id would have passed it, which is why the read is
# heading-anchored.
assert_not_contains "$ERR" "SQ-001" \
  "a decided id is not reported as missing"

# "Not applicable", declared in clarifications.md, IS an answer — a rebuild with
# no server side has no backend stack to choose.
cat > "$P/.specclaw/analysis/clarifications.md" <<'EOF'
# Clarifications

## Not Applicable

- **SQ-014** — no server-side component; this rebuild is a static client.
EOF
OUT="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>/dev/null)"; rc=$?
assert_eq "0" "$rc" "a declared not-applicable satisfies a required decision"
assert_eq "not applicable" \
  "$(jq -r '.decisions_required[] | select(.id=="SQ-014") | .decision' <<< "$OUT")" \
  "and is recorded as such, with its own source"

P="$WORK/t4"; new_target "$P"
OUT="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>/dev/null)"; rc=$?
assert_eq "0" "$rc" "collect succeeds when every required decision is made"
assert_eq "fresh" "$(jq -r '.mode' <<< "$OUT")" "an empty target repo is a fresh bootstrap"
assert_eq "7" "$(jq -r '[.decisions_required[] | select(.resolved)] | length' <<< "$OUT")" \
  "all seven required decisions resolve"
assert_eq "14" "$(jq -r '.vocabulary.pillar_ids | length' <<< "$OUT")" \
  "the closed pillar vocabulary is handed to the agent"

# ─────────────────────────────────────────────────────────────────────────────
echo "== the foundation-only gate =="

P="$WORK/g1"; new_target "$P"; write_declaration "$P"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "0" "$rc" "a genuine foundation passes the gate"
assert_contains "$OUT" "cannot prove the absence of capability logic" \
  "and the PASS states the limit rather than overclaiming"

# THE BOUNDARY. A file declared as a capability is the thing a BL item creates.
P="$WORK/g2"; new_target "$P"; write_declaration "$P"
jq '.files_created += [{"path":"api/Patients.cs","purpose":"capability"}]' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
printf 'public class PatientsController {}\n' > "$P/api/Patients.cs"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "1" "$rc" "a scaffold carrying a BL capability fails the gate"
assert_contains "$OUT" "api/Patients.cs" "and the failure names the file"
assert_contains "$OUT" "belongs to its BL item" "and says where it belongs instead"

P="$WORK/g3"; new_target "$P"; write_declaration "$P"
jq '.route_census += [{"route":"/patients","kind":"query","file":"api/P.cs:1"}]' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "1" "$rc" "a capability endpoint beyond the health check fails the gate"
assert_contains "$OUT" "/patients" "and names the route"

P="$WORK/g4"; new_target "$P"; write_declaration "$P"
printf 'app.MapGet("/health", () => "ok"); // implements DR-014\n' > "$P/api/Program.cs"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "1" "$rc" "a scaffolded file citing a DR-### rule fails the gate"
assert_contains "$OUT" "DR-014" "and names the id it found"

P="$WORK/g5"; new_target "$P"; write_declaration "$P"
printf ':root { --c: #0a6 } /* TK-007 */\n' > "$P/web/src/theme.css"
jq '.files_created += [{"path":"web/src/theme.css","purpose":"theme"}]' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "1" "$rc" "a token group the declaration never claimed fails the gate"
assert_contains "$OUT" "TK-007" "and names the group"

P="$WORK/g6"; new_target "$P"; write_declaration "$P"
jq '.pillars[3] |= del(.reason)' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
OUT="$(bash "$BOOT_BIN" gate "$P/.specclaw" 2>&1)"; rc=$?
assert_eq "1" "$rc" "an absent pillar with no stated reason fails the gate"
assert_contains "$OUT" "never a silent skip" "because a silent skip is how half a foundation reads as a whole one"

# ─────────────────────────────────────────────────────────────────────────────
echo "== smoke and record =="

P="$WORK/r1"; new_target "$P"; write_declaration "$P"
bash "$BOOT_BIN" gate "$P/.specclaw" >/dev/null 2>&1
ERR="$(bash "$BOOT_BIN" record "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "record refuses before smoke has run"
assert_contains "$ERR" "smoke-results.json" "and names what is missing"
assert_eq "no" "$([ -f "$P/.specclaw/bootstrap/bootstrap-manifest.json" ] && echo yes || echo no)" \
  "and writes no manifest at all"

P="$WORK/r2"; new_target "$P"; write_declaration "$P"
jq '.smoke_checks[0].command = "exit 3"' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
bash "$BOOT_BIN" gate "$P/.specclaw" >/dev/null 2>&1
bash "$BOOT_BIN" smoke "$P/.specclaw" >/dev/null 2>&1; src=$?
assert_eq "1" "$src" "smoke exits non-zero when a check fails"
ERR="$(bash "$BOOT_BIN" record "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "a failed required smoke check blocks the record"
assert_contains "$ERR" "api-build" "and names the check"

P="$WORK/r3"; new_target "$P"; write_declaration "$P"
jq 'del(.decisions_consumed[6])' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
bash "$BOOT_BIN" gate  "$P/.specclaw" >/dev/null 2>&1
bash "$BOOT_BIN" smoke "$P/.specclaw" >/dev/null 2>&1
ERR="$(bash "$BOOT_BIN" record "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "record refuses a declaration that skipped a required decision"
assert_contains "$ERR" "SQ-014" "and names the one it cannot show a source for"

P="$WORK/r4"; new_target "$P"; write_declaration "$P"
jq '.decisions_consumed[0].source = "docs/adr/does-not-exist.md"' \
  "$P/.specclaw/bootstrap/.bootstrap-declaration.json" > "$P/d" \
  && mv "$P/d" "$P/.specclaw/bootstrap/.bootstrap-declaration.json"
bash "$BOOT_BIN" gate  "$P/.specclaw" >/dev/null 2>&1
bash "$BOOT_BIN" smoke "$P/.specclaw" >/dev/null 2>&1
ERR="$(bash "$BOOT_BIN" record "$P/.specclaw" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "a cited decision source that does not exist is refused"

P="$WORK/r5"; new_target "$P"; write_declaration "$P"; run_bootstrap "$P"
MF="$P/.specclaw/bootstrap/bootstrap-manifest.json"
assert_eq "yes" "$([ -f "$MF" ] && echo yes || echo no)" "a clean run records a manifest"
assert_eq "true" "$(jq -r '.foundation_ready' "$MF")" "foundation_ready is computed true"
assert_eq "PASS" "$(jq -r '.gate.result' "$MF")" "the gate result travels into the manifest"
assert_eq "7" "$(jq -r '.decisions_consumed | length' "$MF")" \
  "every consumed decision is recorded with its source"
assert_eq "no" "$([ -f "$P/.specclaw/bootstrap/.bootstrap-declaration.json" ] && echo yes || echo no)" \
  "the transient declaration is consumed and deleted"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "true" "$(jq -r '.foundation_ready' <<< "$OUT")" "the propose gate now passes"
assert_eq "cors" "$(jq -r '.pillars_absent_by_decision | join(",")' <<< "$OUT")" \
  "and reports which pillars are absent BY DECISION rather than missing"

# ─────────────────────────────────────────────────────────────────────────────
echo "== re-running on an existing foundation =="

OUT="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>/dev/null)"
assert_eq "recorded-ready" "$(jq -r '.mode' <<< "$OUT")" \
  "re-running on a healthy foundation is a no-op, not a rebuild"

# A manifest that exists but is not ready gap-fills — and only the broken half.
jq '.foundation_ready = false' "$MF" > "$P/m" && mv "$P/m" "$MF"
OUT="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>/dev/null)"
assert_eq "gap-fill" "$(jq -r '.mode' <<< "$OUT")" "an unready manifest gap-fills"
assert_eq "true" "$(jq -r '.prior_manifest != null' <<< "$OUT")" \
  "and the agent is handed the prior manifest so it never re-creates a present pillar"

# NEVER scaffold over an application somebody already wrote.
P="$WORK/adopt"; new_target "$P"
mkdir -p "$P/src"; printf 'console.log(1)\n' > "$P/src/index.js"
OUT="$(bash "$BOOT_BIN" collect "$P/.specclaw" 2>/dev/null)"
assert_eq "adopt-candidate" "$(jq -r '.mode' <<< "$OUT")" \
  "existing source with no manifest is an adopt candidate, never a fresh scaffold"

# ─────────────────────────────────────────────────────────────────────────────
echo "== not-applicable: a declaration, never an inference =="

P="$WORK/na"; new_target "$P"
ERR="$(bash "$BOOT_BIN" not-applicable "$P/.specclaw" --reason "legacy repo" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "a not-applicable declaration with no named human is refused"
assert_contains "$ERR" "attributable" "because a declaration that switches off a gate must be"

bash "$BOOT_BIN" not-applicable "$P/.specclaw" --reason "this is the legacy repo" \
  --declared-by "Tester, 2026-08-14" >/dev/null 2>&1
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "true" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "a declared non-target passes the gate"
assert_eq "Tester, 2026-08-14" "$(jq -r '.not_applicable.declared_by' <<< "$OUT")" \
  "and the gate reports who declared it"

P="$WORK/r6"; new_target "$P"; write_declaration "$P"; run_bootstrap "$P"
ERR="$(bash "$BOOT_BIN" not-applicable "$P/.specclaw" --reason x --declared-by "T, 2026-08-14" 2>&1 >/dev/null)"; rc=$?
assert_eq "1" "$rc" "not-applicable refuses to overwrite a real recorded foundation"

# ─────────────────────────────────────────────────────────────────────────────
echo "== the gate fails CLOSED =="

P="$WORK/c1"; new_target "$P"; write_declaration "$P"; run_bootstrap "$P"
printf 'not json at all\n' > "$P/.specclaw/bootstrap/bootstrap-manifest.json"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "false" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "a manifest that cannot be parsed is not a foundation we can vouch for"

P="$WORK/c2"; new_target "$P"; write_declaration "$P"; run_bootstrap "$P"
jq '.bootstrap_schema = 99' "$P/.specclaw/bootstrap/bootstrap-manifest.json" > "$P/m" \
  && mv "$P/m" "$P/.specclaw/bootstrap/bootstrap-manifest.json"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "false" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "an unknown manifest schema is refused rather than read under assumed defaults"

# record never writes ready-with-a-failed-check, so this combination can only
# come from a hand edit — and the gate says exactly that instead of passing.
P="$WORK/c3"; new_target "$P"; write_declaration "$P"; run_bootstrap "$P"
jq '.smoke[0].result = "FAILED"' "$P/.specclaw/bootstrap/bootstrap-manifest.json" > "$P/m" \
  && mv "$P/m" "$P/.specclaw/bootstrap/bootstrap-manifest.json"
OUT="$(bash "$BOOT_BIN" foundation-check "$P/.specclaw" 2>/dev/null)"
assert_eq "false" "$(jq -r '.foundation_ready' <<< "$OUT")" \
  "a manifest claiming ready while recording a failed check is refused"
assert_contains "$(jq -r '.reason' <<< "$OUT")" "edited by hand" "and says why it is impossible"

echo
echo "=================================================="
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
