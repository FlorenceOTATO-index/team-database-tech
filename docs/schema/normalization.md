# Normalization — FARS 2024 (up to 3NF)

Author: Jue Wang | Date: 2026-10-04

Input: `00_source_columns.md` (universal relations = one per processed CSV).
Output: the final relation list in `relational-schema.md`, and the DDL in
`sql/schema/`.

## Step 0 — Universal relations

One universal relation per source CSV, with the natural key from the source
inventory. Nothing is assumed normalized yet.

## Step 1 — Functional dependencies

FDs observed in the data (verify against the CSV headers while filling in
Step 0):

```
accident:
  ST_CASE -> STATE, COUNTY, CITY, DAY, MONTH, YEAR, HOUR, MINUTE, ... (all crash attributes)
  STATE -> STATENAME                      (removed already, see 3NF)
  (STATE, COUNTY) -> COUNTYNAME           (removed already, see 3NF)
  (STATE, CITY) -> CITYNAME               (removed already, see 3NF)

vehicle:
  (ST_CASE, VEH_NO) -> all vehicle attributes

person:
  (ST_CASE, VEH_NO, PER_NO) -> all person attributes

lookups (already in 3NF by construction):
  (column, code) -> label
  (STATE, COUNTY) -> county_name
  (STATE, CITY) -> city_name

child tables, e.g.:
  (ST_CASE, EVENTNUM) -> cevent attributes        (check exact key per table)
  (ST_CASE, VEH_NO, PER_NO, DRUGNUM) -> ...       (drugs needs surrogate key, see below)
```

## Step 2 — First normal form (1NF)

Check: every attribute atomic, no repeating groups, each row uniquely
identifiable. (Core files: accident, vehicle, person.)

- **Atomic values:** every cell holds a single code — 0 multi-value cells in
  all three files (see Evidence).
