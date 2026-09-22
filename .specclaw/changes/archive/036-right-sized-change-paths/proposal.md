# Proposal: Right-sized change paths — spike / bounded / architectural, with one approval gate

**Created:** 2026-09-19
**Status:** 🟡 Draft
**Source of the idea:** `obra/superpowers` `skills/brainstorming/SKILL.md` v6.3 "Three Paths" router — *"the ceremony scales with the task; the approval gate never does"*, plus its one-way upgrade ratchet. Adapted: specclaw always writes artifacts to disk; superpowers' in-chat design and visual companion are not taken.

## Problem

Every specclaw change pays the same ceremony. `specclaw-validate-change` requires `proposal.md` →
`spec.md` + `design.md` + `tasks.md` → build → verify before a PR, whether the change is a new
subsystem or a one-line flag. Two consequences, both visible in this repo:

- **Small work routes around specclaw.** The `specclaw.sln` sitting untracked in the working tree, the
  README typo fixed on `main`, the "quick" config edit — none has a change dir, so none has a paper
  trail, and `context.md` never learns about them. The framework is most controlled exactly where it is
  least used.
- **Feasibility questions get built.** "Can `systemd-run` cap Playwright memory on macOS?" is a question
  whose output is an *answer*. Today the only shape available is a change that ends in code, so the
  probe code gets kept, tasked, and verified.

superpowers' classification is the useful learning: a **spike** (output is an answer, anything built is
throwaway), a **bounded** change (an existing flow in this repo is being altered — a flag, an endpoint,
a one-file fix), and an **architectural** change (new subsystem, interface others depend on). The
ceremony differs; the approval before implementation does not. And when hidden complexity appears
mid-task, the path is upgraded, announced, and never downgraded.

What we do **not** take: superpowers presents a bounded design *in chat* and writes nothing. specclaw's
premise is that the artifact is the control — so bounded still writes files, just fewer.

## Proposed Solution

**1. Classification at propose time.** `/specclaw:propose` adds a `**Size:** spike | bounded |
architectural` line under Impact, announced to the operator with the one-sentence reason
(*"this alters `specclaw-verify collect`, which already exists → bounded"*). The operator can override
in the approval reply. `specclaw-set-phase … proposal approved --size <s>` records it in `state.json`;
`specclaw-validate-change` reads it from there. When party mode ran, the classifier's `tier` is offered
as the default (it already judges depth; do not judge twice).

**2. Artifacts per size.**

| Size | plan writes | build | verify | pr |
|---|---|---|---|---|
| **spike** | `findings.md` only (question, what was tried, recommendation, "code kept: none") | not permitted | not permitted | not permitted → `archive` directly |
| **bounded** | `spec.md` (acceptance criteria + the one design decision inline) and `tasks.md`; **no `design.md`** | as today | as today | as today |
| **architectural** | `spec.md`, `design.md`, `tasks.md` — exactly today | as today | as today | as today |

`specclaw-validate-change` becomes size-aware: `design.md` is required only for architectural; a spike
refuses `build`/`verify`/`pr` with *"spikes end in a recommendation; propose the follow-up as its own
change"*. `templates/findings.md` is new and small.

**3. The one-way ratchet.** `specclaw-set-size .specclaw <change> <new-size> --reason "…"` accepts
only upgrades (`spike → bounded → architectural`), appends a `Size upgraded` row to `status.md`, and —
for bounded → architectural — makes `design.md` required again, so the next `validate-change` stops
until `/specclaw:plan --design-only` fills it. The build skill and the loop call it when a task's
`files:` list grows past the spec's file map or a task fails with a `design_gap` learning. Downgrade is
refused by name, same discipline as `stub-append --strategy item-split`.

**4. The approval gate is identical on every path.** `proposal approved` remains the only thing that
unlocks `plan`; a spike's `findings.md` is presented and needs an explicit "noted" before archive. The
router (change 033) gets a Red-Flag row: *"too small to need a proposal" → it is a bounded change; the
proposal is five lines.*

**5. Dashboard.** `STATUS.md` rows show the size glyph (`⚡ spike`, `▫ bounded`, `▣ architectural`) so
the operator sees at a glance how much ceremony each active change carries.

## Scope

### In Scope
- Size field in `templates/proposal.md`, elicitation/announcement in `skills/propose/SKILL.md`.
- `state.json` `size`; `specclaw-set-phase --size`; new `bin/specclaw-set-size` (upgrade-only).
- Size-aware `specclaw-validate-change`; `skills/plan/SKILL.md` per-size artifact list;
  `templates/findings.md`; `skills/archive` accepting a spike straight from `plan`.
- Ratchet hooks in `skills/build/SKILL.md` and `specclaw-loop` (advisory: they *call* set-size and
  report; they do not decide silently).
- `specclaw-update-status`/`specclaw-status-row` glyphs; bats for validate-change matrix and ratchet
  refusals. Shellcheck-clean.

### Out of Scope
- In-chat designs with no file. Bounded still writes `spec.md`.
- The visual companion / browser server.
- Changing what `build`, `verify`, `pr` do for bounded and architectural — they are unchanged.
- Auto-classifying from diff size after the fact. Size is declared before work, upgraded during, never
  inferred afterwards.

## Impact

- **Files affected:** ~9 (estimated) — `templates/proposal.md`, `templates/findings.md`,
  `skills/{propose,plan,build,archive}/SKILL.md`, `specclaw-validate-change`, `specclaw-set-phase`,
  new `specclaw-set-size`, `specclaw-status-row`, bats.
- **Complexity:** medium — the contract change is in `validate-change`; everything else is
  template/skill text.
- **Risk:** medium — `validate-change` is a prerequisite gate for every phase; a bug there blocks all
  changes. Mitigation: a change with no `size` in `state.json` is treated as `architectural` (today's
  behaviour), so every existing change is unaffected.

## Open Questions

1. **Does a bounded change get a `design.md` section inside `spec.md`** ("Approach", ≤ 10 lines) or
   truly nothing? Lean: one inline section — the file map is what `verify` checks scope against.
2. **Who may upgrade during the loop?** The controller can detect `files:` drift mechanically; should it
   halt with `size-upgrade-needed` rather than upgrade itself? Lean: halt and ask — an upgrade changes
   what the operator approved.
3. **Is a spike allowed to leave a branch?** Throwaway code on a `specclaw/<change>` branch that is never
   merged — delete on archive, or keep for reference?
4. **Should party mode's classifier tiers map 1:1** (`light → bounded`, `standard/deep → architectural`)
   or stay independent signals?

---

**To proceed:** Review this proposal and approve to begin planning.
