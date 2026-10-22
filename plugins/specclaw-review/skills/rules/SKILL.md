---
name: rules
description: Use when setting up specclaw-review in a repo, when the user wants review rules created or improved, or asks what the reviewer should check in this codebase.
---

# specclaw-review: create the review rules for this repo

Two outputs:
1. a `review:` block in `.specclaw/config.yaml`;
2. rule files in `.specclaw/review/rules/`.

**Write nothing until the user approves what you show them.** Rules decide what blocks a PR, so a rule written
silently is a gate nobody agreed to.

## 1. Find what the repo already has

Run `specclaw-review discover` (or call the `review_discover` MCP tool). It is read-only and lists:
- the repo's governance by category, with sizes;
- whether those files define severity;
- the existing repo rules;
- how much review history is on disk;
- whether a PR host can be read;
- a suggested `review:` block.

Before you go on:
- **Existing governance wins.** Point `review.governance` at those files; they are read fresh every round. Never
  copy them into rule files, because copies go stale.
- **Decisions/ADRs stay out of the rulebook.** List them for the user. The reviewer reads them with its tools when
  a change touches them.
- **Over budget:** if the inlined size is over budget, propose which files to drop from `governance`, smallest
  value first: long guides, tutorials, and anything an ADR already covers. Show the size before and after.
- **Severity:** if the files define severity, say so. `severity: project` applies by default, so the repo's own
  idea of "major" wins.

## 2. Draft rules only for what is missing

Mine the repo's **own** review history and write down what it keeps getting wrong. Never write generic advice;
the plugin's packs already hold that.

Sources, best first:
1. **Past PR review comments.** Read only, last 30–50 merged PRs.
   - **GitHub:**
     `gh api "repos/{owner}/{repo}/pulls/comments?per_page=100" --paginate -q '.[] | [.path, .body] | @tsv' | head -2000`
   - **Azure DevOps:** use the token in `.specclaw/.env` (`AZDO_TOKEN`; never print it). Read
     `_apis/git/repositories/<repo>/pullrequests?searchCriteria.status=completed&$top=50`, then each PR's
     `/threads`.
2. **The repo's records:** `.specclaw/changes/*/learnings.md` and `follow-ups.md`.
3. **Recurring lessons in review memory:** `specclaw-review learn` (dry-run).

Group the findings by root cause, not by wording. Keep a group only when it recurs, at least twice in different
PRs, and nothing in the governance already says it. For each kept group, draft one rule:

```
- **R<n> <short name>.** <the defect, stated so a reviewer can check it in a diff>. <what to do instead>.
  Severity: <blocker|major|minor>. Seen: <PR ids or change names>.
```

- A rule must name a concrete failure ("a failed read rendered as an empty list"), never a preference ("prefer
  clean code").
- Put rules in `.specclaw/review/rules/<topic>.md`, one topic per file, with IDs unique across files.
- If a group is mechanical (a pattern a test or linter could catch), propose a **guard** instead of a rule. A guard
  changes behaviour; a rule only reminds the reviewer.

## 3. Show, then write

Show the user, in one message:
- the `review:` block;
- each new rule file in full;
- the rulebook size (`specclaw-review rules | wc -c` after, estimated before);
- the PRs or changes each rule came from.

On their yes:
1. Write the config block (merge into an existing `review:` block, never duplicate it) and the rule files.
2. Run `specclaw-review rules` and confirm it prints them.
3. Run `specclaw-review init` once, so the review-memory guard rule is installed.

## 4. Keep it alive

After a few review loops, run the `learn` skill. Lessons the loop records twice become rule proposals for the same
folder.
