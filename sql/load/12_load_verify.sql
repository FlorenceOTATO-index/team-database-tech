-- 12_load_verify.sql
-- Checks that the load worked, in four parts:
--   1. Staging      all 39 CSVs were staged in full, with no LOAD DATA warnings
--   2. Tables       all 53 fars tables exist and hold their expected row counts
--   3. Transforms   the derived and multi-source tables came out as designed
--   4. Spot checks  blanks became NULL; FARS codes and text values were kept as written
-- Foreign keys are not re-checked row by row: all 44 FK constraints stayed
-- enabled during the load, so no row could be inserted without its parent.
--
-- Prints one results table (expected vs actual, PASS/FAIL) and the row count
-- of every fars table, then ends with an error if any check failed.
-- 13_load_drop_staging.sql only drops staging after this script has passed.
--
-- Run after 11, from the repository root:
--   mysql -u root -p -t < sql/load/12_load_verify.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- ------------------------------------------------------------------------
-- Current row count of every staging table and every fars table
-- (expected counts are in fars_stage.expected_rows, filled by 01).
-- ------------------------------------------------------------------------

DROP TABLE IF EXISTS fars_stage.actual_rows;
CREATE TABLE fars_stage.actual_rows (
  object_type VARCHAR(8)  NOT NULL,
  object_name VARCHAR(64) NOT NULL,
  actual_rows BIGINT      NOT NULL,
  PRIMARY KEY (object_type, object_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO fars_stage.actual_rows (object_type, object_name, actual_rows)
SELECT 'staging', 'acc_aux', COUNT(*) FROM fars_stage.`acc_aux`
UNION ALL SELECT 'staging', 'accident', COUNT(*) FROM fars_stage.`accident`
UNION ALL SELECT 'staging', 'cevent', COUNT(*) FROM fars_stage.`cevent`
UNION ALL SELECT 'staging', 'crashrf', COUNT(*) FROM fars_stage.`crashrf`
UNION ALL SELECT 'staging', 'damage', COUNT(*) FROM fars_stage.`damage`
UNION ALL SELECT 'staging', 'distract', COUNT(*) FROM fars_stage.`distract`
UNION ALL SELECT 'staging', 'drimpair', COUNT(*) FROM fars_stage.`drimpair`
UNION ALL SELECT 'staging', 'driverrf', COUNT(*) FROM fars_stage.`driverrf`
UNION ALL SELECT 'staging', 'drugs', COUNT(*) FROM fars_stage.`drugs`
UNION ALL SELECT 'staging', 'factor', COUNT(*) FROM fars_stage.`factor`
UNION ALL SELECT 'staging', 'maneuver', COUNT(*) FROM fars_stage.`maneuver`
UNION ALL SELECT 'staging', 'miacc', COUNT(*) FROM fars_stage.`miacc`
UNION ALL SELECT 'staging', 'midrvacc', COUNT(*) FROM fars_stage.`midrvacc`
UNION ALL SELECT 'staging', 'miper', COUNT(*) FROM fars_stage.`miper`
UNION ALL SELECT 'staging', 'nmcrash', COUNT(*) FROM fars_stage.`nmcrash`
UNION ALL SELECT 'staging', 'nmdistract', COUNT(*) FROM fars_stage.`nmdistract`
UNION ALL SELECT 'staging', 'nmimpair', COUNT(*) FROM fars_stage.`nmimpair`
UNION ALL SELECT 'staging', 'nmprior', COUNT(*) FROM fars_stage.`nmprior`
UNION ALL SELECT 'staging', 'parkwork', COUNT(*) FROM fars_stage.`parkwork`
UNION ALL SELECT 'staging', 'pbtype', COUNT(*) FROM fars_stage.`pbtype`
UNION ALL SELECT 'staging', 'per_aux', COUNT(*) FROM fars_stage.`per_aux`
UNION ALL SELECT 'staging', 'person', COUNT(*) FROM fars_stage.`person`
UNION ALL SELECT 'staging', 'personrf', COUNT(*) FROM fars_stage.`personrf`
UNION ALL SELECT 'staging', 'pvehiclesf', COUNT(*) FROM fars_stage.`pvehiclesf`
UNION ALL SELECT 'staging', 'race', COUNT(*) FROM fars_stage.`race`
UNION ALL SELECT 'staging', 'safetyeq', COUNT(*) FROM fars_stage.`safetyeq`
UNION ALL SELECT 'staging', 'veh_aux', COUNT(*) FROM fars_stage.`veh_aux`
UNION ALL SELECT 'staging', 'vehicle', COUNT(*) FROM fars_stage.`vehicle`
UNION ALL SELECT 'staging', 'vehiclesf', COUNT(*) FROM fars_stage.`vehiclesf`
UNION ALL SELECT 'staging', 'vevent', COUNT(*) FROM fars_stage.`vevent`
UNION ALL SELECT 'staging', 'violatn', COUNT(*) FROM fars_stage.`violatn`
UNION ALL SELECT 'staging', 'vision', COUNT(*) FROM fars_stage.`vision`
UNION ALL SELECT 'staging', 'vpicdecode', COUNT(*) FROM fars_stage.`vpicdecode`
UNION ALL SELECT 'staging', 'vpictrailerdecode', COUNT(*) FROM fars_stage.`vpictrailerdecode`
UNION ALL SELECT 'staging', 'vsoe', COUNT(*) FROM fars_stage.`vsoe`
UNION ALL SELECT 'staging', 'weather', COUNT(*) FROM fars_stage.`weather`
UNION ALL SELECT 'staging', 'code_labels', COUNT(*) FROM fars_stage.`code_labels`
UNION ALL SELECT 'staging', 'county', COUNT(*) FROM fars_stage.`county`
UNION ALL SELECT 'staging', 'city', COUNT(*) FROM fars_stage.`city`
UNION ALL SELECT 'target', 'calendar', COUNT(*) FROM `fars`.`calendar`
UNION ALL SELECT 'target', 'death_time', COUNT(*) FROM `fars`.`death_time`
UNION ALL SELECT 'target', 'vin_detail', COUNT(*) FROM `fars`.`vin_detail`
UNION ALL SELECT 'target', 'pvin_detail', COUNT(*) FROM `fars`.`pvin_detail`
UNION ALL SELECT 'target', 'vpic_labels', COUNT(*) FROM `fars`.`vpic_labels`
UNION ALL SELECT 'target', 'state_region', COUNT(*) FROM `fars`.`state_region`
UNION ALL SELECT 'target', 'roadfc_inter', COUNT(*) FROM `fars`.`roadfc_inter`
UNION ALL SELECT 'target', 'junc_intsec', COUNT(*) FROM `fars`.`junc_intsec`
UNION ALL SELECT 'target', 'age_band_map', COUNT(*) FROM `fars`.`age_band_map`
UNION ALL SELECT 'target', 'ped_crash_group', COUNT(*) FROM `fars`.`ped_crash_group`
UNION ALL SELECT 'target', 'bike_crash_group', COUNT(*) FROM `fars`.`bike_crash_group`
UNION ALL SELECT 'target', 'code_labels', COUNT(*) FROM `fars`.`code_labels`
UNION ALL SELECT 'target', 'county', COUNT(*) FROM `fars`.`county`
UNION ALL SELECT 'target', 'city', COUNT(*) FROM `fars`.`city`
UNION ALL SELECT 'target', 'accident', COUNT(*) FROM `fars`.`accident`
UNION ALL SELECT 'target', 'crash_unit', COUNT(*) FROM `fars`.`crash_unit`
UNION ALL SELECT 'target', 'vehicle', COUNT(*) FROM `fars`.`vehicle`
UNION ALL SELECT 'target', 'parkwork', COUNT(*) FROM `fars`.`parkwork`
UNION ALL SELECT 'target', 'person', COUNT(*) FROM `fars`.`person`
UNION ALL SELECT 'target', 'acc_aux', COUNT(*) FROM `fars`.`acc_aux`
UNION ALL SELECT 'target', 'cevent', COUNT(*) FROM `fars`.`cevent`
UNION ALL SELECT 'target', 'crashrf', COUNT(*) FROM `fars`.`crashrf`
UNION ALL SELECT 'target', 'weather', COUNT(*) FROM `fars`.`weather`
UNION ALL SELECT 'target', 'miacc', COUNT(*) FROM `fars`.`miacc`
UNION ALL SELECT 'target', 'midrvacc', COUNT(*) FROM `fars`.`midrvacc`
UNION ALL SELECT 'target', 'parkwork_hazmat', COUNT(*) FROM `fars`.`parkwork_hazmat`
UNION ALL SELECT 'target', 'crash_pbszone', COUNT(*) FROM `fars`.`crash_pbszone`
UNION ALL SELECT 'target', 'damage', COUNT(*) FROM `fars`.`damage`
UNION ALL SELECT 'target', 'distract', COUNT(*) FROM `fars`.`distract`
UNION ALL SELECT 'target', 'drimpair', COUNT(*) FROM `fars`.`drimpair`
UNION ALL SELECT 'target', 'driverrf', COUNT(*) FROM `fars`.`driverrf`
UNION ALL SELECT 'target', 'factor', COUNT(*) FROM `fars`.`factor`
UNION ALL SELECT 'target', 'maneuver', COUNT(*) FROM `fars`.`maneuver`
UNION ALL SELECT 'target', 'vehiclesf', COUNT(*) FROM `fars`.`vehiclesf`
UNION ALL SELECT 'target', 'violatn', COUNT(*) FROM `fars`.`violatn`
UNION ALL SELECT 'target', 'vision', COUNT(*) FROM `fars`.`vision`
UNION ALL SELECT 'target', 'veh_aux', COUNT(*) FROM `fars`.`veh_aux`
UNION ALL SELECT 'target', 'vevent', COUNT(*) FROM `fars`.`vevent`
UNION ALL SELECT 'target', 'vsoe', COUNT(*) FROM `fars`.`vsoe`
UNION ALL SELECT 'target', 'vpicdecode', COUNT(*) FROM `fars`.`vpicdecode`
UNION ALL SELECT 'target', 'vpictrailerdecode', COUNT(*) FROM `fars`.`vpictrailerdecode`
UNION ALL SELECT 'target', 'pvehiclesf', COUNT(*) FROM `fars`.`pvehiclesf`
UNION ALL SELECT 'target', 'drugs', COUNT(*) FROM `fars`.`drugs`
UNION ALL SELECT 'target', 'miper', COUNT(*) FROM `fars`.`miper`
UNION ALL SELECT 'target', 'nmcrash', COUNT(*) FROM `fars`.`nmcrash`
UNION ALL SELECT 'target', 'nmdistract', COUNT(*) FROM `fars`.`nmdistract`
UNION ALL SELECT 'target', 'nmimpair', COUNT(*) FROM `fars`.`nmimpair`
UNION ALL SELECT 'target', 'nmprior', COUNT(*) FROM `fars`.`nmprior`
UNION ALL SELECT 'target', 'pbtype', COUNT(*) FROM `fars`.`pbtype`
UNION ALL SELECT 'target', 'per_aux', COUNT(*) FROM `fars`.`per_aux`
UNION ALL SELECT 'target', 'personrf', COUNT(*) FROM `fars`.`personrf`
UNION ALL SELECT 'target', 'race', COUNT(*) FROM `fars`.`race`
UNION ALL SELECT 'target', 'safetyeq', COUNT(*) FROM `fars`.`safetyeq`;

-- ------------------------------------------------------------------------
-- Checks (expected vs actual; status is computed)
-- ------------------------------------------------------------------------

DROP TABLE IF EXISTS fars_stage.verify_results;
CREATE TABLE fars_stage.verify_results (
  check_id   INT UNSIGNED NOT NULL AUTO_INCREMENT,
  area       VARCHAR(16)  NOT NULL,
  check_name VARCHAR(100) NOT NULL,
  expected   BIGINT,
  actual     BIGINT,
  status     CHAR(4) AS (IF(expected <=> actual, 'PASS', 'FAIL')) STORED,
  PRIMARY KEY (check_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- 1. Staging: every CSV was staged in full, without LOAD DATA warnings.
INSERT INTO fars_stage.verify_results (area, check_name, expected, actual)
SELECT 'Staging', 'Staging tables present', 39,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'fars_stage' AND TABLE_NAME IN (
      'acc_aux', 'accident', 'cevent', 'crashrf', 'damage', 'distract',
      'drimpair', 'driverrf', 'drugs', 'factor', 'maneuver', 'miacc',
      'midrvacc', 'miper', 'nmcrash', 'nmdistract', 'nmimpair', 'nmprior',
      'parkwork', 'pbtype', 'per_aux', 'person', 'personrf', 'pvehiclesf',
      'race', 'safetyeq', 'veh_aux', 'vehicle', 'vehiclesf', 'vevent',
      'violatn', 'vision', 'vpicdecode', 'vpictrailerdecode', 'vsoe',
      'weather', 'code_labels', 'county', 'city'))
UNION ALL
SELECT 'Staging', 'Staging tables with the same row count as their CSV', 39,
  (SELECT COUNT(*) FROM fars_stage.expected_rows AS e
     JOIN fars_stage.actual_rows AS a
       ON a.object_type = e.object_type AND a.object_name = e.object_name
    WHERE e.object_type = 'staging' AND a.actual_rows = e.expected_rows)
UNION ALL
SELECT 'Staging', 'CSV data rows staged (all 39 files)',
  (SELECT SUM(expected_rows) FROM fars_stage.expected_rows WHERE object_type = 'staging'),
  (SELECT SUM(actual_rows) FROM fars_stage.actual_rows WHERE object_type = 'staging')
UNION ALL
SELECT 'Staging', 'CSV files loaded by LOAD DATA', 39,
  (SELECT COUNT(*) FROM fars_stage.load_log)
UNION ALL
SELECT 'Staging', 'LOAD DATA warnings (all files)', 0,
  (SELECT SUM(conditions) FROM fars_stage.load_log);

-- 2. Tables: all 53 tables exist with their expected row counts (per-table list printed below).
INSERT INTO fars_stage.verify_results (area, check_name, expected, actual)
SELECT 'Tables', 'fars tables present', 53,
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'fars' AND TABLE_TYPE = 'BASE TABLE')
UNION ALL
SELECT 'Tables', 'fars tables with their expected row count', 53,
  (SELECT COUNT(*) FROM fars_stage.expected_rows AS e
     JOIN fars_stage.actual_rows AS a
       ON a.object_type = e.object_type AND a.object_name = e.object_name
    WHERE e.object_type = 'target' AND a.actual_rows = e.expected_rows)
UNION ALL
SELECT 'Tables', 'Rows loaded into fars (all 53 tables)',
  (SELECT SUM(expected_rows) FROM fars_stage.expected_rows WHERE object_type = 'target'),
  (SELECT SUM(actual_rows) FROM fars_stage.actual_rows WHERE object_type = 'target')
UNION ALL
SELECT 'Tables', 'Foreign key constraints in place', 44,
  (SELECT COUNT(*) FROM information_schema.REFERENTIAL_CONSTRAINTS
    WHERE CONSTRAINT_SCHEMA = 'fars');

-- 3. Transforms: the derived and multi-source tables.
INSERT INTO fars_stage.verify_results (area, check_name, expected, actual)
SELECT 'Transforms', 'calendar: one row per date', 366,
  (SELECT COUNT(*) FROM `fars`.`calendar`)
UNION ALL
SELECT 'Transforms', 'accident', 36297,
  (SELECT COUNT(*) FROM `fars`.`accident`)
UNION ALL
SELECT 'Transforms', 'crash_unit: all units', 57537,
  (SELECT COUNT(*) FROM `fars`.`crash_unit`)
UNION ALL
SELECT 'Transforms', 'crash_unit: in-transport units (V)', 56011,
  (SELECT COUNT(*) FROM `fars`.`crash_unit` WHERE `unit_type` = 'V')
UNION ALL
SELECT 'Transforms', 'crash_unit: parked/working units (P)', 1526,
  (SELECT COUNT(*) FROM `fars`.`crash_unit` WHERE `unit_type` = 'P')
UNION ALL
SELECT 'Transforms', 'crash_unit: P units with no ROLLOVER (no occupants)', 1206,
  (SELECT COUNT(*) FROM `fars`.`crash_unit` WHERE `unit_type` = 'P' AND `ROLLOVER` IS NULL)
UNION ALL
SELECT 'Transforms', 'vehicle', 56011,
  (SELECT COUNT(*) FROM `fars`.`vehicle`)
UNION ALL
SELECT 'Transforms', 'parkwork', 1526,
  (SELECT COUNT(*) FROM `fars`.`parkwork`)
UNION ALL
SELECT 'Transforms', 'vin_detail: one row per VIN', 49396,
  (SELECT COUNT(*) FROM `fars`.`vin_detail`)
UNION ALL
SELECT 'Transforms', 'pvin_detail: one row per PVIN', 1465,
  (SELECT COUNT(*) FROM `fars`.`pvin_detail`)
UNION ALL
SELECT 'Transforms', 'person', 88326,
  (SELECT COUNT(*) FROM `fars`.`person`)
UNION ALL
SELECT 'Transforms', 'person: MULTRACE filled from race.csv', 88326,
  (SELECT COUNT(*) FROM `fars`.`person` WHERE `MULTRACE` IS NOT NULL)
UNION ALL
SELECT 'Transforms', 'drugs: every test result', 128399,
  (SELECT COUNT(*) FROM `fars`.`drugs`)
UNION ALL
SELECT 'Transforms', 'drugs: repeated test results kept', 748,
  (SELECT SUM(n - 1) FROM (
     SELECT COUNT(*) AS n FROM `fars`.`drugs`
     GROUP BY `ST_CASE`, `VEH_NO`, `PER_NO`, `DRUGSPEC`, `DRUGMETHOD`, `DRUGRES`,
              `DRUGQTY`, `DRUGACTQTY`, `DRUGUOM`) AS g)
UNION ALL
SELECT 'Transforms', 'vevent: (unit, event) links', 120270,
  (SELECT COUNT(*) FROM `fars`.`vevent`)
UNION ALL
SELECT 'Transforms', 'vsoe', 120270,
  (SELECT COUNT(*) FROM `fars`.`vsoe`);

-- 4. Spot checks: blanks became NULL, codes and text kept as written.
INSERT INTO fars_stage.verify_results (area, check_name, expected, actual)
SELECT 'Spot checks', 'accident.TWAY_ID2 blanks stored as NULL', 26567,
  (SELECT COUNT(*) FROM `fars`.`accident` WHERE `TWAY_ID2` IS NULL)
UNION ALL
SELECT 'Spot checks', 'acc_aux.CENSUS_2020_TRACT_FIPS leading zeros kept', 7075,
  (SELECT COUNT(*) FROM `fars`.`acc_aux`
    WHERE `CENSUS_2020_TRACT_FIPS` LIKE '0%' AND CHAR_LENGTH(`CENSUS_2020_TRACT_FIPS`) = 11)
UNION ALL
SELECT 'Spot checks', 'code_labels text codes 10a and -99.000 kept', 2,
  (SELECT COUNT(*) FROM `fars`.`code_labels`
    WHERE (`column` = 'PEDSNR' AND `code` = '10a')
       OR (`column` = 'DRUGACTQTY' AND `code` = '-99.000'))
UNION ALL
SELECT 'Spot checks', 'vehicle.VIN code 999999999999 kept (not NULL)', 1322,
  (SELECT COUNT(*) FROM `fars`.`vehicle` WHERE `VIN` = '999999999999');

-- ------------------------------------------------------------------------
-- Results
-- ------------------------------------------------------------------------

SELECT area, check_name, expected, actual, status
FROM fars_stage.verify_results
ORDER BY check_id;

-- Row count of every fars table (the per-table detail behind check 2).
SELECT e.object_name AS fars_table, e.expected_rows AS expected, a.actual_rows AS actual,
       IF(e.expected_rows <=> a.actual_rows, 'PASS', 'FAIL') AS status
FROM fars_stage.expected_rows AS e
LEFT JOIN fars_stage.actual_rows AS a
  ON a.object_type = e.object_type AND a.object_name = e.object_name
WHERE e.object_type = 'target'
ORDER BY e.object_name;

-- Staging tables that did not load cleanly (no rows when every CSV loaded in full).
SELECT e.object_name AS staging_table, e.expected_rows AS expected, a.actual_rows AS actual,
       l.conditions AS load_warnings
FROM fars_stage.expected_rows AS e
LEFT JOIN fars_stage.actual_rows AS a
  ON a.object_type = e.object_type AND a.object_name = e.object_name
LEFT JOIN fars_stage.load_log AS l ON l.staging_table = e.object_name
WHERE e.object_type = 'staging'
  AND NOT (e.expected_rows <=> a.actual_rows AND l.conditions <=> 0)
ORDER BY e.object_name;

SELECT COUNT(*) AS checks, SUM(status = 'PASS') AS passed, SUM(status = 'FAIL') AS failed
FROM fars_stage.verify_results;

CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM fars_stage.verify_results WHERE status = 'FAIL') = 0,
  'Load verification failed: see the FAIL rows above');
