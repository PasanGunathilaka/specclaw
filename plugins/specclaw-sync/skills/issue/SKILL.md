---
description: Use when a change should be mirrored as a Jira issue.
---

# specclaw issue

**First, run** `specclaw-ensure-init .specclaw` — idempotently creates `.specclaw/` if it doesn't exist (silent if already initialized; auto-inits using the current directory's basename as the project name).

Create a Jira issue from a specclaw proposal. Requires `proposal.md` (run `/specclaw:propose` first).

1. **Check idempotency:** if `status.md` already records a Jira issue for this change, warn and skip.
2. **Run:** `specclaw-jira-issue .specclaw <change>`
   - Requires `JIRA_TOKEN`, `JIRA_URL`, `JIRA_EMAIL`, `JIRA_PROJECT` (set via `/specclaw-sync:auth-jira`).
   - Builds summary (≤255 chars) from the first non-header line of `proposal.md`.
   - Builds description (ADF format) from `proposal.md` + `spec.md` (if present).
   - Creates the issue via Jira REST API v3.
   - **Saves:** appends `**Jira Issue:** [KEY](url)` to `status.md`.
3. Report the Jira issue key and URL to the user.
