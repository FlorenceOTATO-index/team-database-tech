-- 06_load_vehicle_parkwork.sql
-- Phase 2: vehicle and parkwork (the crash_unit subtypes).
-- Parents: accident (04), crash_unit (05), vin_detail (03). parkwork keeps
-- its P* unit columns as the approved schema lists them, even though
-- crash_unit also holds a copy.
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/06_load_vehicle_parkwork.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`vehicle`) = 0, 'fars.vehicle must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`parkwork`) = 0, 'fars.parkwork must be empty before loading');

-- vehicle: 56,011 rows expected.
-- Not loaded from data/processed/vehicle.csv: STATE, VE_FORMS, MONTH, DAY,
-- HOUR, MINUTE, HARM_EV, MAN_COLL, MOD_YEAR, VPICMAKE, VPICMODEL,
-- VPICBODYCLASS, MAKE, BODY_TYP, ICFINALBODY, GVWR_FROM, GVWR_TO, TOW_VEH,
-- SPEC_USE, EMER_USE, ROLLOVER, IMPACT1, FIRE_EXP, MAK_MOD, VIN_1, VIN_2,
-- VIN_3, VIN_4, VIN_5, VIN_6, VIN_7, VIN_8, VIN_9, VIN_10, VIN_11, VIN_12.
-- Reason: crash-level copies live in accident, the 16 unit attributes in
-- crash_unit, VIN_1..VIN_12 in vin_detail.
INSERT INTO `fars`.`vehicle` (
  `ST_CASE`, `VEH_NO`, `ACC_TYPE`, `BUS_USE`, `CARGO_BT`, `CDL_STAT`,
  `DEATHS`, `DEFORMED`, `DR_DRINK`, `DR_HGT`, `DR_PRES`, `DR_WGT`, `DR_ZIP`,
  `FIRST_MO`, `FIRST_YR`, `HAZ_CNO`, `HAZ_ID`, `HAZ_INV`, `HAZ_PLAC`,
  `HAZ_REL`, `HIT_RUN`, `J_KNIFE`, `LAST_MO`, `LAST_YR`, `L_COMPL`,
  `L_ENDORS`, `L_RESTRI`, `L_STATE`, `L_STATUS`, `L_TYPE`, `MCARR_I1`,
  `MCARR_I2`, `MCARR_ID`, `MODEL`, `M_HARM`, `NUMOCCS`, `OWNER`, `PCRASH4`,
  `PCRASH5`, `PREV_ACC`, `PREV_DWI`, `PREV_OTH`, `PREV_SPD`, `PREV_SUS1`,
  `PREV_SUS2`, `PREV_SUS3`, `P_CRASH1`, `P_CRASH2`, `P_CRASH3`, `REG_STAT`,
  `ROLINLOC`, `SPEEDREL`, `TOWED`, `TRAV_SP`, `TRLR1GVWR`, `TRLR1VIN`,
  `TRLR2GVWR`, `TRLR2VIN`, `TRLR3GVWR`, `TRLR3VIN`, `UNDEROVERRIDE`,
  `UNITTYPE`, `VALIGN`, `VIN`, `VNUM_LAN`, `VPAVETYP`, `VPROFILE`,
  `VSPD_LIM`, `VSURCOND`, `VTCONT_F`, `VTRAFCON`, `VTRAFWAY`, `V_CONFIG`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`ACC_TYPE`, '') AS `ACC_TYPE`,
  NULLIF(s.`BUS_USE`, '') AS `BUS_USE`,
  NULLIF(s.`CARGO_BT`, '') AS `CARGO_BT`,
  NULLIF(s.`CDL_STAT`, '') AS `CDL_STAT`,
  NULLIF(s.`DEATHS`, '') AS `DEATHS`,
  NULLIF(s.`DEFORMED`, '') AS `DEFORMED`,
  NULLIF(s.`DR_DRINK`, '') AS `DR_DRINK`,
  NULLIF(s.`DR_HGT`, '') AS `DR_HGT`,
  NULLIF(s.`DR_PRES`, '') AS `DR_PRES`,
  NULLIF(s.`DR_WGT`, '') AS `DR_WGT`,
  NULLIF(s.`DR_ZIP`, '') AS `DR_ZIP`,
  NULLIF(s.`FIRST_MO`, '') AS `FIRST_MO`,
  NULLIF(s.`FIRST_YR`, '') AS `FIRST_YR`,
  NULLIF(s.`HAZ_CNO`, '') AS `HAZ_CNO`,
  NULLIF(s.`HAZ_ID`, '') AS `HAZ_ID`,
  NULLIF(s.`HAZ_INV`, '') AS `HAZ_INV`,
  NULLIF(s.`HAZ_PLAC`, '') AS `HAZ_PLAC`,
  NULLIF(s.`HAZ_REL`, '') AS `HAZ_REL`,
  NULLIF(s.`HIT_RUN`, '') AS `HIT_RUN`,
  NULLIF(s.`J_KNIFE`, '') AS `J_KNIFE`,
  NULLIF(s.`LAST_MO`, '') AS `LAST_MO`,
  NULLIF(s.`LAST_YR`, '') AS `LAST_YR`,
  NULLIF(s.`L_COMPL`, '') AS `L_COMPL`,
  NULLIF(s.`L_ENDORS`, '') AS `L_ENDORS`,
  NULLIF(s.`L_RESTRI`, '') AS `L_RESTRI`,
  NULLIF(s.`L_STATE`, '') AS `L_STATE`,
  NULLIF(s.`L_STATUS`, '') AS `L_STATUS`,
  NULLIF(s.`L_TYPE`, '') AS `L_TYPE`,
  NULLIF(s.`MCARR_I1`, '') AS `MCARR_I1`,
  NULLIF(s.`MCARR_I2`, '') AS `MCARR_I2`,
  NULLIF(s.`MCARR_ID`, '') AS `MCARR_ID`,
  NULLIF(s.`MODEL`, '') AS `MODEL`,
  NULLIF(s.`M_HARM`, '') AS `M_HARM`,
  NULLIF(s.`NUMOCCS`, '') AS `NUMOCCS`,
  NULLIF(s.`OWNER`, '') AS `OWNER`,
  NULLIF(s.`PCRASH4`, '') AS `PCRASH4`,
  NULLIF(s.`PCRASH5`, '') AS `PCRASH5`,
  NULLIF(s.`PREV_ACC`, '') AS `PREV_ACC`,
  NULLIF(s.`PREV_DWI`, '') AS `PREV_DWI`,
  NULLIF(s.`PREV_OTH`, '') AS `PREV_OTH`,
  NULLIF(s.`PREV_SPD`, '') AS `PREV_SPD`,
  NULLIF(s.`PREV_SUS1`, '') AS `PREV_SUS1`,
  NULLIF(s.`PREV_SUS2`, '') AS `PREV_SUS2`,
  NULLIF(s.`PREV_SUS3`, '') AS `PREV_SUS3`,
  NULLIF(s.`P_CRASH1`, '') AS `P_CRASH1`,
  NULLIF(s.`P_CRASH2`, '') AS `P_CRASH2`,
  NULLIF(s.`P_CRASH3`, '') AS `P_CRASH3`,
  NULLIF(s.`REG_STAT`, '') AS `REG_STAT`,
  NULLIF(s.`ROLINLOC`, '') AS `ROLINLOC`,
  NULLIF(s.`SPEEDREL`, '') AS `SPEEDREL`,
  NULLIF(s.`TOWED`, '') AS `TOWED`,
  NULLIF(s.`TRAV_SP`, '') AS `TRAV_SP`,
  NULLIF(s.`TRLR1GVWR`, '') AS `TRLR1GVWR`,
  NULLIF(s.`TRLR1VIN`, '') AS `TRLR1VIN`,
  NULLIF(s.`TRLR2GVWR`, '') AS `TRLR2GVWR`,
  NULLIF(s.`TRLR2VIN`, '') AS `TRLR2VIN`,
  NULLIF(s.`TRLR3GVWR`, '') AS `TRLR3GVWR`,
  NULLIF(s.`TRLR3VIN`, '') AS `TRLR3VIN`,
  NULLIF(s.`UNDEROVERRIDE`, '') AS `UNDEROVERRIDE`,
  NULLIF(s.`UNITTYPE`, '') AS `UNITTYPE`,
  NULLIF(s.`VALIGN`, '') AS `VALIGN`,
  NULLIF(s.`VIN`, '') AS `VIN`,
  NULLIF(s.`VNUM_LAN`, '') AS `VNUM_LAN`,
  NULLIF(s.`VPAVETYP`, '') AS `VPAVETYP`,
  NULLIF(s.`VPROFILE`, '') AS `VPROFILE`,
  NULLIF(s.`VSPD_LIM`, '') AS `VSPD_LIM`,
  NULLIF(s.`VSURCOND`, '') AS `VSURCOND`,
  NULLIF(s.`VTCONT_F`, '') AS `VTCONT_F`,
  NULLIF(s.`VTRAFCON`, '') AS `VTRAFCON`,
  NULLIF(s.`VTRAFWAY`, '') AS `VTRAFWAY`,
  NULLIF(s.`V_CONFIG`, '') AS `V_CONFIG`
