# Import verification — FARS 2024 in MySQL

Author: Jue Wang | Date: TODO

Purpose: evidence that the schema builds and the data loads — required for the
mid-presentation ("row counts, sample queries"). Run after
`sql/schema/*.sql` and `sql/load/*.sql`.

## How it was run

```
mysql -u root -p < sql/schema/01_create_core_tables.sql
mysql -u root -p < sql/schema/02_create_child_tables.sql
mysql -u root -p < sql/schema/03_create_lookups.sql
mysql -u root -p < sql/load/*.sql        -- load scripts, in order
mysql -u root -p < sql/schema/04_constraints_indexes.sql
```

MySQL version: TODO (`SELECT VERSION();`)

## Row counts

| Table    | Rows in MySQL | Rows in processed CSV | Match? |
|----------|---------------|-----------------------|--------|
| accident | TODO          | TODO                  |        |
| vehicle  | TODO          | TODO                  |        |
| person   | TODO          | TODO                  |        |
| drugs    | TODO          | TODO                  |        |
| ...      |               |                       |        |

Get CSV counts with `wc -l data/processed/<file>.csv` (minus 1 for the header).

## Sample queries

```sql
-- 1. One crash with its vehicles and people
SELECT a.ST_CASE, a.STATE, v.VEH_NO, p.PER_NO
FROM accident a
JOIN vehicle v ON v.ST_CASE = a.ST_CASE
JOIN person  p ON p.ST_CASE = v.ST_CASE AND p.VEH_NO = v.VEH_NO
LIMIT 5;

-- 2. Non-motorists are present and joinable to their crash
SELECT COUNT(*) AS non_motorists
FROM person
WHERE VEH_NO = 0;

-- 3. Label lookup join works
SELECT a.ST_CASE, a.HARM_EV, l.label AS harm_ev_name
FROM accident a
JOIN code_labels l
  ON l.`column` = 'HARM_EV' AND l.code = a.HARM_EV
LIMIT 5;

-- 4. FK integrity: every vehicle/person points at a real crash
SELECT COUNT(*) AS orphan_vehicles
FROM vehicle v LEFT JOIN accident a ON a.ST_CASE = v.ST_CASE
WHERE a.ST_CASE IS NULL;
-- expect 0
```

Paste the result of each query below (or screenshot into `reports/`).

### Results

TODO
