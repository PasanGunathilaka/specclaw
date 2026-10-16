## Node rules

- **ND1** A promise that is neither awaited nor returned (floating), or `forEach(async …)` where order or
  completion matters → **major**.
- **ND2** Errors swallowed by `.catch(() => {})` or by a `try` that returns a default (B3) → **major**.
- **ND3** `child_process.exec` with interpolated input → **blocker** (B8). Use `execFile`/`spawn` with an
  argument array instead.
- **ND4** `==` against values that may be `0`, `""` or `null` where they mean different things → **major**
  with a scenario.
- **ND5** Unbounded `JSON.parse` of external input without try/catch → **major** (B6).
