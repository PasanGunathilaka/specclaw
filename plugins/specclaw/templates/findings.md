# Findings: {{title}}

**Change:** {{change_name}}
**Created:** {{date}}
**Size:** ⚡ spike

<!--
  A SPIKE'S ONLY DELIVERABLE. A spike answers a question; it does not ship code.
  `specclaw-validate-change` refuses build, verify and pr for a spike, and
  accepts `archive` on this file instead of a verify report.

  Keep it short. If it is growing sections, the spike has become a bounded or
  architectural change — run `specclaw-set-size` and say why.
-->

## The question

{{question}}

_One sentence, answerable. "Can systemd-run cap Playwright memory on macOS?" —
not "investigate memory."_

## What was tried

{{attempts}}

_Each attempt: what was run, what happened. Enough for someone to repeat it
without asking you._

## What we found

{{findings}}

## Recommendation

{{recommendation}}

_What should happen next, and what it costs. If the answer is "do nothing",
say so — a spike that concludes against the work has done its job._

## Follow-up

{{followup}}

_The change to propose next, if any. A spike never becomes the implementation:
propose the follow-up as its own change._

---

**Code kept:** none

<!--
  This line is not decoration. A spike's code is throwaway by definition, and
  anything worth keeping is worth proposing properly. If code WAS kept, this
  change was not a spike — upgrade it with `specclaw-set-size` and say why.
-->
