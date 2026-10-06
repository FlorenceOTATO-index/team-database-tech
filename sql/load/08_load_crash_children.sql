-- 08_load_crash_children.sql
-- Phase 2: crash-level child tables.
-- Parent: accident (04). cevent is loaded here because vevent (10) references
-- it.
-- acc_aux.CENSUS_2020_TRACT_FIPS goes into CHAR(11) as text, keeping its
-- leading zeros.
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/08_load_crash_children.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`acc_aux`) = 0, 'fars.acc_aux must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`cevent`) = 0, 'fars.cevent must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`crashrf`) = 0, 'fars.crashrf must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`weather`) = 0, 'fars.weather must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`miacc`) = 0, 'fars.miacc must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`midrvacc`) = 0, 'fars.midrvacc must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`parkwork_hazmat`) = 0, 'fars.parkwork_hazmat must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`crash_pbszone`) = 0, 'fars.crash_pbszone must be empty before loading');

-- acc_aux: 36,297 rows expected.
-- Not loaded from data/processed/acc_aux.csv: YEAR, STATE, FATALS, A_REGION,
-- A_INTER, A_INTSEC.
-- Reason: YEAR, STATE and FATALS are copies of accident; A_REGION, A_INTER
-- and A_INTSEC live in state_region, roadfc_inter and junc_intsec.
INSERT INTO `fars`.`acc_aux` (
  `ST_CASE`, `A_CRAINJ`, `A_RU`, `A_RELRD`, `A_ROADFC`, `A_JUNC`, `A_MANCOL`,
  `A_TOD`, `A_DOW`, `A_CT`, `A_WEATHER`, `A_LT`, `A_MC`, `A_SBUSCR`,
  `A_SPCRA`, `A_PED`, `A_PED_F`, `A_PEDAL`, `A_PEDAL_F`, `A_ROLL`,
  `A_POLPUR`, `A_POSBAC`, `A_D15_19`, `A_D16_19`, `A_D15_20`, `A_D16_20`,
  `A_D65PLS`, `A_D21_24`, `A_D16_24`, `A_RD`, `A_HR`, `A_DIST`, `A_DROWSY`,
  `A_WRONGWAY`, `BIA`, `SPJ_INDIAN`, `INDIAN_RES`, `CENSUS_2020_TRACT_FIPS`,
  `TRACT`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`A_CRAINJ`, '') AS `A_CRAINJ`,
  NULLIF(s.`A_RU`, '') AS `A_RU`,
  NULLIF(s.`A_RELRD`, '') AS `A_RELRD`,
  NULLIF(s.`A_ROADFC`, '') AS `A_ROADFC`,
  NULLIF(s.`A_JUNC`, '') AS `A_JUNC`,
  NULLIF(s.`A_MANCOL`, '') AS `A_MANCOL`,
  NULLIF(s.`A_TOD`, '') AS `A_TOD`,
  NULLIF(s.`A_DOW`, '') AS `A_DOW`,
  NULLIF(s.`A_CT`, '') AS `A_CT`,
  NULLIF(s.`A_WEATHER`, '') AS `A_WEATHER`,
  NULLIF(s.`A_LT`, '') AS `A_LT`,
  NULLIF(s.`A_MC`, '') AS `A_MC`,
  NULLIF(s.`A_SBUSCR`, '') AS `A_SBUSCR`,
  NULLIF(s.`A_SPCRA`, '') AS `A_SPCRA`,
  NULLIF(s.`A_PED`, '') AS `A_PED`,
  NULLIF(s.`A_PED_F`, '') AS `A_PED_F`,
  NULLIF(s.`A_PEDAL`, '') AS `A_PEDAL`,
  NULLIF(s.`A_PEDAL_F`, '') AS `A_PEDAL_F`,
  NULLIF(s.`A_ROLL`, '') AS `A_ROLL`,
  NULLIF(s.`A_POLPUR`, '') AS `A_POLPUR`,
  NULLIF(s.`A_POSBAC`, '') AS `A_POSBAC`,
  NULLIF(s.`A_D15_19`, '') AS `A_D15_19`,
  NULLIF(s.`A_D16_19`, '') AS `A_D16_19`,
  NULLIF(s.`A_D15_20`, '') AS `A_D15_20`,
  NULLIF(s.`A_D16_20`, '') AS `A_D16_20`,
  NULLIF(s.`A_D65PLS`, '') AS `A_D65PLS`,
  NULLIF(s.`A_D21_24`, '') AS `A_D21_24`,
  NULLIF(s.`A_D16_24`, '') AS `A_D16_24`,
  NULLIF(s.`A_RD`, '') AS `A_RD`,
  NULLIF(s.`A_HR`, '') AS `A_HR`,
  NULLIF(s.`A_DIST`, '') AS `A_DIST`,
  NULLIF(s.`A_DROWSY`, '') AS `A_DROWSY`,
  NULLIF(s.`A_WRONGWAY`, '') AS `A_WRONGWAY`,
  NULLIF(s.`BIA`, '') AS `BIA`,
  NULLIF(s.`SPJ_INDIAN`, '') AS `SPJ_INDIAN`,
  NULLIF(s.`INDIAN_RES`, '') AS `INDIAN_RES`,
  NULLIF(s.`CENSUS_2020_TRACT_FIPS`, '') AS `CENSUS_2020_TRACT_FIPS`,
  NULLIF(s.`TRACT`, '') AS `TRACT`
