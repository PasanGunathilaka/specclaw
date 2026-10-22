# Review memory: read it only through MCP

`.specclaw/review-memory/` holds this repo's review lessons. **Never open, grep, cat or edit it directly.**
It grows without limit; a direct read loads all of it into context.

- To read lessons, call the `memory_query` MCP tool (server `specclaw-review`) with the files you are working
  on. It returns the relevant top lessons within a fixed token budget. Without MCP, run
  `specclaw-review memory query --files <paths>`.
- To record a lesson, call `memory_put`. Review rounds (`review_run`) record their own findings.
- Rules belong in `.specclaw/review/rules/*.md`. Those files are meant to be read and edited.
