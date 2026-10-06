# FARS 2024 — Schema Design (Saida)

Scope: initial ER/EER design and mapping to the relational model. Built on Ryan's
cleaned data in `data/processed/`; no cleaning was redone.

**Files inspected:** `README.md`, `docs/data_dictionary.md`, `data/processed/README.md`,
the header rows + key/join checks on all 36 CSVs in `data/processed/`, and
`sql/schema/01_create_tables.sql` (53 tables) as implemented by the team.
Every claim below is measured on the actual data — nothing is assumed.

**Reconciliation note.** This document was first written before the DDL existed. It has
since been revised to match the implemented schema: the `crash_unit` supertype replaces
the earlier "two separate weak entities" design, and the `PERSON` specialization is now
two-way rather than three-way. Section 3 records why the first version was wrong, because
the correction is itself worth presenting.

---

## 0. Verified vs assumed

**Verified** (stated in the repo docs, with row counts):

| Fact | Source |
|---|---|
| `accident` = 1 row per crash, PK `ST_CASE`, unique nationally | data dictionary |
| `vehicle` = 1 row per in-transport vehicle, PK `(ST_CASE, VEH_NO)` | data dictionary |
| `person` = 1 row per person, PK `(ST_CASE, VEH_NO, PER_NO)` | data dictionary |
| 9,020 `person` rows have `VEH_NO = 0` — non-motorists, match no unit | data dictionary |
| `parkwork` / `pvehiclesf` (1,526 rows) use their own numbering | data dictionary, checked on 2024 data |
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
| **Key overlap between `vehicle` and `parkwork`** | **0** → 56,011 + 1,526 = 57,537, a clean shared keyspace |
| Crashes with **zero** units | **0** → ACCIDENT total in HAS_UNIT |
| Crashes with **zero** persons | **0** → ACCIDENT total in INCLUDES |
| Units with **zero** occupant rows | **292** → CRASH_UNIT **partial** in OCCUPIES |
| Occupants (`VEH_NO > 0`) with no matching unit | **0** → OCCUPANT total in OCCUPIES |
| `drugs` exact duplicate rows | 748 → surrogate key required |

---

## 1. Entities, attributes, candidate keys

| Entity | Why it is an entity | Candidate key | Kind |
|---|---|---|---|
| **ACCIDENT** | The crash is the unit the project asks questions about; 46 attributes of its own; every other table hangs off it | `ST_CASE` | Strong |
| **CRASH_UNIT** | Generalization of everything that occupies a numbered slot in a crash. `VEH_NO` restarts at 1 in every crash, and the two kinds of unit share one disjoint keyspace (verified: 0 overlap). Holds the 17 attributes that apply to **both** kinds — `BODY_TYP`, `MAKE`, `MOD_YEAR`, `ROLLOVER`, `IMPACT1`, `GVWR_FROM`/`GVWR_TO` among them | `(ST_CASE, VEH_NO)` | **Weak** on ACCIDENT — `VEH_NO` is the partial key |
| **VEHICLE** | Subtype of CRASH_UNIT: units in transport. `TRAV_SP`, `DEATHS`, `VIN` and ~100 more of its own, plus nine child tables that reference it and not the supertype (`damage`, `violatn`, `driverrf`, `maneuver`…) | inherits `(ST_CASE, VEH_NO)` | **Subtype** |
| **PARKED_WORK_VEH** | Subtype of CRASH_UNIT: parked or working vehicles, 1,526 rows with their own attributes (`PTYPE`…) | inherits `(ST_CASE, VEH_NO)` | **Subtype** |
| **PERSON** | 66 attributes; the subject of injury-severity and impairment questions | `(ST_CASE, VEH_NO, PER_NO)` | **Weak** on ACCIDENT; `(VEH_NO, PER_NO)` is the composite partial key |
| **DRUG_TEST** | One person can have several results, and 748 rows are exact duplicates, so no natural key exists | surrogate `drug_id` | Weak on PERSON (surrogate discriminator) |
| **CRASH_EVENT / VEHICLE_EVENT** | `cevent` (99,225) and `vevent` (120,270) are ordered event sequences, many per crash/unit | `(ST_CASE, EVENTNUM)` / `(ST_CASE, VEH_NO, EVENTNUM)` | Weak |
| **STATE_COUNTY, STATE_CITY, CODE_LABEL** | Lookup relations from Ryan's cleaning, not conceptual entities — they exist to remove the duplicated `XNAME` columns | composite as above | Logical-model only |

**Not modelled as entities.** `acc_aux`, `veh_aux`, `per_aux` are NHTSA-derived convenience
columns at the same grain as their parent, so they are 1:1 extensions, not new entities —
either fold them into the parent table or keep them as optional 1:1 side tables.

---

## 2. Relationships — both directions, with participation

