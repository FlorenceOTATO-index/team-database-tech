# Relational schema — FARS 2024

Author: Jue Wang | Date: 2026-10-05 | Branch: `jue/normalization`
Status: design complete — DDL not yet generated
Provenance: `docs/schema/normalization.md` (proofs),
`scripts/verify_normalization.py` (checks — all pass)

## Overview

**53 relations, all in strict third normal form:**
36 source tables + 14 created by normalization + 3 ETL lookups.

| Group | Count | Relations |
|---|---|---|
| Core | 6 | accident, calendar, vehicle, vin_detail, person, death_time |
| Crash-level | 8 | acc_aux, cevent, crashrf, weather, miacc, midrvacc, parkwork_hazmat, crash_pbszone |
| Unit supertype | 1 | crash_unit |
| Vehicle-level | 16 | damage, distract, drimpair, driverrf, factor, maneuver, pvehiclesf, vehiclesf, violatn, vision, veh_aux, vevent, vsoe, vpicdecode, vpictrailerdecode, parkwork |
| Person-level | 11 | drugs, miper, nmcrash, nmdistract, nmimpair, nmprior, pbtype, per_aux, personrf, race, safetyeq |
| Normalization lookups | 8 | vpic_labels, pvin_detail, state_region, roadfc_inter, junc_intsec, age_band_map, ped_crash_group, bike_crash_group |
| ETL lookups | 3 | code_labels, county, city |

Table names are `snake_case` per repo SQL convention (`normalization.md`
used UPPERCASE for the new relations for emphasis — same tables).
Column types are assigned at DDL time.

## Core relations

### `accident` — 36,297 rows (one row per crash)
**PK** `ST_CASE` · **FK** `(YEAR, MONTH, DAY)` → `calendar`
**Columns (45):** ST_CASE, ARR_HOUR, ARR_MIN, CITY, COUNTY, DAY, FATALS,
FUNC_SYS, HARM_EV, HOSP_HR, HOSP_MN, HOUR, LATITUDE, LGT_COND, LONGITUD,
MAN_COLL, MILEPT, MINUTE, MONTH, NHS, NOT_HOUR, NOT_MIN, PEDS, PERMVIT,
PERNOTMVIT, PERSONS, PVH_INVL, RAIL, RD_OWNER, RELJCT1, RELJCT2, REL_ROAD,
ROUTE, RUR_URB, SCH_BUS, SP_JUR, STATE, TWAY_ID, TWAY_ID2, TYP_INT,
VE_FORMS, VE_TOTAL, WEATHER, WRK_ZONE, YEAR

### `calendar` — 366 rows · **NEW** (3NF: `(YEAR, MONTH, DAY) → DAY_WEEK`)
**PK** `(YEAR, MONTH, DAY)` · no FKs
**Columns (4):** YEAR, MONTH, DAY, DAY_WEEK

### `vehicle` — 56,011 rows (one row per in-transport vehicle)
**PK** `(ST_CASE, VEH_NO)` · **FKs** `ST_CASE` → `accident`, `(ST_CASE, VEH_NO)` → `crash_unit` (subtype, D5), `VIN` → `vin_detail`
**Columns (73):** ST_CASE, VEH_NO, ACC_TYPE, BUS_USE, CARGO_BT,
CDL_STAT, DEATHS, DEFORMED, DR_DRINK, DR_HGT, DR_PRES, DR_WGT, DR_ZIP,
FIRST_MO, FIRST_YR, HAZ_CNO, HAZ_ID,
HAZ_INV, HAZ_PLAC, HAZ_REL, HIT_RUN, J_KNIFE, LAST_MO,
LAST_YR, L_COMPL, L_ENDORS, L_RESTRI, L_STATE, L_STATUS, L_TYPE,
MCARR_I1, MCARR_I2, MCARR_ID, MODEL, M_HARM, NUMOCCS, OWNER, PCRASH4,
PCRASH5, PREV_ACC, PREV_DWI, PREV_OTH, PREV_SPD, PREV_SUS1, PREV_SUS2,
PREV_SUS3, P_CRASH1, P_CRASH2, P_CRASH3, REG_STAT, ROLINLOC,
SPEEDREL, TOWED, TRAV_SP, TRLR1GVWR, TRLR1VIN, TRLR2GVWR,
TRLR2VIN, TRLR3GVWR, TRLR3VIN, UNDEROVERRIDE, UNITTYPE, VALIGN, VIN, VNUM_LAN,
VPAVETYP, VPROFILE, VSPD_LIM, VSURCOND,
VTCONT_F, VTRAFCON, VTRAFWAY, V_CONFIG
Note: `UNITTYPE` is constant `[1]` on all 56,011 rows — pending drop decision. 16 unit-grain attributes moved to `crash_unit` (D9).

