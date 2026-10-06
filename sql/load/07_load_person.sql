-- 07_load_person.sql
-- Phase 2: person (MULTRACE from race.csv, D8).
-- One row per person, including the 9,020 non-motorists with VEH_NO = 0.
-- Parents: accident (04), death_time (03). There is no FK from person to
-- vehicle (D1).
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/07_load_person.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`person`) = 0, 'fars.person must be empty before loading');

-- ------------------------------------------------------------------------
-- Preconditions
-- ------------------------------------------------------------------------

-- race.csv must carry exactly one MULTRACE value per person ...
CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM (
     SELECT 1 FROM `fars_stage`.`race`
     GROUP BY `ST_CASE`, `VEH_NO`, `PER_NO`
     HAVING COUNT(DISTINCT NULLIF(`MULTRACE`, '')) > 1) AS x) = 0,
  'race.csv has more than one MULTRACE value for a person');
-- ... and every person in person.csv must have one.
CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM `fars_stage`.`person` AS s
    WHERE NOT EXISTS (SELECT 1 FROM `fars_stage`.`race` AS r
                      WHERE r.`ST_CASE` = s.`ST_CASE` AND r.`VEH_NO` = s.`VEH_NO`
                        AND r.`PER_NO` = s.`PER_NO` AND r.`MULTRACE` <> '')) = 0,
  'a person in person.csv has no MULTRACE value in race.csv');

-- ------------------------------------------------------------------------
-- Load
-- ------------------------------------------------------------------------

-- person: 88,326 rows expected.
-- Not loaded from data/processed/person.csv: STATE, VE_FORMS, COUNTY, MONTH,
-- DAY, HOUR, MINUTE, HARM_EV, MAN_COLL, SCH_BUS, RUR_URB, FUNC_SYS, MOD_YEAR,
-- VPICMAKE, VPICMODEL, VPICBODYCLASS, MAKE, BODY_TYP, ICFINALBODY, GVWR_FROM,
-- GVWR_TO, TOW_VEH, SPEC_USE, EMER_USE, ROLLOVER, IMPACT1, FIRE_EXP, MAK_MOD,
-- DEATH_TM.
-- Reason: crash-level copies live in accident, the 16 unit attributes in
-- crash_unit, DEATH_TM in death_time.
-- MULTRACE is not in person.csv; it comes from race.csv, which carries one
-- MULTRACE value per person (checked above, so no fallback value is ever
-- used).
INSERT INTO `fars`.`person` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `AGE`, `AIR_BAG`, `ALC_RES`, `ALC_STATUS`,
  `ATST_TYP`, `DEATH_DA`, `DEATH_HR`, `DEATH_MN`, `DEATH_MO`, `DEATH_YR`,
  `DEVMOTOR`, `DEVTYPE`, `DOA`, `DRINKING`, `DRUGS`, `DSTATUS`, `EJECTION`,
  `EJ_PATH`, `EXTRICAT`, `HELM_MIS`, `HELM_USE`, `HISPANIC`, `HOSPITAL`,
  `INJ_SEV`, `LAG_HRS`, `LAG_MINS`, `LOCATION`, `MULTRACE`, `PER_TYP`,
  `REST_MIS`, `REST_USE`, `SEAT_POS`, `SEX`, `STR_VEH`, `WORK_INJ`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`AGE`, '') AS `AGE`,
  NULLIF(s.`AIR_BAG`, '') AS `AIR_BAG`,
  NULLIF(s.`ALC_RES`, '') AS `ALC_RES`,
  NULLIF(s.`ALC_STATUS`, '') AS `ALC_STATUS`,
  NULLIF(s.`ATST_TYP`, '') AS `ATST_TYP`,
  NULLIF(s.`DEATH_DA`, '') AS `DEATH_DA`,
  NULLIF(s.`DEATH_HR`, '') AS `DEATH_HR`,
  NULLIF(s.`DEATH_MN`, '') AS `DEATH_MN`,
  NULLIF(s.`DEATH_MO`, '') AS `DEATH_MO`,
  NULLIF(s.`DEATH_YR`, '') AS `DEATH_YR`,
  NULLIF(s.`DEVMOTOR`, '') AS `DEVMOTOR`,
  NULLIF(s.`DEVTYPE`, '') AS `DEVTYPE`,
  NULLIF(s.`DOA`, '') AS `DOA`,
  NULLIF(s.`DRINKING`, '') AS `DRINKING`,
  NULLIF(s.`DRUGS`, '') AS `DRUGS`,
  NULLIF(s.`DSTATUS`, '') AS `DSTATUS`,
  NULLIF(s.`EJECTION`, '') AS `EJECTION`,
  NULLIF(s.`EJ_PATH`, '') AS `EJ_PATH`,
  NULLIF(s.`EXTRICAT`, '') AS `EXTRICAT`,
  NULLIF(s.`HELM_MIS`, '') AS `HELM_MIS`,
  NULLIF(s.`HELM_USE`, '') AS `HELM_USE`,
  NULLIF(s.`HISPANIC`, '') AS `HISPANIC`,
  NULLIF(s.`HOSPITAL`, '') AS `HOSPITAL`,
  NULLIF(s.`INJ_SEV`, '') AS `INJ_SEV`,
  NULLIF(s.`LAG_HRS`, '') AS `LAG_HRS`,
  NULLIF(s.`LAG_MINS`, '') AS `LAG_MINS`,
  NULLIF(s.`LOCATION`, '') AS `LOCATION`,
  (SELECT MIN(NULLIF(r.`MULTRACE`, '')) FROM `fars_stage`.`race` AS r
     WHERE r.`ST_CASE` = s.`ST_CASE` AND r.`VEH_NO` = s.`VEH_NO` AND r.`PER_NO` = s.`PER_NO`) AS `MULTRACE`,
  NULLIF(s.`PER_TYP`, '') AS `PER_TYP`,
  NULLIF(s.`REST_MIS`, '') AS `REST_MIS`,
  NULLIF(s.`REST_USE`, '') AS `REST_USE`,
  NULLIF(s.`SEAT_POS`, '') AS `SEAT_POS`,
  NULLIF(s.`SEX`, '') AS `SEX`,
  NULLIF(s.`STR_VEH`, '') AS `STR_VEH`,
  NULLIF(s.`WORK_INJ`, '') AS `WORK_INJ`
FROM `fars_stage`.`person` AS s;

COMMIT;