| Relationship | Reading A → B | Reading B → A | Ratio | Participation |
|---|---|---|---|---|
| ACCIDENT **HAS_UNIT** CRASH_UNIT | one crash involves many numbered units | one unit belongs to exactly one crash | 1:N | **both total** — 0 crashes have no unit |
| ACCIDENT **INCLUDES** PERSON | one crash involves many persons | one person belongs to exactly one crash | 1:N | **both total** — 0 crashes have no person |
| OCCUPANT **OCCUPIES** CRASH_UNIT | one unit carries many occupants | one occupant is in exactly one unit | N:1 | OCCUPANT **total** (0 orphans); CRASH_UNIT **partial** — 292 units carry nobody |
| PERSON **TESTED** DRUG_TEST | one person may have many drug results | each result belongs to one person | 1:N | DRUG_TEST total; PERSON partial (128,399 results vs 88,326 persons, not all tested) |

Both identifying relationships (HAS_UNIT, INCLUDES) are double diamonds; OCCUPIES is an
ordinary relationship, since CRASH_UNIT does not supply PERSON's identity — ACCIDENT does.

**OCCUPIES is deliberately not enforced as a foreign key.** `VEH_NO = 0` encodes
"no unit" rather than NULL, so an FK from `person` would be violated by all 9,020
non-motorist rows. Making it enforceable would mean a 0 → NULL conversion touching the
DDL, the loader and every query. The relationship is real and the diagram shows it; the
constraint is left to the application layer.

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
| `damage` (damaged areas) | **vehicle** only | 14 | 32,296 |
| `violatn` (violations) | **vehicle** only | 13 | 2,074 |
| `driverrf` | **vehicle** only | 9 | 5,009 |
| `factor`, `drimpair`, `vision`, `distract`, `maneuver` | **vehicle** only | 2–6 | 7–168 |
| `vevent` (unit event sequence) | **unit** | — | the only child table that FKs `crash_unit` |
| `cevent` (crash event sequence) | crash | 22 | 23,296 |
| `crashrf`, `weather` | crash | 3–4 | 254–391 |

**The child tables sit at mixed grains, and that is the second reason CRASH_UNIT exists
(design note D5 in the DDL).** Checked against `01_create_tables.sql`: `vevent` is the
**only** child table whose foreign key targets `crash_unit` — it records what happened to
a unit, which is meaningful whether that unit was moving or parked. Everything else at
unit grain (`damage`, `violatn`, `driverrf`, `distract`, `drimpair`, `maneuver`, `vision`,
`factor`, `veh_aux`) references `vehicle`, because each describes something a parked
vehicle cannot do.

That split is the evidence for the supertype. A single flat "vehicle" entity would have
forced driver-only attributes onto the 1,526 parked rows where they are meaningless. The
plain-ER diagram shows both cases side by side on CRASH_UNIT — `VEH_EVENT`, which belongs
there, and `VIOLATION`, which does not — and its caption names the difference. Resolving
it is precisely what the EER specialization buys.

In Chen notation these are **double ovals** on their parent entity. In the relational
model each becomes its own relation keyed by *(parent key + sequence or value)* —
which is exactly how Ryan's cleaning already left them, so no restructuring is needed.

Two are **repeating groups**, which is a different defect: `TRLR1VIN`/`TRLR2VIN`/`TRLR3VIN`
and `PREV_SUS1`/`PREV_SUS2`/`PREV_SUS3` in `vehicle` are numbered columns holding a list.
Strictly these violate 1NF and should become their own relations. For the mid-presentation
I note them rather than restructure, since they sit outside the core query questions.

---

## 3. EER: are the specializations genuinely justified?

**Yes — two of them, and the data forces both.**

### 3.1 CRASH_UNIT → VEHICLE | PARKED_WORK_VEH

Attribute-defined on `unit_type`.

| Subtype | `unit_type` | Rows | Subtype-only attributes |
|---|---|---|---|
| VEHICLE | `'V'` | 56,011 | `TRAV_SP`, driver and travel attributes, driver-only child tables |
| PARKED_WORK_VEH | `'P'` | 1,526 | `PTYPE` |

- **Disjoint (d)** — one `unit_type` value per row.
- **Total** — 56,011 + 1,526 = 57,537, the whole of `crash_unit`.
- **Shared key is sound** — the `(ST_CASE, VEH_NO)` key sets are **disjoint: 0 overlap**.

### 3.2 PERSON → OCCUPANT | NON_MOTORIST

Attribute-defined on `PER_TYP`.

| Subtype | `PER_TYP` codes | Rows | `VEH_NO` |
|---|---|---|---|
| OCCUPANT | 1 driver, 2 passenger, 3 occupant of non-transport vehicle, 9 unknown occupant | 79,306 | > 0, matches a `crash_unit` row |
| NON_MOTORIST | 4, 5 pedestrian, 6 bicyclist, 7, 8, 10 | 9,020 | `0` — no unit |

- **Disjoint (d)** — `PER_TYP` holds one value per row.
- **Total** — 79,306 + 9,020 = 88,326, the full table. Zero rows unclassified.
- **Inherited key** — both keep `(ST_CASE, VEH_NO, PER_NO)`; neither has a key of its own.
- **Zero orphans** — every one of the 79,306 occupants matches a `crash_unit` row.

### 3.3 Two corrections worth presenting

Both of my first-draft design decisions were wrong, and the data is what showed it.