### `vin_detail` — 49,396 rows · **NEW** (3NF: `VIN → VIN_1..12`)
**PK** `VIN` · no FKs
**Columns (13):** VIN, VIN_1, VIN_2, VIN_3, VIN_4, VIN_5, VIN_6, VIN_7,
VIN_8, VIN_9, VIN_10, VIN_11, VIN_12

### `person` — 88,326 rows (one row per person involved)
**PK** `(ST_CASE, VEH_NO, PER_NO)` ·
**FKs** `ST_CASE` → `accident`, `(DEATH_HR, DEATH_MN)` → `death_time`
**Columns (38):** ST_CASE, VEH_NO, PER_NO, AGE, AIR_BAG, ALC_RES, ALC_STATUS,
ATST_TYP, DEATH_DA, DEATH_HR, DEATH_MN, DEATH_MO, DEATH_YR, DEVMOTOR, DEVTYPE,
DOA, DRINKING, DRUGS, DSTATUS, EJECTION, EJ_PATH, EXTRICAT, HELM_MIS,
HELM_USE, HISPANIC, HOSPITAL, INJ_SEV, LAG_HRS, LAG_MINS, LOCATION, MULTRACE, PER_TYP,
REST_MIS, REST_USE, SEAT_POS, SEX, STR_VEH, WORK_INJ
Note: **no FK to `vehicle`** — 9,020 rows have `VEH_NO = 0` (non-motorists)
and match no vehicle row (decision D1).

### `death_time` — 1,457 rows · **NEW** (3NF: `(DEATH_HR, DEATH_MN) → DEATH_TM`)
**PK** `(DEATH_HR, DEATH_MN)` · no FKs
**Columns (3):** DEATH_HR, DEATH_MN, DEATH_TM

## Crash-level relations

### `acc_aux` — 36,297 rows
**PK** `ST_CASE` · **FK** `ST_CASE` → `accident`
**Columns (39):** ST_CASE, A_CRAINJ, A_RU, A_RELRD, A_ROADFC, A_JUNC, A_MANCOL,
A_TOD, A_DOW, A_CT, A_WEATHER, A_LT, A_MC, A_SBUSCR, A_SPCRA, A_PED, A_PED_F,
A_PEDAL, A_PEDAL_F, A_ROLL, A_POLPUR, A_POSBAC, A_D15_19, A_D16_19, A_D15_20,
A_D16_20, A_D65PLS, A_D21_24, A_D16_24, A_RD, A_HR, A_DIST, A_DROWSY,
A_WRONGWAY, BIA, SPJ_INDIAN, INDIAN_RES, CENSUS_2020_TRACT_FIPS, TRACT
(Removed: STATE, YEAR, FATALS — exact copies of accident; A_REGION →
`state_region`; A_INTER → `roadfc_inter`; A_INTSEC → `junc_intsec`.)
TRACT kept: binary (0/1), `ST_CASE → TRACT` (verified 2026-10-05).

### `cevent` — 99,225 rows
**PK** `(ST_CASE, EVENTNUM)` · **FK** `ST_CASE` → `accident`
**Columns (7):** ST_CASE, EVENTNUM, VNUMBER1, AOI1, SOE, VNUMBER2, AOI2

### `crashrf` — 36,587 rows
**PK** `(ST_CASE, CRASHRF)` · **FK** `ST_CASE` → `accident`
**Columns (2):** ST_CASE, CRASHRF

### `weather` — 36,692 rows
**PK** `(ST_CASE, WEATHER)` · **FK** `ST_CASE` → `accident`
**Columns (2):** ST_CASE, WEATHER

### `miacc` — 36,297 rows
**PK** `ST_CASE` · **FK** `ST_CASE` → `accident`
**Columns (11):** ST_CASE, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10

### `midrvacc` — 36,229 rows
**PK** `ST_CASE` · **FK** `ST_CASE` → `accident`
**Columns (11):** ST_CASE, A1, A2, A3, A4, A5, A6, A7, A8, A9, A10

### `parkwork_hazmat` — 1,070 rows · **NEW** (2NF: `ST_CASE → PHAZ_*`)
**PK** `ST_CASE` · **FK** `ST_CASE` → `accident`
**Columns (6):** ST_CASE, PHAZ_INV, PHAZPLAC, PHAZ_ID, PHAZ_CNO, PHAZ_REL

