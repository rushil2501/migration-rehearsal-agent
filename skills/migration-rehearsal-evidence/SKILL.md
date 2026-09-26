---
name: migration-rehearsal-evidence
description: Use when rehearsing a PostgreSQL column rename to classify source-code references and assemble evidence before the production approval gate.
---

# Migration rehearsal evidence

Use this runbook for a proposed `ALTER TABLE ... RENAME COLUMN ... TO ...`.
The agent manifest controls the ordered workflow, database aliases, and final
approval gate. This skill supplies the evidence checks and report vocabulary.

## Classify source references

1. Derive the table, old column, and new column from the user's SQL. Do not
   substitute identifiers from an example migration.
2. Count a source file as scanned only after reading its actual content. A
   GitHub MCP acknowledgment or blob SHA is not source text. Record the ref,
   files enumerated, files read, unreadable files, and limit-skipped files.
3. Split SQL into statements, including SQL inside application strings. Bind
   table aliases and unqualified column names within each statement only.
   Never borrow the table from another statement in the same file.
4. Classify each match as one of:
   - **Direct break candidate:** a statement reads or writes the old column on
     the renamed table or an alias bound to that table.
   - **View-output reference:** a statement reads the old output name from a
     dependent view, without referring directly to the renamed base table.
   - **Ambiguous application reference:** a model field, variable, or SQL
     fragment whose relation to the table is not established by the source.
5. Cite the exact line containing each matched old-column token. Count
   affected SQL statements separately from individual token occurrences; one
   statement can contain the old column more than once. Do not call a view
   reference a direct break. Revisit its impact after the staging view check.

## Reconcile database evidence

- Inventory catalog dependencies before DDL. Separate column-level dependent
  objects from table-level internal objects such as row types and TOAST tables.
- Record whether the staging DDL succeeded. A successful ALTER alone says
  nothing about application SQL compatibility.
- Run the old direct SQL and the actual cloned view separately. A PostgreSQL
  column rename can update a view's internal reference while preserving its
  output column name; report the observed outcomes without assuming either.
- Put exact SQL error text and SQLSTATE in the report when available.

## Report and decision

Generate structured JSON in the sandbox with `migration_target`, `code_scan`,
`dependencies`, `migration`, `direct_query_check`, `view_check`, `errors`, and
`recommendation`. Repeat the key evidence in the visible chat report. Mark an
unreadable or truncated code scan `partial` or `unavailable`, never clean.
Recommend updating and retesting proven direct break candidates before a real
deployment. Let the manifest's TrueForge tool-approval policy pause the final
production call; this skill never grants approval or invokes that call.