FROM `fars_stage`.`vehicle` AS s;

-- parkwork: 1,526 rows expected.
-- Not loaded from data/processed/parkwork.csv: STATE, PVE_FORMS, PMONTH,
-- PDAY, PHOUR, PMINUTE, PHARM_EV, PMAN_COLL, PTRLR3VIN, PTRLR3GVWR, PHAZ_INV,
-- PHAZPLAC, PHAZ_ID, PHAZ_CNO, PHAZ_REL, PVIN_1, PVIN_2, PVIN_3, PVIN_4,
-- PVIN_5, PVIN_6, PVIN_7, PVIN_8, PVIN_9, PVIN_10, PVIN_11, PVIN_12.
-- Reason: crash-level copies live in accident, PHAZ_* in parkwork_hazmat,
-- PVIN_1..PVIN_12 in pvin_detail; PTRLR3VIN and PTRLR3GVWR are not in the
-- schema (dataset constants).
INSERT INTO `fars`.`parkwork` (
  `ST_CASE`, `VEH_NO`, `PNUMOCCS`, `PTYPE`, `PHIT_RUN`, `PREG_STAT`,
  `POWNER`, `PVIN`, `PMODYEAR`, `PVPICMAKE`, `PVPICMODEL`, `PVPICBODYCLASS`,
  `PMAKE`, `PMODEL`, `PBODYTYP`, `PICFINALBODY`, `PGVWR_FROM`, `PGVWR_TO`,
  `PTRAILER`, `PTRLR1VIN`, `PTRLR2VIN`, `PTRLR1GVWR`, `PTRLR2GVWR`,
  `PMCARR_ID`, `PMCARR_I1`, `PMCARR_I2`, `PV_CONFIG`, `PCARGTYP`, `PBUS_USE`,
  `PSP_USE`, `PEM_USE`, `PUNDEROVERRIDE`, `PIMPACT1`, `PVEH_SEV`, `PTOWED`,
  `PM_HARM`, `PFIRE`, `PMAK_MOD`, `PDEATHS`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PNUMOCCS`, '') AS `PNUMOCCS`,
  NULLIF(s.`PTYPE`, '') AS `PTYPE`,
  NULLIF(s.`PHIT_RUN`, '') AS `PHIT_RUN`,
  NULLIF(s.`PREG_STAT`, '') AS `PREG_STAT`,
  NULLIF(s.`POWNER`, '') AS `POWNER`,
  NULLIF(s.`PVIN`, '') AS `PVIN`,
  NULLIF(s.`PMODYEAR`, '') AS `PMODYEAR`,
  NULLIF(s.`PVPICMAKE`, '') AS `PVPICMAKE`,
  NULLIF(s.`PVPICMODEL`, '') AS `PVPICMODEL`,
  NULLIF(s.`PVPICBODYCLASS`, '') AS `PVPICBODYCLASS`,
  NULLIF(s.`PMAKE`, '') AS `PMAKE`,
  NULLIF(s.`PMODEL`, '') AS `PMODEL`,
  NULLIF(s.`PBODYTYP`, '') AS `PBODYTYP`,
  NULLIF(s.`PICFINALBODY`, '') AS `PICFINALBODY`,
  NULLIF(s.`PGVWR_FROM`, '') AS `PGVWR_FROM`,
  NULLIF(s.`PGVWR_TO`, '') AS `PGVWR_TO`,
  NULLIF(s.`PTRAILER`, '') AS `PTRAILER`,
  NULLIF(s.`PTRLR1VIN`, '') AS `PTRLR1VIN`,
  NULLIF(s.`PTRLR2VIN`, '') AS `PTRLR2VIN`,
  NULLIF(s.`PTRLR1GVWR`, '') AS `PTRLR1GVWR`,
  NULLIF(s.`PTRLR2GVWR`, '') AS `PTRLR2GVWR`,
  NULLIF(s.`PMCARR_ID`, '') AS `PMCARR_ID`,
  NULLIF(s.`PMCARR_I1`, '') AS `PMCARR_I1`,
  NULLIF(s.`PMCARR_I2`, '') AS `PMCARR_I2`,
  NULLIF(s.`PV_CONFIG`, '') AS `PV_CONFIG`,
  NULLIF(s.`PCARGTYP`, '') AS `PCARGTYP`,
  NULLIF(s.`PBUS_USE`, '') AS `PBUS_USE`,
  NULLIF(s.`PSP_USE`, '') AS `PSP_USE`,
  NULLIF(s.`PEM_USE`, '') AS `PEM_USE`,
  NULLIF(s.`PUNDEROVERRIDE`, '') AS `PUNDEROVERRIDE`,
  NULLIF(s.`PIMPACT1`, '') AS `PIMPACT1`,
  NULLIF(s.`PVEH_SEV`, '') AS `PVEH_SEV`,
  NULLIF(s.`PTOWED`, '') AS `PTOWED`,
  NULLIF(s.`PM_HARM`, '') AS `PM_HARM`,
  NULLIF(s.`PFIRE`, '') AS `PFIRE`,
  NULLIF(s.`PMAK_MOD`, '') AS `PMAK_MOD`,
  NULLIF(s.`PDEATHS`, '') AS `PDEATHS`
FROM `fars_stage`.`parkwork` AS s;

COMMIT;
