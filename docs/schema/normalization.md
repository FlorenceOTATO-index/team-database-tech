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



### Step 2 — Second normal form (child tables)

**Partial dependencies resolved:**

| # | Where | Partial FD | Resolution | Lossless proof |
|---|---|---|---|---|
| C1 | 30 child tables | ST_CASE → STATE | Dropped from all 30; STATE lives in ACCIDENT | FD verified per file; 1,715,857 cells removed |
| C2 | veh_aux | ST_CASE → YEAR, STATE | Dropped (YEAR = 2024 constant, documented; STATE in ACCIDENT) | FD verified |
| C3 | per_aux | ST_CASE → YEAR, STATE | Dropped (same as C2) | FD verified |
| C4 | parkwork | ST_CASE → PVE_FORMS, PMONTH, PDAY, PHOUR, PMINUTE, PHARM_EV, PMAN_COLL | Dropped; exact copies of accident columns | 0 mismatches / 1,526 rows |
| C5 | parkwork | ST_CASE → PHAZ_INV, PHAZPLAC, PHAZ_ID, PHAZ_CNO, PHAZ_REL | New PARKWORK_HAZMAT (1,070 rows, PK ST_CASE) | key unique; 0 mismatches |
| C6 | acc_aux | ST_CASE → FATALS, YEAR, STATE | Dropped; exact copies of accident | 0 / 36,297 mismatches |
| C7 | pbtype | ST_CASE → PBSZONE | New CRASH_PBSZONE (8,419 rows, PK ST_CASE) | key unique; 0 mismatches |
| C8 | parkwork | ∅ → PTRLR3VIN, PTRLR3GVWR | Dropped as dataset constants | constant across 1,526 rows |

Column counts after 2NF: acc_aux 45→42, veh_aux 20→18, per_aux 25→23,
parkwork 66→51, pbtype 24→22, drugs 10→10 (−STATE, +drug_id surrogate);
every other child table −1 (STATE). New relations: PARKWORK_HAZMAT
(6 cols), CRASH_PBSZONE (2 cols). 49 columns removed in total.

**Tested and kept — spurious FDs (no decomposition):**

Empirical FD checks flag false positives; each flag was falsification-tested:

- *Sparsity trap* (`vpicdecode`): 18 flagged columns have ≤287 non-nulls of
  55,087 rows (one has a single non-null). `nunique` ignores nulls, so the FD
  holds vacuously. Kept at vehicle grain.
- *Near-constant trap* (`vpicdecode`): ELECTRONICSTABILITYCONTROL is
  "Standard" in 13,289/13,290 populated rows; PRETENSIONER is "Yes" in
  1,869/1,870. The 1,537 unanimously-agreeing crashes are expected by chance
  (expected disagreements ≈ 0.23, observed 0) — and no semantic FD exists
  (a crash cannot determine factory equipment). Kept.
- *Single-row vacuity* (`vpictrailerdecode`): 1,581/1,610 vehicles tow one
  trailer, so every column trivially satisfies the via-key check. The 29
  two-trailer pairs were tested: NOTE disagreed in 5/29 (genuinely
  trailer-grain); the rest agreed 29/29 — insufficient to establish an FD
  with no semantic basis. Kept at trailer grain.

**Result:** all child relations in 2NF — 1,715,857 redundant STATE cells
eliminated, 49 columns removed, 2 new relations, both proven lossless.


### Step 3 — Third normal form (child tables)

**Transitive dependencies resolved (strict — 8 new relations):**

| # | FD | New relation (key) | Rows | Proof |
|---|---|---|---|---|
| D1 | 68 × (*ID → *NAME) | VPIC_LABELS(attribute, id, label) | 3,170 | 0 violations; 0 mismatches |
| D2 | PVIN → PVIN_1..12 | PVIN_DETAIL(PVIN) | 1,465 | key unique; 0 mismatches |
| D3 | STATE → A_REGION | STATE_REGION(STATE) | 51 | key unique; 0 mismatches |
| D4 | A_ROADFC → A_INTER | ROADFC_INTER(A_ROADFC) | 7 | key unique; 0 mismatches |
| D5 | A_JUNC → A_INTSEC | JUNC_INTSEC(A_JUNC) | 4 | key unique; 0 mismatches |
| D6 | A_AGE3 → 5 coarser schemes | AGE_BAND_MAP(A_AGE3) | 13 | key unique; 0 mismatches |
| D7 | PEDCTYPE → PEDCGP | PED_CRASH_GROUP(PEDCTYPE) | 51 | key unique; 0 mismatches |
| D8 | BIKECTYPE → BIKECGP | BIKE_CRASH_GROUP(BIKECTYPE) | 66 | key unique; 0 mismatches |