### `crash_pbszone` — 8,419 rows · **NEW** (2NF: `ST_CASE → PBSZONE`)
**PK** `ST_CASE` · **FK** `ST_CASE` → `accident`
**Columns (2):** ST_CASE, PBSZONE

## Unit supertype (D5, D9)

### `crash_unit` — 57,537 rows · **NEW** (supertype: `vehicle` ∪ `parkwork`; 16 unit-grain attributes)
**PK** `(ST_CASE, VEH_NO)`
**Columns (19):** ST_CASE, VEH_NO, unit_type (`'V'` in-transport vehicle, `'P'` parked/working vehicle), BODY_TYP, EMER_USE, FIRE_EXP, GVWR_FROM, GVWR_TO, ICFINALBODY, IMPACT1, MAKE, MAK_MOD, MOD_YEAR, ROLLOVER, SPEC_USE, TOW_VEH, VPICBODYCLASS, VPICMAKE, VPICMODEL
Disjoint union of the `vehicle` (56,011) and `parkwork` (1,526) key sets — 0 overlap verified on 2024 data. `vehicle` and `parkwork` are subtypes (FK → `crash_unit`). The 16 unit-grain attributes (D9) are populated from `vehicle.csv` for in-transport units and from `person` (deduped by unit) for parked/working units. Mixed-grain children `vevent`, `vpicdecode`, `vpictrailerdecode` FK here (`vsoe` follows via `vevent`).

## Vehicle-level relations

All carry `FK (ST_CASE, VEH_NO)` → `vehicle`, except `parkwork` /
`pvehiclesf` (separate numbering — `FK ST_CASE` → `accident` only, decision D3).

### `damage` — 240,091 rows
**PK** `(ST_CASE, VEH_NO, DAMAGE)`
**Columns (3):** ST_CASE, VEH_NO, DAMAGE

### `distract` — 56,026 rows
**PK** `(ST_CASE, VEH_NO, DRDISTRACT)`
**Columns (3):** ST_CASE, VEH_NO, DRDISTRACT

### `drimpair` — 56,181 rows
**PK** `(ST_CASE, VEH_NO, DRIMPAIR)`
**Columns (3):** ST_CASE, VEH_NO, DRIMPAIR

### `driverrf` — 62,603 rows
**PK** `(ST_CASE, VEH_NO, DRIVERRF)`
**Columns (3):** ST_CASE, VEH_NO, DRIVERRF

### `factor` — 56,076 rows
**PK** `(ST_CASE, VEH_NO, VEHICLECC)`
**Columns (3):** ST_CASE, VEH_NO, VEHICLECC

### `maneuver` — 56,018 rows
**PK** `(ST_CASE, VEH_NO, MANEUVER)`
**Columns (3):** ST_CASE, VEH_NO, MANEUVER

### `pvehiclesf` — 1,526 rows (parked/working vehicles, separate numbering)
**PK** `(ST_CASE, VEH_NO, PVEHICLESF)` · **FK** `ST_CASE` → `accident`
**Columns (3):** ST_CASE, VEH_NO, PVEHICLESF

### `vehiclesf` — 56,013 rows
**PK** `(ST_CASE, VEH_NO, VEHICLESF)`
**Columns (3):** ST_CASE, VEH_NO, VEHICLESF

### `violatn` — 59,670 rows
**PK** `(ST_CASE, VEH_NO, VIOLATION)`
**Columns (3):** ST_CASE, VEH_NO, VIOLATION

### `vision` — 56,049 rows
**PK** `(ST_CASE, VEH_NO, VISION)`
**Columns (3):** ST_CASE, VEH_NO, VISION

### `veh_aux` — 56,011 rows
**PK** `(ST_CASE, VEH_NO)`
**Columns (18):** ST_CASE, VEH_NO, A_WRONGWAYDRV, A_DRDIS, A_DRDRO, A_VRD,
A_BODY, A_IMP1, A_VROLL, A_LIC_S, A_LIC_C, A_CDL_S, A_MC_L_S, A_SPVEH, A_SBUS,
A_MOD_YR, A_FIRE_EXP, A_TOWED
(Removed: YEAR — constant 2024; STATE — exact copy of accident.)

### `vevent` — 120,270 rows
**PK** `(ST_CASE, VEH_NO, VEVENTNUM)` · **FKs** `(ST_CASE, VEH_NO)` → `crash_unit` (D5), `(ST_CASE, EVENTNUM)` → `cevent` (D6)
**Columns (4):** ST_CASE, EVENTNUM, VEH_NO, VEVENTNUM
(Removed: VNUMBER1, AOI1, SOE, VNUMBER2, AOI2 — exact duplicates of `cevent`, D6.)

