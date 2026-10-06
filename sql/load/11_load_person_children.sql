-- 11_load_person_children.sql
-- Phase 2: person-level child tables.
-- Parent: person (07). Non-motorist rows (VEH_NO = 0) load like any other
-- person.
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/11_load_person_children.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`drugs`) = 0, 'fars.drugs must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`miper`) = 0, 'fars.miper must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`nmcrash`) = 0, 'fars.nmcrash must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`nmdistract`) = 0, 'fars.nmdistract must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`nmimpair`) = 0, 'fars.nmimpair must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`nmprior`) = 0, 'fars.nmprior must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`pbtype`) = 0, 'fars.pbtype must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`per_aux`) = 0, 'fars.per_aux must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`personrf`) = 0, 'fars.personrf must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`race`) = 0, 'fars.race must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`safetyeq`) = 0, 'fars.safetyeq must be empty before loading');

-- drugs: 128,399 rows expected.
-- Not loaded from data/processed/drugs.csv: STATE.
-- Reason: STATE is a copy of accident.STATE. drug_id comes from
-- AUTO_INCREMENT. No DISTINCT: the 748 repeated test results are real and all
-- load (D2).
INSERT INTO `fars`.`drugs` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `DRUGSPEC`, `DRUGMETHOD`, `DRUGRES`,
  `DRUGQTY`, `DRUGACTQTY`, `DRUGUOM`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`DRUGSPEC`, '') AS `DRUGSPEC`,
  NULLIF(s.`DRUGMETHOD`, '') AS `DRUGMETHOD`,
  NULLIF(s.`DRUGRES`, '') AS `DRUGRES`,
  NULLIF(s.`DRUGQTY`, '') AS `DRUGQTY`,
  NULLIF(s.`DRUGACTQTY`, '') AS `DRUGACTQTY`,
  NULLIF(s.`DRUGUOM`, '') AS `DRUGUOM`
FROM `fars_stage`.`drugs` AS s;

-- miper: 64,616 rows expected.
INSERT INTO `fars`.`miper` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `P1`, `P2`, `P3`, `P4`, `P5`, `P6`, `P7`,
  `P8`, `P9`, `P10`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`P1`, '') AS `P1`,
  NULLIF(s.`P2`, '') AS `P2`,
  NULLIF(s.`P3`, '') AS `P3`,
  NULLIF(s.`P4`, '') AS `P4`,
  NULLIF(s.`P5`, '') AS `P5`,
  NULLIF(s.`P6`, '') AS `P6`,
  NULLIF(s.`P7`, '') AS `P7`,
  NULLIF(s.`P8`, '') AS `P8`,
  NULLIF(s.`P9`, '') AS `P9`,
  NULLIF(s.`P10`, '') AS `P10`
FROM `fars_stage`.`miper` AS s;

-- nmcrash: 13,054 rows expected.
-- Not loaded from data/processed/nmcrash.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`nmcrash` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `NMCC`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`NMCC`, '') AS `NMCC`
FROM `fars_stage`.`nmcrash` AS s;

-- nmdistract: 9,020 rows expected.
-- Not loaded from data/processed/nmdistract.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`nmdistract` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `NMDISTRACT`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`NMDISTRACT`, '') AS `NMDISTRACT`
FROM `fars_stage`.`nmdistract` AS s;

-- nmimpair: 9,037 rows expected.
-- Not loaded from data/processed/nmimpair.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`nmimpair` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `NMIMPAIR`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`NMIMPAIR`, '') AS `NMIMPAIR`
FROM `fars_stage`.`nmimpair` AS s;

-- nmprior: 9,344 rows expected.
-- Not loaded from data/processed/nmprior.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`nmprior` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `NMACTION`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`NMACTION`, '') AS `NMACTION`
FROM `fars_stage`.`nmprior` AS s;

-- pbtype: 8,940 rows expected.
-- Not loaded from data/processed/pbtype.csv: STATE, PBSZONE, PEDCGP, BIKECGP.
-- Reason: STATE is a copy of accident.STATE. PBSZONE lives in crash_pbszone,
-- PEDCGP in ped_crash_group, BIKECGP in bike_crash_group.
INSERT INTO `fars`.`pbtype` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `PBAGE`, `PBSEX`, `PBPTYPE`, `PBCWALK`,
  `PBSWALK`, `PEDCTYPE`, `BIKECTYPE`, `PEDLOC`, `BIKELOC`, `PEDPOS`,
  `BIKEPOS`, `PEDDIR`, `BIKEDIR`, `MOTDIR`, `MOTMAN`, `PEDLEG`, `PEDSNR`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`PBAGE`, '') AS `PBAGE`,
  NULLIF(s.`PBSEX`, '') AS `PBSEX`,
  NULLIF(s.`PBPTYPE`, '') AS `PBPTYPE`,
  NULLIF(s.`PBCWALK`, '') AS `PBCWALK`,
  NULLIF(s.`PBSWALK`, '') AS `PBSWALK`,
  NULLIF(s.`PEDCTYPE`, '') AS `PEDCTYPE`,
  NULLIF(s.`BIKECTYPE`, '') AS `BIKECTYPE`,
  NULLIF(s.`PEDLOC`, '') AS `PEDLOC`,
  NULLIF(s.`BIKELOC`, '') AS `BIKELOC`,
  NULLIF(s.`PEDPOS`, '') AS `PEDPOS`,
  NULLIF(s.`BIKEPOS`, '') AS `BIKEPOS`,
  NULLIF(s.`PEDDIR`, '') AS `PEDDIR`,
  NULLIF(s.`BIKEDIR`, '') AS `BIKEDIR`,
  NULLIF(s.`MOTDIR`, '') AS `MOTDIR`,
  NULLIF(s.`MOTMAN`, '') AS `MOTMAN`,
  NULLIF(s.`PEDLEG`, '') AS `PEDLEG`,
  NULLIF(s.`PEDSNR`, '') AS `PEDSNR`
