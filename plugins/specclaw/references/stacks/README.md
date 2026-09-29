# Stack references

On-demand, per-stack **reading guidance** for the brownfield analysis agents
(`bf-codebase-analyst`, `bf-domain-analyst`, `bf-architecture-analyst`) — how to
*read* a legacy estate: what each artifact is, where logic hides, what to ask.
Resolved on demand from facts the collector already emits; nothing here changes
the collector or any command's execution path.

## One reference file

- **Filename:** `<stack-id>.md` here (e.g. `oracle-era.md`).
- **Required headings** (see `oracle-era.md`): `1. Artifact map`,
  `2. Where the business rules usually are`, `3. Coupling and boundaries`,
  `4. Version and topology signals`, `5. Binary limitations`,
  `6. Guidance for bf-analyze`, `7. Guidance for bf-domain`,
  `8. Guidance for bf-architecture`, `9. Not in this file`.
- **Guidance only** — it describes how to read a stack, never a target, a
  migration, a "modern equivalent", or an effort estimate.

## How a reference resolves — `index.json`

Declarative data, not logic. Each `stacks[]` entry names a `file` and a
`resolve_any` list of predicates over the collector's `artifact_categories`
(including its `by_extension` map). A stack resolves when **any** predicate holds:

- `category_present: "<name>"` — `<name>` is a key of `artifact_categories` (the
  collector omits zero-file categories, so a present key means count > 0).
- `category_extension_any: { "category", "extensions": [...] }` — that category's
  `by_extension` contains **any** listed extension.
- `all_of: [ ... ]` — every listed predicate holds.

Adding a future stack is one `stacks[]` entry plus one `<stack-id>.md` file — no
command or agent code changes.

## Two rules that never bend

- **PD-09** — a reference is never repository evidence: it may say what to
  inspect, never justify a finding, and is never quoted/cited in a report.
- **PD-10** — a reference increases investigation depth, not confidence: folder
  names, filenames and conventions stay signals to investigate, never claims
  without repository evidence opened this run.
