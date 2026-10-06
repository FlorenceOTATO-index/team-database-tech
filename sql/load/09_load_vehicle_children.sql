-- 09_load_vehicle_children.sql
-- Phase 2: vehicle-level child tables.
-- Parent: vehicle (06) for the first ten tables; pvehiclesf references
-- accident only, as the approved schema defines.
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/09_load_vehicle_children.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`damage`) = 0, 'fars.damage must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`distract`) = 0, 'fars.distract must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`drimpair`) = 0, 'fars.drimpair must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`driverrf`) = 0, 'fars.driverrf must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`factor`) = 0, 'fars.factor must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`maneuver`) = 0, 'fars.maneuver must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`vehiclesf`) = 0, 'fars.vehiclesf must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`violatn`) = 0, 'fars.violatn must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`vision`) = 0, 'fars.vision must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`veh_aux`) = 0, 'fars.veh_aux must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`pvehiclesf`) = 0, 'fars.pvehiclesf must be empty before loading');

-- damage: 240,091 rows expected.
-- Not loaded from data/processed/damage.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`damage` (
  `ST_CASE`, `VEH_NO`, `DAMAGE`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`DAMAGE`, '') AS `DAMAGE`
FROM `fars_stage`.`damage` AS s;

-- distract: 56,026 rows expected.
-- Not loaded from data/processed/distract.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`distract` (
  `ST_CASE`, `VEH_NO`, `DRDISTRACT`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`DRDISTRACT`, '') AS `DRDISTRACT`
FROM `fars_stage`.`distract` AS s;

-- drimpair: 56,181 rows expected.
-- Not loaded from data/processed/drimpair.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`drimpair` (
  `ST_CASE`, `VEH_NO`, `DRIMPAIR`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`DRIMPAIR`, '') AS `DRIMPAIR`
FROM `fars_stage`.`drimpair` AS s;

-- driverrf: 62,603 rows expected.
-- Not loaded from data/processed/driverrf.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`driverrf` (
  `ST_CASE`, `VEH_NO`, `DRIVERRF`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`DRIVERRF`, '') AS `DRIVERRF`
FROM `fars_stage`.`driverrf` AS s;

-- factor: 56,076 rows expected.
-- Not loaded from data/processed/factor.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`factor` (
  `ST_CASE`, `VEH_NO`, `VEHICLECC`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`VEHICLECC`, '') AS `VEHICLECC`
FROM `fars_stage`.`factor` AS s;

-- maneuver: 56,018 rows expected.
-- Not loaded from data/processed/maneuver.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`maneuver` (
  `ST_CASE`, `VEH_NO`, `MANEUVER`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`MANEUVER`, '') AS `MANEUVER`
FROM `fars_stage`.`maneuver` AS s;

-- vehiclesf: 56,013 rows expected.
-- Not loaded from data/processed/vehiclesf.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`vehiclesf` (
  `ST_CASE`, `VEH_NO`, `VEHICLESF`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`VEHICLESF`, '') AS `VEHICLESF`
FROM `fars_stage`.`vehiclesf` AS s;

-- violatn: 59,670 rows expected.
-- Not loaded from data/processed/violatn.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`violatn` (
  `ST_CASE`, `VEH_NO`, `VIOLATION`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`VIOLATION`, '') AS `VIOLATION`
FROM `fars_stage`.`violatn` AS s;

-- vision: 56,049 rows expected.
-- Not loaded from data/processed/vision.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`vision` (
  `ST_CASE`, `VEH_NO`, `VISION`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`VISION`, '') AS `VISION`
FROM `fars_stage`.`vision` AS s;

-- veh_aux: 56,011 rows expected.
-- Not loaded from data/processed/veh_aux.csv: YEAR, STATE.
-- Reason: YEAR is the constant 2024; STATE is a copy of accident.
INSERT INTO `fars`.`veh_aux` (
  `ST_CASE`, `VEH_NO`, `A_WRONGWAYDRV`, `A_DRDIS`, `A_DRDRO`, `A_VRD`,
  `A_BODY`, `A_IMP1`, `A_VROLL`, `A_LIC_S`, `A_LIC_C`, `A_CDL_S`, `A_MC_L_S`,
  `A_SPVEH`, `A_SBUS`, `A_MOD_YR`, `A_FIRE_EXP`, `A_TOWED`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`A_WRONGWAYDRV`, '') AS `A_WRONGWAYDRV`,
  NULLIF(s.`A_DRDIS`, '') AS `A_DRDIS`,
  NULLIF(s.`A_DRDRO`, '') AS `A_DRDRO`,
  NULLIF(s.`A_VRD`, '') AS `A_VRD`,
  NULLIF(s.`A_BODY`, '') AS `A_BODY`,
  NULLIF(s.`A_IMP1`, '') AS `A_IMP1`,
  NULLIF(s.`A_VROLL`, '') AS `A_VROLL`,
  NULLIF(s.`A_LIC_S`, '') AS `A_LIC_S`,
  NULLIF(s.`A_LIC_C`, '') AS `A_LIC_C`,
  NULLIF(s.`A_CDL_S`, '') AS `A_CDL_S`,
  NULLIF(s.`A_MC_L_S`, '') AS `A_MC_L_S`,
  NULLIF(s.`A_SPVEH`, '') AS `A_SPVEH`,
  NULLIF(s.`A_SBUS`, '') AS `A_SBUS`,
  NULLIF(s.`A_MOD_YR`, '') AS `A_MOD_YR`,
  NULLIF(s.`A_FIRE_EXP`, '') AS `A_FIRE_EXP`,
  NULLIF(s.`A_TOWED`, '') AS `A_TOWED`
FROM `fars_stage`.`veh_aux` AS s;

-- pvehiclesf: 1,526 rows expected.
-- Not loaded from data/processed/pvehiclesf.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`pvehiclesf` (
  `ST_CASE`, `VEH_NO`, `PVEHICLESF`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PVEHICLESF`, '') AS `PVEHICLESF`
FROM `fars_stage`.`pvehiclesf` AS s;

COMMIT;
