---
description: Use when a build is finished and the user asks whether it is done or passes.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/verify.md` and follow it instead of this file.

# specclaw verify (lean)

1. `specclaw-validate-change .specclaw <change> verify`. Stop if it fails.
2. Run the configured test, lint and build commands (`config.yaml`, or the project's standard ones). Record the commands and their exit codes. Then run `specclaw-preset-check .`; exit 1 is a FAIL, and its JSON lists each violation to fix. Then run `specclaw-quality-scan . --gate`: exit 1 is a FAIL (name the `high` functions and the duplicates), and exit 2 means a tool did not run, which is also a FAIL until it can.
3. Screenshots, saved under `.specclaw/changes/<change>/shots/`:
   - Start the app if the change has a UI.
   - Run `specclaw-screenshot <app-url> …/shots/app.png` and `specclaw-screenshot .specclaw/mock/index.html#<change> …/shots/mock.png`.
   - **Exit 3** (Playwright unavailable): give the user both locations and ask them to compare by eye. Record `compared by eye: <name>` only after they answer.
   - **Never record a pass without a screenshot or a human comparison.**
4. Under `## Verify` in `change.md`, write:
   - `**Verdict:** PASS` or `FAIL` on the first line
   - one `- AC-n: pass|fail — <evidence>` line per criterion
   - the commands run and the screenshot paths
5. `specclaw-set-phase .specclaw <change> verify done` (or `failed`), then `specclaw-update-status .specclaw`. On PASS, the next step is `/specclaw:pr`. On FAIL, fix with `/specclaw:build` and re-verify.