### `vsoe` — 120,270 rows (child of `vevent`)
**PK** `(ST_CASE, VEH_NO, VEVENTNUM)` ·
**FK** `(ST_CASE, VEH_NO, VEVENTNUM)` → `vevent`
**Columns (5):** ST_CASE, VEH_NO, VEVENTNUM, SOE, AOI

### `vpicdecode` — 55,087 rows (vPIC API decode, one row per vehicle)
**PK** `(ST_CASE, VEH_NO)` · **FK** `(ST_CASE, VEH_NO)` → `crash_unit` (mixed vehicle+parkwork units, D5)
**Columns (126):** ST_CASE, VEH_NO, VEHICLEDESCRIPTOR, VINDECODEDON,
VINDECODEERROR, VEHICLETYPEID, MANUFACTURERFULLNAMEID, MAKEID, MODELID,
MODELYEAR, SERIES, TRIM, SERIES2, TRIM2, PLANTCOUNTRYID, PLANTSTATE, PLANTCITY,
PLANTCOMPANYNAME, DESTINATIONMARKETID, BASEPRICE, NOTE, BODYCLASSID,
DOORSCOUNT, WINDOWS, WHEELBASETYPEID, TRACKWIDTHIN,
GROSSVEHICLEWEIGHTRATINGFROMID, GROSSVEHICLEWEIGHTRATINGTOID, CURBWEIGHTLB,
WHEELBASEIN_FROM, WHEELBASEIN_TO, WHEELSCOUNT, WHEELSIZEFRONTIN,
WHEELSIZEREARIN, TRUCKBODYCABTYPEID, TRUCKBEDTYPEID, TRUCKBEDLENGTHIN,
BUSTYPEID, BUSFLOORCONFIGURATIONTYPEID, BUSLENGTHFT, OTHERBUSINFO,
CUSTOMMOTORCYCLETYPEID, MOTORCYCLESUSPENSIONTYPEID, MOTORCYCLECHASSISTYPEID,
OTHERMOTORCYCLEINFO, STEERINGLOCATIONID, ENTERTAINMENTSYSTEMID, SEATSCOUNT,
SEATROWSCOUNT, TRANSMISSIONSPEEDS, TRANSMISSIONSTYLEID, DRIVETYPEID,
AXLESCOUNT, AXLECONFIGURATIONID, BRAKESYSTEMTYPEID, BRAKESYSTEMDESC,
EVDRIVEUNITID, BATTERYKWH_FROM, BATTERYKWH_TO, BATTERYV_FROM, BATTERYV_TO,
BATTERYA_FROM, BATTERYPACKSPERVEHICLE, BATTERYMODULESPERPACK,
BATTERYCELLSPERMODULE, BATTERYTYPEID, OTHERBATTERYINFO, CHARGERLEVELID,
CHARGERPOWERKW, ENGINEMANUFACTURER, ENGINEMODEL, ENGINECONFIGURATIONID,
ENGINEPOWERKW, ENGINESTROKECYCLES, ENGINECYLINDERSCOUNT, ENGINEBRAKEHP_FROM,
ENGINEBRAKEHP_TO, ENGINECOOLINGTYPEID, DISPLACEMENTCI, DISPLACEMENTCC,
DISPLACEMENTL, FUELTYPEPRIMARYID, FUELTYPESECONDARYID,
FUELDELIVERYINJECTIONTYPEID, ENGINEVALVETRAINDESIGNID,
ENGINEELECTRIFICATIONLEVELID, ENGINETURBOID, TOPSPEEDMPH, OTHERENGINEINFO,
SEATBELTTYPEID, PRETENSIONERID, AIRBAGLOCFRONTID, AIRBAGLOCKNEEID,
AIRBAGLOCSIDEID, AIRBAGLOCCURTAINID, AIRBAGLOCSEATCUSHIONID,
OTHERRESTRAINTSYSTEMINFO, FORWARDCOLLISIONWARNINGID, DYNAMICBRAKESUPPORTID,
CRASHIMMINENTBRAKINGID, PEDESTRIANAUTOEMERGENCYBRAKINGID, BLINDSPOTWARNINGID,
BLINDSPOTINTERVENTIONID, LANEDEPARTUREWARNINGID, LANEKEEPINGASSISTANCEID,
LANECENTERINGASSISTANCEID, BACKUPCAMERAID, REARCROSSTRAFFICALERTID,
REARAUTOMATICEMERGENCYBRAKINGID, PARKASSISTID, DAYTIMERUNNINGLIGHTID,
HEADLAMPLIGHTSOURCEID, SEMIAUTOHEADLAMPBEAMSWITCHINGID, ADAPTIVEDRIVINGBEAMID,
ADAPTIVECRUISECONTROLID, ANTILOCKBRAKESYSTEMID, ELECTRONICSTABILITYCONTROLID,
TPMSID, AUTOMATICCRASHNOTIFICATIONID, EVENTDATARECORDERID, TRACTIONCONTROLID,
AUTOPEDESTRIANALERTINGSOUNDID, KEYLESSIGNITIONID, SAEAUTOMATIONLEVEL_FROM,
AUTOREVERSESYSTEMID, ACTIVESAFETYSYSNOTE
(Removed: STATE; 68 `*NAME` label columns → `vpic_labels`. The 68 `*ID`
columns stay here as compact codes; join `vpic_labels` for display labels.)

