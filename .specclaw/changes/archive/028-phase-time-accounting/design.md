# Design: Phase time accounting

**Change:** 028-phase-time-accounting
**Created:** 2026-08-01

## The ledger is append-only, and that is the design

```
changes/<change>/timeline.jsonl
{"ev":"start","span":"T5","kind":"task","label":"…","at":"…","ts":1758..,"model":"sonnet-5","attempt":2}
{"ev":"stop","span":"T5","at":"…","ts":1758..,"status":"ok"}
```

Two events per span, never a rewrite. Three consequences, all of them the point:

- **Concurrent wave tasks cannot clobber each other.** Build runs up to `parallel_tasks` agents at
  once; a file that is read-modify-written by each of them loses spans. `>>` of a single line under
  the pipe buffer does not.
- **A crashed run leaves an open span**, which `report` renders as `⏱ still running`. A ledger that
  lost the record instead would make a hang indistinguishable from a step that never started — which
  is exactly the question this change exists to answer.
- **Nothing needs to be locked**, so a timer call is one `date` and one `>>`.

`duration_s` is computed at report time from the two `ts` fields rather than stored, so a
`stop` that arrives late is still correct.

## Fail-open is a hard rule here, not a nicety

Every `specclaw-timer` call exits 0 except on a usage error. A build that fails because its
*stopwatch* broke would be a strictly worse outcome than the unaccountability this change is fixing,
and the call sites are inside the longest scripts in the plugin.

`timing.enabled: false` short-circuits `start`/`stop` before any file is touched, so switching the
feature off costs nothing and leaves no partial ledgers behind.

## The progress line is the deliverable, not the ledger

```
⏱ build 18m32s · wave 2/4 · T5 in flight 6m11s (sonnet-5, attempt 2) · slowest so far: T3 9m04s
```

The dstm-apps teardown — *"agent stopped responding (no reply for 13 min)"* — happened because the
supervisor could not tell "thinking hard" from "hung". A pane that emits this every 60 seconds is
never silent for 13 minutes, and the line names the **active step** and the **current bottleneck**,
so the judgement it enables is "this is normal" or "this is not", rather than "something is
happening".

## Baselines are project-local, and absent baselines say so

`--baseline` takes the median over spans with the same `kind` **and** `label` in that project's
`changes/archive/*/timeline.jsonl`. Not a table shipped with the plugin: that would be a median of
somebody else's hardware, test suite and network, and a comparison against it is unfalsifiable.

A project with no archived history prints the report and one line saying there is no baseline yet.
The failure to avoid is a silently absent column, which reads as "nothing was anomalous".

The anomaly marker is **descriptive only**. A slow run is not a failed one, and a timing feature that
can fail a build is a timing feature people switch off.

## What is deliberately not here

Token and dollar accounting (different data source, natural follow-up), making anything faster
(this measures; optimisation is a later change informed by the first ledgers), OTLP or any external
backend, and retroactive reconstruction for already-archived changes.

## Test plan

`tests/run-timing-tests.sh`: the span round-trip, concurrency, the unclosed span, both report
formats, `agent-runs` rows, the baseline's present and absent cases, the anomaly threshold either
side, `timing.enabled: false`, a corrupt ledger line, `run-long` without `--change`, and the PR
section's presence and absence.
