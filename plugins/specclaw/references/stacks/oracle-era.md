# Oracle-era stack reference

Reading guidance for an agent that has never seen an Oracle-era estate — server-side
PL/SQL (packages, triggers, views, types), SQL*Loader ingestion, and Forms/Reports
clients. It describes how to **read** this stack: what each artifact is, where logic
hides, and what to ask. It is methodology only. Nothing here is evidence about any
repository; every claim in a report still rests on a file opened this run (PD-09),
and a reference deepens investigation without raising confidence (PD-10).

## 1. Artifact map

What each artifact is and where its logic lives:

- `.pkh` / `.pks` — package **spec** (the public contract). Read these FIRST and list
  the entry points a package exposes.
- `.pkb` / `.plb` — package **body** (the implementation behind a spec).
- `.prc` / `.fnc` — standalone procedures / functions.
- `.trg` — triggers: implicit rules that fire on DML. Never skip them; logic here runs
  without any caller naming it.
- `.vw` — views: often the surface where one schema reads another's data.
- `.typ` / `.tps` / `.tpb` — object types (spec and body).
- `.sql` — mixed DDL/DML/scripts. Classify by **content**, not the extension: DDL →
  schema facts; grants / synonyms / database links → coupling candidates; anonymous
  blocks → job/script candidates.
- `.ctl` — SQL*Loader control files: an ingestion route candidate (source file →
  target table).
- `.fmb` / `.mmb` / `.pll` / `.olb` — Forms binaries.
- `.rdf` — Reports binaries.

## 2. Where the business rules usually are

In this stack, logic typically sits in packages, triggers and constraints — not in UI
code. Enumerate, and treat each as a candidate until the file is opened and cited:

- packages, by spec (`.pkh`/`.pks`), then the matching body;
- triggers per table (`.trg`);
- `CHECK` / foreign-key / unique constraints from DDL;
- `DBMS_JOB` / `DBMS_SCHEDULER` calls, and cron-driven `sqlplus` / `sqlldr` scripts, as
  workflow entry-point candidates.

Every item found is a candidate; it becomes a finding only after the file is opened and
quoted.

## 3. Coupling and boundaries

What to look for: `GRANT`, `CREATE SYNONYM`, `CREATE DATABASE LINK`, views selecting
from another schema, `schema.object` qualified references, and shared sequences.

A schema is a container-boundary **candidate**; grants, synonyms, views and database
links are edge **candidates**, reportable as `direct database coupling` only with a
`[path:line]` citation. The same DDL repeated under different owners is a signal to
investigate as multi-tenant-by-schema — do not count it as duplicated logic without
evidence.

## 4. Version and topology signals

Folder names, filenames, comments and headers that carry a product version are
**historical signals only** (PD-10). To establish a runtime, look for deployment
descriptors, configuration, scripts or release notes that state it. When signals
conflict, or no runtime evidence exists, write:

`Insufficient evidence to determine current runtime; signals: <list with paths>`

Never assert a production version from a path or a folder name.

## 5. Binary limitations

Forms/Reports binaries (`.fmb`/`.mmb`/`.pll`/`.olb`/`.rdf`): record name, size, count
and directory only. Never open, unpack, or infer screen or report behaviour from a
binary or its filename.

If XML exports (for example from `frmf2xml` or `rwconverter`) are present, treat those
as readable source and say so. Compiled Java alongside PL/SQL is recorded as "runtime
present, source absent" under limitations.

Use this sentence verbatim when only a binary is available:

`Insufficient evidence to determine <X>: only binary artifact <path> is available.`

## 6. Guidance for bf-analyze

- Report database-source LOC separately from application-language LOC.
- Group structure by schema/owner when derivable from DDL, else by directory.
- Risks to look for: present binaries with absent source; triggers as hidden logic;
  cross-schema grants; and multiple release snapshots of the same object — list all of
  them, flag `multiple snapshots present`, and do not choose one.

## 7. Guidance for bf-domain

- Entity candidates from `CREATE TABLE` DDL (columns, PK/FK). `COMMENT ON` statements
  are first-class domain evidence.
- Business rules from package procedures, triggers and `CHECK` constraints; cite the
  procedure `[path:line]`, not the table.
- Workflows from procedure call chains and job/loader scripts.
- Value objects from record and object types.
- Never derive an entity from a table name alone when the DDL is absent.

## 8. Guidance for bf-architecture

- Container candidates: each schema; and each runtime that connects (Forms server,
  report server, application server, loader host, scheduler) — only where config, a
  script or a deployment descriptor proves it.
- Components: packages grouped by prefix or schema.
- Edges: SQL over JDBC/OCI, direct table write, database link, and file-drop → loader.
- Draw the database as a container, not an external system. Annotate binaries-only
  runtimes `source unavailable`.

## 9. Not in this file

This file does not name any target stack, any migration pattern, any "modern
equivalent", or any effort heuristic. It describes how to read the stack, and nothing
about what to rebuild it into.