### `vpictrailerdecode` — 1,639 rows
**PK** `(ST_CASE, VEH_NO, TRAILER_NO)` · **FK** `(ST_CASE, VEH_NO)` → `crash_unit` (mixed vehicle+parkwork units, D5)
**Columns (38):** ST_CASE, VEH_NO, TRAILER_NO, VEHICLEDESCRIPTOR, VINDECODEDON,
VINDECODEERROR, VEHICLETYPEID, VEHICLETYPE, MANUFACTURERFULLNAMEID,
MANUFACTURERFULLNAME, MAKEID, MAKE, MODELID, MODEL, MODELYEAR, SERIES, TRIM,
PLANTCOUNTRYID, PLANTCOUNTRY, PLANTSTATE, PLANTCITY, PLANTCOMPANYNAME, NOTE,
BODYCLASSID, BODYCLASS, GROSSVEHICLEWEIGHTRATINGFROMID,
GROSSVEHICLEWEIGHTRATINGFROM, GROSSVEHICLEWEIGHTRATINGTOID,
GROSSVEHICLEWEIGHTRATINGTO, TRAILERBODYTYPEID, TRAILERBODYTYPE,
TRAILERTYPECONNECTIONID, TRAILERTYPECONNECTION, TRAILERLENGTHFT,
OTHERTRAILERINFO, AXLESCOUNT, AXLECONFIGURATIONID, AXLECONFIGURATION
(Removed: STATE.)

### `parkwork` — 1,526 rows (parked/working vehicles, separate numbering)
**PK** `(ST_CASE, VEH_NO)` · **FKs** `ST_CASE` → `accident`, `(ST_CASE, VEH_NO)` → `crash_unit` (subtype, D5) (**no FK to `vehicle`** — numbering is separate, decision D3)
**Columns (39):** ST_CASE, VEH_NO, PNUMOCCS, PTYPE, PHIT_RUN, PREG_STAT,
POWNER, PVIN, PMODYEAR, PVPICMAKE, PVPICMODEL, PVPICBODYCLASS, PMAKE, PMODEL,
PBODYTYP, PICFINALBODY, PGVWR_FROM, PGVWR_TO, PTRAILER, PTRLR1VIN, PTRLR2VIN,
PTRLR1GVWR, PTRLR2GVWR, PMCARR_ID, PMCARR_I1, PMCARR_I2, PV_CONFIG, PCARGTYP,
PBUS_USE, PSP_USE, PEM_USE, PUNDEROVERRIDE, PIMPACT1, PVEH_SEV, PTOWED,
PM_HARM, PFIRE, PMAK_MOD, PDEATHS
(Removed: STATE; PVE_FORMS, PMONTH, PDAY, PHOUR, PMINUTE, PHARM_EV,
PMAN_COLL — exact copies of accident; PHAZ_* → `parkwork_hazmat`;
PTRLR3VIN, PTRLR3GVWR — constants; PVIN_1..12 → `pvin_detail`.)

## Person-level relations

All carry `FK (ST_CASE, VEH_NO, PER_NO)` → `person`
(the join works for `VEH_NO = 0` non-motorists too, since they are rows in
`person`).

### `drugs` — 128,399 rows
**PK** `drug_id` (surrogate, `AUTO_INCREMENT`) — decision D2
**Columns (9):** drug_id, ST_CASE, VEH_NO, PER_NO, DRUGSPEC,
DRUGMETHOD, DRUGRES, DRUGQTY, DRUGACTQTY, DRUGUOM
(748 exact-duplicate rows, so no natural key exists; logical key
`(ST_CASE, VEH_NO, PER_NO, ...)` kept as a non-unique index.
STATE removed — `ST_CASE → STATE` verified (2026-10-05), so it is a transitive dependency (3NF); crash STATE comes via `accident`.)

