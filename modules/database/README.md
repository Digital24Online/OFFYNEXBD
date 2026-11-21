# OFFYNEX Database — implementation and completion specification

## Current implemented foundation
- Local typed field definitions, row CRUD, basic data validation, CSV import/export and recovery-oriented workspace records exist.
- This is a local table workspace, not yet a relational database engine or SQL client.

## Remaining implementation
- Add multiple tables, stable primary keys, unique constraints and schema version/migration system.
- Add relationships (one-to-one, one-to-many, many-to-many), foreign-key validation and safe cascade rules.
- Add table view with sort, filter, search, grouping, saved views and bulk edit.
- Add query builder with projections, conditions, joins, aggregates and parameterized query execution; SQL console only with safe sandboxing if included.
- Add indexes, pagination, background work and performance limits for larger datasets.
- Add import/export for CSV, JSON and XLSX with schema mapping, duplicate resolution and validation report.
- Add reports, charts, print/PDF, backups, restore and cross-table consistency checks.
- Define encryption/access control for sensitive local database files and data deletion/export policy.

## Acceptance gates
- Migration, relationship integrity, query correctness, large-table, import/export and crash-recovery tests.
- Backup/restore preserves keys, relations, constraints and data types.
- Analyze, full tests and signed Android build pass; performance and security checks recorded.
