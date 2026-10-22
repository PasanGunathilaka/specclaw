# Architecture Report: {{title}}

**Path analyzed:** {{path}}
**Date analyzed:** {{date}}

<!--
  Stack references (conditional, additive). If — and ONLY if — one or more stack
  references resolved this run (see the analyst agent's "Stack references" rule),
  emit a single line here, below the metadata block and above the first `##`
  heading:

      Stack references applied: <comma-separated reference filenames>

  If no stack reference resolved, omit this line entirely — no line, no heading.
  A reference is methodology only and is never cited as evidence (PD-09, PD-10).
-->

## System Context (L1)

```mermaid
{{l1_diagram}}
```

{{l1_narrative}}

## Containers (L2)

```mermaid
{{l2_diagram}}
```

{{l2_narrative}}

## Components (L3)

```mermaid
{{l3_diagram}}
```

{{l3_narrative}}

## Code (L4)

```mermaid
{{l4_diagram}}
```

{{l4_narrative}}
