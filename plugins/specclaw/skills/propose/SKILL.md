---
description: Draft a new change proposal. INVOKE IMMEDIATELY whenever the user mentions a proposal, feature idea, change request, new initiative, or anything they want to add/build/implement — do NOT gather details conversationally first. The skill itself will ask for any missing information after invocation. Creates .specclaw/changes/<name>/proposal.md with problem statement, solution, scope, impact, and open questions. When party.enabled is set, also runs the adversarial review panel over the draft — asking first, unless party.default — and writes party-report.md. The first step in the propose → plan → build → verify → pr lifecycle.
---

**Flow check:** run `specclaw-ensure-init .specclaw && specclaw-flow .specclaw`. If it prints `full`, read `$CLAUDE_PLUGIN_ROOT/references/full/propose.md` and follow it instead of this file.

# specclaw propose (lean)

A lean change is one page plus a visible mock edit, approved before any code exists.

1. Ask once for the idea if it is missing. Name the change `<NNN>-<slug>`, with NNN from `specclaw-next-change-number .specclaw`. Create `.specclaw/changes/<change>/`.
2. Write `change.md` from `$CLAUDE_PLUGIN_ROOT/templates/lean/change.md`:
   - **Problem:** 2–3 lines.
   - **Acceptance Criteria:** numbered `AC-n`, each checkable by one test or by looking at the screen. Cover everything; no padding.
3. Edit `.specclaw/mock/index.html` (plain HTML, inline CSS, fake data, no external URLs):
   - **Still has `data-change="000-template"`:** this is change 001. Replace it with the minimal overall app: layout, navigation, main screens, fake data. For a library or CLI, show sample input and output.
   - **Otherwise:** add or edit only `<section data-change="<change>" id="<change>">` blocks. Never edit another change's section; if you need to, ask.
4. Fill **Mock Delta**: what changed on screen, plus the anchor link.
5. Present `change.md` and tell the user to open `.specclaw/mock/index.html#<change>`. **Stop until they approve.**
6. On approval: `specclaw-set-phase .specclaw <change> proposal approved`, then `specclaw-update-status .specclaw`. If `specclaw-gh-sync` is on PATH and `github.sync: true`, run `specclaw-gh-sync create .specclaw <change>`; skip silently otherwise.
