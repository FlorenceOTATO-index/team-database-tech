-- 04_load_accident.sql
-- Phase 2: accident.
-- One row per crash. Parent: calendar (03).
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/04_load_accident.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`accident`) = 0, 'fars.accident must be empty before loading');

-- accident: 36,297 rows expected.
-- Not loaded from data/processed/accident.csv: DAY_WEEK.
-- Reason: DAY_WEEK lives in calendar.
INSERT INTO `fars`.`accident` (
  `ST_CASE`, `ARR_HOUR`, `ARR_MIN`, `CITY`, `COUNTY`, `DAY`, `FATALS`,
  `FUNC_SYS`, `HARM_EV`, `HOSP_HR`, `HOSP_MN`, `HOUR`, `LATITUDE`,
  `LGT_COND`, `LONGITUD`, `MAN_COLL`, `MILEPT`, `MINUTE`, `MONTH`, `NHS`,
  `NOT_HOUR`, `NOT_MIN`, `PEDS`, `PERMVIT`, `PERNOTMVIT`, `PERSONS`,
  `PVH_INVL`, `RAIL`, `RD_OWNER`, `RELJCT1`, `RELJCT2`, `REL_ROAD`, `ROUTE`,
  `RUR_URB`, `SCH_BUS`, `SP_JUR`, `STATE`, `TWAY_ID`, `TWAY_ID2`, `TYP_INT`,
  `VE_FORMS`, `VE_TOTAL`, `WEATHER`, `WRK_ZONE`, `YEAR`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`ARR_HOUR`, '') AS `ARR_HOUR`,
  NULLIF(s.`ARR_MIN`, '') AS `ARR_MIN`,
  NULLIF(s.`CITY`, '') AS `CITY`,
  NULLIF(s.`COUNTY`, '') AS `COUNTY`,
  NULLIF(s.`DAY`, '') AS `DAY`,
  NULLIF(s.`FATALS`, '') AS `FATALS`,
  NULLIF(s.`FUNC_SYS`, '') AS `FUNC_SYS`,
  NULLIF(s.`HARM_EV`, '') AS `HARM_EV`,
  NULLIF(s.`HOSP_HR`, '') AS `HOSP_HR`,
  NULLIF(s.`HOSP_MN`, '') AS `HOSP_MN`,
  NULLIF(s.`HOUR`, '') AS `HOUR`,
  NULLIF(s.`LATITUDE`, '') AS `LATITUDE`,
  NULLIF(s.`LGT_COND`, '') AS `LGT_COND`,
  NULLIF(s.`LONGITUD`, '') AS `LONGITUD`,
  NULLIF(s.`MAN_COLL`, '') AS `MAN_COLL`,
  NULLIF(s.`MILEPT`, '') AS `MILEPT`,
  NULLIF(s.`MINUTE`, '') AS `MINUTE`,
  NULLIF(s.`MONTH`, '') AS `MONTH`,
  NULLIF(s.`NHS`, '') AS `NHS`,
  NULLIF(s.`NOT_HOUR`, '') AS `NOT_HOUR`,
  NULLIF(s.`NOT_MIN`, '') AS `NOT_MIN`,
  NULLIF(s.`PEDS`, '') AS `PEDS`,
  NULLIF(s.`PERMVIT`, '') AS `PERMVIT`,
  NULLIF(s.`PERNOTMVIT`, '') AS `PERNOTMVIT`,
  NULLIF(s.`PERSONS`, '') AS `PERSONS`,
  NULLIF(s.`PVH_INVL`, '') AS `PVH_INVL`,
  NULLIF(s.`RAIL`, '') AS `RAIL`,
  NULLIF(s.`RD_OWNER`, '') AS `RD_OWNER`,
  NULLIF(s.`RELJCT1`, '') AS `RELJCT1`,
  NULLIF(s.`RELJCT2`, '') AS `RELJCT2`,
  NULLIF(s.`REL_ROAD`, '') AS `REL_ROAD`,
  NULLIF(s.`ROUTE`, '') AS `ROUTE`,
  NULLIF(s.`RUR_URB`, '') AS `RUR_URB`,
  NULLIF(s.`SCH_BUS`, '') AS `SCH_BUS`,
  NULLIF(s.`SP_JUR`, '') AS `SP_JUR`,
  NULLIF(s.`STATE`, '') AS `STATE`,
  NULLIF(s.`TWAY_ID`, '') AS `TWAY_ID`,
  NULLIF(s.`TWAY_ID2`, '') AS `TWAY_ID2`,
  NULLIF(s.`TYP_INT`, '') AS `TYP_INT`,
  NULLIF(s.`VE_FORMS`, '') AS `VE_FORMS`,
  NULLIF(s.`VE_TOTAL`, '') AS `VE_TOTAL`,
  NULLIF(s.`WEATHER`, '') AS `WEATHER`,
  NULLIF(s.`WRK_ZONE`, '') AS `WRK_ZONE`,
  NULLIF(s.`YEAR`, '') AS `YEAR`
FROM `fars_stage`.`accident` AS s;

COMMIT;
