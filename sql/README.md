# SQL

| Folder | Contents | Naming |
|---|---|---|
| `schema/` | `CREATE TABLE`, indexes, constraints | `01_create_tables.sql`, `02_create_lookups.sql`, … (run in order) |
| `load/` | Scripts that load `data/processed/` into MySQL | `01_load_accident.sql`, … |
| `queries/` | Analysis queries: one question per file, with the question in a comment at the top | `q01_deadliest_states.sql`, … |

Run a file from the terminal:
```bash
mysql -u root -p < sql/schema/01_create_tables.sql
```
Or open it in MySQL Workbench and execute it there.
