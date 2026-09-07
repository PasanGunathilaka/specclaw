#!/usr/bin/env bash
# run-bf-context-tests.sh — regression suite for specclaw-bf-context, the
# generator that writes a project context router skill from artifacts a
# brownfield project has already produced.
#
# What this suite protects, and why each one is here:
#
#   - IT ROUTES, IT DOES NOT COPY. The generated file may name paths, modules
#     and the two status lines, and nothing else. A rule, a decision, or a
#     DR/BL/SCR/GM/QI id appearing in it would mean the generator had started
#     summarising its inputs — a second copy of them, stale the moment either
#     side changed. Asserted directly against the output.
#
#   - A HAND-WRITTEN SKILL IS NEVER OVERWRITTEN. Full regeneration is only safe
#     because nothing in the file is authored. That reasoning holds for a file
#     THIS command wrote, which the marker establishes, and for no other file.
#     Asserted by hash, so a refusal that still touched the file would fail.
#
#   - FRONTMATTER STAYS FIRST. Claude Code reads a skill's frontmatter only when
#     the opening `---` is the file's very first line. The generated-by marker
#     therefore sits after it, and a future edit that moved the marker up would
#     silently cost every generated skill its description and its name.
#
#   - ABSENCE IS STATED, NEVER FATAL. A project part-way through the pipeline is
#     the normal case, not an error case. The one refusal is the unmarked file.
#
#   - IT IS STACK-BLIND. No framework, language or vendor name in the generator.
#
# Bash + coreutils. jq is not used, and is not needed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CTX_BIN="$PLUGIN_ROOT/bin/specclaw-bf-context"

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

new_project() { # <root> [project_name]
  local root="$1" name="${2:-Fixture Project}"
  rm -rf "$root"; mkdir -p "$root/.specclaw/analysis" "$root/.specclaw/baseline"
  printf 'project:\n  name: "%s"\n  description: ""\n' "$name" > "$root/.specclaw/config.yaml"
}

# A confirmed map with a withdrawn tombstone and a deliberately non-contiguous
# id sequence — MOD ids are permanent, so a generated list must reproduce what
# the map says rather than tidying it into a range.
seed_map() { # <root> [status]
  cat > "$1/.specclaw/analysis/module-map.md" <<EOF
# Module Map

**Status:** ${2:-CONFIRMED by Hafsa, 2026-08-07}

### MOD-001 — Patient Registry
- **Business rules:** DR-007, DR-011
- **Backlog items:** BL-003

### MOD-002 — Appointments
- **Screens:** SCR-004

### MOD-004 — Billing

### MOD-003 — WITHDRAWN 2026-08-09, superseded by MOD-001
EOF
}

seed_blueprint() { # <root> <status>
  printf '# Target Architecture\n\n**Blueprint status:** %s\n' "$2" \
    > "$1/.specclaw/analysis/target-architecture.md"
}

# Documents whose CONTENT must never reach the generated file.
seed_loaded_docs() { # <root>
  printf '# Decisions\n\n### SQ-001 — Target platform\n**Decision:** rebuild on the newer runtime\n**Decided by:** Hafsa, 2026-08-05\n' \
    > "$1/.specclaw/analysis/decisions.md"
  printf '# Domain Model\n\n### DR-007 — Interest is rounded half-up at two places\n' \
    > "$1/.specclaw/analysis/domain-model.md"
  printf '# Functional Spec\n\n### SCR-004 — Appointment grid\n' \
    > "$1/.specclaw/analysis/functional-spec.md"
  printf '# Scenarios\n\n### GM-001 — Register a patient\n' \
    > "$1/.specclaw/baseline/scenarios.md"
}

out_of() { # <root> <slug>
  cat "$1/.claude/skills/$2-context/SKILL.md" 2>/dev/null
}
run_ctx() { bash "$CTX_BIN" "$1/.specclaw" 2>&1; }
hash_of() { sha256sum "$1" 2>/dev/null | cut -d' ' -f1; }

echo "=================================================="
echo "specclaw-bf-context regression suite"
echo "=================================================="

# ── 1. A full artifact set ───────────────────────────────────────────────────
echo
echo "-- a project with artifacts --"

R="$WORK/full"; new_project "$R" "Hospital Management System"
seed_map "$R"; seed_blueprint "$R" "PROVISIONAL(SQ-014)"; seed_loaded_docs "$R"
OUT="$(run_ctx "$R")"; RC=$?
assert_eq "0" "$RC" "a project with artifacts generates cleanly"

F="$R/.claude/skills/hospital-management-system-context/SKILL.md"
if [ -f "$F" ]; then ok "the file lands under .claude/skills/<project>-context/"
else bad "the file lands under .claude/skills/<project>-context/" "no file at $F"; fi

