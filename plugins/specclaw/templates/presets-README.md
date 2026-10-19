# Project presets

Coding presets for this repo. Lean build reads every file `specclaw-presets .specclaw` prints:
`base` first, then each name in `config.yaml` `presets: [..]`.

- `<name>.md` here **replaces** the built-in preset of the same name (`base`, `dotnet`, `node`,
  `nextjs`, `python`, `react-spa`), or adds a new one (`acme-dotnet`, `go`). List it in `presets:`.
- To keep a preset and add your rules after it, open the file with frontmatter:

  ```markdown
  ---
  extends: dotnet
  ---
  # Our .NET rules
  ```

  `extends: dotnet` in `dotnet.md` keeps the built-in dotnet. `extends` is the only key; anything
  else in the frontmatter, a missing closing `---`, or an `extends:` line outside it, is
  reported as an error.
- Names are lowercase letters, digits and hyphens. Unknown names are reported by `specclaw-presets`.
- Presets are prose guidance. `specclaw-preset-check` only enforces the built-in mechanical rules.