### `miper` — 64,616 rows
**PK** `(ST_CASE, VEH_NO, PER_NO)`
**Columns (13):** ST_CASE, VEH_NO, PER_NO, P1, P2, P3, P4, P5, P6, P7, P8,
P9, P10

### `nmcrash` — 13,054 rows
**PK** `(ST_CASE, VEH_NO, PER_NO, NMCC)`
**Columns (4):** ST_CASE, VEH_NO, PER_NO, NMCC

### `nmdistract` — 9,020 rows
**PK** `(ST_CASE, VEH_NO, PER_NO)`
**Columns (4):** ST_CASE, VEH_NO, PER_NO, NMDISTRACT

### `nmimpair` — 9,037 rows
**PK** `(ST_CASE, VEH_NO, PER_NO, NMIMPAIR)`
**Columns (4):** ST_CASE, VEH_NO, PER_NO, NMIMPAIR

### `nmprior` — 9,344 rows
**PK** `(ST_CASE, VEH_NO, PER_NO, NMACTION)`
**Columns (4):** ST_CASE, VEH_NO, PER_NO, NMACTION

### `pbtype` — 8,940 rows
**PK** `(ST_CASE, VEH_NO, PER_NO)`
**Columns (20):** ST_CASE, VEH_NO, PER_NO, PBAGE, PBSEX, PBPTYPE, PBCWALK,
PBSWALK, PEDCTYPE, BIKECTYPE, PEDLOC, BIKELOC, PEDPOS, BIKEPOS, PEDDIR,
BIKEDIR, MOTDIR, MOTMAN, PEDLEG, PEDSNR
(Removed: STATE; PBSZONE → `crash_pbszone`; PEDCGP → `ped_crash_group`;
BIKECGP → `bike_crash_group`.)

### `per_aux` — 88,326 rows
**PK** `(ST_CASE, VEH_NO, PER_NO)`
**Columns (18):** ST_CASE, VEH_NO, PER_NO, A_AGE3, A_AGE6, A_AGE7, A_AGE8,
A_PTYPE, A_RESTUSE, A_HELMUSE, A_ALCTES, A_HISP, A_RCAT, A_HRACE, A_EJECT,
A_PERINJ, A_LOC, A_DOA
(Removed: STATE, YEAR — YEAR constant 2024; A_AGE1, A_AGE2, A_AGE4, A_AGE5,
A_AGE9 → `age_band_map`.)

### `personrf` — 88,343 rows
**PK** `(ST_CASE, VEH_NO, PER_NO, PERSONRF)`
**Columns (4):** ST_CASE, VEH_NO, PER_NO, PERSONRF

### `race` — 88,517 rows
**PK** `(ST_CASE, VEH_NO, PER_NO, RACE_ORDER)`
**Columns (5):** ST_CASE, VEH_NO, PER_NO, RACE, RACE_ORDER
(`ORDER` renamed `RACE_ORDER` — ORDER is reserved in MySQL.
MULTRACE moved to `person` — constant per person, partial dependency (D8).)

### `safetyeq` — 9,020 rows
**PK** `(ST_CASE, VEH_NO, PER_NO)`
**Columns (9):** ST_CASE, VEH_NO, PER_NO, NMHELMET, NMPROPAD, NMOTHPRO,
NMREFCLO, NMLIGHT, NMOTHPRE

## Normalization lookups (reference joins, not FKs)

These hold the right-hand sides of transitive FDs. They are joined on
non-unique columns (e.g. `accident.STATE`), so they are **not** FK targets
in the strict sense — they are reference tables for queries and display.

### `vpic_labels` — 3,170 rows · **NEW** (3NF: 68 × `*ID → *NAME`)
**PK** `(attribute, id)`
**Columns (3):** attribute, id, label
(`attribute` names which vpicdecode ID column the pair belongs to, e.g.
`'MAKE'`; `id`/`label` are the code and its display text.)

### `pvin_detail` — 1,465 rows · **NEW** (3NF: `PVIN → PVIN_1..12`)
**PK** `PVIN`
**Columns (13):** PVIN, PVIN_1, PVIN_2, PVIN_3, PVIN_4, PVIN_5, PVIN_6,
PVIN_7, PVIN_8, PVIN_9, PVIN_10, PVIN_11, PVIN_12

### `state_region` — 51 rows · **NEW** (3NF: `STATE → A_REGION`)
**PK** `STATE`
**Columns (2):** STATE, A_REGION

