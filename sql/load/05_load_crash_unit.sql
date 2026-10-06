-- 05_load_crash_unit.sql
-- Phase 2: crash_unit (unit supertype, D5 and D9).
-- Every unit in a crash: in-transport vehicles (V) and parked/working
-- vehicles (P). Parent: accident (04).
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/05_load_crash_unit.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`crash_unit`) = 0, 'fars.crash_unit must be empty before loading');

-- ------------------------------------------------------------------------
-- Preconditions
-- ------------------------------------------------------------------------

-- Every unit is either in transport (vehicle.csv) or parked/working (parkwork.csv), never both.
CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM `fars_stage`.`parkwork` AS p
    WHERE EXISTS (SELECT 1 FROM `fars_stage`.`vehicle` AS v
                  WHERE v.`ST_CASE` = p.`ST_CASE` AND v.`VEH_NO` = p.`VEH_NO`)) = 0,
  'vehicle.csv and parkwork.csv share a (ST_CASE, VEH_NO) unit key');
-- The occupants of a parked unit must agree on ROLLOVER; otherwise the value would be a guess.
CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM `fars_stage`.`parkwork` AS p
    WHERE (SELECT COUNT(DISTINCT NULLIF(x.`ROLLOVER`, '')) FROM `fars_stage`.`person` AS x
           WHERE x.`ST_CASE` = p.`ST_CASE` AND x.`VEH_NO` = p.`VEH_NO`) > 1) = 0,
  'occupants of a parked unit disagree on ROLLOVER');

-- ------------------------------------------------------------------------
-- Load
-- ------------------------------------------------------------------------

-- crash_unit: 57,537 rows expected.
-- 57,537 = 56,011 in-transport units (V) + 1,526 parked/working units (P).
-- V rows: key and all 16 unit attributes from vehicle.csv.
-- P rows: key and 15 attributes from the parkwork.csv P* columns (MOD_YEAR <-
-- PMODYEAR, VPICMAKE <- PVPICMAKE, VPICMODEL <- PVPICMODEL, VPICBODYCLASS <-
-- PVPICBODYCLASS, MAKE <- PMAKE, BODY_TYP <- PBODYTYP, ICFINALBODY <-
-- PICFINALBODY, GVWR_FROM <- PGVWR_FROM, GVWR_TO <- PGVWR_TO, TOW_VEH <-
-- PTRAILER, SPEC_USE <- PSP_USE, EMER_USE <- PEM_USE, IMPACT1 <- PIMPACT1,
-- FIRE_EXP <- PFIRE, MAK_MOD <- PMAK_MOD).
-- P-row ROLLOVER: parkwork.csv has no rollover column, so it comes from the
-- unit's occupant rows in person.csv (checked above to agree). Units without
-- occupants keep NULL; no FARS code is substituted.
INSERT INTO `fars`.`crash_unit` (
  `ST_CASE`, `VEH_NO`, `unit_type`, `BODY_TYP`, `EMER_USE`, `FIRE_EXP`,
  `GVWR_FROM`, `GVWR_TO`, `ICFINALBODY`, `IMPACT1`, `MAKE`, `MAK_MOD`,
  `MOD_YEAR`, `ROLLOVER`, `SPEC_USE`, `TOW_VEH`, `VPICBODYCLASS`, `VPICMAKE`,
  `VPICMODEL`
)
SELECT
  NULLIF(v.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(v.`VEH_NO`, '') AS `VEH_NO`,
  'V' AS `unit_type`,
  NULLIF(v.`BODY_TYP`, '') AS `BODY_TYP`,
  NULLIF(v.`EMER_USE`, '') AS `EMER_USE`,
  NULLIF(v.`FIRE_EXP`, '') AS `FIRE_EXP`,
  NULLIF(v.`GVWR_FROM`, '') AS `GVWR_FROM`,
  NULLIF(v.`GVWR_TO`, '') AS `GVWR_TO`,
  NULLIF(v.`ICFINALBODY`, '') AS `ICFINALBODY`,
  NULLIF(v.`IMPACT1`, '') AS `IMPACT1`,
  NULLIF(v.`MAKE`, '') AS `MAKE`,
  NULLIF(v.`MAK_MOD`, '') AS `MAK_MOD`,
  NULLIF(v.`MOD_YEAR`, '') AS `MOD_YEAR`,
  NULLIF(v.`ROLLOVER`, '') AS `ROLLOVER`,
  NULLIF(v.`SPEC_USE`, '') AS `SPEC_USE`,
  NULLIF(v.`TOW_VEH`, '') AS `TOW_VEH`,
  NULLIF(v.`VPICBODYCLASS`, '') AS `VPICBODYCLASS`,
  NULLIF(v.`VPICMAKE`, '') AS `VPICMAKE`,
  NULLIF(v.`VPICMODEL`, '') AS `VPICMODEL`
FROM `fars_stage`.`vehicle` AS v
UNION ALL
SELECT
  NULLIF(p.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(p.`VEH_NO`, '') AS `VEH_NO`,
  'P' AS `unit_type`,
  NULLIF(p.`PBODYTYP`, '') AS `BODY_TYP`,
  NULLIF(p.`PEM_USE`, '') AS `EMER_USE`,
  NULLIF(p.`PFIRE`, '') AS `FIRE_EXP`,
  NULLIF(p.`PGVWR_FROM`, '') AS `GVWR_FROM`,
  NULLIF(p.`PGVWR_TO`, '') AS `GVWR_TO`,
  NULLIF(p.`PICFINALBODY`, '') AS `ICFINALBODY`,
  NULLIF(p.`PIMPACT1`, '') AS `IMPACT1`,
  NULLIF(p.`PMAKE`, '') AS `MAKE`,
  NULLIF(p.`PMAK_MOD`, '') AS `MAK_MOD`,
  NULLIF(p.`PMODYEAR`, '') AS `MOD_YEAR`,
  (SELECT MIN(NULLIF(x.`ROLLOVER`, '')) FROM `fars_stage`.`person` AS x
     WHERE x.`ST_CASE` = p.`ST_CASE` AND x.`VEH_NO` = p.`VEH_NO`) AS `ROLLOVER`,
  NULLIF(p.`PSP_USE`, '') AS `SPEC_USE`,
  NULLIF(p.`PTRAILER`, '') AS `TOW_VEH`,
  NULLIF(p.`PVPICBODYCLASS`, '') AS `VPICBODYCLASS`,
  NULLIF(p.`PVPICMAKE`, '') AS `VPICMAKE`,
  NULLIF(p.`PVPICMODEL`, '') AS `VPICMODEL`
FROM `fars_stage`.`parkwork` AS p;

COMMIT;
