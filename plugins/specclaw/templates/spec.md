# Spec: {{title}}

**Change:** {{change_name}}
**Created:** {{date}}
**Status:** 🟡 Draft

## Overview

{{overview}}

## Requirements

### Functional Requirements

{{functional_requirements}}

### Non-Functional Requirements

{{non_functional_requirements}}

## Acceptance Criteria

Each criterion must pass for the change to be considered complete.

<!--
  WHEN THIS CHANGE BYPASSES A DEPENDENCY (see ## Bypassed Dependencies below),
  every criterion carries one of two labels, and no criterion may go unlabelled:

    - [real]           verified against real behaviour.
    - [stub: ST-###]   verified only against what that stub fakes.

  A [stub: ST-###] criterion is a weaker claim than it looks, and the label is
  what stops it reading as a strong one. "Approval succeeds for an admin user"
  verified against a stub that always returns an admin proves the approval
  path runs — not that the real auth module will ever produce that user.

  Labels are omitted entirely on a change with no bypass. They are not
  decoration: /specclaw:build reads them to know which criteria its stub work
  has to satisfy, and a reviewer reads them to know which parts of a green
  build are actually load-bearing.

  WHEN THIS CHANGE RESUMES AN ITEM SPLIT (see ## Resumed From Split below), a
  third label applies:

    - [already built: IS-###]  satisfied by the earlier slice; OUT OF SCOPE
                               for this change.

  Those criteria are carried forward so the item's full acceptance basis stays
  visible in one place — but this change does not implement them and must not
  be measured against them. Re-specifying completed scope is how a resume turns
  into a rewrite of working code, which is precisely what the IS-### record
  exists to prevent.

  WHEN THIS CHANGE IS THE NOW-SLICE OF A SPLIT (## Item Split below), the
  criteria cover the NOW-SLICE ONLY, and one criterion is mandatory: that the
  deferred scope is genuinely ABSENT, not half-present. A partly-wired deferred
  layer is worse than an absent one, because it looks built.
-->

{{acceptance_criteria}}

## Edge Cases

{{edge_cases}}

## Dependencies

{{dependencies}}

## Bypassed Dependencies

<!--
  PRESENT ONLY when proposal.md carries a ## Dependency Bypass section. Omit
  the whole thing otherwise.

  Carried forward from the proposal by /specclaw:plan — the spec is where a
  bypass stops being a scheduling decision and becomes a set of build
  obligations. One subsection per ST-###:

    ### ST-001 — <what it fakes, for whom>

    - **Substitutes:** BL-014 (MOD-005 — Auth)
    - **Strategy:** stub-interface
    - **Stands in with:** <the concrete sketch the human chose>
    - **Scoping mechanism:** <the repo's own dev/test isolation mechanism this
      stub will use — named concretely, because the acceptance criterion below
      has to be checkable against it>
    - **Criteria verified against this stub:** AC-3, AC-4
    - **Retires when:** BL-014 is built and its consumers re-replay clean.

  TWO CRITERIA ARE MANDATORY per stub, and both belong in ## Acceptance
  Criteria above so they are actually gated:

    1. The dev/test-scoping assertion, naming the mechanism — e.g. "a
       production-profile boot resolves the real IAuthProvider or fails to
       start; the ST-001 stub is not registered outside Development."
       "The stub is dev-only" is NOT acceptable: it restates the rule instead
       of giving a reviewer something to check.
    2. The registry-completion obligation: ST-001's Fakes and Implementation
       fields carry the real file:line once the stub exists.

  See references/stub-discipline.md for the hard rule these enforce.
-->

{{bypassed_dependencies}}

## Item Split

<!--
  PRESENT ONLY when proposal.md carries a ## Item Split section. Omit
  otherwise.

  Carried forward by /specclaw:plan. A split is NOT a bypassed dependency:
  nothing is faked, so no criterion is labelled [stub: ...] because of it, and
  there is no scoping mechanism to assert. What the spec owes a split is
  SCOPE HONESTY.

    ### IS-001 — BL-010 (MOD-002)

    - **Implemented by this change:** <the now-slice> — rules DR-014, DR-015
    - **Deferred:** <the remainder> — rules DR-002
    - **Blocked until:** BL-001 BUILT, BL-003 BUILT
    - **Where the deferred scope attaches:** <the seam it will plug into —
      part of THIS change's design even though the implementation is not>

  MANDATORY CRITERION: the deferred scope is genuinely absent, not
  half-present. Name it as something a reviewer can check.

  The acceptance criteria above cover the now-slice only. Any criterion for
  deferred scope is either absent or explicitly marked out of scope citing
  this IS-###.

  See templates/CONTRACT.md (o) and references/split-discipline.md.
-->

{{item_split}}

## Resumed From Split

<!--
  PRESENT ONLY when proposal.md carries a ## Resumes Split section. Omit
  otherwise.

    ### Resumes IS-001 — BL-010 (MOD-002)

    - **Already built:** <what the earlier slice implemented> — rules DR-014,
      DR-015, marked [already built: IS-001] above and OUT OF SCOPE here
    - **Evidence:** change `view-patient-grid`, PR #61, replay run
      2026-08-18-142230
    - **This change implements:** <the deferred scope> — rules DR-002

  THIS CHANGE IMPLEMENTS THE REMAINDER ONLY. /specclaw:build must treat the
  already-built code as existing and integrate with it, never re-create it.

  Note what a clean verify on this change does and does not mean: it means the
  remainder works. The ITEM's acceptance is /specclaw-bf:bf-replay --item BL-###,
  and only a clean run there marks IS-001 COMPLETE.
-->

{{resumed_from_split}}

## Notes

{{notes}}
