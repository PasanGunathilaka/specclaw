# Design: Session-start bootstrap and intent router

**Change:** 033-session-bootstrap-router
**Created:** 2026-09-19

## Three files, one of which is prose and is the actual product

```
hooks/hooks.json               registration                          (12 lines)
hooks/session-start            the emitter — config gate, JSON, fail-open
bin/specclaw-bootstrap-snapshot  the live state block, from disk only
skills/using-specclaw/SKILL.md the router text — injected verbatim
```

The mechanism is small. The work is the router text, and the constraint on it is a byte cap: this
runs on **every** session start, clear and compact in the project, so every sentence is paid for
repeatedly. 8000 bytes, enforced by the suite, is the whole design pressure.

## The config gate, and why it is the config file

```bash
[ -f "./.specclaw/config.yaml" ] || exit 0
```

Not `-d .specclaw`. A `.specclaw/` directory turns up in repos that once had a change dir committed,
in vendored copies, and in this plugin's own test fixtures. `config.yaml` is what `specclaw-init`
writes and what every script reads; its presence is the definition of "this is a specclaw project".

`bootstrap.enabled` is then read **block-scoped**, with the same discipline `party_val` documents at
length in the plugin `CLAUDE.md`:

```
yaml_val config bootstrap.enabled   →  greps `enabled:` across the whole file
                                    →  finds build.dynamic_agents.enabled → false
```

That is not a hypothetical. The shipped `config.yaml` carries `enabled:` under `loop:`, under
`party:`, under `build.dynamic_agents:` and under `notifications:` — four of them above where
`bootstrap:` will sit. A whole-file read would switch the bootstrap off, or on, according to
whichever block happens to come first, while the config plainly says otherwise. So the hook seeks the
column-0 `bootstrap:` line and reads only until the next column-0 key.

## Why `printf` and not a heredoc

superpowers hit a bash 5.3 heredoc hang building exactly this payload (their issue #571). The output
is a single line of JSON assembled from `printf`, with escaping done in parameter substitution. It is
uglier and it cannot hang.

## Fail-open, stated precisely

Every path exits 0. There are exactly three outcomes:

| Situation | stdout | exit |
|---|---|---|
| not a specclaw project, or `enabled: false` | *empty* | 0 |
| healthy | one JSON object, router + snapshot | 0 |
| snapshot failed (corrupt state, missing tool) | one JSON object, router only | 0 |

The third row is the one worth designing for. A partial JSON document is worse than no document —
the harness would reject it and the session would start with a parse error instead of a router — so
the snapshot is captured into a variable **first**, and only a successful capture is included.

## The forcing gate is scoped to one route, on purpose

superpowers' doctrine — *"if there is even a 1% chance a skill applies you ABSOLUTELY MUST invoke
it"* — is persuasion-heavy and non-deterministic. Applied to every verb it makes the router a mood
rather than a table.

It is taken for `propose` and nothing else, because `propose` is the only route with **no recovery
path**. A change that begins without a proposal has no change dir, and no later verb can create one
retroactively: the paper trail is lost at that moment or not at all. Every other row can be reached
late — a build can be verified afterwards, a bug can be debugged after being noticed — so every other
row is advisory and may be declined.

## The snapshot is what makes the routing controlled

superpowers injects a doctrine. This injects a doctrine **and the project's recorded state**:

```
## specclaw state (live, 2026-09-19 10:41 UTC)
- 032-party-mode ▫ — build in progress, 6/8 tasks, 0 failed
- 028-phase-time-accounting — proposal awaiting approval
```

"The tests are failing", said mid-build, routes to the loop or to `/specclaw:debug`. Said on a clean
tree, it is new work. Without state in context the model cannot tell the two apart, and no amount of
routing prose fixes that. The snapshot reads `state.json`, `tasks.md` (through
`specclaw-parse-tasks --count`, the only counter) and `proposal.md` — **all from disk, never a model
turn** — and writes nothing at all, so a session start has no side effects.

## Test plan

`tests/run-bootstrap-hook-tests.sh`, bash + coreutils, CI-registered: the two silent paths, the
healthy path's JSON validity and content, the snapshot-off path, the corrupt-state path, the
block-scoped config read against a fixture carrying four decoy `enabled:` keys above `bootstrap:`,
the byte cap against a 12-change project, the no-write guarantee, `max_lines`, the two-builds case,
and `hooks.json`'s own validity.
