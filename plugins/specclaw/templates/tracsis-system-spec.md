# {{form_name}} — System Specification

**Source file(s):** {{source_files}}
**Date generated:** {{date}}

## Part 1 — System Overview, Architecture & Web Connection Rationale

{{overview}}

## Part 2 — Legacy Connection Protocols & Communication Matrix

| Protocol | Trigger / Location | Target | Parameters Passed | Business Rationale |
|---|---|---|---|---|
{{connection_matrix_rows}}

## Part 3 — Form Canvas Metadata

{{canvas_metadata}}

## Part 4 — UI Layout & Absolute Coordinates

| Canvas | Control Name | Control Type | X | Y | Width | Height |
|---|---|---|---|---|---|---|
{{layout_rows}}

## Part 5 — Structural Hierarchy (Canvases & Data Blocks)

{{structural_hierarchy}}

## Part 6 — Trigger & PL/SQL Business Logic Inventory

| Trigger | Scope | Fires On | Business Logic Summary |
|---|---|---|---|
{{trigger_inventory_rows}}

## Part 7 — Modern React + Tailwind TSX Component Code

{{react_components}}
