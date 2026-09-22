#!/usr/bin/env bash
# run-codex-plugin-tests.sh — verify the native Codex marketplace package.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
MARKETPLACE_FILE="$REPO_ROOT/.agents/plugins/marketplace.json"
CODEX_MANIFEST="$PLUGIN_DIR/.codex-plugin/plugin.json"
CLAUDE_MANIFEST="$PLUGIN_DIR/.claude-plugin/plugin.json"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/ci.yml"

failed=0

pass() { printf 'PASS: %s\n' "$1"; }
fail() { printf 'FAIL: %s\n' "$1" >&2; failed=1; }

[ -f "$MARKETPLACE_FILE" ] \
  && pass "Codex marketplace manifest exists" \
  || fail "Codex marketplace manifest exists at .agents/plugins/marketplace.json"

[ -f "$CODEX_MANIFEST" ] \
  && pass "native Codex plugin manifest exists" \
  || fail "native Codex plugin manifest exists at plugins/specclaw/.codex-plugin/plugin.json"

if [ -f "$MARKETPLACE_FILE" ] && [ -f "$CODEX_MANIFEST" ]; then
  python3 - "$MARKETPLACE_FILE" "$CODEX_MANIFEST" "$CLAUDE_MANIFEST" "$PLUGIN_DIR" <<'PY' \
    && pass "marketplace and plugin manifests satisfy the package contract" \
    || fail "marketplace and plugin manifests satisfy the package contract"
import json
import os
import sys

marketplace_path, codex_path, claude_path, plugin_dir = sys.argv[1:]
with open(marketplace_path, encoding="utf-8") as handle:
    marketplace = json.load(handle)
with open(codex_path, encoding="utf-8") as handle:
    codex = json.load(handle)
with open(claude_path, encoding="utf-8") as handle:
    claude = json.load(handle)

assert marketplace["name"] == "chan4lk"
entry = next(plugin for plugin in marketplace["plugins"] if plugin["name"] == "specclaw")
assert entry["source"] == {"source": "local", "path": "./plugins/specclaw"}
assert os.path.realpath(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(marketplace_path))), entry["source"]["path"])) == os.path.realpath(plugin_dir)
assert codex["skills"] == "./skills/"
for field in ("name", "version", "description", "author", "homepage", "repository", "license", "keywords"):
    assert codex[field] == claude[field], field
PY
fi

if [ -f "$CODEX_MANIFEST" ]; then
  for skill_dir in "$PLUGIN_DIR"/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name="$(basename "$skill_dir")"
    [ -f "$skill_dir/SKILL.md" ] \
      && pass "canonical skill is packaged: $skill_name" \
      || fail "canonical skill is packaged: $skill_name"
  done
fi

[ -f "$WORKFLOW_FILE" ] || fail "CI workflow exists"
if [ -f "$WORKFLOW_FILE" ]; then
  grep -Fq 'run: bash plugins/specclaw/tests/run-codex-plugin-tests.sh' "$WORKFLOW_FILE" \
    && pass "CI runs the Codex package contract" \
    || fail "CI runs the Codex package contract"

  grep -Fq "plugins/specclaw/.codex-plugin/plugin.json" "$WORKFLOW_FILE" \
    && pass "CI parses the native Codex manifest" \
    || fail "CI parses the native Codex manifest"
fi

[ "$failed" -eq 0 ] || exit 1
printf 'All Codex plugin package checks passed.\n'
