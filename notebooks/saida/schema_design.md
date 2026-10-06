# FARS 2024 — Schema Design (Saida)

Scope: initial ER/EER design and mapping to the relational model. Built on Ryan's
cleaned data in `data/processed/`; no cleaning was redone.

**Files inspected:** `README.md`, `docs/data_dictionary.md`, `data/processed/README.md`,
and the header rows + key/join checks on all 36 CSVs in `data/processed/`.
`sql/schema/` is **empty** (only `.gitkeep`), so there is no existing DDL to reconcile.
Every claim below is now measured on the actual data — nothing is assumed.

---

## 0. Verified vs assumed

**Verified** (stated in the repo docs, with row counts):

| Fact | Source |
|---|---|
| `accident` = 1 row per crash, PK `ST_CASE`, unique nationally | data dictionary |
| `vehicle` = 1 row per in-transport vehicle, PK `(ST_CASE, VEH_NO)` | data dictionary |
| `person` = 1 row per person, PK `(ST_CASE, VEH_NO, PER_NO)` | data dictionary |
| 9,020 `person` rows have `VEH_NO = 0` — non-motorists, match no vehicle | data dictionary |
| `parkwork` / `pvehiclesf` (1,526 rows) use separate numbering; **none** join `vehicle` | data dictionary, checked on 2024 data |
| `drugs` has 748 exact duplicate rows → needs a surrogate key | data dictionary |
| County and city codes repeat across states → lookup key is `(STATE, COUNTY)` / `(STATE, CITY)` | processed README |
| 36,297 crashes · 56,011 vehicles · 88,326 persons | processed README |
| `race.ORDER` renamed `RACE_ORDER`; all values are text; unknown codes (8/9/99…) not NULL | processed README |

**Measured on the data** (all checks re-run on `data/processed/`):

| Check | Result |
|---|---|
| `ST_CASE` unique in `accident` | 36,297 / 36,297, 0 duplicates |
| `(ST_CASE, VEH_NO)` unique in `vehicle` | 56,011 distinct, 0 duplicates |
| `(ST_CASE, VEH_NO, PER_NO)` unique in `person` | 88,326 distinct, 0 duplicates |
| `(ST_CASE, VEH_NO)` unique in `parkwork` | 1,526 distinct, 0 duplicates |
| Crashes with **zero** vehicles | **0** → ACCIDENT total in IN_CRASH |
| Crashes with **zero** persons | **0** → ACCIDENT total in INCLUDES |
| Vehicles with **zero** occupant rows | **292** → VEHICLE **partial** in OCCUPIES |
| `parkwork` rows that join `vehicle` | **0 of 1,526** → no FK, confirmed |
| `drugs` exact duplicate rows | 748 → surrogate key required |

---

## 1. Entities, attributes, candidate keys

| Entity | Why it is an entity | Candidate key | Kind |
|---|---|---|---|
| **ACCIDENT** | The crash is the unit the project asks questions about; 46 attributes of its own; every other table hangs off it | `ST_CASE` | Strong |
| **VEHICLE** | Has 109 attributes of its own and its own child tables (`damage`, `maneuver`, `vevent`…); `VEH_NO` is **not** unique on its own — it restarts at 1 in every crash | `(ST_CASE, VEH_NO)` | **Weak** — identity borrowed from ACCIDENT, `VEH_NO` is the partial key |
| **PERSON** | 66 attributes; the subject of injury-severity and impairment questions | `(ST_CASE, VEH_NO, PER_NO)` | **Weak** on ACCIDENT; `(VEH_NO, PER_NO)` is the composite partial key |
| **PARKED_WORK_VEH** | Separate real-world object: parked or working vehicles, numbered independently, 1,526 rows that provably do not join `vehicle` | `(ST_CASE, VEH_NO)` | **Weak** on ACCIDENT |
| **DRUG_TEST** | One person can have several results, and 748 rows are exact duplicates, so no natural key exists | surrogate `drug_id` | Weak on PERSON (surrogate discriminator) |
| **CRASH_EVENT / VEHICLE_EVENT** | `cevent` (99,225) and `vevent` (120,270) are ordered event sequences, many per crash/vehicle | `(ST_CASE, EVENTNUM)` / `(ST_CASE, VEH_NO, EVENTNUM)` | Weak |
| **STATE_COUNTY, STATE_CITY, CODE_LABEL** | Lookup relations from Ryan's cleaning, not conceptual entities — they exist to remove the duplicated `XNAME` columns | composite as above | Logical-model only |

**Not modelled as entities.** `acc_aux`, `veh_aux`, `per_aux` are NHTSA-derived convenience
columns at the same grain as their parent, so they are 1:1 extensions, not new entities —
either fold them into the parent table or keep them as optional 1:1 side tables.

---

## 2. Relationships — both directions, with participation

