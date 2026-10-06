# MySQL Database Setup

The MySQL schema and data-loading pipeline are now complete.

The final database contains:

- 53 relational tables
- 53 primary keys
- 44 foreign key constraints
- 2,173,931 rows across the final tables

All 39 processed CSV files were successfully loaded and verified.

## 1. Pull the latest repository

After this PR is merged:

```bash
git checkout main
git pull origin main
```

Run the following commands from the repository root.

## 2. Create the MySQL schema

```bash
/usr/local/mysql/bin/mysql -u root -p < sql/schema/01_create_tables.sql
```

This creates the `fars` database and its 53 tables.

## 3. Create staging tables

```bash
/usr/local/mysql/bin/mysql -u root -p < sql/load/01_load_staging_tables.sql
```

This creates the temporary `fars_stage` database.

All staging columns are stored as text so the CSV data is preserved before type conversion.

## 4. Enable LOCAL INFILE

Check whether it is enabled:

```sql
SHOW VARIABLES LIKE 'local_infile';
```

If it is OFF, run in MySQL Workbench:

```sql
SET GLOBAL local_infile = ON;
```

## 5. Load the processed CSV files

Run:

```bash
/usr/local/mysql/bin/mysql --local-infile=1 -u root -p < sql/load/02_load_staging_data.sql
```

A successful staging load should show all 39 files as `PASS`, for example:

```text
staging_table    expected_rows    actual_rows    load_warnings    status

accident         36297            36297          0                PASS
person           88326            88326          0                PASS
vehicle          56011            56011          0                PASS
...
```

All 39 rows should show:

```text
load_warnings = 0
status = PASS
```

## 6. Load the normalized database

Run scripts 03 through 11 in order:

```bash
cat sql/load/03_load_reference.sql \
    sql/load/04_load_accident.sql \
    sql/load/05_load_crash_unit.sql \
    sql/load/06_load_vehicle_parkwork.sql \
    sql/load/07_load_person.sql \
    sql/load/08_load_crash_children.sql \
    sql/load/09_load_vehicle_children.sql \
    sql/load/10_load_unit_children.sql \
    sql/load/11_load_person_children.sql \
| /usr/local/mysql/bin/mysql -u root -p
```

If the command finishes without an error, the tables have been loaded.

## 7. Verify the database

Run:

```bash
/usr/local/mysql/bin/mysql -u root -p -t < sql/load/12_load_verify.sql
```

A successful result should include:

```text
Staging tables present                         39 / 39   PASS
LOAD DATA warnings                              0 / 0    PASS

fars tables present                            53 / 53   PASS
fars tables with expected row count            53 / 53   PASS
Rows loaded into fars                     2173931 / 2173931 PASS
Foreign key constraints                        44 / 44   PASS
```

The final summary should be:

```text
checks    passed    failed
29        29        0
```

You can use a screenshot of this output as evidence that the dataset was successfully imported into MySQL.

## 8. SQL exploration

Once verification passes, the database is ready for individual SQL exploration.

Use:

```sql
USE fars;
```

Each member can then independently write their required:

- 2 basic SQL queries
- 2 advanced SQL queries

Query files can be added under:

```text
sql/queries/
```

For example:

```text
sql/queries/matt_queries.sql
sql/queries/ryan_queries.sql
```

## Notes

`13_load_drop_staging.sql` is optional.

Do not run it until the staging tables are no longer needed for debugging or source-to-target comparison.