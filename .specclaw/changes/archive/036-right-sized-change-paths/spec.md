# Spec: Right-sized change paths — spike / bounded / architectural

**Change:** 036-right-sized-change-paths
**Created:** 2026-09-19
**Status:** 🟢 Approved

## Overview

Every specclaw change pays the same ceremony today: proposal → spec + design + tasks → build →
verify → PR, whether it is a new subsystem or a one-line flag. The consequence is not that small work
is slow — it is that small work **routes around specclaw entirely** and leaves no paper trail, so the
framework is least used exactly where it is most controlled.

This change gives a change a declared **size**, and makes the artifact set follow from it. The
approval gate does not move: `proposal approved` is still the only thing that unlocks `plan`, on
every path.

## Decisions (open questions resolved at approval)

| # | Question | Decision |
|---|----------|----------|
| 1 | Does a bounded change get a design section inside `spec.md`? | **Yes** — one `## Approach` section, ≤ 10 lines, carrying the file map. `verify` checks scope against that map, so removing it would remove the thing bounded changes are checked against. |
| 2 | Who may upgrade during the loop? | **Nobody automatically.** The loop and build *detect* drift and halt with `size-upgrade-needed`; a human runs `specclaw-set-size`. An upgrade changes what the operator approved. |
| 3 | May a spike leave a branch? | A spike needs no branch. `findings.md` is the deliverable and is committed like any other artifact; throwaway probe code is **not** committed. `validate-change` refusing `build`/`verify`/`pr` is what enforces it. |
| 4 | Do party tiers map 1:1 to sizes? | **Offered, not binding.** `thin → bounded`, `standard`/`deep` → `architectural` is the *default* presented at propose time; the operator may override. Two independent judgements, one of which seeds the other. |

## Requirements

### Functional Requirements

- **FR1** — `spike | bounded | architectural` is the closed set of sizes.
- **FR2** — `specclaw-set-phase … --size <s>` records `"size"` at the top level of `state.json`,
  validates it against FR1's set, and **carries it over** on every later write exactly as `branch`
  already is.
- **FR3** — A change with no recorded size is treated as `architectural` — today's behaviour — so no
  existing change is affected by this change landing.
- **FR4** — `specclaw-validate-change` is size-aware:
  | Size | `plan` | `build` | `verify` | `pr` | `archive` |
  |---|---|---|---|---|---|
  | spike | proposal.md | **refused** | **refused** | **refused** | `findings.md` |
  | bounded | proposal.md | spec.md + tasks.md (**no design.md**) | as today | as today | verify-report.md |
  | architectural | proposal.md | spec.md + design.md + tasks.md | as today | as today | verify-report.md |
- **FR5** — A spike's refusal names the recovery: *"spikes end in a recommendation; propose the
  follow-up as its own change."*
- **FR6** — `bin/specclaw-set-size <dir> <change> <new> --reason "…"` accepts **upgrades only**
  along `spike → bounded → architectural`, and refuses a downgrade or a no-op **by name**, exit 2.
- **FR7** — An upgrade appends a `Size upgraded` row to `status.md` carrying the reason, via
  `specclaw-status-row` — never a `sed` on the pipe-delimited table.
- **FR8** — `specclaw-set-size` requires a recorded phase; it re-records the current phase rather
  than writing `state.json` itself, so `specclaw-set-phase` stays the only writer of that document.
- **FR9** — `templates/proposal.md` carries a `**Size:**` line under Impact;
  `skills/propose/SKILL.md` elicits it, announces the classification with its one-sentence reason,
  and accepts an override in the approval reply.
- **FR10** — `templates/findings.md` is a new, small template: the question, what was tried, the
  recommendation, and `Code kept: none`.
- **FR11** — `skills/plan/SKILL.md` writes the per-size artifact set; `skills/archive/SKILL.md`
  accepts a spike straight from `plan`.
- **FR12** — `specclaw-update-status` renders a size glyph after the change name — `⚡` spike,
  `▫` bounded, `▣` architectural — **only when a size is actually recorded**. An absent size reads
  as `architectural` everywhere else, so glyphing the default would stamp a declared-looking `▣` on
  every change that predates sizes: a claim nobody made.
- **FR13** — `skills/build/SKILL.md` and `specclaw-loop` **call** `set-size` guidance; they never
  upgrade silently. Drift past the spec's file map halts with `size-upgrade-needed`.

### Non-Functional Requirements

- **NFR1** — `validate-change` is the prerequisite gate for every phase. A bug there blocks all
  changes, so every size read is fail-open: unreadable or absent state means `architectural`.
- **NFR2** — Bash + coreutils; no new dependency. Shellcheck-clean.

## Acceptance Criteria

- **AC-1** — `set-phase … --size bounded` writes `"size": "bounded"` into `state.json`.
- **AC-2** — A later `set-phase` with no `--size` preserves it.
- **AC-3** — `--size nonsense` exits 2 and writes nothing.
- **AC-4** — A change with no size passes `build` validation only with all three artifacts — today's
  behaviour, unchanged.
- **AC-5** — A `bounded` change passes `build` validation with `spec.md` + `tasks.md` and no
  `design.md`.
- **AC-6** — A `spike` is refused `build`, `verify` and `pr`, and the message names the follow-up.
- **AC-7** — A `spike` passes `archive` with `findings.md` and no `verify-report.md`.
- **AC-8** — `set-size` spike→bounded→architectural all succeed; each records the reason.
- **AC-9** — `set-size` architectural→bounded is refused by name, exit 2, and changes nothing.
- **AC-10** — `set-size bounded → bounded` is refused as a no-op, exit 2.
- **AC-11** — `set-size` on a change with no `state.json` exits 2 and says to record a phase first.
- **AC-12** — An upgrade upserts a `Size` row in `status.md` carrying `⬆️ <new>` and
  `upgraded from <old> — <reason>`, leaving every other line byte-identical. Upserted rather than
  appended so the row always states the *current* size; the ratchet means the history is one-way and
  the reason for the latest move is the one that matters.
- **AC-13** — bounded → architectural makes `design.md` required again: `build` validation, which
  passed a moment earlier, now fails naming `design.md`.
- **AC-14** — `templates/findings.md` exists and carries the `Code kept:` line.
- **AC-15** — In non-strict mode (`workflow.strict: false`) a spike's refusals are warnings, exit 0,
  exactly as every other `validate-change` failure behaves.

## Edge Cases

- `state.json` present but unparseable → size reads as absent → `architectural`. Never an error.
- `--size` given on a `--force`d backwards transition → recorded like any other write.
- A spike that someone gave a `spec.md` → still refused `build`; the size, not the file set, decides.

## Dependencies

None hard. 033's router gains a Red-Flag row pointing at this change; the row is prose.