| Relationship | Reading A → B | Reading B → A | Ratio | Participation |
|---|---|---|---|---|
| ACCIDENT **IN_CRASH** VEHICLE | one crash involves many in-transport vehicles | one vehicle belongs to exactly one crash | 1:N | **both total** — 0 crashes have no vehicle |
| ACCIDENT **INCLUDES** PERSON | one crash involves many persons | one person belongs to exactly one crash | 1:N | **both total** — 0 crashes have no person |
| ACCIDENT **PARKED_IN** PARKED_WORK_VEH | a crash may involve parked/working vehicles | each belongs to exactly one crash | 1:N | PWV **total**; ACCIDENT **partial** — only 1,526 rows across 36,297 crashes |
| VEHICLE **OCCUPIES** IN_TRANSPORT_OCC | one vehicle carries many occupants | one occupant is in exactly one vehicle | 1:N | occupant **total**; VEHICLE **partial** — 292 vehicles have no occupant row |
| PARKED_WORK_VEH **OCCUPIES** PARKED_VEH_OCC | a parked vehicle may have occupants | each belongs to one parked vehicle | 1:N | occupant **total**; parked vehicle **partial** |
| PERSON **TESTED** DRUG_TEST | one person may have many drug results | each result belongs to one person | 1:N | DRUG_TEST total; PERSON partial (128,399 results vs 88,326 persons, not all tested) |

The ACCIDENT–PARKED_WORK_VEH participation is the clearest evidence-backed *partial*
in the model: 1,526 rows cannot cover 36,297 crashes.

---

## 2b. Composite and multivalued attributes

### Composite attributes (verified by column structure)

| Composite | Simple components | Table |
|---|---|---|
| **CrashDateTime** | `MONTH`, `DAY`, `YEAR`, `HOUR`, `MINUTE` | `accident` |
| **Location** | `LATITUDE`, `LONGITUD` | `accident` |
| **NotifiedTime / ArrivedTime / HospitalTime** | `NOT_HOUR`+`NOT_MIN`, `ARR_HOUR`+`ARR_MIN`, `HOSP_HR`+`HOSP_MN` | `accident` |
| **RoadwayID** | `ROUTE`, `TWAY_ID`, `TWAY_ID2`, `MILEPT` | `accident` |
| **DeathDateTime** | `DEATH_MO`, `DEATH_DA`, `DEATH_YR`, `DEATH_HR`, `DEATH_MN` | `person` |
| **GVWR range** | `GVWR_FROM`, `GVWR_TO` | `vehicle` |

FARS stores no single timestamp column — the date and time are **already decomposed**,
which is the composite-attribute pattern seen from the physical side. In the ER diagram
they are drawn as one composite oval with its components beneath; in the relational
model only the components become columns, so the physical layout needs no change.

`VIN_1 … VIN_12` is a different case: it is a **decomposition of a single atomic value**,
not a composite attribute. Checked on 2,000 sampled rows — the twelve columns concatenate
to `VIN[:12]` in 2,000/2,000. These are derived columns for prefix matching, so `VIN` is
the attribute and the twelve are redundant; they should not be modelled.

### Multivalued attributes (verified by counting rows per parent)

Every one of these has a parent with **more than one** row, so each is genuinely
multivalued, not a 1:1 extension:

| Attribute group | Parent grain | Max rows per parent | Parents with >1 |
|---|---|---|---|
| `drugs` | person | 47 | 12,680 |
| `race` | person | 5 | 163 |
| `nmcrash` | person (non-motorist) | 6 | 3,199 |
| `personrf` | person | 2 | 17 |
| `damage` (damaged areas) | vehicle | 14 | 32,296 |
| `violatn` (violations) | vehicle | 13 | 2,074 |
| `driverrf` | vehicle | 9 | 5,009 |
| `factor`, `drimpair`, `vision`, `distract`, `maneuver` | vehicle | 2–6 | 7–168 |
| `cevent` (event sequence) | crash | 22 | 23,296 |
| `crashrf`, `weather` | crash | 3–4 | 254–391 |

In Chen notation these are **double ovals** on their parent entity. In the relational
model each becomes its own relation keyed by *(parent key + sequence or value)* —
which is exactly how Ryan's cleaning already left them, so no restructuring is needed.

Two are **repeating groups**, which is a different defect: `TRLR1VIN`/`TRLR2VIN`/`TRLR3VIN`
and `PREV_SUS1`/`PREV_SUS2`/`PREV_SUS3` in `vehicle` are numbered columns holding a list.
Strictly these violate 1NF and should become their own relations. For the mid-presentation
I note them rather than restructure, since they sit outside the core query questions.

---

## 3. EER: is specialization genuinely justified?

**Yes — one specialization, and the data forces it.**

`PERSON` specializes **three** ways, attribute-defined on `PER_TYP`:

| Subtype | `PER_TYP` codes | Rows | `VEH_NO` points to |
|---|---|---|---|
| IN_TRANSPORT_OCC | 1 driver, 2 passenger, 9 unknown occupant | 78,880 | `vehicle` |
| PARKED_VEH_OCC | 3 occupant of vehicle not in-transport | 426 | `parkwork` |
| NON_MOTORIST | 4, 5 pedestrian, 6 bicyclist, 7, 8, 10 | 9,020 | nothing (`VEH_NO = 0`) |

- **Disjoint (d)** — `PER_TYP` holds one value per row.
- **Total** — the three groups sum to 88,326, the full table. Zero rows unclassified.
- **Inherited key** — all three keep `(ST_CASE, VEH_NO, PER_NO)`; none has a key of its own.

**Correction worth presenting.** My first draft split only on `VEH_NO = 0`, giving a
binary MOTORIST / NON_MOTORIST. Checking the data broke it: **426 person rows have
`VEH_NO > 0` but match no `vehicle` row**. All 426 are `PER_TYP = 3`, occupants of
*parked* vehicles, and all 426 join `parkwork` instead. A binary split would have put
them in MOTORIST and the FK to `VEHICLE` would have rejected every one.

**Why this is not cosmetic.** `PERSON.VEH_NO` is a *polymorphic* reference: depending on
`PER_TYP` it points to `vehicle`, to `parkwork`, or to nothing. No single foreign key can
express that. The specialization puts each FK where it is valid — IN_TRANSPORT_OCC →
`VEHICLE`, PARKED_VEH_OCC → `PARKED_WORK_VEH`, NON_MOTORIST → no vehicle FK at all —
while all three keep their FK to `ACCIDENT`.

The physical layout agrees. All six non-motorist child tables (`pbtype`, `safetyeq`,
`nmcrash`, `nmdistract`, `nmimpair`, `nmprior`) contain **only** persons from the
NON_MOTORIST subtype — I checked each: zero rows fall outside it.

**Weak entities are also genuine**, not decoration: `VEH_NO` and `PER_NO` restart inside
every crash, so neither identifies anything on its own.

**What I deliberately did not do.** `PARKED_WORK_VEH` is *not* modelled as a sibling
subtype of `VEHICLE` under a generalized "vehicle in crash" supertype. That would look
more advanced but would be wrong: the two use independent numbering sequences, so a
shared supertype key would collide. They are separate weak entities on ACCIDENT.

**What would justify more EER.** A second specialization of `PERSON` into DRIVER vs
PASSENGER is tempting (`PER_TYP` encodes it), but it adds nothing unless we attach
driver-only child tables (`drimpair`, `distract`, `violatn`) to it — worth doing for the
final project, not for the mid-presentation. Adding other FARS years would also justify
a `CRASH_YEAR` dimension; with 2024 only, `YEAR` is a constant and carries no information.

---

## 4. Mapping to the relational model

| EER construct | Relational result |
|---|---|
| Strong entity ACCIDENT | `ACCIDENT(ST_CASE PK, …)` |
| Weak entity + identifying relationship | owner PK + partial key as composite PK, owner PK also FK → `VEHICLE(ST_CASE, VEH_NO)` |
| Specialization (disjoint, total, attribute-defined) | **single-table** approach: keep one `PERSON` table, with `VEH_NO` as the discriminator, plus `NON_MOTORIST_DET` for the subtype-only attributes. Avoids splitting 88,326 rows across two tables that every query would have to UNION. |
| Entity with no natural key | surrogate `drug_id AUTO_INCREMENT` on `DRUG_TEST` |
| Multivalued / repeating groups (`cevent`, `vevent`, `drugs`) | separate relations keyed by parent + sequence number |
| Code/label pairs | lookup relations; `CODE_LABEL(column, code)` is the generic one |

Normalization sits with whoever owns that section, but the design is already in 3NF at
the core: every non-key attribute depends on the whole composite key, and the `XNAME`
columns that would have caused transitive dependencies were moved to lookups during
cleaning.

---

## 5. Deliverables

| File | Put it in | Purpose |
|---|---|---|
| `fars_core_eer.png` | `docs/erd/` | slide visual (Chen/EER notation, with legend) |
| `fars_core_eer.svg` | `docs/erd/` | vector version |
| `fars_erd.mmd` | `docs/erd/` | **editable** Mermaid source; renders natively on GitHub |
| `verify_design_assumptions.sql` | `sql/queries/` | 10 checks that confirm every assumption above |
| `schema_design.md` | `docs/` | this document |

**Status:** every structural claim is measured, not assumed. The remaining work is the
DDL itself (`sql/schema/`), data types (everything is text in `data/processed/`), and the
NULL-vs-empty-string decision for FARS unknown codes.
