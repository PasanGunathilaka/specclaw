#!/usr/bin/env bash
# run-trigger-tests.sh — does an utterance actually reach the right specclaw verb?
#
# specclaw's conversational routing has always been asserted and never tested.
# The README promises that "i have a proposal" fires /specclaw:propose; twenty
# suites cover the bash layer and none covered that sentence.
#
# THIS SUITE COSTS API CALLS. It is opt-in behind SPECCLAW_TRIGGER_EVALS=1 and
# runs nightly, never on every push — a suite that spends money by default is a
# suite somebody switches off, and a switched-off suite is worse than none
# because the badge still says it exists.
#
# It asserts on the `Skill` TOOL INVOCATION in the JSON, never on prose. A model
# that says "I'll use the propose skill" and invokes nothing is the exact failure
# being measured; a prose assertion would score it as a pass.
#
# Routing is stochastic, so each row runs SPECCLAW_TRIGGER_REPS times (default 5)
# and the measurement is a hit RATE. A single sample is an anecdote.
#
# Environment:
#   SPECCLAW_TRIGGER_EVALS=1     required — otherwise this skips and exits 0
#   SPECCLAW_TRIGGER_REPS=5      reps per row
#   SPECCLAW_TRIGGER_MODEL=sonnet  recorded in the matrix; a result without its
#                                  model is not a result
#   SPECCLAW_TRIGGER_ROW="<text>"  run one utterance only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"

FIXTURE="$SCRIPT_DIR/fixtures/triggers.tsv"
RESULTS_DIR="$SCRIPT_DIR/results"
REPS="${SPECCLAW_TRIGGER_REPS:-5}"
MODEL="${SPECCLAW_TRIGGER_MODEL:-sonnet}"
ONLY="${SPECCLAW_TRIGGER_ROW:-}"

if [ "${SPECCLAW_TRIGGER_EVALS:-}" != "1" ]; then
  cat >&2 <<'SKIP'
run-trigger-tests.sh: SKIPPED.

This suite drives a real model and costs API calls. Set SPECCLAW_TRIGGER_EVALS=1
to run it:

  SPECCLAW_TRIGGER_EVALS=1 bash plugins/specclaw/tests/run-trigger-tests.sh

