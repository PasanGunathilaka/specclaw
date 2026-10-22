# Preset: base

Always applies. Listed presets add to it; `preset_overrides` in `config.yaml` may change the numbers and is recorded in `change.md`.

## Code
- No comments in code files. Names carry the meaning. Tool pragmas are allowed (`eslint-disable`, `@ts-expect-error`, `noqa`, `type: ignore`, `#pragma`, `#nullable`, shebangs).
- At most 80 lines per file, tests included (`max_lines`). Split by responsibility before you reach it.
- One responsibility per function. Keep functions under the `quality.*` complexity and length thresholds.
- No abstraction with fewer than two callers, unless the preset requires the boundary.
- No dead code, no commented-out code, no TODOs.

## Duplication
- Shared code lives in the preset's shared location (named in each preset under **Shared**).
- When the same logic appears twice, extract it there: a base class, a generic handler, a shared hook or a utility.
- `specclaw-quality-scan` measures duplication; never judge it by reading the code.

## Tests
- At most one test per acceptance criterion, named after it (`ac1_…`, `AC1 …`).
- Test behaviour through the public surface. No tests for private helpers, getters or framework wiring.

## Checks
- `specclaw-preset-check .` enforces the line limit, the comment rule and any preset structure rule.
- `specclaw-quality-scan . --gate` enforces the duplication and complexity thresholds.
