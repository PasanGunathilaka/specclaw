# Stub discipline

Rules for implementing a **dependency bypass** — the mechanism that lets a
module be built before the modules it depends on exist. The registry format and
the taint mechanics live in `templates/CONTRACT.md` (m) and
`templates/module-stubs.md`; this document is the part the *build* step needs:
what a stub may be, what it may never be, and what the spec has to assert.

Read this when a change's `proposal.md` carries a `## Dependency Bypass`
section. Otherwise it does not apply to you.

## No stub code lives in this plugin

There are no snippets here, and there will not be any. The three strategies
below are **shapes**. What a stub actually looks like — the language, the
injection mechanism, the test-scoping idiom, the flag system — is designed by
the build agent by reading the rebuild repo, exactly as harness code, replay
tests, and the project's error vocabulary are. A stack name or a code sample in
this file would be the signal that something is being written in the wrong
place.

## The hard rule: dev/test scope only

**A stub is never reachable from a production code path.**

Not "unlikely to be hit." Not "guarded by a check nobody would remove." The
requirement is structural unreachability — the stub must be *impossible* to
serve to a real user without someone deliberately changing configuration or
build wiring. Whatever the rebuild's stack calls that:

- a test-only source set or module that production never compiles or ships
- a registration that exists only under a dev/test profile, environment, or
  build tag
- a flag that is off in every non-dev configuration, with the off path being
  the one production takes by default rather than by assertion

Whichever mechanism the repo already uses for this is the one to use. Inventing
a new isolation mechanism for a stub is itself a smell: if the repo has no
existing way to keep code out of production, that is the problem to raise
before writing the stub.

**Why the rule is absolute.** A bypass buys schedule at the cost of certainty,
and the whole bargain rests on the stub being provably temporary and provably
inert. A stub that can serve a real user is not a bypass with a trade-off —
it is a fabricated response shipped to production, which is a defect regardless
of how it was labelled. There is no deadline that makes it a good trade.

**The spec must assert it.** The change's `spec.md` carries this as a checkable
acceptance criterion naming the concrete mechanism used, e.g. *"the ST-001 stub
is registered only under the dev profile; a production-profile boot resolves
the real interface or fails to start."* An untestable restatement of the rule
("the stub is dev-only") does not satisfy this — name the mechanism, and make
the criterion something a reviewer can check.

## The three faking strategies

Each `ST-###` entry's `Strategy` field is one of these three. They are not
interchangeable; pick by what the dependency actually is. (The fourth answer
`/specclaw:propose` offers — `item-split` — is not a stub and is not here; see
below.)

### `stub-interface`

The dependency's **contract** exists (or can be written now) but nothing
implements it. Supply a dev/test-only implementation returning fixed,
**obviously fake** values.

- Fake data should be recognisable as fake on sight. A stub user named
  `stub-user` with role `STUB_ADMIN` is self-documenting in a log; one named
  `Sarah Chen` with role `admin` will eventually be mistaken for real data by a
  human reading an incident timeline.
- Best when the consuming code needs a *shape* to compile and exercise, and the
  dependency's real logic is irrelevant to what this item does.
- Worst when the consuming item's own behaviour depends on the dependency's
  decisions — then you are not stubbing a dependency, you are inventing the
  business rule you were supposed to be verifying.

### `mock-data`

Real code paths run, against unreal content: a seeded table, a fixture file, a
pre-populated store.

- Declare the seed path in the entry's `Mock seed` field. Note the honest limit
  from `CONTRACT.md` (m.5): nothing can *assert* the seed was inactive during a
  later acceptance run. The field exists so a human and the retirement block can
  check, not so a command can guarantee.
- Best when the dependency owns *data* the consumer reads and does not own the
  rules the consumer exercises.

### `feature-flag`

The consuming code path is written in full and disabled behind a flag that is
off until the real module lands.

- The only strategy where the delivered code is the *final* code. Retirement is
  turning the flag on, which makes it the cheapest to retire and the easiest to
  forget — the registry entry is what stops it becoming permanently dark code.
- Best when the dependency is genuinely absent (no contract to stub, no data to
  mock) and the honest answer is "this path cannot run yet."

## The fourth option, which is not a stub

`item-split` — ship the part that does not need the dependency, and let the
remainder wait — is the fourth answer `/specclaw:propose` offers, and it is
**not one of the three strategies above and not a stub at all**.

It belongs to a different registry (`item-splits.md`, `IS-###`), a different
state model (`ACTIVE → READY-TO-RESUME → COMPLETE`), and it never taints
anything, because nothing unreal was ever in the tree. `stub-append --strategy
item-split` is refused by name.

The distinction is not bookkeeping. A stub raises the question *"was the thing
under test real?"*. A split raises an entirely different one: *"is this item
even finished?"* — and answering it needs fields an `ST-###` entry does not
have (what was deferred, which rules each half covers, what unblocks it).
Recording a split as a stub is how a real project shipped a screen-bearing
backlog item with no user interface at all and nothing anywhere noticed.

**If the chosen strategy is `item-split`, this document does not apply.** Read
`references/split-discipline.md` instead.

Entries recorded before `item-splits.md` existed keep `Strategy: item-split` in
`module-stubs.md` forever — `ST-###` ids are permanent and entries are never
deleted (`CONTRACT.md` (c)). They are excluded from taint and from the
retirement block, and `/specclaw-bf:bf-rebuild-plan` names them once with the
manual step rather than pretending a migration happened.

## What the build step owes the registry

After implementing the stub, complete its `ST-NNN` entry:

- **`Fakes:`** — what it concretely does instead of the real thing, in the
  project's own language. Replaces the propose-time `not yet implemented`.
- **`Implementation:`** — the stub's `file:line`, followed by *how* it is
  dev/test scoped (the concrete mechanism, matching the spec's criterion).

Both are citations, not summaries. `file:line` for a stub is the same
commitment as the `file:line` an error-map entry carries for the condition it
names: a reviewer must be able to jump to it and see the claim is true.

## What the build step must never do

- **Never widen a stub's reach to make a test pass.** If a test needs the stub
  in a scope where it does not belong, the test is exercising the wrong thing.
- **Never add a stub that is not in the registry.** An unregistered stub is
  invisible to taint stamping, which means a report will claim a clean PASS
  that was earned against fabricated behaviour. This is the single failure mode
  the whole mechanism exists to prevent.
- **Never choose or change a strategy.** The strategy is a human decision made
  at propose time. If implementation reveals the chosen one is wrong, say so
  and stop — that is a decision to hand back, not to make.
- **Never leave a consumed stub out of `Consumed by`.** That field is the join
  key: an item missing from it produces untainted fixtures, and an untainted
  fixture built on a stub is a false verdict.