### `roadfc_inter` — 7 rows · **NEW** (3NF: `A_ROADFC → A_INTER`)
**PK** `A_ROADFC`
**Columns (2):** A_ROADFC, A_INTER

### `junc_intsec` — 4 rows · **NEW** (3NF: `A_JUNC → A_INTSEC`)
**PK** `A_JUNC`
**Columns (2):** A_JUNC, A_INTSEC

### `age_band_map` — 13 rows · **NEW** (3NF: `A_AGE3 → A_AGE1, A_AGE2, A_AGE4, A_AGE5, A_AGE9`)
**PK** `A_AGE3`
**Columns (6):** A_AGE3, A_AGE1, A_AGE2, A_AGE4, A_AGE5, A_AGE9
(`A_AGE3` is the finest age scheme; the rest are coarser re-binnings.)

### `ped_crash_group` — 51 rows · **NEW** (3NF: `PEDCTYPE → PEDCGP`)
**PK** `PEDCTYPE`
**Columns (2):** PEDCTYPE, PEDCGP

### `bike_crash_group` — 66 rows · **NEW** (3NF: `BIKECTYPE → BIKECGP`)
**PK** `BIKECTYPE`
**Columns (2):** BIKECTYPE, BIKECGP

## ETL lookups (pre-existing)

| Table | PK | Columns | Rows |
|---|---|---|---|
| `code_labels` | (`column`, `code`) | `column` VARCHAR(32), code INT, label VARCHAR(128) | 8,892 |
| `county` | (`STATE`, `COUNTY`) | STATE, COUNTY, county_name | 2,827 |
| `city` | (`STATE`, `CITY`) | STATE, CITY, city_name | 5,507 |

`` `column` `` is backticked — COLUMN is reserved in MySQL.

## Foreign key summary

| Child FK | References | Notes |
|---|---|---|
| vehicle.ST_CASE | accident.ST_CASE | |
| vehicle.VIN | vin_detail.VIN | FK to a non-PK unique column |
| person.ST_CASE | accident.ST_CASE | |
| person.(DEATH_HR, DEATH_MN) | death_time.(DEATH_HR, DEATH_MN) | FK to a non-PK unique column |
| accident.(YEAR, MONTH, DAY) | calendar.(YEAR, MONTH, DAY) | FK to a non-PK unique column |
| acc_aux / cevent / crashrf / weather / miacc / midrvacc / parkwork_hazmat / crash_pbszone .ST_CASE | accident.ST_CASE | |
| damage / distract / drimpair / driverrf / factor / maneuver / vehiclesf / violatn / vision / veh_aux .(ST_CASE, VEH_NO) | vehicle.(ST_CASE, VEH_NO) | |
| vevent / vpicdecode / vpictrailerdecode .(ST_CASE, VEH_NO) | crash_unit.(ST_CASE, VEH_NO) | mixed vehicle+parkwork units (D5) |
| vehicle.(ST_CASE, VEH_NO) / parkwork.(ST_CASE, VEH_NO) | crash_unit.(ST_CASE, VEH_NO) | subtype FKs (D5) |
| vevent.(ST_CASE, EVENTNUM) | cevent.(ST_CASE, EVENTNUM) | event descriptors live in cevent (D6) |
| vsoe.(ST_CASE, VEH_NO, VEVENTNUM) | vevent.(ST_CASE, VEH_NO, VEVENTNUM) | PK minimality (D7); follows vevent to crash_unit |
| parkwork.ST_CASE, pvehiclesf.ST_CASE | accident.ST_CASE | no FK to vehicle (D3); parkwork also FK → crash_unit (D5) |
| drugs / miper / nmcrash / nmdistract / nmimpair / nmprior / pbtype / per_aux / personrf / race / safetyeq .(ST_CASE, VEH_NO, PER_NO) | person.(ST_CASE, VEH_NO, PER_NO) | includes VEH_NO = 0 rows |
| **No FK** person → vehicle | — | would reject 9,020 valid non-motorist rows (D1) |

## Design decisions

**D1 — Non-motorists (`person.VEH_NO = 0`).** 9,020 person rows
(pedestrians, cyclists) have `VEH_NO = 0` and match no `vehicle` row.
Options considered: (a) separate `non_motorist` table, (b) keep in `person`
with FK only to `accident`. Chosen: **(b)** — one person table keeps
person-level queries simple (no UNION), and the `VEH_NO = 0` convention is
documented here and in the data dictionary. The vehicle↔person link for
motorists is a logical join (`WHERE VEH_NO > 0`), not an enforced FK.

