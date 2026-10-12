# shellcheck shell=bash
# lib/pr-git.sh — git steps shared by specclaw-pr and specclaw-azdo-pr (change 043).
#
# Both PR scripts used to carry their own copy of the test-policy prompt, the
# change-folder staging and the push, and so carried the same three bugs. These
# helpers are the one copy. Sourced, never executed: no top-level side effects.
# Callers define die() and warn().

# pr_require_change_branch <expected_branch> <base_branch>
# Refuse to stage, push or open a PR from the base branch or a detached HEAD.
pr_require_change_branch() {
  local expected="$1" base="$2" current
  current="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
  if [[ -z "$current" ]]; then
    die "HEAD is detached — check out the change branch '$expected' and re-run."
  fi
  if [[ "$current" == "$base" ]]; then
    die "on the base branch '$base', not the change branch '$expected'. It may have been merged by finalize (git.merge_on_finalize: true). Check out '$expected' and re-run."
  fi
}

# pr_require_tty_or_die
# The test-policy prompt reads /dev/tty, so test that (not stdin). With no
# terminal the prompt can never be answered: exit 2 rather than loop.
pr_require_tty_or_die() {
  if ! { : </dev/tty; } 2>/dev/null; then
    echo "ERROR: pr.test_policy is not set and there is no terminal to ask on." >&2
    echo "  Set it in .specclaw/config.yaml, then re-run:" >&2
    echo "    pr:" >&2
    echo "      test_policy: \"none\"   # none | unit | e2e | both" >&2
    exit 2
  fi
}

# pr_stage_change_trail <change_path> <commit_message>
# Commit the change folder's planning trail, leaving out the dispatch lock that
# the running pr dispatch itself holds. The same pathspec feeds the
# "still uncommitted" check, so an un-ignored lock never fails it either.
pr_stage_change_trail() {
  local change_path="$1" msg="$2"
  [[ -d "$change_path" ]] || return 0
  local -a spec=(-- "$change_path" ":(exclude)${change_path}/.lock")
  if [[ -n "$(git status --porcelain "${spec[@]}" 2>/dev/null)" ]]; then
    echo "Staging ${change_path}/ artifacts for the PR…"
    git add "${spec[@]}" 2>/dev/null || true
    if ! git diff --cached --quiet "${spec[@]}" 2>/dev/null; then
      git commit -m "$msg" --only "${spec[@]}" >/dev/null 2>&1 || true
    fi
  fi
  if [[ -n "$(git status --porcelain "${spec[@]}" 2>/dev/null)" ]]; then
    die "planning artifacts under $change_path are not committed — refusing to open a PR without the proposal trail. Commit them (git add '$change_path' && git commit) and re-run."
  fi
}

# pr_publish_branch
# Push before the PR is created. A branch whose upstream is its own name on a
# remote gets a plain push. Anything else is published as itself with -u:
# specclaw-build cuts the branch from origin/<base>, so its upstream starts as
# the BASE branch, and a plain push there is refused (push.default=simple) or,
# worse, lands on the base. The remote is the upstream's, else origin, else
# the only remote. Never guess between several.
pr_publish_branch() {
  local branch remotes remote up_remote up_merge
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || echo HEAD)"
  up_remote="$(git config "branch.${branch}.remote" 2>/dev/null || true)"
  up_merge="$(git config "branch.${branch}.merge" 2>/dev/null || true)"
  if [[ -n "$up_remote" && "$up_remote" != "." && "$up_merge" == "refs/heads/${branch}" ]]; then
    git push >&2 || die "git push of '$branch' to $up_remote failed — the PR was not created."
    return 0
  fi
  if [[ -n "$up_remote" && "$up_remote" != "." ]]; then
    git push -u "$up_remote" HEAD >&2 || die "git push -u $up_remote HEAD failed for '$branch' — the PR was not created."
    return 0
  fi
  remotes="$(git remote)"
  if [[ -z "$remotes" ]]; then
    die "no git remote is configured, so '$branch' cannot be published. Add one (git remote add origin <url>) and re-run."
  elif printf '%s\n' "$remotes" | grep -qx origin; then
    remote=origin
  elif [[ "$(printf '%s\n' "$remotes" | wc -l | tr -d ' ')" -eq 1 ]]; then
    remote="$remotes"
  else
    die "no 'origin' remote and several others: $(printf '%s\n' "$remotes" | paste -sd ' ' -). Push '$branch' yourself (git push -u <remote> HEAD) and re-run."
  fi
  git push -u "$remote" HEAD >&2 || die "git push -u $remote HEAD failed for '$branch' — the PR was not created."
}

# pr_commit_bookkeeping <change> <url> <file>...
# Commit what recording the PR rewrote (state.json, status.md, STATUS.md) and
# push it. The PR already exists, so every failure here only warns.
pr_commit_bookkeeping() {
  local change="$1" url="$2"; shift 2
  local -a files=()
  local f
  for f in "$@"; do
    [[ -e "$f" && -n "$(git status --porcelain -- "$f" 2>/dev/null)" ]] && files+=("$f")
  done
  [[ ${#files[@]} -gt 0 ]] || return 0
  if ! git add -- "${files[@]}" 2>/dev/null ||
     ! git commit -m "specclaw(${change}): record PR ${url}" --only -- "${files[@]}" >/dev/null 2>&1; then
    warn "could not commit the PR bookkeeping (${files[*]}) — commit it by hand; the PR is live at $url"
    return 0
  fi
  git push >/dev/null 2>&1 || warn "could not push the PR bookkeeping commit — run git push; the PR is live at $url"
  return 0
}
