# Target Foundation Plan: {{title}}

**Date:** {{date}}
**Repo:** the NEW (rebuild) repository
**Written by:** `bf-bootstrap-architect`, inside `/specclaw-bf:bf-bootstrap`

<!--
  THE HUMAN-READABLE HALF OF THE FOUNDATION STAGE.

  bootstrap-manifest.json is what bash reads; this document is what a person
  reads. It is written BEFORE the scaffold exists, deliberately, so a reviewer
  can disagree with the SHAPE rather than only with the result — the same
  reason /specclaw-bf:bf-baseline asks a human to confirm the recommended seam
  before any harness code is generated.

  ── THIS PLAN CONSUMES DECISIONS; IT NEVER MAKES THEM ────────────────────
  Every stack claim below cites the SQ/CQ id that decided it and the file that
  records it. A part of the stack with no citation is not a plan, it is a
  guess wearing a plan's clothes — and the whole reason this stage exists is
  that a guess made here is inherited by every backlog item built afterwards.

  If a required decision is missing, /specclaw-bf:bf-bootstrap has already
  refused to run and named the id. Nothing in this document ever fills such a
  gap with a default.

  ── THE FOUNDATION-ONLY BOUNDARY ─────────────────────────────────────────
  The "Not In Scope" section below is not boilerplate — it is the load-bearing
  half of this document. A foundation implements no backlog capability: no
  sign-in, no grid, no registration, no payments, no domain entity, no domain
  table, no capability endpoint or screen, and no placeholder named after one.
  Each of those is named here together with the BL-### that owns it, so a
  reader can see the line was drawn on purpose rather than wherever the
  scaffolding happened to stop.

  ── STACK-AGNOSTIC BY CONSTRUCTION ───────────────────────────────────────
  There is no per-stack scaffold template anywhere in this plugin. The agent
  generates the skeleton for whatever stack decisions.md names, in that
  stack's own idiom, the same way harness code and replay tests are generated.
  If you are tempted to add a framework name or a code sample to THIS FILE
  (the template), that is the signal you are writing the wrong artifact — the
  rendered copy in a project names that project's stack, and only there.

  Replace every {{placeholder}} with real content. Do not add sections.
-->

## Resolved Target Stack

<!--
  One row per part of the stack. EVERY row cites the decision id and the file
  that records it. "Because it is the modern choice" is not a source.
-->

{{resolved_stack}}

## Structure

<!--
  The project/directory layout, and why it is that shape in THIS stack's own
  conventions. A reviewer who works in this stack should find nothing
  surprising here. Name the layer boundaries and what each layer may depend
  on — those boundaries are what keeps a later backlog item from having to
  invent them.
-->

{{structure}}

## Boundaries

<!--
  Where the seams are, so a backlog item knows where to plug in:
  - the frontend -> API boundary, and the client mechanism that crosses it
  - the API -> domain boundary
  - the domain -> persistence boundary
  - the place authentication will attach when its own BL item lands
    (a BOUNDARY, never an implementation — auth is a backlog item)
  - error-handling conventions: how an error surfaces, is logged, is shaped
  These are conventions and empty seams. No business rule decides anything
  in any of them.
-->

{{boundaries}}

## Testing Approach

<!--
  How each side is tested, in the runner this stack actually uses, plus the
  one trivial test per side that proves the runner executes. This is the
  structure /specclaw-bf:bf-replay's generated replay tests will later have to
  live alongside, so name the convention explicitly.
-->

{{testing_approach}}

## Local Development Setup

<!--
  What a developer runs to get this working from a fresh clone: the commands,
  the services they need (database, etc.), and how configuration and secrets
  are supplied WITHOUT being committed. Every command here should be one a
  reader can copy.
-->

{{dev_setup}}

## Smoke Verification

<!--
  The checks that prove the foundation actually runs, drawn from the closed
  set: frontend-build, frontend-start, api-build, api-start, db-connect,
  migrations-infra, frontend-to-api, test-frontend, test-backend.

  Every command must TERMINATE ON ITS OWN. A start check is
  start -> prove it answered -> stop, never a bare long-running server
  command: `specclaw-bf-bootstrap smoke` records a command that does not
  return as FAILED (timed out), which is the honest result rather than a hung
  step.

  A check that genuinely does not apply is SKIPPED WITH A STATED REASON. A
  skip with no reason is indistinguishable from never having considered it,
  and `record` refuses one.
-->

{{smoke_verification}}

## UI Token Plumbing

<!--
  The exact line drawn between plumbing and values, and why. Omit nothing:

  - MAY: the theme mechanism (provider/registration, the token declaration
    structure in this platform's own idiom, the layout shell), plus the VALUES
    of TK- groups whose scope is `global`. Those are unioned into every
    screen-bearing item's UI-fidelity line by /specclaw-bf:bf-rebuild-plan, which
    makes them a shared prerequisite of all of them — and a shared
    prerequisite no single item can own is what "foundation" means.

  - MAY NOT: a TK- group scoped to a specific SCR-###, and any screen's layout
    structure, even under FAITHFUL. Those are exactly what a named human signs
    in ui-review.md, per change, per screen.

  - Under REINTERPRET, an undecided SQ-013, or a decided policy whose
    .specclaw/ui/ artifacts are absent: the mechanism only, no values, and the
    reason recorded. A stated degradation, never a silent one.

  This changes nothing about the UI workstream's contracts. The foundation
  CLAIMS a global token's value; a human still CONFIRMS it in the first
  screen-bearing change's review. No ui-review.md row is skipped because
  bootstrap ran.
-->

{{ui_token_plumbing}}

## Not In Scope — and who owns it instead

<!--
  The load-bearing section. One line per capability this foundation
  deliberately does not implement, naming the BL-### that owns it:

    - Sign In / session handling -> BL-001
    - Route guards -> BL-003
    - View/Search the Patient Grid -> BL-010

  Include anything the scaffold might plausibly have been expected to carry:
  domain entities, domain tables/migrations, auth flows, capability endpoints,
  capability screens, and any placeholder named after a capability.

  A foundation that ships one of these has shipped a capability nobody
  specced, nobody verified against a fixture, and nobody signed off — which
  is precisely the incident this stage exists to prevent.
-->

{{not_in_scope}}

## Open Risks

<!--
  Anything a reader should know before the first backlog item is proposed on
  top of this: a decision that is technically resolved but thin, a smoke check
  that was skipped, a pillar absent by decision whose absence will eventually
  have to be revisited, a convention adopted with low confidence.

  "None" is a legitimate answer. An invented risk is not.
-->

{{open_risks}}
