# Carry-through for bypasses and splits

Core plan, build and verify point here when a change carries a `## Dependency Bypass`, `## Item Split` or `## Resumes Split` section. `stub-discipline.md` and `split-discipline.md` sit next to this file.

## Plan

3b. **Dependency bypass carry-through.** If `proposal.md` has a `## Dependency Bypass` section, read `.specclaw/analysis/module-stubs.md` for each cited `ST-###` and read `stub-discipline.md`. The spec is where a bypass stops being a scheduling decision and becomes build obligations — carry it forward explicitly in all three files:

- **`spec.md` → `## Bypassed Dependencies`:** one subsection per `ST-###` (substitutes / strategy / stands in with / scoping mechanism / which criteria it backs / when it retires).
- **`spec.md` → `## Acceptance Criteria`:** label **every** criterion `[real]` or `[stub: ST-###]`. No criterion goes unlabelled on a change with a bypass — an unlabelled criterion reads as verified against real behaviour, and that is exactly the false impression the labels exist to prevent.
- **`spec.md` → two mandatory criteria per stub:** (1) the dev/test-scoping assertion, **naming the repo's own isolation mechanism** so a reviewer can check it — "the stub is dev-only" restates the rule instead of testing it; (2) the registry-completion obligation (`Fakes` and `Implementation` carry a real `file:line`).
- **`design.md`:** how the stub is built in *this* repo's stack and what makes it structurally unreachable from production.
- **`tasks.md`:** an explicit stub-implementation task (`Kind: impl`) that the consuming tasks depend on, in an earlier wave.

If the spec cannot state a checkable scoping mechanism — because the repo has no existing way to keep code out of production — **say so and stop before writing tasks**. That is a finding to hand back, not a gap to plan around: a stub with no isolation mechanism is a fabricated response shipped to production.

Skip all of this when the proposal has no bypass section, which is the normal case.

3c. **Item-split carry-through.** If `proposal.md` has a `## Item Split` or `## Resumes Split` section, read the cited `IS-###` in `.specclaw/analysis/item-splits.md` and read `split-discipline.md`. **A split is not a bypass** — nothing is faked, so no criterion is labelled `[stub: ...]` because of it and there is no scoping mechanism to assert. What the spec owes a split is **scope honesty**:

**Now-slice (`## Item Split`):**

- **`spec.md` → `## Item Split`:** the `IS-###`, what this change implements, what is deferred, the `DR-###` rules each half covers, what unblocks the remainder, and **where the deferred scope will attach** — that seam is part of this change's design even though its implementation is not.
- **`spec.md` → `## Acceptance Criteria`:** criteria cover the **now-slice only**. Any criterion for deferred scope is absent or explicitly out of scope citing the `IS-###`. A spec that states criteria for scope this change is not building produces a verify run that fails for the right reason and a reviewer who cannot tell why.
- **One mandatory criterion:** the deferred scope is genuinely **absent, not half-present**. A partly-wired deferred layer is worse than an absent one, because it looks built.
- **`tasks.md`:** no task for deferred scope. **If a task cannot be completed without it, the partition is wrong — say so and stop.** That is a decision to hand back, not one to adjust by quietly moving the boundary.

**Resume (`## Resumes Split`):**

- **`spec.md` → `## Resumed From Split`:** the `IS-###`, what the earlier slice built, and its change/PR/replay evidence.
- **Label every criterion the earlier slice already satisfied `[already built: IS-###]` and mark it out of scope.** They stay visible so the item's full acceptance basis reads in one place; this change is not measured against them.
- **`tasks.md`:** the deferred scope plus its integration, and nothing else. Re-specifying completed scope turns a resume into a rewrite of working code — precisely what the `IS-###` record exists to prevent.

Skip all of this when the proposal has neither section, which is the normal case.

## Build

**c'.** **Stub tasks** — only when `spec.md` has a `## Bypassed Dependencies` section. For a task implementing an `ST-###` stub, add `stub-discipline.md` to that agent's context alongside the usual payload, and hold it to two things:

- **The hard rule: dev/test scope only.** The stub must be *structurally unreachable* from any production code path — a test-only source set, a dev-profile-only registration, a flag that is off by default in production rather than by assertion. Use whatever mechanism the repo already has; inventing a new isolation mechanism for a stub is itself the signal to stop and report. "Unlikely to be hit" is not scoping. A stub that can serve a real user is not a bypass, it is a fabricated response in production.
- **The stub must match the strategy the human chose.** If implementation shows the chosen strategy is wrong, stop and report it — that is a decision to hand back, not one to make. Never widen a stub's reach to make a test pass.

After the task lands, complete its registry entry with the real citation:

```bash
specclaw-bf-rebuild-collect stub-update .specclaw ST-### \
  --fakes "<what it concretely does instead of the real thing>" \
  --implementation "<path/File.ext:88> — <how it is dev/test scoped>"
```

Both are citations, not summaries: a reviewer must be able to jump to that `file:line` and see the claim is true. **Never add a stub that has no registry entry** — an unregistered stub is invisible to `/specclaw-bf:bf-replay`'s taint stamping, so a report will later claim a clean PASS that was earned against fabricated behaviour.

**c''.** **Split changes** — only when `spec.md` has a `## Item Split` or `## Resumed From Split` section. Add `split-discipline.md` to the relevant agents' context, and hold the build to three things:

- **Never build deferred scope.** The spec's now-slice is the whole job. If a task cannot be completed without the deferred scope, **stop and report** — that means the partition is wrong, which is a decision to hand back, not a boundary to move. Widening the slice to make a test pass is the same failure as widening a stub's reach.
- **On a resume, never rebuild what the earlier slice already built.** Read the `IS-###`'s `Implemented now`, `Rules implemented` and `Change`/`Evidence` fields and treat that code as existing — you are integrating with it. Criteria labelled `[already built: IS-###]` are out of scope and must not be re-implemented.
- **Complete the entry's evidence fields** once the change lands:

```bash
specclaw-bf-rebuild-collect split-update .specclaw IS-### \
  --change "<change-name>" --evidence "<PR url or merge sha>"
```

**Never flip a split's Status yourself.** `READY-TO-RESUME` is computed by bash during `/specclaw-bf:bf-rebuild-plan --refresh` from the blocked-until items' own declared `BUILT:` notes; `COMPLETE` requires a clean `/specclaw-bf:bf-replay --item BL-###` run to cite, and `split-update` refuses `COMPLETE` straight from `ACTIVE`.

## Verify

Skip entirely unless `spec.md` carries a `## Item Split` or `## Resumed From Split` section — the normal case, no output, no error.

When it does, this run verifies **a slice of a backlog item, not the item**. Say so on the report's face, immediately under the verdict:

> **Partial-slice verification (split IS-001).** This verifies the scope this change agreed to build. `BL-010` is not fully built: `<the deferred scope>` remains, blocked until `BL-001 BUILT, BL-003 BUILT`. The item's own acceptance is `/specclaw-bf:bf-replay --item BL-010`, which reports PARTIAL while the split is open.

Two rules for the verdict itself:

- **Criteria labelled `[already built: IS-###]` are out of scope.** They were satisfied by the earlier slice and this change does not implement them. Verifying against them would fail a change for not re-doing finished work.
- **A clean verdict here means "the slice we agreed to build works".** It does not mean the feature exists, and the report must never phrase it that way. That distinction is the whole reason the split is on the record.

