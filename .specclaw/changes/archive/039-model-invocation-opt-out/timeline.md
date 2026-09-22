# Timeline: 039-model-invocation-opt-out

**Total measured (leaf spans):** 53m39s  ·  **Retries:** 0

## By kind

- **phase** — 31m22s across 3 span(s)
- **task** — 53m39s across 7 span(s)
- **wave** — 40m01s across 3 span(s)

## Slowest

- `verify-1789881582` (phase) — verify — **23m27s**
- `W3` (wave) — wave 3 — **19m14s**
- `T6` (task) — Test suite for the narration gate — **18m07s**

## Spans

| Span | Kind | Label | Model | Attempt | Status | Duration |
|---|---|---|---|---|---|---|
| `propose` | phase | propose | - | - | ok | 2m45s |
| `plan` | phase | plan | - | - | ok | 5m10s |
| `W1` | wave | wave 1 | - | - | ok | 6m59s |
| `T1` | task | Audit and classify every bf spawn site | anthropic/claude-sonnet-5 | 1 | ok | 6m50s |
| `T2` | task | Add the bf: config block | inline | 1 | ok | 3m03s |
| `T3` | task | Gitignore the collector handoff directory | inline | 1 | ok | 3m07s |
| `W2` | wave | wave 2 | - | - | ok | 13m48s |
| `T4` | task | T4 | anthropic/claude-sonnet-5 | 1 | ok | 8m12s |
| `T5` | task | T5 | anthropic/claude-sonnet-5 | 1 | ok | 13m44s |
| `W3` | wave | wave 3 | - | - | ok | 19m14s |
| `T6` | task | Test suite for the narration gate | anthropic/claude-sonnet-5 | 1 | ok | 18m07s |
| `T7` | task | Register the suite and bump the version | inline | 1 | ok | 36s |
| `verify-1789881582` | phase | verify | - | - | ok | 23m27s |

_No baseline: this project has no archived timelines to compare against yet._
