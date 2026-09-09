# Spec Guidelines

Accumulated spec and design guidance for this repo.
Promoted from spec_gap and design_gap learnings — never from the plugin.

---

## [L15 from 033-capability-acceptance-basis] design_gap — A fact that two subcommands both need is a function, never a local in 

**Promoted:** 2026-09-09 15:04 UTC
**Category:** design_gap
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
A fact that two subcommands both need is a function, never a local in one of them. Fixing the exit-0 verdict, the classification was declared as a local in cmd_render, but the compute_verdict_summary call site lives in cmd_finalize -- a different subcommand. Under set -u that is an unbound-variable abort, so 'finalize' silently wrote NO evidence package at all: a worse failure than the bug being fixed, since the evidence package is the committed proof of mechanical verification. It was caught only by a pre-existing suite I had not written.

### Recommended Action
When wiring a new fact into a multi-subcommand script, grep for EVERY call site of the consumer before choosing where the value lives, and prefer a reader function over a local the moment a second subcommand needs it. Also: bash -n does not catch this -- only running each subcommand does.

---

## [L17 from 033-capability-acceptance-basis] design_gap — An invariant nothing computes on both sides is not tested, however con

**Promoted:** 2026-09-09 18:31 UTC
**Category:** design_gap
**Priority:** high
**Source change:** 033-capability-acceptance-basis

### Insight
An invariant nothing computes on both sides is not tested, however confidently it is documented. specclaw-bf-replay:427-433 states as TESTED that --item's selection equals the backlog's own Verification fixture list. It never was: specclaw-bf-rebuild-collect:2608 ORs the scenario's 'Verifies backlog item' field in as a join key while CONTRACT.md and bf-replay both state that field is metadata and never a join key, so the two sides join on different keys and can disagree. This change's own tasks.md claimed T9 covered that invariant; what existed was a byte-identity assertion over the two extractors -- a different property entirely, since identical functions can still be fed different inputs or consumed differently.

### Recommended Action
When a doc comment claims an invariant is tested, grep for the test before believing it. To test an equality between two producers, RUN BOTH and diff the outputs -- never assert that their shared helper is identical and call that the invariant.

---