Column moves: vpicdecode −68 NAMEs (194→126), parkwork −12 PVIN_i (51→39),
acc_aux −3 (42→39: A_REGION, A_INTER, A_INTSEC), per_aux −5 age
schemes (23→18), pbtype −2 groups (22→20). TRACT kept, not dropped: binary (0/1); ST_CASE → TRACT holds
(36,116 ones, 181 zeros — verified 2026-10-05). The "dataset constant"
premise was refuted by the data; TRACT stays in acc_aux as an ordinary
crash-grain attribute.
Null-key rows are excluded from the physical lookups.

**Tested and kept — spurious transitive FDs:**

- *Sparsity* (vpicdecode): 18 flagged columns have ≤287 non-nulls of 55,087
  rows — FD holds vacuously. Kept at vehicle grain.
- *Near-constant* (vpicdecode): ELECTRONICSTABILITYCONTROL = "Standard" in
  13,289/13,290 populated rows; PRETENSIONER = "Yes" in 1,869/1,870.
  Expected disagreements ≈ 0.23, observed 0 — chance, no semantic FD
  (a crash cannot determine factory equipment). Kept.
- *Single-row vacuity* (vpictrailerdecode): 1,581/1,610 single-trailer
  vehicles; the 29 two-trailer pairs were falsification-tested (NOTE
  disagreed in 5/29 — genuinely trailer-grain). Kept at trailer grain.

**Result:** all 33 child tables in strict 3NF — 91 columns relocated into
8 new relations, all proven lossless; 1 constant dropped.



### Step 4 — Mixed-grain children: `crash_unit` supertype (D5)

Post-verification finding (2026-10-05, from colleague review): `vevent`,
`vsoe`, `vpicdecode` and `vpictrailerdecode` contain units from **both**
`vehicle` (56,011 in-transport) and `parkwork` (1,526 parked/working).
Numbering is separate (0 overlap — D3 still holds), but parked/working
units still receive event rows and VIN decodes. Measured on 2024 data:

| child | units in `vehicle` | units in `parkwork` | orphans |
|---|---|---|---|
| vevent | 56,011 | 1,526 | 0 |
| vsoe | 56,011 | 1,526 | 0 |
| vpicdecode | 53,633 | 1,454 | 0 |
| vpictrailerdecode | 1,531 | 79 | 0 |

FKs from these tables to `vehicle` would fail — 4,585 unit references with
no parent (the D1 failure mode). Ten other vehicle-grain children are
vehicle-only (0 parkwork units, 0 orphans).

Resolution: new supertype `crash_unit(ST_CASE, VEH_NO, unit_type)` holding
the disjoint union of the two key sets (57,537 rows). `vehicle` and
`parkwork` are subtypes (FK → `crash_unit`); `vevent`, `vpicdecode` and
`vpictrailerdecode` FK to `crash_unit` (`vsoe` follows via `vevent`). Unlike
D1, every row satisfies the supertype FK (0 orphans), so enforcement is
safe. Permanent regression check in `scripts/verify_normalization.py`
(D5 block).

### Step 5 — Post-verification corrections (D6–D9)

Colleague review (2026-10-05) identified four further issues.

**D6 — `vevent` deduplicated against `cevent`.** `vevent` carried five
columns (`VNUMBER1`, `AOI1`, `SOE`, `VNUMBER2`, `AOI2`) duplicating `cevent`
for the same `(ST_CASE, EVENTNUM)`. Dropped from `vevent`; kept
`FK (ST_CASE, EVENTNUM)` → `cevent`. `vevent` is now a pure (unit, event)
link: 9 → 4 columns.

**D7 — `vsoe` PK minimality.** `(ST_CASE, VEH_NO, VEVENTNUM)` is already
unique in `vsoe` (120,270 rows), so `SOE` need not be in the PK. PK shrunk
to 3 columns; `SOE` remains as a regular attribute.

**D8 — `MULTRACE` moved to `person` (2NF).** `MULTRACE` is constant per
`(ST_CASE, VEH_NO, PER_NO)` in `race` — a partial dependency on a
4-column key. Moved to `person`, where the full key determines it.

**D9 — Unit-grain columns to `crash_unit` (lossless `person`).** The 16
columns moved from `person` to `vehicle` in Step 3 (`BODY_TYP`, `EMER_USE`,
`FIRE_EXP`, `GVWR_FROM`, `GVWR_TO`, `ICFINALBODY`, `IMPACT1`, `MAKE`,
`MAK_MOD`, `MOD_YEAR`, `ROLLOVER`, `SPEC_USE`, `TOW_VEH`, `VPICBODYCLASS`,
`VPICMAKE`, `VPICMODEL`) are unit-grain, not vehicle-grain: 426 `person`
rows belong to `parkwork` units, whose values (e.g. `ROLLOVER`) exist only
in `person` and are unrecoverable via `vehicle`. They now live on
`crash_unit` — populated from `vehicle.csv` for in-transport units,
from `person` (deduped by unit) for parked/working units. `vehicle` sheds
them (89 → 73 cols). Decomposition now lossless for all 88,326 persons.

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
