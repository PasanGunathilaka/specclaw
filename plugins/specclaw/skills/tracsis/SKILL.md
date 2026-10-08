---
description: Analyzes a converted Oracle Forms XML export (_fmb.xml/_mmb.xml/_olb.xml) for the Tracsis Modernization project: web connections, UI coordinates, triggers, data blocks, mapped to React + Tailwind. Writes <FORM_NAME>_SYSTEM_SPEC.md. Use when reverse-engineering an Oracle Forms module.
---

# specclaw tracsis

Analyze a converted Oracle Forms XML file and write its system specification. Read-only with respect to the source XML — writes only the generated `<FORM_NAME>_SYSTEM_SPEC.md`. Standalone: no `.specclaw/` project state required.

1. **Resolve the target file.** If the user's message names a path, use it (validate it exists). Otherwise look for `*_fmb.xml` file(s) in the current directory, or the directory the user named:
   ```bash
   ls *_fmb.xml 2>/dev/null
   ```
   If more than one is found, ask the user which one before proceeding — never guess which form they meant.

2. **Validate the file exists.** If it doesn't, surface that to the user and stop — don't invent a path or proceed on a guess.

3. **Check for companion files** in the same directory as the `_fmb.xml` (soft — pass paths if present, don't fail if absent):
   ```bash
   ls "<dir>"/*_mmb.xml 2>/dev/null
   ls "<dir>"/*_olb.xml 2>/dev/null
   ```
   These are optional context (menu definitions, shared object libraries the form may reference) — the agent runs fine without them.

4. **Resolve the output directory.** Default to the same directory as the source `_fmb.xml`, unless the user's message names a different output location. The exact filename (`<FORM_NAME>_SYSTEM_SPEC.md`) is decided by the agent from the module's own real name — this skill only resolves the directory.

5. **Spawn the analysis agent:** `Agent` tool, `subagent_type: "tracsis"`. Pass as context:
   - The resolved `_fmb.xml` path.
   - The resolved `_mmb.xml`/`_olb.xml` paths, if present (Step 3).
   - The resolved output directory (Step 4).
   - The resolved template path (`$CLAUDE_PLUGIN_ROOT/templates/tracsis-system-spec.md`).

6. The agent reads the XML, performs the full seven-part analysis, and writes `<FORM_NAME>_SYSTEM_SPEC.md` itself, per its own Output section — this skill does not write the file.

7. **Relay the agent's summary to the user** — the form name analyzed, the output file's full path, the connection/trigger counts, and any part it could not complete with real evidence. Don't paraphrase away the gap list; that's exactly what a reviewer needs to know before trusting the document.

## What this command does not do

It never assumes a fixed Oracle Forms XML schema — every tag/attribute name it relies on is confirmed against the actual file in that run, never templated from memory. It never fabricates a business rationale for a connection it can't ground in what it read, never invents a layout coordinate that isn't literally in the file, and never claims the Part 7 React/Tailwind mapping is more than a structural starting point for the modernization team.