FROM `fars_stage`.`pbtype` AS s;

-- per_aux: 88,326 rows expected.
-- Not loaded from data/processed/per_aux.csv: A_AGE1, A_AGE2, A_AGE4, A_AGE5,
-- A_AGE9, STATE, YEAR.
-- Reason: STATE is a copy of accident.STATE. YEAR is the constant 2024;
-- A_AGE1, A_AGE2, A_AGE4, A_AGE5 and A_AGE9 live in age_band_map. Columns are
-- mapped by name: the CSV order differs from the table.
INSERT INTO `fars`.`per_aux` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `A_AGE3`, `A_AGE6`, `A_AGE7`, `A_AGE8`,
  `A_PTYPE`, `A_RESTUSE`, `A_HELMUSE`, `A_ALCTES`, `A_HISP`, `A_RCAT`,
  `A_HRACE`, `A_EJECT`, `A_PERINJ`, `A_LOC`, `A_DOA`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`A_AGE3`, '') AS `A_AGE3`,
  NULLIF(s.`A_AGE6`, '') AS `A_AGE6`,
  NULLIF(s.`A_AGE7`, '') AS `A_AGE7`,
  NULLIF(s.`A_AGE8`, '') AS `A_AGE8`,
  NULLIF(s.`A_PTYPE`, '') AS `A_PTYPE`,
  NULLIF(s.`A_RESTUSE`, '') AS `A_RESTUSE`,
  NULLIF(s.`A_HELMUSE`, '') AS `A_HELMUSE`,
  NULLIF(s.`A_ALCTES`, '') AS `A_ALCTES`,
  NULLIF(s.`A_HISP`, '') AS `A_HISP`,
  NULLIF(s.`A_RCAT`, '') AS `A_RCAT`,
  NULLIF(s.`A_HRACE`, '') AS `A_HRACE`,
  NULLIF(s.`A_EJECT`, '') AS `A_EJECT`,
  NULLIF(s.`A_PERINJ`, '') AS `A_PERINJ`,
  NULLIF(s.`A_LOC`, '') AS `A_LOC`,
  NULLIF(s.`A_DOA`, '') AS `A_DOA`
FROM `fars_stage`.`per_aux` AS s;

-- personrf: 88,343 rows expected.
-- Not loaded from data/processed/personrf.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`personrf` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `PERSONRF`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`PERSONRF`, '') AS `PERSONRF`
FROM `fars_stage`.`personrf` AS s;

-- race: 88,517 rows expected.
-- Not loaded from data/processed/race.csv: STATE, MULTRACE.
-- Reason: STATE is a copy of accident.STATE. MULTRACE is loaded into person
-- (D8).
INSERT INTO `fars`.`race` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `RACE`, `RACE_ORDER`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`RACE`, '') AS `RACE`,
  NULLIF(s.`RACE_ORDER`, '') AS `RACE_ORDER`
FROM `fars_stage`.`race` AS s;

-- safetyeq: 9,020 rows expected.
-- Not loaded from data/processed/safetyeq.csv: STATE.
-- Reason: STATE is a copy of accident.STATE.
INSERT INTO `fars`.`safetyeq` (
  `ST_CASE`, `VEH_NO`, `PER_NO`, `NMHELMET`, `NMPROPAD`, `NMOTHPRO`,
  `NMREFCLO`, `NMLIGHT`, `NMOTHPRE`
)
SELECT
  NULLIF(s.`ST_CASE`, '') AS `ST_CASE`,
  NULLIF(s.`VEH_NO`, '') AS `VEH_NO`,
  NULLIF(s.`PER_NO`, '') AS `PER_NO`,
  NULLIF(s.`NMHELMET`, '') AS `NMHELMET`,
  NULLIF(s.`NMPROPAD`, '') AS `NMPROPAD`,
  NULLIF(s.`NMOTHPRO`, '') AS `NMOTHPRO`,
  NULLIF(s.`NMREFCLO`, '') AS `NMREFCLO`,
  NULLIF(s.`NMLIGHT`, '') AS `NMLIGHT`,
  NULLIF(s.`NMOTHPRE`, '') AS `NMOTHPRE`
FROM `fars_stage`.`safetyeq` AS s;

COMMIT;