- **Repeating groups:** header scan for numbered-column patterns found only
  `VIN_1`–`VIN_12` in vehicle.csv. These are fixed positional characters of
  the VIN — atomic, fixed count — so this is not a violation; splitting them
  out would be over-normalization. No repeating groups in accident/person.
  (Multi-row facts like events, drugs, safety equipment are already separate
  child tables in FARS — e.g. `cevent`, `drugs`, `safetyeq` — which is why the
  core files don't repeat them.)
- **Row identifiability:** natural keys verified unique on real data —
  `ST_CASE` (accident), `(ST_CASE, VEH_NO)` (vehicle),
  `(ST_CASE, VEH_NO, PER_NO)` (person).

Result: all three core relations satisfy 1NF.

### Evidence

| Check | Method | Result |
|---|---|---|
| Atomic values | `grep -c ';'` per file + row spot-checks | accident: 0; vehicle: 0; person: 0 multi-value cells |
| Repeating groups | numbered-column header scan (`grep -E '_[0-9]+$'`) on all three headers | only VIN_1–VIN_12 in vehicle.csv (positional, kept deliberately); none in accident/person |
| Row identifiability | uniqueness queries (`scripts/verify_normalization.py`) | ST_CASE: True; (ST_CASE, VEH_NO): True; (ST_CASE, VEH_NO, PER_NO): True |

Full output: run `python scripts/verify_normalization.py` from the repo root.



## Step 3 — Second normal form (2NF)

Check: every non-key attribute depends on the *whole* key — no partial
dependencies. (Core files: accident, vehicle, person.)

### Functional dependency catalog

Computed from the processed CSV headers (`scripts/verify_normalization.py`):

- **FD1:** `ST_CASE →` 45 crash attributes (STATE, COUNTY, MONTH, DAY, HOUR,
  HARM_EV, MAN_COLL, VE_FORMS, … — full list in script output)
- **FD2:** `(ST_CASE, VEH_NO) →` 99 vehicle attributes (VIN, MOD_YEAR, MAKE,
  …, DR_DRINK, …)
- **FD3:** `(ST_CASE, VEH_NO, PER_NO) →` 35 person attributes (AGE, SEX,
  PER_TYP, INJ_SEV, …)

`accident` has a single-column key, so it is in 2NF by definition — partial
dependencies are impossible with a one-column key.

### Violations found

Proven on real data (each column constant within its parent group):

- `vehicle.csv`: 8 crash-grain columns depend on `ST_CASE` alone — STATE,
  VE_FORMS, MONTH, DAY, HOUR, MINUTE, HARM_EV, MAN_COLL. Example: crash
  10007's `HARM_EV = 12` is stored once per vehicle row instead of once per
  crash.
- `person.csv`: 12 crash-grain columns depend on `ST_CASE` alone (STATE,
  COUNTY, MONTH, DAY, HOUR, MINUTE, HARM_EV, MAN_COLL, SCH_BUS, RUR_URB,
  FUNC_SYS, VE_FORMS) and 16 vehicle-grain columns depend on
  `(ST_CASE, VEH_NO)` alone (MOD_YEAR, MAKE, VPICMAKE, …, MAK_MOD). Example:
  crash 10003's non-motorist row carries empty vehicle columns while
  motorist rows repeat identical values.

### Decomposition

Every attribute keeps a home — nothing is deleted. Misplaced columns stay
in their parent relation:

- **ACCIDENT** — 46 columns, PK `ST_CASE` (unchanged)
- **VEHICLE** — 101 columns, PK `(ST_CASE, VEH_NO)`, FK `ST_CASE → accident`
  (vehicle.csv minus the 8 crash-grain columns)
- **PERSON** — 38 columns, PK `(ST_CASE, VEH_NO, PER_NO)`,
  FK `ST_CASE → accident`
  (person.csv minus 12 crash-grain and 16 vehicle-grain columns)

The decomposition is dependency-preserving (FD1/FD2/FD3 each live wholly in
one relation) and lossless (re-joining on the keys recovers every moved
value — 0 mismatches across all 36 moved columns).

### Verification

- Each moved column proven constant within its parent group (empty
  exception lists — any exception would have blocked the move).
- Each *new* relation swept for leftover partial dependencies across all
  remaining columns: PERSON clean; VEHICLE clean except `UNITTYPE`, which is
  single-valued (`1` = motor vehicle in transport) on all 56,011 rows — a
  degenerate partial dependency (the FD holds vacuously); it describes the
  vehicle, so it stays in VEHICLE.
- Method: `python scripts/verify_normalization.py` → ALL CHECKS PASSED.

### Result

The three core relations are in 2NF. (Consequence: the flat `vehicle.csv`
and `person.csv` were not in 2NF and therefore not in 3NF; the decomposed
design is.)


## Step 4 — Third normal form (3NF)

Check: no transitive dependencies — no non-key attribute determined via
another non-key attribute. Applied to the decomposed design (the flat
vehicle/person fail 2NF, hence 3NF, by inheritance — Step 3).

### Transitive dependencies eliminated by the ETL

The raw FARS files carried label columns transitively dependent on their
codes (`HARM_EV → HARM_EVNAME`, `STATE → STATENAME`,
`(STATE, COUNTY) → COUNTYNAME`, …). The ETL extracted them to
`data/processed/lookups/` — accident 80 → 46 columns, vehicle 201 → 109,
person 126 → 66 (per `data/processed/manifest.json`). Verified: 0 `*NAME`
columns remain in any core file, and each lookup key is unique
(code_labels 8,892 rows; county 2,827; city 5,507) — the extracted
relations are themselves 3NF-clean.

### Transitive dependencies extracted (strict 3NF)

| # | FD | New relation | Key | Rows | Lossless proof |
|---|---|---|---|---|---|
| T1 | (YEAR, MONTH, DAY) → DAY_WEEK | CALENDAR | (YEAR, MONTH, DAY) | 366 | 0 mismatches |
| T2 | VIN → VIN_1 … VIN_12 | VIN_DETAIL | VIN | 49,396 | 0 mismatches (NaN-aware; 98 short VINs keep nulls as-is) |
| T3 | (DEATH_HR, DEATH_MN) → DEATH_TM | DEATH_TIME | (DEATH_HR, DEATH_MN) | 1,457 | 0 mismatches |

Each new table holds one row per key; re-joining reproduces every original
value exactly — no information lost. The new tables are 3NF-clean:
VIN_DETAIL has a single-column key; CALENDAR and DEATH_TIME each carry a
single non-key attribute, so no transitive chain can exist inside them.

### Final core relations (strict 3NF)

| Relation | Columns | PK | FKs |
|---|---|---|---|
| ACCIDENT | 45 (dropped DAY_WEEK) | ST_CASE | (YEAR, MONTH, DAY) → CALENDAR |
| CALENDAR | 4 | (YEAR, MONTH, DAY) | — |
| VEHICLE | 89 (dropped VIN_1..VIN_12) | (ST_CASE, VEH_NO) | ST_CASE → ACCIDENT; VIN → VIN_DETAIL |
| VIN_DETAIL | 13 | VIN | — |
| PERSON | 37 (dropped DEATH_TM) | (ST_CASE, VEH_NO, PER_NO) | ST_CASE → ACCIDENT; (DEATH_HR, DEATH_MN) → DEATH_TIME |
| DEATH_TIME | 3 | (DEATH_HR, DEATH_MN) | — |

Derived facts are recovered by join, e.g.
`accident ⋈ calendar ON (year, month, day)` and
`vehicle ⋈ vin_detail USING (vin)`. The FKs into CALENDAR/DEATH_TIME
reference non-PK columns — legal: an FK needs a unique target, not
necessarily a PK.

### FD catalog (final)

Every attribute in the processed core files is accounted for: 179
non-key attributes across 6 FDs, each stored in the relation whose key
determines it.

| FD | Determinant → dependents | Attributes | Stored in |
|----|--------------------------|-----------:|-----------|
| FD1 | ST_CASE → crash facts | 44 | ACCIDENT |
| FD2 | (ST_CASE, VEH_NO) → vehicle facts | 87 | VEHICLE |
| FD3 | (ST_CASE, VEH_NO, PER_NO) → person facts | 34 | PERSON |
| FD4 | (YEAR, MONTH, DAY) → DAY_WEEK | 1 | CALENDAR |
| FD5 | VIN → VIN_1 … VIN_12 | 12 | VIN_DETAIL |
| FD6 | (DEATH_HR, DEATH_MN) → DEATH_TM | 1 | DEATH_TIME |
| | **Total** | **179** | |

### Result

Core design is in strict 3NF: no partial dependencies (Step 3), no
transitive dependencies (Step 4). What that bought, in numbers:

- **3 flat files → 9 relations** (6 core + 3 lookups); 221 columns → 191,
  every column's determinant identified in the catalog above.
- **2NF removed 36 duplicated attributes** — 8 crash-level out of vehicle,
  12 crash-level + 16 vehicle-level out of person — eliminating
  **≈1.3M redundant cells**:
  - 8 × (56,011 − 36,297) = 157,712 (crash facts copied per vehicle)
  - 12 × (88,326 − 36,297) = 624,348 (crash facts copied per person)
  - 16 × (88,326 − 56,011) = 517,040 (vehicle facts copied per person)
- **3NF extracted 3 derived attributes** into CALENDAR (366 rows),
  VIN_DETAIL (49,396 rows) and DEATH_TIME (1,457 rows) — each proven
  lossless with 0 mismatches, so no information was lost, only relocated.
- **Verification:** `python scripts/verify_normalization.py` → ALL CHECKS PASSED.


## Step 5 — Final relations

| Relation | Primary key | Columns | Notes |
|----------|-------------|--------:|-------|
| accident | ST_CASE | 45 | one row per crash |
| calendar | (YEAR, MONTH, DAY) | 4 | one row per date; DAY_WEEK extracted (3NF) |
| vehicle | (ST_CASE, VEH_NO) | 89 | one row per in-transport vehicle |
| vin_detail | VIN | 13 | VIN_1..VIN_12 extracted (3NF); nulls kept for short VINs |
| person | (ST_CASE, VEH_NO, PER_NO) | 37 | includes non-motorists with VEH_NO = 0 |
| death_time | (DEATH_HR, DEATH_MN) | 3 | DEATH_TM extracted (3NF) |
| cevent | TODO (verify) | | crash-level events |
| drugs | drug_id (surrogate) | | duplicates make natural key impossible |
| race | TODO — note `RACE_ORDER` rename | | person-level |
| safetyeq | TODO (verify) | | person-level |
| ... | ... | | one row per child table in 00_source_columns.md |
| code_labels | (`column`, code) | 4 | lookup (8,892 rows) |
| county | (STATE, COUNTY) | 3 | lookup (2,827 rows) |
| city | (STATE, CITY) | 3 | lookup (5,507 rows) |


## Child tables

### Step 1 — First normal form (child tables)

All 32 natural keys verified unique (2026-10-05); `drugs` needs a surrogate.
Ambiguous grains were resolved empirically (e.g. `distract`: 15 vehicles
have 2 rows → grain is one-row-per-distraction, not per vehicle).

**Crash level** — key starts with `ST_CASE`:

| CSV | Rows | Key | Grain |
|---|---|---|---|
| acc_aux.csv | 36,297 | ST_CASE | one row per crash (auxiliary aggregates) |
| cevent.csv | 99,225 | (ST_CASE, EVENTNUM) | one row per crash event |
| crashrf.csv | 36,587 | (ST_CASE, CRASHRF) | one row per crash-related factor |
| miacc.csv | 36,297 | ST_CASE | one row per crash (Michigan aux) |
| midrvacc.csv | 36,229 | ST_CASE | one row per crash with driver data (Michigan) |
| weather.csv | 36,692 | (ST_CASE, WEATHER) | one row per weather condition |

**Vehicle level** — key starts with `(ST_CASE, VEH_NO)`:

| CSV | Rows | Key | Grain |
|---|---|---|---|
| damage.csv | 240,091 | (ST_CASE, VEH_NO, DAMAGE) | one row per damaged area |
| distract.csv | 56,026 | (ST_CASE, VEH_NO, DRDISTRACT) | one row per driver distraction |
| drimpair.csv | 56,181 | (ST_CASE, VEH_NO, DRIMPAIR) | one row per driver impairment |
| driverrf.csv | 62,603 | (ST_CASE, VEH_NO, DRIVERRF) | one row per driver-related factor |
| factor.csv | 56,076 | (ST_CASE, VEH_NO, VEHICLECC) | one row per vehicle circumstance |
| maneuver.csv | 56,018 | (ST_CASE, VEH_NO, MANEUVER) | one row per driver maneuver |
| parkwork.csv | 1,526 | (ST_CASE, VEH_NO) | one row per parked/working vehicle |
| pvehiclesf.csv | 1,526 | (ST_CASE, VEH_NO, PVEHICLESF) | one row per parked-vehicle safety factor |
| vehiclesf.csv | 56,013 | (ST_CASE, VEH_NO, VEHICLESF) | one row per vehicle safety factor |
| vevent.csv | 120,270 | (ST_CASE, VEH_NO, VEVENTNUM) | one row per vehicle event |
| violatn.csv | 59,670 | (ST_CASE, VEH_NO, VIOLATION) | one row per violation charged |
| vision.csv | 56,049 | (ST_CASE, VEH_NO, VISION) | one row per vision obstruction |
| vpicdecode.csv | 55,087 | (ST_CASE, VEH_NO) | one row per vPIC-decoded vehicle |
| vpictrailerdecode.csv | 1,639 | (ST_CASE, VEH_NO, TRAILER_NO) | one row per decoded trailer |
| vsoe.csv | 120,270 | (ST_CASE, VEH_NO, VEVENTNUM, SOE) | one row per sequence-of-events entry |
| veh_aux.csv | 56,011 | (ST_CASE, VEH_NO) | one row per vehicle (auxiliary aggregates) |

**Person level** — key starts with `(ST_CASE, VEH_NO, PER_NO)`:

| CSV | Rows | Key | Grain |
|---|---|---|---|
| drugs.csv | 128,399 | drug_id (surrogate) | one row per drug test; 748 exact dup rows |
| miper.csv | 64,616 | (ST_CASE, VEH_NO, PER_NO) | one row per person (Michigan) |
| nmcrash.csv | 13,054 | (ST_CASE, VEH_NO, PER_NO, NMCC) | one row per non-motorist crash circumstance |
| nmdistract.csv | 9,020 | (ST_CASE, VEH_NO, PER_NO) | one row per non-motorist |
| nmimpair.csv | 9,037 | (ST_CASE, VEH_NO, PER_NO, NMIMPAIR) | one row per non-motorist impairment |
| nmprior.csv | 9,344 | (ST_CASE, VEH_NO, PER_NO, NMACTION) | one row per non-motorist prior action |
| pbtype.csv | 8,940 | (ST_CASE, VEH_NO, PER_NO) | one row per non-motorist (ped/bike details) |
| per_aux.csv | 88,326 | (ST_CASE, VEH_NO, PER_NO) | one row per person (auxiliary aggregates) |
| personrf.csv | 88,343 | (ST_CASE, VEH_NO, PER_NO, PERSONRF) | one row per person-related factor |
| race.csv | 88,517 | (ST_CASE, VEH_NO, PER_NO, RACE_ORDER) | one row per race entry (ordered) |
| safetyeq.csv | 9,020 | (ST_CASE, VEH_NO, PER_NO) | one row per non-motorist (safety equipment) |

**1NF notes:**
- Atomicity: no semicolon-packed coded values in any file. `vpicdecode`
  (2,553 cells) and `vpictrailerdecode` (10 cells) contain `;` only inside
  free-text vPIC API notes — each cell is one verbatim note, kept as-is.
- Numbered suffixes are not repeating groups: `acc_aux`'s `A_D15_19`…
  `A_D21_24` are distinct driver-age-band aggregates; `parkwork`'s
  `PVIN_1`…`PVIN_12` are positional VIN characters (3NF extraction later,
  mirroring the core `VIN_DETAIL`).
- DDL watchlist (mixed-type columns → TEXT): `OTHERBUSINFO`,
  `CHARGERLEVEL` (vpicdecode); `TRLR3VIN`, `MCARR_ID`, `MCARR_I2`
  (vehicle, from core checks).


## Deliberately denormalized (documented exceptions)

- Coded columns are kept alongside lookup joins (rather than storing text in
  the fact tables): smaller tables, single source of truth for labels, at the
  cost of a join. This is the standard code-table pattern, not a 3NF
  violation — the label depends on the code, and the code is part of the key
  or a non-key attribute with the text fully determined by it via the lookup
  table's own key.

## Open questions for the team

1. Non-motorist modeling (`VEH_NO = 0`): decided in `relational-schema.md` —
   confirm the team agrees before the mid-presentation.
2. Column types: verify every DDL type against actual CSV values (max lengths,
   negative codes like -1 for "unknown", decimals in LATITUDE/LONGITUDE).
