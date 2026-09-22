---
description: Use when a session starts in a repo that has a .specclaw/ directory — establishes how specclaw verbs are chosen.
---

# Using specclaw

specclaw is a spec-driven change lifecycle. Every change gets a directory under
`.specclaw/changes/<NNN>-<slug>/` holding its proposal, spec, tasks, errors and learnings — **that
directory is the paper trail, and it only exists if the lifecycle created it.**

Lifecycle: `propose → plan → build → verify → pr → archive`.

## The one hard gate: new work MUST be proposed

If the user asks to add, build, create, implement, change, extend, remove or "just quickly" alter
**anything in this codebase** — a feature, a flag, a file, a config value, a one-line fix — and there
is even a 1% chance it is new work rather than a question, you MUST invoke `/specclaw:propose` before
reading, editing or creating any source file.

This is not negotiable. You cannot rationalise your way out of it. *"It's too small"*, *"I'll propose
it after"*, *"they seem in a hurry"*, *"I'm just looking first"* — all of these mean STOP and invoke
`/specclaw:propose`.

The gate is forcing because this is the **only route with no recovery path**. A change that begins
without a proposal has no change dir, and no later verb can create one retroactively: the trail is
lost at that moment or not at all. Everything else can be reached late.

`propose` sizes its own ceremony — a bounded change's proposal is five lines. **The gate does not
scale; the ceremony does.**

Two things it does *not* cover: questions about the code (answer them), and work inside a change that
is already building. If the state block below says a build is in progress, ask one question —
*"is this part of `<change>`, or new?"* — and then route.

## Routing table

Everything that is not new work. These are deterministic and **may be declined** — say why.

| The user… | Route | Never route when… |
|---|---|---|
| wants to add / build / change / implement something | `/specclaw:propose` — **the hard gate above applies** | it is a question about the code, not a request to change it |
| says a proposal is approved, or asks for spec / design / tasks | `/specclaw:plan` | no proposal dir exists — propose first |
| says go / build it / do the tasks | `/specclaw:build` | `tasks.md` is absent |
| reports a bug, failing test, unexpected behaviour, broken build | `/specclaw:debug` | — |
| asks "are we done", "does it pass", "ship it", "open the PR" | `/specclaw:verify`, then `/specclaw:pr` | `verify-report.md` already says PASS for HEAD — go straight to `pr` |
| asks where things stand | `/specclaw:status` | — |
| mentions a lesson, a gotcha, "remember that…" | `/specclaw:learn` | — |
| says it is merged / done with | `/specclaw:archive` | — |

**Never route** for: `auth-azdo` and `auth-jira` (credentials — the user runs those), read-only
questions about the code, and anything the user asks for by another tool's name.

## Announce the route

Before the first tool call, say one line:

> Using `/specclaw:<verb>` — "<the phrase that matched>"

So a wrong route costs one message to veto, instead of being discovered three files later.

## Red flags — each one means STOP

| Thought | Reality |
|---|---|
| "This is too small for a proposal" | Then it is a **bounded** change and the proposal is five lines. |
| "I'll just fix it and propose after" | There is no "after". No change dir means no trail, ever. |
| "The user seems in a hurry" | A proposal for a one-line fix takes seconds. Losing the trail costs hours later. |
| "Let me explore the codebase first" | Reading is fine. Editing is not. The gate is on the edit. |
| "They said 'quick', so they want it informal" | They want it fast. `propose` is fast. |
| "It's just config / just a doc / just a rename" | All changes. All proposable. |
| "There's no specclaw dir for this yet" | That is what `propose` is for. |
| "I already know what the plan is" | Then writing it down costs nothing. |

## If superpowers is also installed

`brainstorming` may run **inside** propose's elicitation, but the artifact is `proposal.md`.
`writing-plans` is replaced by `/specclaw:plan`. Two frameworks, one paper trail.
