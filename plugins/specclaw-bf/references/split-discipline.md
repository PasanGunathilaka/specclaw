# Split discipline

Rules for an **item split** — the dependency-bypass option that fakes nothing.
The registry format and the state model live in `templates/CONTRACT.md` (o) and
`templates/item-splits.md`; this document is the part `plan`, `build` and
`verify` need: what a split may be, what it may never be, what the spec has to
assert, and what happens when the item is resumed months later.

Read this when a change's `proposal.md` carries a `## Item Split` or
`## Resumes Split` section. Otherwise it does not apply to you.

## Why this is not stub discipline

`stub-interface`, `mock-data` and `feature-flag` all **fake a dependency**. They
produce an `ST-###` entry, they can taint a verdict, and they are *retired* when
the real module lands. `references/stub-discipline.md` governs those.

An item split fakes nothing. It **defers real scope**. So:

| | stub strategies | item split |
|---|---|---|
| Registry | `ST-###` in `module-stubs.md` | `IS-###` in `item-splits.md` |
| Fake behaviour in the tree | yes | none |
| Taint | possible | **never** |
| Question it raises | "was the thing under test real?" | "is this item even finished?" |
| Lifecycle | `ACTIVE → RETIRING → RETIRED` | `ACTIVE → READY-TO-RESUME → COMPLETE` |
| Ends when | the stub code is gone and the consumers re-replay clean | the deferred scope is built and the **full item** replays clean |

Nothing about a split is "safer" than a stub because of this. A stub risks a
verdict earned against something unreal; a split risks **an item everyone
believes is done that is missing a layer nobody wrote down**. The second failure
is quieter and lasts longer, which is why the record is stricter about scope than
the stub registry ever needed to be.

## The incident this exists because of

A rebuild's `BL-010 — View/Search the Patient Grid` depended on `BL-001`
(authentication) and `BL-003` (route guards), neither built. `item-split` was
chosen to defer **the auth integration**. What the proposal actually produced
was a split that cut **the entire frontend**: an ASP.NET Core API, EF Core,
PostgreSQL and passing backend tests shipped, and no React application at all.
A user-visible, screen-bearing backlog item silently became a backend-only
implementation.

Two things went wrong, and both are now mechanical:

1. **The split widened beyond what was chosen.** `split-append` now refuses a
   rule partition that does not account for the item's acceptance basis exactly,
   and refuses to remove the whole `ui` layer from a screen-bearing item without
   a named human confirming that consequence.
2. **Nothing recorded what was deferred.** An `ST-###` entry has no field for
   it. `IS-###` has six.

## Prefer a vertical slice

**A split should be a thin end-to-end capability, not a horizontal stack cut.**

- **Vertical (preferred):** the grid renders, calls a real endpoint, runs a real
  query, reads real persisted data — and only the auth integration waits. The
  item delivers something a user can open.
- **Horizontal (usually wrong):** every layer below the UI ships and the UI
  waits (or vice versa). The item looks nearly finished and delivers nothing
  anyone can use, and its screen-bearing acceptance basis goes unmet with no
  fixture able to notice.

A horizontal cut is occasionally the honest answer — a genuinely headless item,
a batch job, an integration with no interface. When it is, say so explicitly and
confirm it. When it is not, the vertical slice is almost always available: the
dependency that is actually missing is usually one seam, not one layer.

## What the split must never do

- **Never widen beyond what the human chose.** The split the user selected is
  the split that happens. If implementation reveals the chosen split is not
  buildable, **stop and hand it back** — that is a decision to return, not one
  to adjust. Silently moving one more rule into the deferred half is the exact
  failure this whole mechanism exists to prevent.
- **Never remove a whole layer without the confirmation on the record.** For a
  screen-bearing item and the `ui` layer this is enforced by a refusal. For every
  other layer it is on you to present the consequence before recording it.
- **Never leave a rule in neither half.** `split-append` refuses this, and the
  reason is worth understanding: a rule belonging to neither half is scope nobody
  owns, so nothing can later tell whether it shipped. It is also what lets
  `/specclaw-bf:bf-replay --item` name which of the item's fixtures cover built vs
  deferred scope, instead of an agent judging prose at run time.
- **Never treat the deferred scope as optional.** It is the remainder of an item
  someone still expects. `Blocked until` is what makes it come back.

## What `/specclaw:plan` owes a split

When `proposal.md` carries `## Item Split`, read the `IS-###` entry and carry it
into all three files:

- **`spec.md` → `## Item Split`:** the `IS-###`, what ships now, what is
  deferred, which rules each half covers, and what unblocks the remainder.
- **`spec.md` → `## Acceptance Criteria`:** the criteria cover **the now-slice
  only**. Every criterion for deferred scope is either absent or explicitly
  marked out of scope citing the `IS-###`. A spec that states criteria for scope
  this change is not building produces a verify run that fails for the right
  reason and a reviewer who cannot tell why.
- **`spec.md`:** one criterion asserting that the **deferred scope is genuinely
  absent, not half-present**. A partly-wired deferred layer is worse than an
  absent one: it looks built.
- **`design.md`:** where the deferred scope will attach when it lands — the seam
  is part of this change's design even though the implementation is not.
- **`tasks.md`:** no task for deferred scope. If a task cannot be completed
  without it, that is the signal the partition is wrong; say so and stop.

**On a resume** (`## Resumes Split`), the direction inverts:

- **`spec.md` → `## Resumed From Split`:** cite the `IS-###`, the change that
  built the first slice, and its PR/replay evidence.
- **Label every criterion the earlier slice already satisfied
  `[already built: IS-###]` and place it out of scope.** This change implements
  the remainder. Re-specifying completed scope is how a resume turns into a
  rewrite of working code.
- `tasks.md` covers **only** the deferred scope plus its integration.

## What `/specclaw:build` owes a split

- **Never rebuild scope the `IS-###` records as already implemented.** Read the
  entry's `Implemented now`, `Rules implemented` and `Change`/`Evidence` fields
  and treat that code as existing. On a resume you are integrating, not
  re-creating.
- **Complete the entry's evidence fields** once the change lands:

```bash
specclaw-bf-rebuild-collect split-update .specclaw IS-### \
  --change "<change-name>" --evidence "<PR url or merge sha>"
```

- **Never flip a Status yourself.** `READY-TO-RESUME` is computed by bash during
  `/specclaw-bf:bf-rebuild-plan --refresh`; `COMPLETE` needs a clean
  `/specclaw-bf:bf-replay --item BL-###` run to cite.
- **Never widen the slice to make a test pass.** If a test needs deferred scope,
  the test belongs to the deferred half.

## What `/specclaw:verify` owes a split

Verify a **partial slice** against the now-slice's criteria, and say plainly in
`verify-report.md` that this is a partial-slice verification citing the
`IS-###` — never that the backlog item is verified. The item's own acceptance is
`/specclaw-bf:bf-replay --item BL-###`, and while a split is `ACTIVE` or
`READY-TO-RESUME` that run reports **PARTIAL** and cannot be its final
acceptance.

A clean verify on a split change means "the slice we agreed to build works". It
does not mean the feature exists.

## What a split can never claim

An `IS-###` makes a deferral **traceable**, not harmless. The item is
unfinished, `rebuild-backlog.md` says so on its face, and every `--item` replay
of it reports PARTIAL until the remainder lands. Whether shipping the slice is
worth the incompleteness is a human judgement about a named, dated, recorded
decision — which is the most this format can honestly offer, and considerably
more than an unrecorded split offers, because an unrecorded split is
indistinguishable from a finished item.