**D2 — `drugs` surrogate key.** 748 rows are exact duplicates of another
row (real repeated test results), so no natural key exists.
`drug_id INT AUTO_INCREMENT PRIMARY KEY`; the logical key
`(ST_CASE, VEH_NO, PER_NO, ...)` is kept as a non-unique index.

**D3 — `parkwork` / `pvehiclesf` have no FK to `vehicle`.** Their 1,526
rows describe parked/working vehicles numbered separately from
`vehicle.csv`; zero rows match a `vehicle` row (verified on 2024 data).
They reference `accident` only.

**D4 — Deferred FK creation.** `sql/schema/04_constraints_indexes.sql`
adds FKs after the load scripts run, so bulk `LOAD DATA` isn't slowed by
constraint checks. Equivalent to creating them upfront for correctness.

**D5 — `crash_unit` supertype for mixed-grain children.** Post-verification finding (2026-10-05, colleague review): `vevent`, `vsoe`, `vpicdecode` and `vpictrailerdecode` contain units from *both* `vehicle` (56,011) and `parkwork` (1,526) — numbering is separate (0 overlap, D3 still holds), but parked/working units get event rows and VIN decodes. Measured: vevent/vsoe cover all 1,526 parkwork units; vpicdecode 1,454; vpictrailerdecode 79; 0 orphans. FKs to `vehicle` would fail (4,585 unit references with no parent) — the D1 failure mode. New supertype `crash_unit(ST_CASE, VEH_NO, unit_type)` = vehicle ∪ parkwork key sets (57,537 rows); `vehicle`/`parkwork` are subtypes (FK → `crash_unit`); `vevent`, `vpicdecode`, `vpictrailerdecode` FK to `crash_unit` (`vsoe` follows via `vevent`). Ten vehicle-only children keep FK to `vehicle`. Unlike D1, every row satisfies the supertype FK, so enforcement is safe.

**D6 — `vevent` deduplicated against `cevent`.** Five columns (`VNUMBER1`, `AOI1`, `SOE`, `VNUMBER2`, `AOI2`) duplicated `cevent` for the same `(ST_CASE, EVENTNUM)` (0 mismatches). Removed from `vevent` (9 → 4 cols); `FK (ST_CASE, EVENTNUM)` → `cevent` kept.

**D7 — `vsoe` PK minimality.** `(ST_CASE, VEH_NO, VEVENTNUM)` already unique (120,270 rows); `SOE` removed from PK, kept as attribute.

**D8 — `MULTRACE` to `person` (2NF).** Constant per `(ST_CASE, VEH_NO, PER_NO)` in `race` — partial dependency. Moved to `person`.

**D9 — 16 unit-grain columns to `crash_unit`.** `BODY_TYP`, `EMER_USE`, `FIRE_EXP`, `GVWR_FROM`, `GVWR_TO`, `ICFINALBODY`, `IMPACT1`, `MAKE`, `MAK_MOD`, `MOD_YEAR`, `ROLLOVER`, `SPEC_USE`, `TOW_VEH`, `VPICBODYCLASS`, `VPICMAKE`, `VPICMODEL` are FD on the unit key, not the vehicle key: 426 `person` rows belong to `parkwork` units whose values exist only in `person` (unrecoverable via `vehicle`). Now on `crash_unit` (from `vehicle.csv` for V units, `person` deduped for P units). `vehicle` 89 → 73 cols. Lossless for all persons.

## ER diagram

Source: `../erd/fars_erd.drawio` (editable) · exported PNG:
`../erd/fars_erd.png` — TODO: draw and export from this schema.

## DDL watchlist

Columns needing special handling at DDL/load time (see normalization.md):
- Codes are identifiers, not numbers → `TEXT`/`VARCHAR`: `code_labels.code` must be text (leading zeros, non-numeric codes); label columns → `VARCHAR(255)` (item 7).
- Blank-value handling: convert empty strings to `NULL` before loading into numeric MySQL columns (`NULLIF(col,'')` in `LOAD DATA` or equivalent) — `''` → `0` coercion corrupts missingness (item 9).
- Mixed int/str → `TEXT`: `vehicle.TRLR3VIN`, `vehicle.MCARR_ID`,
  `vehicle.MCARR_I2`, `vpicdecode.OTHERBUSINFO`, `vpicdecode.CHARGERLEVEL`
- `acc_aux.CENSUS_2020_TRACT_FIPS` — float-mangled in source CSV, clean on load
- `race.RACE_ORDER` — renamed from reserved word `ORDER`
- `code_labels.column` — backticked, reserved word
