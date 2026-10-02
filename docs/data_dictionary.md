# Data Dictionary

Starter notes on how the FARS 2024 tables fit together. Expand this as we design the schema.

## Core tables and keys

| Table | One row per | Primary key |
|---|---|---|
| `accident` | crash | `ST_CASE` |
| `vehicle` | vehicle in a crash | `ST_CASE, VEH_NO` |
| `person` | person involved | `ST_CASE, VEH_NO, PER_NO` |

`ST_CASE` is unique nationally. Its leading digits encode `STATE`, so it's the crash ID used everywhere.

```
accident (ST_CASE)
   ├── vehicle (ST_CASE, VEH_NO)
   │      └── person (ST_CASE, VEH_NO, PER_NO)   ← motorists
   └── person (ST_CASE, VEH_NO = 0, PER_NO)       ← non-motorists (pedestrians, cyclists)
```

> **Watch out:** 9,020 rows in `person` have `VEH_NO = 0`. These are non-motorists, so they don't match any vehicle. A foreign key from `person` to `vehicle` would reject them. Decide as a team how to model this (for example, a separate non-motorist table, or an FK only to `accident`).

## Child tables, grouped by the key they hang off

| Level | Tables |
|---|---|
| Crash (`ST_CASE`) | `cevent`, `crashrf`, `weather`, `ACC_AUX`, `MIACC`, `MIDRVACC` |
| Vehicle (`ST_CASE, VEH_NO`) | `damage`, `distract`, `drimpair`, `driverrf`, `factor`, `maneuver`, `parkwork`, `pvehiclesf`, `vehiclesf`, `violatn`, `vision`, `vevent`, `vsoe`, `vpicdecode`, `vpictrailerdecode`, `VEH_AUX` |
| Person (`ST_CASE, VEH_NO, PER_NO`) | `drugs`, `race`, `personrf`, `pbtype`, `safetyeq`, `nmcrash`, `nmdistract`, `nmimpair`, `nmprior`, `PER_AUX`, `MIPER` |

`parkwork` and `pvehiclesf` describe parked/working vehicles, which are numbered separately from the in-transport vehicles in `vehicle`, so none of their 1,526 rows match a `vehicle` row (checked on the 2024 data). Don't give them a foreign key to `vehicle`.

Many of these are "multi-row" tables. For example, a person can have several `drugs` rows, so their primary key needs an extra column. Check each one before writing DDL.

`drugs` even has 748 rows that are exact copies of another row. These are real repeated test results (for example, two different drugs both coded "Other Drug"), not errors, so `drugs` will need a surrogate key such as an auto-increment `drug_id`.

`race.ORDER` is renamed `RACE_ORDER` in `data/processed/` because `ORDER` is a MySQL keyword.

## Code vs. label columns
In the raw files almost every coded column `X` has a matching text column `XNAME`, e.g. `STATE`/`STATENAME`, `HARM_EV`/`HARM_EVNAME`. In `data/processed/` the codes stay in the tables and the text lives in `data/processed/lookups/`:

| Lookup | Key | Example |
|---|---|---|
| `code_labels.csv` | `column, code` | `HARM_EV, 42` → Tree (Standing Only) |
| `county.csv` | `STATE, COUNTY` | `1, 125` → TUSCALOOSA (125) |
| `city.csv` | `STATE, CITY` | `6, 1980` → LOS ANGELES (city codes repeat across states) |

Getting a label back is a join:
```sql
SELECT a.ST_CASE, a.HARM_EV, l.label AS harm_ev_name
FROM accident a
JOIN code_labels l ON l.`column` = 'HARM_EV' AND l.code = a.HARM_EV;
```

Labels that only repeated the code (e.g. `LATITUDENAME` = `LATITUDE`) aren't in the lookups. The value is still in the code column. A few codes had more than one spelling in the raw data. `lookups/label_conflicts.csv` lists every variant and which one was kept.