**First error — a binary split on `VEH_NO = 0`.** That gave MOTORIST / NON_MOTORIST, and
it broke immediately: **426 person rows have `VEH_NO > 0` but match no `vehicle` row**.
All 426 are `PER_TYP = 3`, occupants of *parked* vehicles, and all 426 join `parkwork`.
A binary split would have put them in MOTORIST and an FK to `VEHICLE` would have rejected
every one. I corrected this to a three-way split: IN_TRANSPORT_OCC / PARKED_VEH_OCC /
NON_MOTORIST, on the reasoning that `PERSON.VEH_NO` was *polymorphic* — pointing at
`vehicle`, at `parkwork`, or at nothing depending on `PER_TYP`.

**Second error — rejecting the supertype.** I argued `PARKED_WORK_VEH` should *not* be a
sibling subtype of `VEHICLE` under a shared supertype, on the grounds that their
independent numbering would collide. Checking the data disproves it: the
`(ST_CASE, VEH_NO)` key sets are **disjoint** — 56,011 + 1,526 = 57,537, zero overlap.
The `VEH_NO` *ranges* overlap (1–15 vs 1–10), which is what misled me; the *pairs* never
do. The `crash_unit` supertype in the implemented schema is sound.

**And the first correction then collapses back.** Once `crash_unit` exists, `VEH_NO` is
no longer polymorphic: all 79,306 occupants point at exactly one table. The three-way
`PERSON` split was solving a problem the supertype removes, so it simplifies to two
subtypes. The 426 parked-vehicle occupants are ordinary OCCUPANTs whose unit happens to
have `unit_type = 'P'`.

The physical layout agrees. All six non-motorist child tables (`pbtype`, `safetyeq`,
`nmcrash`, `nmdistract`, `nmimpair`, `nmprior`) contain **only** persons from the
NON_MOTORIST subtype — I checked each: zero rows fall outside it.

**Weak entities are also genuine**, not decoration: `VEH_NO` and `PER_NO` restart inside
every crash, so neither identifies anything on its own.

**What would justify more EER.** A further specialization of OCCUPANT into DRIVER vs
PASSENGER is tempting (`PER_TYP` encodes it), but it adds nothing unless we attach
driver-only child tables (`drimpair`, `distract`, `violatn`) to it — worth doing for the
final project, not for the mid-presentation. Adding other FARS years would also justify
a `CRASH_YEAR` dimension; with 2024 only, `YEAR` is a constant and carries no information.

---

## 4. Mapping to the relational model

| EER construct | Relational result |
|---|---|
| Strong entity ACCIDENT | `accident(ST_CASE PK, …)` |
| Weak entity + identifying relationship | owner PK + partial key as composite PK, owner PK also FK → `crash_unit(ST_CASE, VEH_NO)`, `person(ST_CASE, VEH_NO, PER_NO)` |
| **Specialization CRASH_UNIT (disjoint, total, attribute-defined)** | **multi-table**: supertype `crash_unit(ST_CASE, VEH_NO, unit_type, …17 shared attributes)` with `CHECK (unit_type IN ('V','P'))`; subtypes `vehicle` and `parkwork` each FK `(ST_CASE, VEH_NO)` → `crash_unit`. Shared attributes live once on the supertype; subtype-only attributes live on their own table; child tables attach at whichever level they are valid. |
| **Specialization PERSON (disjoint, total, attribute-defined)** | **single-table**: one `person` table with `PER_TYP` as the discriminator. Splitting 88,326 rows across two tables would force a UNION into every query, and the subtypes differ by which *child tables* apply, not by their own columns. |
| Entity with no natural key | surrogate `drug_id AUTO_INCREMENT` on `DRUG_TEST` |
| Multivalued / repeating groups (`cevent`, `vevent`, `drugs`) | separate relations keyed by parent + sequence number |
| Code/label pairs | lookup relations; `CODE_LABEL(column, code)` is the generic one |

Note the two specializations map **differently on purpose**: CRASH_UNIT gets separate
subtype tables because the subtypes carry genuinely different columns, while PERSON stays
as one table because its subtypes differ only in which child tables reference them.

Normalization sits with whoever owns that section, but the design is already in 3NF at
the core: every non-key attribute depends on the whole composite key, and the `XNAME`
columns that would have caused transitive dependencies were moved to lookups during
cleaning.

---

## 5. Deliverables

| File | Location | Purpose |
|---|---|---|
| `fars_core_eer.png` / `.svg` | `notebooks/saida/` | EER diagram — both specializations, Chen notation with legend |
| `fars_core_er.png` / `.svg` | `notebooks/saida/` | plain-ER diagram, kept to show what EER buys us |
| `fars_erd.mmd` | `notebooks/saida/` | editable Mermaid source; renders natively on GitHub |
| `verify_design_assumptions.sql` | `sql/queries/` | 13 checks that confirm every number above |
| `schema_design.md` | `notebooks/saida/` | this document |

**Status:** every structural claim is measured against the implemented schema. Remaining
open items are the NULL-vs-empty-string decision for FARS unknown codes, and whether
`docs/erd/` or `notebooks/saida/` is the agreed home for the diagrams.