G="$(out_of "$R" hospital-management-system)"
assert_contains "$OUT" "modules: 4" "the run reports the module count"
assert_contains "$OUT" "git add" "and reminds the user to commit it"

# ── 2. Frontmatter first, marker second ──────────────────────────────────────
#
# Order matters more than presence here: a marker on line 1 would push the
# opening `---` down, and Claude Code would then treat the whole file as body —
# leaving a skill with no description and no name, which fails silently.
echo
echo "-- frontmatter first, marker second --"

assert_eq "---" "$(head -1 "$F")" "the file opens with the frontmatter fence, not the marker"
assert_contains "$(head -2 "$F" | tail -1)" "description:" "the description is inside the frontmatter"
assert_contains "$G" "generated by specclaw-bf-context" "the generated-by marker is present"
MARKER_LINE="$(grep -n 'generated by specclaw-bf-context' "$F" | head -1 | cut -d: -f1)"
CLOSE_LINE="$(grep -n '^---$' "$F" | sed -n 2p | cut -d: -f1)"
if [ -n "$MARKER_LINE" ] && [ -n "$CLOSE_LINE" ] && [ "$MARKER_LINE" -gt "$CLOSE_LINE" ]; then
  ok "and sits after the closing fence, never before the frontmatter"
else
  bad "and sits after the closing fence, never before the frontmatter" \
      "marker at line ${MARKER_LINE:-none}, closing fence at ${CLOSE_LINE:-none}"
fi

DESC="$(grep -m1 '^description:' "$F")"
assert_contains "$DESC" "Hospital Management System" "the description names the project"
assert_contains "$DESC" "4 modules" "and the module count"
assert_not_contains "$DESC" "MOD-001" "never an id, and never a range of them"
DESC_WORDS="$(printf '%s' "$DESC" | wc -w)"
if [ "$DESC_WORDS" -le 41 ]; then ok "the description stays short ($DESC_WORDS words)"
else bad "the description stays short" "got $DESC_WORDS words"; fi

# ── 3. THE INVARIANT: it routes, it does not copy ────────────────────────────
#
# Every id family below appears in the seeded input documents. None may reach
# the output: the generated file names WHERE an answer lives, never what it is.
echo
echo "-- pointers only, never content --"

assert_not_contains "$G" "DR-007" "no business-rule id reaches the output"
assert_not_contains "$G" "BL-003" "no backlog id either"
assert_not_contains "$G" "SCR-004" "nor a screen id"
assert_not_contains "$G" "GM-001" "nor a scenario id"
assert_not_contains "$G" "rounded half-up" "and no rule text is copied across"
assert_not_contains "$G" "Decision:" "and no decision is restated"
assert_contains "$G" '`.specclaw/analysis/decisions.md`' "the artifact is named instead"

# The module list is the one place ids are legitimate, and it is verbatim.
assert_contains "$G" "MOD-001 — Patient Registry" "modules are listed with their titles"
assert_contains "$G" "MOD-004 — Billing" "including a non-contiguous id"
assert_contains "$G" "MOD-003 — WITHDRAWN" "and a withdrawn module stays visible as a tombstone"

# The two status lines travel verbatim, because both are verdicts about how far
# the documents behind them can be trusted.
assert_contains "$G" "**Status:** CONFIRMED by Hafsa, 2026-08-07" "the map's own Status line is verbatim"
assert_contains "$G" "**Blueprint status:** PROVISIONAL(SQ-014)" "and the blueprint's own status line too"

# ── 4. Presence is reported per artifact ─────────────────────────────────────
echo
echo "-- artifact presence --"

assert_contains "$G" "| \`.specclaw/analysis/module-map.md\` | Which module owns" "each artifact row names the question it answers"
assert_contains "$OUT" "not present:" "the run names what is absent"
assert_contains "$OUT" "bootstrap/bootstrap-manifest.json" "including the foundation manifest"

# ── 5. Absence is stated, never fatal ────────────────────────────────────────
echo
echo "-- a fresh repo with nothing in it --"

R2="$WORK/fresh"; new_project "$R2" "hms-rebuild"
OUT2="$(run_ctx "$R2")"; RC2=$?
assert_eq "0" "$RC2" "a project with no artifacts at all still exits 0"
G2="$(out_of "$R2" hms-rebuild)"
assert_contains "$G2" "module-map.md not present" "the module section says the map is absent"
assert_contains "$G2" "/specclaw:bf-domain" "and names the command that writes one"
assert_contains "$OUT2" "modules: 0" "the run reports zero modules"
assert_contains "$G2" "not present |" "every artifact row reads not present"