FROM `fars_stage`.`acc_aux` AS s;

-- cevent: 99,225 rows expected.
-- Not loaded from data/processed/cevent.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`cevent` (
  `ST_CASE`, `EVENTNUM`, `VNUMBER1`, `AOI1`, `SOE`, `VNUMBER2`, `AOI2`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`EVENTNUM`, '') AS `EVENTNUM`,
  NULLIF(s.`VNUMBER1`, '') AS `VNUMBER1`,
  NULLIF(s.`AOI1`, '') AS `AOI1`,
  NULLIF(s.`SOE`, '') AS `SOE`,
  NULLIF(s.`VNUMBER2`, '') AS `VNUMBER2`,
  NULLIF(s.`AOI2`, '') AS `AOI2`
FROM `fars_stage`.`cevent` AS s;

-- crashrf: 36,587 rows expected.
-- Not loaded from data/processed/crashrf.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`crashrf` (
  `ST_CASE`, `CRASHRF`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`CRASHRF`, '') AS `CRASHRF`
FROM `fars_stage`.`crashrf` AS s;

-- weather: 36,692 rows expected.
-- Not loaded from data/processed/weather.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`weather` (
  `ST_CASE`, `WEATHER`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`WEATHER`, '') AS `WEATHER`
FROM `fars_stage`.`weather` AS s;

-- miacc: 36,297 rows expected.
INSERT INTO `fars`.`miacc` (
  `ST_CASE`, `A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, `A8`, `A9`, `A10`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`A1`, '') AS `A1`,
  NULLIF(s.`A2`, '') AS `A2`,
  NULLIF(s.`A3`, '') AS `A3`,
  NULLIF(s.`A4`, '') AS `A4`,
  NULLIF(s.`A5`, '') AS `A5`,
  NULLIF(s.`A6`, '') AS `A6`,
  NULLIF(s.`A7`, '') AS `A7`,
  NULLIF(s.`A8`, '') AS `A8`,
  NULLIF(s.`A9`, '') AS `A9`,
  NULLIF(s.`A10`, '') AS `A10`
FROM `fars_stage`.`miacc` AS s;

-- midrvacc: 36,229 rows expected.
INSERT INTO `fars`.`midrvacc` (
  `ST_CASE`, `A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, `A8`, `A9`, `A10`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`A1`, '') AS `A1`,
  NULLIF(s.`A2`, '') AS `A2`,
  NULLIF(s.`A3`, '') AS `A3`,
  NULLIF(s.`A4`, '') AS `A4`,
  NULLIF(s.`A5`, '') AS `A5`,
  NULLIF(s.`A6`, '') AS `A6`,
  NULLIF(s.`A7`, '') AS `A7`,
  NULLIF(s.`A8`, '') AS `A8`,
  NULLIF(s.`A9`, '') AS `A9`,
  NULLIF(s.`A10`, '') AS `A10`
FROM `fars_stage`.`midrvacc` AS s;

-- parkwork_hazmat: 1,070 rows expected.
-- Derived: distinct (ST_CASE, PHAZ_INV, PHAZPLAC, PHAZ_ID, PHAZ_CNO,
-- PHAZ_REL) from data/processed/parkwork.csv; ST_CASE -> PHAZ_* (one row per
-- crash with parked/working units). The primary key rejects any key that maps
-- to two different values.
INSERT INTO `fars`.`parkwork_hazmat` (
  `ST_CASE`, `PHAZ_INV`, `PHAZPLAC`, `PHAZ_ID`, `PHAZ_CNO`, `PHAZ_REL`
)
SELECT DISTINCT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`PHAZ_INV`, '') AS `PHAZ_INV`,
  NULLIF(s.`PHAZPLAC`, '') AS `PHAZPLAC`,
  NULLIF(s.`PHAZ_ID`, '') AS `PHAZ_ID`,
  NULLIF(s.`PHAZ_CNO`, '') AS `PHAZ_CNO`,
  NULLIF(s.`PHAZ_REL`, '') AS `PHAZ_REL`
FROM `fars_stage`.`parkwork` AS s;

-- crash_pbszone: 8,419 rows expected.
-- Derived: distinct (ST_CASE, PBSZONE) from data/processed/pbtype.csv;
-- ST_CASE -> PBSZONE. The primary key rejects any key that maps to two
-- different values.
INSERT INTO `fars`.`crash_pbszone` (
  `ST_CASE`, `PBSZONE`
)
SELECT DISTINCT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`PBSZONE`, '') AS `PBSZONE`
FROM `fars_stage`.`pbtype` AS s;

COMMIT;
