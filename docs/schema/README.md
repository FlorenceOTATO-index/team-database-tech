# Schema documentation — reading guide

Jue Wang · `jue/normalization` · 2026-10-05

## Start here

1. **`relational-schema.md`** — the final database design. Every one of the
   52 relations: columns, primary keys, foreign keys, row counts, and the
   design decisions (D1–D4). If you only read one file, read this.
2. **`normalization.md`** — how we got there. For each normal form (1NF →
   2NF → 3NF), for the core tables and then all 33 child tables: the
   functional dependencies, the checks run, the violations found, how each
   was resolved, and the lossless-join proof. Read this to understand *why*
   the schema looks the way it does.
3. **`child_tables_reference.md`** — the raw material. Original column
   lists for all 33 child CSVs, the table hierarchy tree, and the 13
   relations created by normalization. Useful when writing DDL or load
   scripts and you need to check a column name.
4. **`00_source_columns.md`** — column inventory of the three core tables
   (accident / vehicle / person).
5. **`../data_dictionary.md`** — what each column *means* (FARS definitions).

## Verification

`scripts/verify_normalization.py` replays every check from
`normalization.md` against `data/processed/` — key uniqueness, FD
violations, join-back losslessness. Run it any time the data or schema
changes:

```
python scripts/verify_normalization.py
```

## What's next

- [ ] Assign column types and generate DDL in `sql/schema/`
      (watchlist of tricky columns is at the bottom of `relational-schema.md`)
- [ ] Write `sql/load/` scripts and import into MySQL
- [ ] Draw the ERD in `docs/erd/` from `relational-schema.md`
- [ ] Open PR: `jue/normalization` → `main`
