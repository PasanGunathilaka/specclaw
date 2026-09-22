# Error Journal: {{change_name}}

Build errors and their resolutions.

<!--
  Two entry shapes live in this file, and both are written by
  `specclaw-log-error` — never by hand, and never by a model editing this file.

  1. ATTEMPT entries, written when a build task fails:

       ## [T5] Attempt 2 — Wave 1
       **When:** …   **Agent:** …   **Status:** pending | resolved_on_retry
       ### Summary        <one line>
       ### Error Output   <capped at 50 lines>

     They record WHAT happened.

  2. INVESTIGATION entries, written by /specclaw:debug and by the loop's fix
     agent via `specclaw-log-error --investigation`:

       ## [T5] Investigation 2 — <symptom, one line>
       **When:** …
       **Status:** upheld | open
       **Failure-Sig:** <the loop signature this belongs to, or —>
       **Reproduce:** `<one command>` → exit <n>
       **Evidence:** <what was observed, not what was assumed>
       **Hypothesis 1 (withdrawn):** <statement> — <why it was ruled out>
       **Hypothesis 2 (upheld):** <statement>
       **Fix:** <the single change that removed the cause> (commit <sha>)
       **Proof:** <the reproduction command re-run, and its result>

     They record WHY it happened, and every line is one a human can check.

  The verdict in each Hypothesis line is load-bearing, not prose.
  `specclaw-loop decide` counts investigations on one Failure-Sig whose every
  hypothesis is `withdrawn`, and halts with `architecture-question` once
  `loop.architecture_question_limit` of them exist — the signal that the design,
  not the code, is what is wrong. `specclaw-detect-patterns` clusters on the
  upheld hypothesis and the fix, so patterns form around CAUSES rather than
  around error strings.
-->

---
