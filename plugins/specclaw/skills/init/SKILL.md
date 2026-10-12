---
description: Use when a project has no .specclaw/ directory and the user wants to start using specclaw.
---

# specclaw init

1. Ask for a project name and one-line description if not given, then run `specclaw-init . "<name>" "<description>"`. It writes `flow: lean`, lean defaults and `.specclaw/mock/index.html`. It refuses if `.specclaw/` exists; never overwrite.
2. Suggest tracking `.specclaw/` in git.
3. Next step: `/specclaw:propose`. Change 001 draws the minimal mock of the whole app.
