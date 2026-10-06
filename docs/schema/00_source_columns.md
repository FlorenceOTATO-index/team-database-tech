# Source column inventory — FARS 2024 (processed CSVs)

Author: Jue Wang | Date: 2026-10-04

Purpose: the "universal relations" that normalization starts from. Every column
listed here must end up in the final schema or be explicitly dropped with a
reason. This is the input to `normalization.md`.

How to fill in the column lists: run `head -1 data/processed/<file>.csv`
(the cleaned CSVs ship with the repo clone; no raw download needed).

## Core tables

| Table    | Source CSV   | One row per        | Natural key                | Rows   | Columns (processed) |
|----------|--------------|--------------------|----------------------------|--------|---------------------|
| accident | accident.csv | crash              | ST_CASE                    | 36,297 | 46 (raw: 80)        |
| vehicle  | vehicle.csv  | vehicle in a crash | (ST_CASE, VEH_NO)          | 56,011 | 109 (raw: 201)      |
| person   | person.csv   | person involved    | (ST_CASE, VEH_NO, PER_NO)  | 88,326 | 66 (raw: 126)       |

`ST_CASE` is unique nationally. Its leading digits encode `STATE`, so it is the
crash ID used everywhere.

Row/column counts source: `data/processed/manifest.json` (also lists every
dropped `*NAME` label column per file — the 3NF evidence).

### accident columns 

STATE,ST_CASE,PEDS,PERNOTMVIT,VE_TOTAL,VE_FORMS,PVH_INVL,PERSONS,PERMVIT,COUNTY,CITY,MONTH,DAY,DAY_WEEK,YEAR,HOUR,MINUTE,TWAY_ID,TWAY_ID2,ROUTE,RUR_URB,FUNC_SYS,RD_OWNER,NHS,SP_JUR,MILEPT,LATITUDE,LONGITUD,HARM_EV,MAN_COLL,RELJCT1,RELJCT2,TYP_INT,REL_ROAD,WRK_ZONE,LGT_COND,WEATHER,SCH_BUS,RAIL,NOT_HOUR,NOT_MIN,ARR_HOUR,ARR_MIN,HOSP_HR,HOSP_MN,FATALS

### vehicle columns 

STATE,ST_CASE,VEH_NO,PER_NO,VE_FORMS,COUNTY,MONTH,DAY,HOUR,MINUTE,HARM_EV,MAN_COLL,SCH_BUS,RUR_URB,FUNC_SYS,MOD_YEAR,VPICMAKE,VPICMODEL,VPICBODYCLASS,MAKE,BODY_TYP,ICFINALBODY,GVWR_FROM,GVWR_TO,TOW_VEH,SPEC_USE,EMER_USE,ROLLOVER,IMPACT1,FIRE_EXP,MAK_MOD,AGE,SEX,PER_TYP,INJ_SEV,SEAT_POS,REST_USE,REST_MIS,HELM_USE,HELM_MIS,AIR_BAG,EJECTION,EJ_PATH,EXTRICAT,DRINKING,ALC_STATUS,ATST_TYP,ALC_RES,DRUGS,DSTATUS,HOSPITAL,DOA,DEATH_MO,DEATH_DA,DEATH_YR,DEATH_TM,DEATH_HR,DEATH_MN,LAG_HRS,LAG_MINS,STR_VEH,DEVTYPE,DEVMOTOR,LOCATION,WORK_INJ,HISPANIC
(.venv) florence@JuedeMacBook-Air team-database-tech % ls docs/schema


### person columns 

