#!/usr/bin/env bash
# run-description-lint-tests.sh — structural rules for every skill's `description:`.
#
# A skill's description is its ONLY routing surface. superpowers measured the
# failure a long one causes: an agent given a description that summarised the
# workflow followed the description and skipped the skill body — one review
# instead of the two the flowchart required. Every extra sentence is a chance
# for the model to stop reading there.
#
# Three rules, all cheap enough to run on every push:
#
#   LEN        ≤ 300 characters.
#   TRIGGER    says WHEN to use the skill, from a CLOSED set of clauses.
#   NARRATION  carries no workflow narration (`→`, ` then `, `Step `, `first … then`).
#
# THE TRIGGER SET IS CLOSED ON PURPOSE. Any list broad enough to admit
# "Show the project's dashboard" also admits "Manage …", "Create …",
# "Produce …", "Synthesize …" — which is every description in this repo, at
# which point the rule checks nothing. So it admits `Use when`, `Run after`,
# `Invoke when` and their siblings, and nothing else. The day-one offender list
# is therefore large; that is what the baseline is for, and the baseline only
# shrinks.
#
# Baseline discipline is copied from shellcheck-gate.sh verbatim: `<path> <RULE>`
# pairs, no line numbers (so unrelated edits do not churn it), and a fixed
# offence is REPORTED AS PRUNABLE rather than silently accepted.
#
# Usage:
#   bash plugins/specclaw/tests/run-description-lint-tests.sh [--skills-dir DIR] [--baseline FILE]
# Exit: 0 = no unbaselined offences, 1 = new offences.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

SKILLS_DIR="$PLUGIN_DIR/skills"
BASELINE="$SCRIPT_DIR/description-lint-baseline.txt"
MAX_LEN=300

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skills-dir) SKILLS_DIR="${2:-}"; shift 2 ;;
    --baseline)   BASELINE="${2:-}"; shift 2 ;;
    --max-len)    MAX_LEN="${2:-300}"; shift 2 ;;
    -h|--help)    sed -n '2,30p' "$0"; exit 0 ;;
    *)            echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

[ -d "$SKILLS_DIR" ] || { echo "no skills dir: $SKILLS_DIR" >&2; exit 2; }

# The closed set. A description passes TRIGGER when it matches any of these.
TRIGGER_RE='(^|[^a-zA-Z])([Uu]se (when|after|before)|[Rr]un (when|after|before)|[Ii]nvoke (immediately )?when|[Tr]rigger when|[Cc]all(ed)? when|[Ww]hen )'
# Workflow narration. `→` is the lifecycle arrow specifically: the sentence
# "propose → plan → build → verify" belongs in the router (change 033), once,
# not in thirty descriptions.
NARRATION_RE='(→|[[:space:]]then[[:space:]]|Step [0-9]|[Ff]irst,? .* then )'

current="$(mktemp)"
expected="$(mktemp)"
detail="$(mktemp)"
trap 'rm -f "$current" "$expected" "$detail"' EXIT

for skill in "$SKILLS_DIR"/*/SKILL.md; do
  [ -f "$skill" ] || continue
  name="$(basename "$(dirname "$skill")")"
  rel="skills/${name}/SKILL.md"

  # The description's FIRST line only. A folded/multi-line YAML description is
  # deliberately not reassembled: half a description is what the routing layer
  # would see anyway, and the rules should fire on it.
  # awk, not sed: BSD sed rejects the nested `{…;p;q;}` form this needs, and
  # rejects it per file, so the lint reported "no description" for all 35.
  desc="$(awk 'NR<=20 && /^description:[[:space:]]*/ {
      sub(/^description:[[:space:]]*/, ""); print; exit
    }' "$skill")"
  dmi=0
  grep -q '^disable-model-invocation:[[:space:]]*true' "$skill" && dmi=1

  # Strip surrounding quotes — several descriptions are quoted YAML scalars.
  desc="${desc#\"}"; desc="${desc%\"}"
  desc="${desc#\'}"; desc="${desc%\'}"

  if [ -z "$desc" ]; then
    printf '%s TRIGGER\n' "$rel" >> "$current"
    printf '%s TRIGGER: no description: line at all\n' "$rel" >> "$detail"
    continue
  fi

  len="$(printf '%s' "$desc" | wc -m | tr -d ' ')"
  if [ "$len" -gt "$MAX_LEN" ]; then
    printf '%s LEN\n' "$rel" >> "$current"
    printf '%s LEN: %s characters (max %s)\n' "$rel" "$len" "$MAX_LEN" >> "$detail"
  fi

  # A skill nothing can route to by description owes no trigger clause. It still
  # owes brevity and it still owes no narration — it is read by humans, and a
  # long one is paid for in the skill listing either way.
  if [ "$dmi" -eq 0 ] && ! printf '%s' "$desc" | grep -qE "$TRIGGER_RE"; then
    printf '%s TRIGGER\n' "$rel" >> "$current"
    printf '%s TRIGGER: no trigger clause (Use when / Run after / Invoke when / …when …)\n' "$rel" >> "$detail"
  fi

  if printf '%s' "$desc" | grep -qE "$NARRATION_RE"; then
    printf '%s NARRATION\n' "$rel" >> "$current"
    printf '%s NARRATION: workflow narration in the description — move it into the body\n' "$rel" >> "$detail"
  fi
done

LC_ALL=C sort -u -o "$current" "$current"

if [ -f "$BASELINE" ]; then
  grep -vE '^[[:space:]]*(#|$)' "$BASELINE" | LC_ALL=C sort -u > "$expected"
else
  : > "$expected"
fi

new_offences="$(LC_ALL=C comm -13 "$expected" "$current")"
fixed="$(LC_ALL=C comm -23 "$expected" "$current")"

if [ -n "$fixed" ]; then
  echo "These baseline entries no longer offend — prune them from ${BASELINE}:"
  printf '%s\n' "$fixed" | sed 's/^/  /'
  echo
fi

if [ -n "$new_offences" ]; then
  echo "::error::description lint found offences not present in the baseline:"
  printf '%s\n' "$new_offences" | while read -r line; do
    [ -n "$line" ] || continue
    grep -F "$line:" "$detail" | sed 's/^/  /' || printf '  %s\n' "$line"
  done
  echo
  echo "Fix the description, or — only for a skill that predates this rule — add the pair to"
  echo "${BASELINE}. A NEW skill gets no baseline entry: the rules bind from its first commit."
  exit 1
fi

echo "description lint: no new offences ($(grep -c '^' "$current" | tr -d ' ') baselined, $(ls -1 "$SKILLS_DIR" | wc -l | tr -d ' ') skills checked)"
exit 0
