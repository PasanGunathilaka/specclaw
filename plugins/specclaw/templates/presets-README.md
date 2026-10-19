# Project presets

Coding presets for this repo. Lean build reads every file `specclaw-presets .specclaw` prints:
`base` first, then each name in `config.yaml` `presets: [..]`.

- `<name>.md` here **replaces** the built-in preset of the same name (`base`, `dotnet`, `node`,
  `nextjs`, `python`, `react-spa`), or adds a new one (`acme-dotnet`, `go`). List it in `presets:`.
- Make `Extends: <name>` the first line (only `#` headings may come before it) to keep that
  preset and add your rules after it. `Extends: dotnet` in `dotnet.md` keeps the built-in dotnet.
  An `Extends:` line anywhere else, or with extra text, is reported as an error.
- Names are lowercase letters, digits and hyphens. Unknown names are reported by `specclaw-presets`.
- Presets are prose guidance. `specclaw-preset-check` only enforces the built-in mechanical rules.
