# Client Decision Pack: {{title}}

**Plugin version:** {{plugin_version}}
**Generated:** {{date}}
**Source:** .specclaw/analysis/clarifications.md (+ decisions.md, where a decision is already recorded)

{{counts}}

<!--
  NOTE ON THIS COMMENT: never write a literal double-brace placeholder token
  inside this comment's own prose (not even to describe it) — the render
  step's template substitution is a first-occurrence string replace, and a
  token mentioned here would be consumed by this comment instead of the real
  placeholder below. Refer to placeholders by section name instead.

  This is the client-readable face of /specclaw-bf:bf-clarify. It packages the
  BLOCKING questions a rebuild cannot proceed past into a decision paper a
  non-engineer stakeholder can actually read, decide on, and sign.

  IT IS NOT A DECISION MECHANISM. Nothing is ever recorded here. A client's
  choice is written into clarifications.md's own **Answer:**/**Decided by:**/
  **Date:** fields — attributed to the named human who made it, never to
  "the client" and never to an AI agent — and /specclaw-bf:bf-clarify --resolve
  then promotes it into decisions.md. That is the one and only path a
  decision travels, exactly as it was before this document existed.

  WHO WRITES WHAT. The counts line above, the Already Decided section, the
  Not Applicable section, and every "Client decision:" line below are
  computed and written by bash from clarifications.md and decisions.md —
  transcription, never judgement. The agent writes only the per-question
  restatement, the options, the trade-offs and the recommendation. No agent
  ever derives whether a question is decided.

  FULLY REGENERATED EVERY RUN. There is no hand-preserved zone anywhere in
  this file — unlike rebuild-backlog.md's human-added status notes. A
  client's selections survive a regeneration because they live in
  clarifications.md, not here. Editing this file directly is always the
  wrong move: the edit is lost on the next run and never reaches
  decisions.md.

  BLOCKING QUESTIONS ONLY. A non-blocking question is real, and it is asked
  in clarifications.md — it just does not belong in front of a client whose
  time is being spent on what actually holds the rebuild up. The footer
  states how many were excluded.

  OPTIONS ARE GENERATED PER RUN, NEVER TEMPLATED. There is no menu of
  databases, hosts or frameworks in this file or in any bash script — a
  hardcoded stack name here would be an architectural violation. The agent
  generates candidate options at run time from what this repo's own legacy
  analysis shows, and grounds each one in a file:line or a document section.

  Archive-then-replace applies: a re-run archives the prior version into
  .specclaw/analysis/archive/ before writing a new one, exactly like
  clarifications.md and decisions.md.
-->

## How to use this document

1. Read each question under **Pending Client Decisions**. Each one states what
   is being asked, what the realistic options are, what each option means for
   *this* system, and which one we recommend and why.
2. A **Recommended:** line is advice, not a decision. Choosing against it is a
   normal outcome and needs no justification.
3. Record the choice by opening `.specclaw/analysis/clarifications.md`, finding
   that question's `### <ID>` block, and filling in three fields:
   - `- **Answer:**` — the option chosen, in a sentence.
   - `- **Decided by:**` — **the name of the person who decided.** Not "the
     client", not a company name, not an AI agent. A decision with no named
     human behind it cannot be followed up, questioned, or revisited.
   - `- **Date:**` — `YYYY-MM-DD`.
4. Run `/specclaw-bf:bf-clarify --resolve` to promote the answers into
   `.specclaw/analysis/decisions.md`, the record every downstream command reads.
5. Re-run `/specclaw-bf:bf-clarify --options-pack` to regenerate this document. A
   question answered in step 3 moves from *Pending* to *Already Decided*.

Every factual claim about the existing system below cites where it came from —
a `file:line` or a document section. A statement that is professional judgement
rather than evidence is labelled `(judgment)`.

## Pending Client Decisions

{{pending_decisions}}

## Already Decided

{{already_decided}}

## Not Applicable

{{not_applicable}}

## What Happens Next

Every pending question above blocks part of the rebuild. Until it is answered,
the affected work is either held, or planned against a provisional default that
is labelled as provisional wherever it appears — in the rebuild backlog, in the
target architecture blueprint, and in any replay verdict that rests on it.

Answering these does not commit anyone to a schedule. It commits to a direction,
and it lets the rebuild stop guessing.

---

{{non_blocking_note}}