STATE,ST_CASE,VEH_NO,VE_FORMS,MONTH,DAY,HOUR,MINUTE,HARM_EV,MAN_COLL,NUMOCCS,UNITTYPE,HIT_RUN,REG_STAT,OWNER,VIN,MOD_YEAR,VPICMAKE,VPICMODEL,VPICBODYCLASS,MAKE,MODEL,BODY_TYP,ICFINALBODY,GVWR_FROM,GVWR_TO,TOW_VEH,TRLR1VIN,TRLR2VIN,TRLR3VIN,TRLR1GVWR,TRLR2GVWR,TRLR3GVWR,J_KNIFE,MCARR_ID,MCARR_I1,MCARR_I2,V_CONFIG,CARGO_BT,HAZ_INV,HAZ_PLAC,HAZ_ID,HAZ_CNO,HAZ_REL,BUS_USE,SPEC_USE,EMER_USE,TRAV_SP,UNDEROVERRIDE,ROLLOVER,ROLINLOC,IMPACT1,DEFORMED,TOWED,M_HARM,FIRE_EXP,MAK_MOD,VIN_1,VIN_2,VIN_3,VIN_4,VIN_5,VIN_6,VIN_7,VIN_8,VIN_9,VIN_10,VIN_11,VIN_12,DEATHS,DR_DRINK,DR_PRES,L_STATE,DR_ZIP,L_TYPE,L_STATUS,CDL_STAT,L_ENDORS,L_COMPL,L_RESTRI,DR_HGT,DR_WGT,PREV_ACC,PREV_SUS1,PREV_SUS2,PREV_SUS3,PREV_DWI,PREV_SPD,PREV_OTH,FIRST_MO,FIRST_YR,LAST_MO,LAST_YR,SPEEDREL,VTRAFWAY,VNUM_LAN,VSPD_LIM,VALIGN,VPROFILE,VPAVETYP,VSURCOND,VTRAFCON,VTCONT_F,P_CRASH1,P_CRASH2,P_CRASH3,PCRASH4,PCRASH5,ACC_TYPE

## Child tables (multi-row per parent)

Crash level — key starts with `ST_CASE`:
`cevent`, `crashrf`, `weather`, `ACC_AUX`, `MIACC`, `MIDRVACC`

Vehicle level — key starts with `(ST_CASE, VEH_NO)`:
`damage`, `distract`, `drimpair`, `driverrf`, `factor`, `maneuver`, `parkwork`,
`pvehiclesf`, `vehiclesf`, `violatn`, `vision`, `vevent`, `vsoe`, `vpicdecode`,
`vpictrailerdecode`, `VEH_AUX`

Person level — key starts with `(ST_CASE, VEH_NO, PER_NO)`:
`drugs`, `race`, `personrf`, `pbtype`, `safetyeq`, `nmcrash`, `nmdistract`,
`nmimpair`, `nmprior`, `PER_AUX`, `MIPER`

For each child table record: its source CSV, what one row represents, and its
key columns (many need an extra column beyond the parent key — check each one).

## Lookup tables (already extracted by ETL)

| Lookup CSV              | Key              | Example                              |
|-------------------------|------------------|--------------------------------------|
| `lookups/code_labels.csv` | (`column`, code) | `HARM_EV, 42` → Tree (Standing Only) |
| `lookups/county.csv`      | (STATE, COUNTY)  | `1, 125` → TUSCALOOSA                |
| `lookups/city.csv`        | (STATE, CITY)    | `6, 1980` → LOS ANGELES              |

Codes stay in the fact tables; human-readable text lives in the lookups.
`lookups/label_conflicts.csv` records raw-data spelling variants and which one
was kept.

## Known facts that constrain the design

- 9,020 `person` rows have `VEH_NO = 0`. These are non-motorists (pedestrians,
  cyclists) and match no `vehicle` row. A FK from `person` to `vehicle` would
  reject them — see the design decision in `relational-schema.md`.
- `parkwork` and `pvehiclesf` describe parked/working vehicles numbered
  separately from `vehicle`; none of their 1,526 rows match a `vehicle` row.
  No FK to `vehicle`.
- `drugs` contains 748 rows that are exact duplicates of another row (real
  repeated test results, not errors). It needs a surrogate key.
- `race.ORDER` is renamed `RACE_ORDER` in `data/processed/` (`ORDER` is a
  MySQL reserved word).