It is wired into CI on a nightly schedule and on PRs touching skills/**/SKILL.md
or hooks/**, never on every push.
SKIP
  exit 0
fi

[ -f "$FIXTURE" ] || { echo "FATAL: fixture not found: $FIXTURE" >&2; exit 2; }

# A missing CLI is NOT a pass. The whole failure mode this suite guards against
# is a routing check that reports green while measuring nothing.
if ! command -v claude >/dev/null 2>&1; then
  echo "FATAL: the \`claude\` CLI is not on PATH — cannot measure routing." >&2
  echo "A missing tool is a failure here, not a skip: a green routing check that" >&2
  echo "measured nothing is exactly what this suite exists to prevent." >&2
  exit 2
fi

PLUGIN_VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$PLUGIN_DIR/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
PLUGIN_VERSION="${PLUGIN_VERSION:-unknown}"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# seed_state <dir> <state>
seed_state() {
  local root="$1" state="$2"
  mkdir -p "$root/.specclaw/changes"
  cp "$PLUGIN_DIR/templates/config.yaml" "$root/.specclaw/config.yaml"
  case "$state" in
    clean) ;;
    build-active)
      local d="$root/.specclaw/changes/042-a-live-change"
      mkdir -p "$d"
      printf '# Proposal\n' > "$d/proposal.md"
      printf '# Spec\n'     > "$d/spec.md"
      {
        printf '# Tasks\n\n'
        local i
        for i in 1 2 3; do printf -- '- [x] `T%s` — done\n' "$i"; done
        for i in 4 5 6 7 8; do printf -- '- [ ] `T%s` — pending\n' "$i"; done
      } > "$d/tasks.md"
      "$PLUGIN_DIR/bin/specclaw-set-phase" "$root/.specclaw" 042-a-live-change \
        build in-progress --tasks 3/8/0 >/dev/null 2>&1
      ;;
    verified)
      local d="$root/.specclaw/changes/043-a-verified-change"
      mkdir -p "$d"
      printf '# Proposal\n' > "$d/proposal.md"
      printf '# Spec\n'     > "$d/spec.md"
      printf '# Tasks\n\n- [x] `T1` — done\n' > "$d/tasks.md"
      printf '# Verify Report\n\n**Verdict:** PASS\n' > "$d/verify-report.md"
      "$PLUGIN_DIR/bin/specclaw-set-phase" "$root/.specclaw" 043-a-verified-change \
        verify passed --verdict PASS --tasks 1/1/0 >/dev/null 2>&1
      ;;
    *) echo "WARN: unknown state '$state' — treating as clean" >&2 ;;
  esac
}

# invoked_skill <json> → the skill name from the first Skill tool-use block, or ""
# The shape is pinned deliberately (FR6): if it changes, every row returns "" and
# the run fails loudly below rather than reporting a routing collapse.
invoked_skill() {
  printf '%s' "$1" | tr -d '\n' \
    | grep -oE '"name"[[:space:]]*:[[:space:]]*"Skill"[^}]*"skill"[[:space:]]*:[[:space:]]*"[^"]*"' \
    | head -1 | sed -E 's/.*"skill"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/' \
    | sed 's/^specclaw://'
}

mkdir -p "$RESULTS_DIR"
STAMP="$(date -u +%Y-%m-%d)"
OUT="$RESULTS_DIR/triggers-${STAMP}.md"

{
  printf '# Skill-trigger matrix — %s\n\n' "$STAMP"
  printf '**Model:** `%s`  ·  **Reps per row:** %s  ·  **Plugin:** %s\n\n' \
    "$MODEL" "$REPS" "$PLUGIN_VERSION"
  printf '| Utterance | State | Expected | Hit rate | Also saw |\n'
  printf '|---|---|---|---|---|\n'
} > "$OUT"

TOTAL_ROWS=0
PASSED_ROWS=0
ANY_TOOL_BLOCK=0

while IFS=$'\t' read -r utterance expect state note; do
  case "$utterance" in ''|\#*) continue ;; esac
  [ -n "${expect:-}" ] || continue
  if [ -n "$ONLY" ] && [ "$utterance" != "$ONLY" ]; then continue; fi

  TOTAL_ROWS=$((TOTAL_ROWS + 1))
  proj="$WORK/row-$TOTAL_ROWS"
  mkdir -p "$proj"
  seed_state "$proj" "${state:-clean}"

  hits=0
  others=""
  rep=1
  while [ "$rep" -le "$REPS" ]; do
    json="$( cd "$proj" && claude -p "$utterance" \
        --output-format json --max-turns 1 \
        --add-dir "$REPO_ROOT" 2>/dev/null || true )"
    got="$(invoked_skill "$json")"
    [ -n "$got" ] && ANY_TOOL_BLOCK=1
    if [ "$expect" = "none" ]; then
      [ -z "$got" ] && hits=$((hits + 1)) || others="${others} ${got}"
    else
      if [ "$got" = "$expect" ]; then
        hits=$((hits + 1))
      elif [ -n "$got" ]; then
        others="${others} ${got}"
      else
        others="${others} (none)"
      fi
    fi
    rep=$((rep + 1))
  done

  rate=$((hits * 100 / REPS))
  [ "$rate" -ge 60 ] && PASSED_ROWS=$((PASSED_ROWS + 1))
  others="$(printf '%s' "$others" | tr ' ' '\n' | grep -v '^$' | sort -u | tr '\n' ' ')"
  printf '| %s | %s | %s | %s%% (%s/%s) | %s |\n' \
    "$utterance" "${state:-clean}" "$expect" "$rate" "$hits" "$REPS" "${others:-—}" >> "$OUT"
  printf '%-52s %-14s %3s%% (%s/%s)\n' "$utterance" "$expect" "$rate" "$hits" "$REPS"
done < "$FIXTURE"

{
  printf '\n**Rows at or above 60%%:** %s / %s\n' "$PASSED_ROWS" "$TOTAL_ROWS"
} >> "$OUT"

echo
echo "─────────────────────────────"
echo "Rows at or above 60%: $PASSED_ROWS / $TOTAL_ROWS"
echo "Matrix: $OUT"

# FR6: if NOTHING in the whole run produced a recognisable Skill tool-use block,
# the far likelier explanation is that `claude -p`'s output shape changed than
# that routing collapsed to zero across every row. Say so, and fail.
if [ "$ANY_TOOL_BLOCK" -eq 0 ] && [ "$TOTAL_ROWS" -gt 0 ]; then
  echo >&2
  echo "FATAL: not one row produced a recognisable Skill tool-use block." >&2
  echo "That is far more likely to be a change in \`claude -p --output-format json\`" >&2
  echo "than a total routing collapse. Check the JSON shape in invoked_skill()" >&2
  echo "before reading this matrix as a routing regression." >&2
  exit 2
fi

[ "$PASSED_ROWS" -eq "$TOTAL_ROWS" ] || exit 1
exit 0