# A map with no MOD heading is a third state, distinct from an absent map.
R3="$WORK/emptymap"; new_project "$R3" "empty-map"
printf '# Module Map\n\n**Status:** PROPOSED\n' > "$R3/.specclaw/analysis/module-map.md"
run_ctx "$R3" >/dev/null
assert_contains "$(out_of "$R3" empty-map)" "declares no MOD- heading yet" \
  "a present-but-empty map is reported as such, not as absent"

# ── 6. THE REFUSAL: a hand-written skill is never overwritten ────────────────
echo
echo "-- refuses to overwrite a hand-written skill --"

R4="$WORK/handwritten"; new_project "$R4" "mine"
mkdir -p "$R4/.claude/skills/mine-context"
HAND="$R4/.claude/skills/mine-context/SKILL.md"
printf -- '---\ndescription: my own router, written by hand\n---\n\nDo not touch this.\n' > "$HAND"
BEFORE="$(hash_of "$HAND")"
OUT4="$(run_ctx "$R4")"; RC4=$?
assert_eq "1" "$RC4" "an unmarked target file is a refusal"
assert_contains "$OUT4" "$HAND" "naming the exact path it refused"
assert_contains "$OUT4" "hand-written" "and saying why"
assert_eq "$BEFORE" "$(hash_of "$HAND")" "the file is left byte-identical"

# ── 7. A marked file is regenerated wholesale ────────────────────────────────
echo
echo "-- regeneration --"

R5="$WORK/regen"; new_project "$R5" "regen"
seed_map "$R5"
run_ctx "$R5" >/dev/null
F5="$R5/.claude/skills/regen-context/SKILL.md"
FIRST="$(hash_of "$F5")"
run_ctx "$R5" >/dev/null
assert_eq "$FIRST" "$(hash_of "$F5")" "a re-run on unchanged inputs is byte-identical"
assert_eq "1" "$(grep -c 'generated by specclaw-bf-context' "$F5")" \
  "and the marker is not duplicated"

# A changed input changes the output, and the file is replaced, not appended to.
seed_blueprint "$R5" "COMPLETE"
run_ctx "$R5" >/dev/null
assert_contains "$(out_of "$R5" regen)" "**Blueprint status:** COMPLETE" "a new input is picked up"
assert_eq "1" "$(grep -c '^# regen — project context$' "$F5")" "the file is replaced, never appended to"

# ── 8. Argument and configuration handling ───────────────────────────────────
echo
echo "-- argument handling --"

OUT="$(bash "$CTX_BIN" --help 2>&1)"; RC=$?
assert_eq "0" "$RC" "--help exits 0"
assert_contains "$OUT" "Usage: specclaw-bf-context" "and prints usage"

OUT="$(bash "$CTX_BIN" 2>&1)"; RC=$?
assert_eq "2" "$RC" "a missing argument exits 2"

OUT="$(bash "$CTX_BIN" "$WORK/does-not-exist" 2>&1)"; RC=$?
assert_eq "2" "$RC" "a missing .specclaw dir exits 2"
assert_contains "$OUT" "/specclaw:init" "pointing at the command that creates it"

# The project name is READ, never guessed. A basename fallback would produce two
# differently-named routers for two clones of one project.
R6="$WORK/noname"; new_project "$R6" ""
printf 'project:\n  name: ""\n' > "$R6/.specclaw/config.yaml"
OUT="$(run_ctx "$R6")"; RC=$?
assert_eq "2" "$RC" "an empty project.name is a stop, not a basename fallback"
assert_contains "$OUT" "project.name" "naming the field to set"

# ── 9. Stack-blind ───────────────────────────────────────────────────────────
#
# The generator ships no product name. The questions it routes to are identical
# for every project; everything project-specific is read at generation time.
echo
echo "-- no stack knowledge in the generator --"

HITS="$(grep -niE 'react|angular|vue|dotnet|\.net|delphi|pascal|node|java|postgres|sql server' "$CTX_BIN" || true)"
if [ -z "$HITS" ]; then ok "the generator names no framework, language or vendor"
else bad "the generator names no framework, language or vendor" "$HITS"; fi

# ── 10. It writes exactly one file, and only where it said ───────────────────
echo
echo "-- writes one file, touches nothing else --"

R7="$WORK/scope"; new_project "$R7" "scope"; seed_map "$R7"; seed_loaded_docs "$R7"
SPEC_BEFORE="$(find "$R7/.specclaw" -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)"
run_ctx "$R7" >/dev/null
SPEC_AFTER="$(find "$R7/.specclaw" -type f -exec sha256sum {} + | LC_ALL=C sort | sha256sum)"
assert_eq "$SPEC_BEFORE" "$SPEC_AFTER" "nothing under .specclaw/ is modified"
assert_eq "1" "$(find "$R7/.claude" -type f | wc -l | tr -d '[:space:]')" \
  "exactly one file is written under .claude/"

echo
echo "=================================================="
echo "Passed: $PASS   Failed: $FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
