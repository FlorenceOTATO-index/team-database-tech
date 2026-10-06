-- 01_load_staging_tables.sql
-- Phase 1 of the load: (re)create the text-only staging database fars_stage.
--
-- One staging table per source CSV (39: 36 under data/processed/ plus
-- code_labels, county and city under data/processed/lookups/). Column names
-- and order match each CSV header exactly and every column is TEXT, so LOAD
-- DATA performs no type conversion. lookups/label_conflicts.csv has no target
-- table and is not staged.
--
-- Staging uses MyISAM: it is a throwaway area that needs no transactions, and
-- vpicdecode's 195 TEXT columns sit at InnoDB's worst-case row-size limit.
-- The binary NO PAD collation (utf8mb4_0900_bin) makes DISTINCT, GROUP BY,
-- joins and NULLIF(x, '') compare the exact source text.
--
-- This script drops and recreates fars_stage only. No load script drops,
-- recreates or alters fars; to reload from scratch, drop fars yourself and
-- rerun sql/schema/01_create_tables.sql first.
--
-- Load sequence, run from the repository root:
--   mysql -u root -p                 < sql/load/01_load_staging_tables.sql
--   mysql -u root -p --local-infile=1 < sql/load/02_load_staging_data.sql
--   mysql -u root -p                 < sql/load/03_load_reference.sql
--   ... 04 to 11 in numeric order ...
--   mysql -u root -p -t              < sql/load/12_load_verify.sql
--   mysql -u root -p                 < sql/load/13_load_drop_staging.sql
-- The mysql client stops at the first error, so the rest of a failed script never runs.

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

DROP DATABASE IF EXISTS fars_stage;
CREATE DATABASE fars_stage DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_0900_bin;

-- Raises an error (and so stops the mysql client) when a check fails.
DELIMITER //
CREATE PROCEDURE fars_stage.assert_true(IN ok BOOLEAN, IN msg VARCHAR(128))
BEGIN
  IF ok IS NULL OR NOT ok THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = msg;
  END IF;
END//
DELIMITER ;

CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = 'fars' AND TABLE_TYPE = 'BASE TABLE') = 53,
  'fars must hold the 53 tables from sql/schema/01_create_tables.sql');

-- One row per LOAD DATA statement in 02 (server-reported rows and warning count).
CREATE TABLE fars_stage.load_log (
  staging_table VARCHAR(64)  NOT NULL,
  source_file   VARCHAR(255) NOT NULL,
  rows_reported BIGINT,
  conditions    INT,
  loaded_at     TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (staging_table)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- Expected row counts: source CSV data rows (staging) and approved target counts (target).
CREATE TABLE fars_stage.expected_rows (
  object_type   VARCHAR(8)   NOT NULL,
  object_name   VARCHAR(64)  NOT NULL,
  expected_rows INT UNSIGNED NOT NULL,
  PRIMARY KEY (object_type, object_name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO fars_stage.expected_rows (object_type, object_name, expected_rows) VALUES
  ('staging', 'acc_aux', 36297),
  ('staging', 'accident', 36297),
  ('staging', 'cevent', 99225),
  ('staging', 'crashrf', 36587),
  ('staging', 'damage', 240091),
  ('staging', 'distract', 56026),
  ('staging', 'drimpair', 56181),
  ('staging', 'driverrf', 62603),
  ('staging', 'drugs', 128399),
  ('staging', 'factor', 56076),
  ('staging', 'maneuver', 56018),
  ('staging', 'miacc', 36297),
  ('staging', 'midrvacc', 36229),
  ('staging', 'miper', 64616),
  ('staging', 'nmcrash', 13054),
  ('staging', 'nmdistract', 9020),
  ('staging', 'nmimpair', 9037),
  ('staging', 'nmprior', 9344),
  ('staging', 'parkwork', 1526),
  ('staging', 'pbtype', 8940),
  ('staging', 'per_aux', 88326),
  ('staging', 'person', 88326),
  ('staging', 'personrf', 88343),
  ('staging', 'pvehiclesf', 1526),
  ('staging', 'race', 88517),
  ('staging', 'safetyeq', 9020),
  ('staging', 'veh_aux', 56011),
  ('staging', 'vehicle', 56011),
  ('staging', 'vehiclesf', 56013),
  ('staging', 'vevent', 120270),
  ('staging', 'violatn', 59670),
  ('staging', 'vision', 56049),
  ('staging', 'vpicdecode', 55087),
  ('staging', 'vpictrailerdecode', 1639),
  ('staging', 'vsoe', 120270),
  ('staging', 'weather', 36692),
  ('staging', 'code_labels', 8892),
  ('staging', 'county', 2827),
  ('staging', 'city', 5507),
  ('target', 'calendar', 366),
  ('target', 'death_time', 1457),
  ('target', 'vin_detail', 49396),
  ('target', 'pvin_detail', 1465),
  ('target', 'vpic_labels', 3170),
  ('target', 'state_region', 51),
  ('target', 'roadfc_inter', 7),
  ('target', 'junc_intsec', 4),
  ('target', 'age_band_map', 13),
  ('target', 'ped_crash_group', 51),
  ('target', 'bike_crash_group', 66),
  ('target', 'code_labels', 8892),
  ('target', 'county', 2827),
  ('target', 'city', 5507),
  ('target', 'accident', 36297),
  ('target', 'crash_unit', 57537),
  ('target', 'vehicle', 56011),
  ('target', 'parkwork', 1526),
  ('target', 'person', 88326),
  ('target', 'acc_aux', 36297),
  ('target', 'cevent', 99225),
  ('target', 'crashrf', 36587),
  ('target', 'weather', 36692),
  ('target', 'miacc', 36297),
  ('target', 'midrvacc', 36229),
  ('target', 'parkwork_hazmat', 1070),
  ('target', 'crash_pbszone', 8419),
  ('target', 'damage', 240091),
  ('target', 'distract', 56026),
  ('target', 'drimpair', 56181),
  ('target', 'driverrf', 62603),
  ('target', 'factor', 56076),
  ('target', 'maneuver', 56018),
  ('target', 'vehiclesf', 56013),
  ('target', 'violatn', 59670),
  ('target', 'vision', 56049),
  ('target', 'veh_aux', 56011),
  ('target', 'vevent', 120270),
  ('target', 'vsoe', 120270),
  ('target', 'vpicdecode', 55087),
  ('target', 'vpictrailerdecode', 1639),
  ('target', 'pvehiclesf', 1526),
  ('target', 'drugs', 128399),
  ('target', 'miper', 64616),
  ('target', 'nmcrash', 13054),
  ('target', 'nmdistract', 9020),
  ('target', 'nmimpair', 9037),
  ('target', 'nmprior', 9344),
  ('target', 'pbtype', 8940),
  ('target', 'per_aux', 88326),
  ('target', 'personrf', 88343),
  ('target', 'race', 88517),
  ('target', 'safetyeq', 9020);

-- ------------------------------------------------------------------------
-- Staging tables (one per CSV; all columns TEXT, named and ordered as the CSV header)
-- ------------------------------------------------------------------------

-- data/processed/acc_aux.csv: 36,297 data rows
CREATE TABLE fars_stage.`acc_aux` (
  `YEAR` TEXT,
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `FATALS` TEXT,
  `A_CRAINJ` TEXT,
  `A_REGION` TEXT,
  `A_RU` TEXT,
  `A_INTER` TEXT,
  `A_RELRD` TEXT,
  `A_INTSEC` TEXT,
  `A_ROADFC` TEXT,
  `A_JUNC` TEXT,
  `A_MANCOL` TEXT,
  `A_TOD` TEXT,
  `A_DOW` TEXT,
  `A_CT` TEXT,
  `A_WEATHER` TEXT,
  `A_LT` TEXT,
  `A_MC` TEXT,
  `A_SBUSCR` TEXT,
  `A_SPCRA` TEXT,
  `A_PED` TEXT,
  `A_PED_F` TEXT,
  `A_PEDAL` TEXT,
  `A_PEDAL_F` TEXT,
  `A_ROLL` TEXT,
  `A_POLPUR` TEXT,
  `A_POSBAC` TEXT,
  `A_D15_19` TEXT,
  `A_D16_19` TEXT,
  `A_D15_20` TEXT,
  `A_D16_20` TEXT,
  `A_D65PLS` TEXT,
  `A_D21_24` TEXT,
  `A_D16_24` TEXT,
  `A_RD` TEXT,
  `A_HR` TEXT,
  `A_DIST` TEXT,
  `A_DROWSY` TEXT,
  `A_WRONGWAY` TEXT,
  `BIA` TEXT,
  `SPJ_INDIAN` TEXT,
  `INDIAN_RES` TEXT,
  `CENSUS_2020_TRACT_FIPS` TEXT,
  `TRACT` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/accident.csv: 36,297 data rows
CREATE TABLE fars_stage.`accident` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `PEDS` TEXT,
  `PERNOTMVIT` TEXT,
  `VE_TOTAL` TEXT,
  `VE_FORMS` TEXT,
  `PVH_INVL` TEXT,
  `PERSONS` TEXT,
  `PERMVIT` TEXT,
  `COUNTY` TEXT,
  `CITY` TEXT,
  `MONTH` TEXT,
  `DAY` TEXT,
  `DAY_WEEK` TEXT,
  `YEAR` TEXT,
  `HOUR` TEXT,
  `MINUTE` TEXT,
  `TWAY_ID` TEXT,
  `TWAY_ID2` TEXT,
  `ROUTE` TEXT,
  `RUR_URB` TEXT,
  `FUNC_SYS` TEXT,
  `RD_OWNER` TEXT,
  `NHS` TEXT,
  `SP_JUR` TEXT,
  `MILEPT` TEXT,
  `LATITUDE` TEXT,
  `LONGITUD` TEXT,
  `HARM_EV` TEXT,
  `MAN_COLL` TEXT,
  `RELJCT1` TEXT,
  `RELJCT2` TEXT,
  `TYP_INT` TEXT,
  `REL_ROAD` TEXT,
  `WRK_ZONE` TEXT,
  `LGT_COND` TEXT,
  `WEATHER` TEXT,
  `SCH_BUS` TEXT,
  `RAIL` TEXT,
  `NOT_HOUR` TEXT,
  `NOT_MIN` TEXT,
  `ARR_HOUR` TEXT,
  `ARR_MIN` TEXT,
  `HOSP_HR` TEXT,
  `HOSP_MN` TEXT,
  `FATALS` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/cevent.csv: 99,225 data rows
CREATE TABLE fars_stage.`cevent` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `EVENTNUM` TEXT,
  `VNUMBER1` TEXT,
  `AOI1` TEXT,
  `SOE` TEXT,
  `VNUMBER2` TEXT,
  `AOI2` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/crashrf.csv: 36,587 data rows
CREATE TABLE fars_stage.`crashrf` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `CRASHRF` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/damage.csv: 240,091 data rows
CREATE TABLE fars_stage.`damage` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `DAMAGE` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/distract.csv: 56,026 data rows
CREATE TABLE fars_stage.`distract` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `DRDISTRACT` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/drimpair.csv: 56,181 data rows
CREATE TABLE fars_stage.`drimpair` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `DRIMPAIR` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/driverrf.csv: 62,603 data rows
CREATE TABLE fars_stage.`driverrf` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `DRIVERRF` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/drugs.csv: 128,399 data rows
CREATE TABLE fars_stage.`drugs` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `DRUGSPEC` TEXT,
  `DRUGMETHOD` TEXT,
  `DRUGRES` TEXT,
  `DRUGQTY` TEXT,
  `DRUGACTQTY` TEXT,
  `DRUGUOM` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/factor.csv: 56,076 data rows
CREATE TABLE fars_stage.`factor` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VEHICLECC` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/maneuver.csv: 56,018 data rows
CREATE TABLE fars_stage.`maneuver` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `MANEUVER` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/miacc.csv: 36,297 data rows
CREATE TABLE fars_stage.`miacc` (
  `ST_CASE` TEXT,
  `A1` TEXT,
  `A2` TEXT,
  `A3` TEXT,
  `A4` TEXT,
  `A5` TEXT,
  `A6` TEXT,
  `A7` TEXT,
  `A8` TEXT,
  `A9` TEXT,
  `A10` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/midrvacc.csv: 36,229 data rows
CREATE TABLE fars_stage.`midrvacc` (
  `ST_CASE` TEXT,
  `A1` TEXT,
  `A2` TEXT,
  `A3` TEXT,
  `A4` TEXT,
  `A5` TEXT,
  `A6` TEXT,
  `A7` TEXT,
  `A8` TEXT,
  `A9` TEXT,
  `A10` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/miper.csv: 64,616 data rows
CREATE TABLE fars_stage.`miper` (
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `P1` TEXT,
  `P2` TEXT,
  `P3` TEXT,
  `P4` TEXT,
  `P5` TEXT,
  `P6` TEXT,
  `P7` TEXT,
  `P8` TEXT,
  `P9` TEXT,
  `P10` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/nmcrash.csv: 13,054 data rows
CREATE TABLE fars_stage.`nmcrash` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `NMCC` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/nmdistract.csv: 9,020 data rows
CREATE TABLE fars_stage.`nmdistract` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `NMDISTRACT` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/nmimpair.csv: 9,037 data rows
CREATE TABLE fars_stage.`nmimpair` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `NMIMPAIR` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/nmprior.csv: 9,344 data rows
CREATE TABLE fars_stage.`nmprior` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `NMACTION` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/parkwork.csv: 1,526 data rows
CREATE TABLE fars_stage.`parkwork` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PVE_FORMS` TEXT,
  `PMONTH` TEXT,
  `PDAY` TEXT,
  `PHOUR` TEXT,
  `PMINUTE` TEXT,
  `PHARM_EV` TEXT,
  `PMAN_COLL` TEXT,
  `PNUMOCCS` TEXT,
  `PTYPE` TEXT,
  `PHIT_RUN` TEXT,
  `PREG_STAT` TEXT,
  `POWNER` TEXT,
  `PVIN` TEXT,
  `PMODYEAR` TEXT,
  `PVPICMAKE` TEXT,
  `PVPICMODEL` TEXT,
  `PVPICBODYCLASS` TEXT,
  `PMAKE` TEXT,
  `PMODEL` TEXT,
  `PBODYTYP` TEXT,
  `PICFINALBODY` TEXT,
  `PGVWR_FROM` TEXT,
  `PGVWR_TO` TEXT,
  `PTRAILER` TEXT,
  `PTRLR1VIN` TEXT,
  `PTRLR2VIN` TEXT,
  `PTRLR3VIN` TEXT,
  `PTRLR1GVWR` TEXT,
  `PTRLR2GVWR` TEXT,
  `PTRLR3GVWR` TEXT,
  `PMCARR_ID` TEXT,
  `PMCARR_I1` TEXT,
  `PMCARR_I2` TEXT,
  `PV_CONFIG` TEXT,
  `PCARGTYP` TEXT,
  `PHAZ_INV` TEXT,
  `PHAZPLAC` TEXT,
  `PHAZ_ID` TEXT,
  `PHAZ_CNO` TEXT,
  `PHAZ_REL` TEXT,
  `PBUS_USE` TEXT,
  `PSP_USE` TEXT,
  `PEM_USE` TEXT,
  `PUNDEROVERRIDE` TEXT,
  `PIMPACT1` TEXT,
  `PVEH_SEV` TEXT,
  `PTOWED` TEXT,
  `PM_HARM` TEXT,
  `PFIRE` TEXT,
  `PMAK_MOD` TEXT,
  `PVIN_1` TEXT,
  `PVIN_2` TEXT,
  `PVIN_3` TEXT,
  `PVIN_4` TEXT,
  `PVIN_5` TEXT,
  `PVIN_6` TEXT,
  `PVIN_7` TEXT,
  `PVIN_8` TEXT,
  `PVIN_9` TEXT,
  `PVIN_10` TEXT,
  `PVIN_11` TEXT,
  `PVIN_12` TEXT,
  `PDEATHS` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/pbtype.csv: 8,940 data rows
CREATE TABLE fars_stage.`pbtype` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `PBAGE` TEXT,
  `PBSEX` TEXT,
  `PBPTYPE` TEXT,
  `PBCWALK` TEXT,
  `PBSWALK` TEXT,
  `PBSZONE` TEXT,
  `PEDCTYPE` TEXT,
  `BIKECTYPE` TEXT,
  `PEDLOC` TEXT,
  `BIKELOC` TEXT,
  `PEDPOS` TEXT,
  `BIKEPOS` TEXT,
  `PEDDIR` TEXT,
  `BIKEDIR` TEXT,
  `MOTDIR` TEXT,
  `MOTMAN` TEXT,
  `PEDLEG` TEXT,
  `PEDSNR` TEXT,
  `PEDCGP` TEXT,
  `BIKECGP` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/per_aux.csv: 88,326 data rows
CREATE TABLE fars_stage.`per_aux` (
  `A_AGE1` TEXT,
  `A_AGE2` TEXT,
  `A_AGE3` TEXT,
  `A_AGE4` TEXT,
  `A_AGE5` TEXT,
  `A_AGE6` TEXT,
  `A_AGE7` TEXT,
  `A_AGE8` TEXT,
  `A_AGE9` TEXT,
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `YEAR` TEXT,
  `A_PTYPE` TEXT,
  `A_RESTUSE` TEXT,
  `A_HELMUSE` TEXT,
  `A_ALCTES` TEXT,
  `A_HISP` TEXT,
  `A_RCAT` TEXT,
  `A_HRACE` TEXT,
  `A_EJECT` TEXT,
  `A_PERINJ` TEXT,
  `A_LOC` TEXT,
  `A_DOA` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/person.csv: 88,326 data rows
CREATE TABLE fars_stage.`person` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `VE_FORMS` TEXT,
  `COUNTY` TEXT,
  `MONTH` TEXT,
  `DAY` TEXT,
  `HOUR` TEXT,
  `MINUTE` TEXT,
  `HARM_EV` TEXT,
  `MAN_COLL` TEXT,
  `SCH_BUS` TEXT,
  `RUR_URB` TEXT,
  `FUNC_SYS` TEXT,
  `MOD_YEAR` TEXT,
  `VPICMAKE` TEXT,
  `VPICMODEL` TEXT,
  `VPICBODYCLASS` TEXT,
  `MAKE` TEXT,
  `BODY_TYP` TEXT,
  `ICFINALBODY` TEXT,
  `GVWR_FROM` TEXT,
  `GVWR_TO` TEXT,
  `TOW_VEH` TEXT,
  `SPEC_USE` TEXT,
  `EMER_USE` TEXT,
  `ROLLOVER` TEXT,
  `IMPACT1` TEXT,
  `FIRE_EXP` TEXT,
  `MAK_MOD` TEXT,
  `AGE` TEXT,
  `SEX` TEXT,
  `PER_TYP` TEXT,
  `INJ_SEV` TEXT,
  `SEAT_POS` TEXT,
  `REST_USE` TEXT,
  `REST_MIS` TEXT,
  `HELM_USE` TEXT,
  `HELM_MIS` TEXT,
  `AIR_BAG` TEXT,
  `EJECTION` TEXT,
  `EJ_PATH` TEXT,
  `EXTRICAT` TEXT,
  `DRINKING` TEXT,
  `ALC_STATUS` TEXT,
  `ATST_TYP` TEXT,
  `ALC_RES` TEXT,
  `DRUGS` TEXT,
  `DSTATUS` TEXT,
  `HOSPITAL` TEXT,
  `DOA` TEXT,
  `DEATH_MO` TEXT,
  `DEATH_DA` TEXT,
  `DEATH_YR` TEXT,
  `DEATH_TM` TEXT,
  `DEATH_HR` TEXT,
  `DEATH_MN` TEXT,
  `LAG_HRS` TEXT,
  `LAG_MINS` TEXT,
  `STR_VEH` TEXT,
  `DEVTYPE` TEXT,
  `DEVMOTOR` TEXT,
  `LOCATION` TEXT,
  `WORK_INJ` TEXT,
  `HISPANIC` TEXT,
  KEY `idx_person_key` (`ST_CASE`(16), `VEH_NO`(8), `PER_NO`(8))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/personrf.csv: 88,343 data rows
CREATE TABLE fars_stage.`personrf` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `PERSONRF` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/pvehiclesf.csv: 1,526 data rows
CREATE TABLE fars_stage.`pvehiclesf` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PVEHICLESF` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/race.csv: 88,517 data rows
CREATE TABLE fars_stage.`race` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `RACE` TEXT,
  `RACE_ORDER` TEXT,
  `MULTRACE` TEXT,
  KEY `idx_race_key` (`ST_CASE`(16), `VEH_NO`(8), `PER_NO`(8))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/safetyeq.csv: 9,020 data rows
CREATE TABLE fars_stage.`safetyeq` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `PER_NO` TEXT,
  `NMHELMET` TEXT,
  `NMPROPAD` TEXT,
  `NMOTHPRO` TEXT,
  `NMREFCLO` TEXT,
  `NMLIGHT` TEXT,
  `NMOTHPRE` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/veh_aux.csv: 56,011 data rows
CREATE TABLE fars_stage.`veh_aux` (
  `YEAR` TEXT,
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `A_WRONGWAYDRV` TEXT,
  `A_DRDIS` TEXT,
  `A_DRDRO` TEXT,
  `A_VRD` TEXT,
  `A_BODY` TEXT,
  `A_IMP1` TEXT,
  `A_VROLL` TEXT,
  `A_LIC_S` TEXT,
  `A_LIC_C` TEXT,
  `A_CDL_S` TEXT,
  `A_MC_L_S` TEXT,
  `A_SPVEH` TEXT,
  `A_SBUS` TEXT,
  `A_MOD_YR` TEXT,
  `A_FIRE_EXP` TEXT,
  `A_TOWED` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vehicle.csv: 56,011 data rows
CREATE TABLE fars_stage.`vehicle` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VE_FORMS` TEXT,
  `MONTH` TEXT,
  `DAY` TEXT,
  `HOUR` TEXT,
  `MINUTE` TEXT,
  `HARM_EV` TEXT,
  `MAN_COLL` TEXT,
  `NUMOCCS` TEXT,
  `UNITTYPE` TEXT,
  `HIT_RUN` TEXT,
  `REG_STAT` TEXT,
  `OWNER` TEXT,
  `VIN` TEXT,
  `MOD_YEAR` TEXT,
  `VPICMAKE` TEXT,
  `VPICMODEL` TEXT,
  `VPICBODYCLASS` TEXT,
  `MAKE` TEXT,
  `MODEL` TEXT,
  `BODY_TYP` TEXT,
  `ICFINALBODY` TEXT,
  `GVWR_FROM` TEXT,
  `GVWR_TO` TEXT,
  `TOW_VEH` TEXT,
  `TRLR1VIN` TEXT,
  `TRLR2VIN` TEXT,
  `TRLR3VIN` TEXT,
  `TRLR1GVWR` TEXT,
  `TRLR2GVWR` TEXT,
  `TRLR3GVWR` TEXT,
  `J_KNIFE` TEXT,
  `MCARR_ID` TEXT,
  `MCARR_I1` TEXT,
  `MCARR_I2` TEXT,
  `V_CONFIG` TEXT,
  `CARGO_BT` TEXT,
  `HAZ_INV` TEXT,
  `HAZ_PLAC` TEXT,
  `HAZ_ID` TEXT,
  `HAZ_CNO` TEXT,
  `HAZ_REL` TEXT,
  `BUS_USE` TEXT,
  `SPEC_USE` TEXT,
  `EMER_USE` TEXT,
  `TRAV_SP` TEXT,
  `UNDEROVERRIDE` TEXT,
  `ROLLOVER` TEXT,
  `ROLINLOC` TEXT,
  `IMPACT1` TEXT,
  `DEFORMED` TEXT,
  `TOWED` TEXT,
  `M_HARM` TEXT,
  `FIRE_EXP` TEXT,
  `MAK_MOD` TEXT,
  `VIN_1` TEXT,
  `VIN_2` TEXT,
  `VIN_3` TEXT,
  `VIN_4` TEXT,
  `VIN_5` TEXT,
  `VIN_6` TEXT,
  `VIN_7` TEXT,
  `VIN_8` TEXT,
  `VIN_9` TEXT,
  `VIN_10` TEXT,
  `VIN_11` TEXT,
  `VIN_12` TEXT,
  `DEATHS` TEXT,
  `DR_DRINK` TEXT,
  `DR_PRES` TEXT,
  `L_STATE` TEXT,
  `DR_ZIP` TEXT,
  `L_TYPE` TEXT,
  `L_STATUS` TEXT,
  `CDL_STAT` TEXT,
  `L_ENDORS` TEXT,
  `L_COMPL` TEXT,
  `L_RESTRI` TEXT,
  `DR_HGT` TEXT,
  `DR_WGT` TEXT,
  `PREV_ACC` TEXT,
  `PREV_SUS1` TEXT,
  `PREV_SUS2` TEXT,
  `PREV_SUS3` TEXT,
  `PREV_DWI` TEXT,
  `PREV_SPD` TEXT,
  `PREV_OTH` TEXT,
  `FIRST_MO` TEXT,
  `FIRST_YR` TEXT,
  `LAST_MO` TEXT,
  `LAST_YR` TEXT,
  `SPEEDREL` TEXT,
  `VTRAFWAY` TEXT,
  `VNUM_LAN` TEXT,
  `VSPD_LIM` TEXT,
  `VALIGN` TEXT,
  `VPROFILE` TEXT,
  `VPAVETYP` TEXT,
  `VSURCOND` TEXT,
  `VTRAFCON` TEXT,
  `VTCONT_F` TEXT,
  `P_CRASH1` TEXT,
  `P_CRASH2` TEXT,
  `P_CRASH3` TEXT,
  `PCRASH4` TEXT,
  `PCRASH5` TEXT,
  `ACC_TYPE` TEXT,
  KEY `idx_vehicle_key` (`ST_CASE`(16), `VEH_NO`(8))
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vehiclesf.csv: 56,013 data rows
CREATE TABLE fars_stage.`vehiclesf` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VEHICLESF` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vevent.csv: 120,270 data rows
CREATE TABLE fars_stage.`vevent` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `EVENTNUM` TEXT,
  `VEH_NO` TEXT,
  `VEVENTNUM` TEXT,
  `VNUMBER1` TEXT,
  `AOI1` TEXT,
  `SOE` TEXT,
  `VNUMBER2` TEXT,
  `AOI2` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/violatn.csv: 59,670 data rows
CREATE TABLE fars_stage.`violatn` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VIOLATION` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vision.csv: 56,049 data rows
CREATE TABLE fars_stage.`vision` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VISION` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vpicdecode.csv: 55,087 data rows
CREATE TABLE fars_stage.`vpicdecode` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VEHICLEDESCRIPTOR` TEXT,
  `VINDECODEDON` TEXT,
  `VINDECODEERROR` TEXT,
  `VEHICLETYPEID` TEXT,
  `VEHICLETYPE` TEXT,
  `MANUFACTURERFULLNAMEID` TEXT,
  `MANUFACTURERFULLNAME` TEXT,
  `MAKEID` TEXT,
  `MAKE` TEXT,
  `MODELID` TEXT,
  `MODEL` TEXT,
  `MODELYEAR` TEXT,
  `SERIES` TEXT,
  `TRIM` TEXT,
  `SERIES2` TEXT,
  `TRIM2` TEXT,
  `PLANTCOUNTRYID` TEXT,
  `PLANTCOUNTRY` TEXT,
  `PLANTSTATE` TEXT,
  `PLANTCITY` TEXT,
  `PLANTCOMPANYNAME` TEXT,
  `DESTINATIONMARKETID` TEXT,
  `DESTINATIONMARKET` TEXT,
  `BASEPRICE` TEXT,
  `NOTE` TEXT,
  `BODYCLASSID` TEXT,
  `BODYCLASS` TEXT,
  `DOORSCOUNT` TEXT,
  `WINDOWS` TEXT,
  `WHEELBASETYPEID` TEXT,
  `WHEELBASETYPE` TEXT,
  `TRACKWIDTHIN` TEXT,
  `GROSSVEHICLEWEIGHTRATINGFROMID` TEXT,
  `GROSSVEHICLEWEIGHTRATINGFROM` TEXT,
  `GROSSVEHICLEWEIGHTRATINGTOID` TEXT,
  `GROSSVEHICLEWEIGHTRATINGTO` TEXT,
  `CURBWEIGHTLB` TEXT,
  `WHEELBASEIN_FROM` TEXT,
  `WHEELBASEIN_TO` TEXT,
  `WHEELSCOUNT` TEXT,
  `WHEELSIZEFRONTIN` TEXT,
  `WHEELSIZEREARIN` TEXT,
  `TRUCKBODYCABTYPEID` TEXT,
  `TRUCKBODYCABTYPE` TEXT,
  `TRUCKBEDTYPEID` TEXT,
  `TRUCKBEDTYPE` TEXT,
  `TRUCKBEDLENGTHIN` TEXT,
  `BUSTYPEID` TEXT,
  `BUSTYPE` TEXT,
  `BUSFLOORCONFIGURATIONTYPEID` TEXT,
  `BUSFLOORCONFIGURATIONTYPE` TEXT,
  `BUSLENGTHFT` TEXT,
  `OTHERBUSINFO` TEXT,
  `CUSTOMMOTORCYCLETYPEID` TEXT,
  `CUSTOMMOTORCYCLETYPE` TEXT,
  `MOTORCYCLESUSPENSIONTYPEID` TEXT,
  `MOTORCYCLESUSPENSIONTYPE` TEXT,
  `MOTORCYCLECHASSISTYPEID` TEXT,
  `MOTORCYCLECHASSISTYPE` TEXT,
  `OTHERMOTORCYCLEINFO` TEXT,
  `STEERINGLOCATIONID` TEXT,
  `STEERINGLOCATION` TEXT,
  `ENTERTAINMENTSYSTEMID` TEXT,
  `ENTERTAINMENTSYSTEM` TEXT,
  `SEATSCOUNT` TEXT,
  `SEATROWSCOUNT` TEXT,
  `TRANSMISSIONSPEEDS` TEXT,
  `TRANSMISSIONSTYLEID` TEXT,
  `TRANSMISSIONSTYLE` TEXT,
  `DRIVETYPEID` TEXT,
  `DRIVETYPE` TEXT,
  `AXLESCOUNT` TEXT,
  `AXLECONFIGURATIONID` TEXT,
  `AXLECONFIGURATION` TEXT,
  `BRAKESYSTEMTYPEID` TEXT,
  `BRAKESYSTEMTYPE` TEXT,
  `BRAKESYSTEMDESC` TEXT,
  `EVDRIVEUNITID` TEXT,
  `EVDRIVEUNIT` TEXT,
  `BATTERYKWH_FROM` TEXT,
  `BATTERYKWH_TO` TEXT,
  `BATTERYV_FROM` TEXT,
  `BATTERYV_TO` TEXT,
  `BATTERYA_FROM` TEXT,
  `BATTERYPACKSPERVEHICLE` TEXT,
  `BATTERYMODULESPERPACK` TEXT,
  `BATTERYCELLSPERMODULE` TEXT,
  `BATTERYTYPEID` TEXT,
  `BATTERYTYPE` TEXT,
  `OTHERBATTERYINFO` TEXT,
  `CHARGERLEVELID` TEXT,
  `CHARGERLEVEL` TEXT,
  `CHARGERPOWERKW` TEXT,
  `ENGINEMANUFACTURER` TEXT,
  `ENGINEMODEL` TEXT,
  `ENGINECONFIGURATIONID` TEXT,
  `ENGINECONFIGURATION` TEXT,
  `ENGINEPOWERKW` TEXT,
  `ENGINESTROKECYCLES` TEXT,
  `ENGINECYLINDERSCOUNT` TEXT,
  `ENGINEBRAKEHP_FROM` TEXT,
  `ENGINEBRAKEHP_TO` TEXT,
  `ENGINECOOLINGTYPEID` TEXT,
  `ENGINECOOLINGTYPE` TEXT,
  `DISPLACEMENTCI` TEXT,
  `DISPLACEMENTCC` TEXT,
  `DISPLACEMENTL` TEXT,
  `FUELTYPEPRIMARYID` TEXT,
  `FUELTYPEPRIMARY` TEXT,
  `FUELTYPESECONDARYID` TEXT,
  `FUELTYPESECONDARY` TEXT,
  `FUELDELIVERYINJECTIONTYPEID` TEXT,
  `FUELDELIVERYINJECTIONTYPE` TEXT,
  `ENGINEVALVETRAINDESIGNID` TEXT,
  `ENGINEVALVETRAINDESIGN` TEXT,
  `ENGINEELECTRIFICATIONLEVELID` TEXT,
  `ENGINEELECTRIFICATIONLEVEL` TEXT,
  `ENGINETURBOID` TEXT,
  `ENGINETURBO` TEXT,
  `TOPSPEEDMPH` TEXT,
  `OTHERENGINEINFO` TEXT,
  `SEATBELTTYPEID` TEXT,
  `SEATBELTTYPE` TEXT,
  `PRETENSIONERID` TEXT,
  `PRETENSIONER` TEXT,
  `AIRBAGLOCFRONTID` TEXT,
  `AIRBAGLOCFRONT` TEXT,
  `AIRBAGLOCKNEEID` TEXT,
  `AIRBAGLOCKNEE` TEXT,
  `AIRBAGLOCSIDEID` TEXT,
  `AIRBAGLOCSIDE` TEXT,
  `AIRBAGLOCCURTAINID` TEXT,
  `AIRBAGLOCCURTAIN` TEXT,
  `AIRBAGLOCSEATCUSHIONID` TEXT,
  `AIRBAGLOCSEATCUSHION` TEXT,
  `OTHERRESTRAINTSYSTEMINFO` TEXT,
  `FORWARDCOLLISIONWARNINGID` TEXT,
  `FORWARDCOLLISIONWARNING` TEXT,
  `DYNAMICBRAKESUPPORTID` TEXT,
  `DYNAMICBRAKESUPPORT` TEXT,
  `CRASHIMMINENTBRAKINGID` TEXT,
  `CRASHIMMINENTBRAKING` TEXT,
  `PEDESTRIANAUTOEMERGENCYBRAKINGID` TEXT,
  `PEDESTRIANAUTOEMERGENCYBRAKING` TEXT,
  `BLINDSPOTWARNINGID` TEXT,
  `BLINDSPOTWARNING` TEXT,
  `BLINDSPOTINTERVENTIONID` TEXT,
  `BLINDSPOTINTERVENTION` TEXT,
  `LANEDEPARTUREWARNINGID` TEXT,
  `LANEDEPARTUREWARNING` TEXT,
  `LANEKEEPINGASSISTANCEID` TEXT,
  `LANEKEEPINGASSISTANCE` TEXT,
  `LANECENTERINGASSISTANCEID` TEXT,
  `LANECENTERINGASSISTANCE` TEXT,
  `BACKUPCAMERAID` TEXT,
  `BACKUPCAMERA` TEXT,
  `REARCROSSTRAFFICALERTID` TEXT,
  `REARCROSSTRAFFICALERT` TEXT,
  `REARAUTOMATICEMERGENCYBRAKINGID` TEXT,
  `REARAUTOMATICEMERGENCYBRAKING` TEXT,
  `PARKASSISTID` TEXT,
  `PARKASSIST` TEXT,
  `DAYTIMERUNNINGLIGHTID` TEXT,
  `DAYTIMERUNNINGLIGHT` TEXT,
  `HEADLAMPLIGHTSOURCEID` TEXT,
  `HEADLAMPLIGHTSOURCE` TEXT,
  `SEMIAUTOHEADLAMPBEAMSWITCHINGID` TEXT,
  `SEMIAUTOHEADLAMPBEAMSWITCHING` TEXT,
  `ADAPTIVEDRIVINGBEAMID` TEXT,
  `ADAPTIVEDRIVINGBEAM` TEXT,
  `ADAPTIVECRUISECONTROLID` TEXT,
  `ADAPTIVECRUISECONTROL` TEXT,
  `ANTILOCKBRAKESYSTEMID` TEXT,
  `ANTILOCKBRAKESYSTEM` TEXT,
  `ELECTRONICSTABILITYCONTROLID` TEXT,
  `ELECTRONICSTABILITYCONTROL` TEXT,
  `TPMSID` TEXT,
  `TPMS` TEXT,
  `AUTOMATICCRASHNOTIFICATIONID` TEXT,
  `AUTOMATICCRASHNOTIFICATION` TEXT,
  `EVENTDATARECORDERID` TEXT,
  `EVENTDATARECORDER` TEXT,
  `TRACTIONCONTROLID` TEXT,
  `TRACTIONCONTROL` TEXT,
  `AUTOPEDESTRIANALERTINGSOUNDID` TEXT,
  `AUTOPEDESTRIANALERTINGSOUND` TEXT,
  `KEYLESSIGNITIONID` TEXT,
  `KEYLESSIGNITION` TEXT,
  `SAEAUTOMATIONLEVEL_FROM` TEXT,
  `AUTOREVERSESYSTEMID` TEXT,
  `AUTOREVERSESYSTEM` TEXT,
  `ACTIVESAFETYSYSNOTE` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vpictrailerdecode.csv: 1,639 data rows
CREATE TABLE fars_stage.`vpictrailerdecode` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `TRAILER_NO` TEXT,
  `VEHICLEDESCRIPTOR` TEXT,
  `VINDECODEDON` TEXT,
  `VINDECODEERROR` TEXT,
  `VEHICLETYPEID` TEXT,
  `VEHICLETYPE` TEXT,
  `MANUFACTURERFULLNAMEID` TEXT,
  `MANUFACTURERFULLNAME` TEXT,
  `MAKEID` TEXT,
  `MAKE` TEXT,
  `MODELID` TEXT,
  `MODEL` TEXT,
  `MODELYEAR` TEXT,
  `SERIES` TEXT,
  `TRIM` TEXT,
  `PLANTCOUNTRYID` TEXT,
  `PLANTCOUNTRY` TEXT,
  `PLANTSTATE` TEXT,
  `PLANTCITY` TEXT,
  `PLANTCOMPANYNAME` TEXT,
  `NOTE` TEXT,
  `BODYCLASSID` TEXT,
  `BODYCLASS` TEXT,
  `GROSSVEHICLEWEIGHTRATINGFROMID` TEXT,
  `GROSSVEHICLEWEIGHTRATINGFROM` TEXT,
  `GROSSVEHICLEWEIGHTRATINGTOID` TEXT,
  `GROSSVEHICLEWEIGHTRATINGTO` TEXT,
  `TRAILERBODYTYPEID` TEXT,
  `TRAILERBODYTYPE` TEXT,
  `TRAILERTYPECONNECTIONID` TEXT,
  `TRAILERTYPECONNECTION` TEXT,
  `TRAILERLENGTHFT` TEXT,
  `OTHERTRAILERINFO` TEXT,
  `AXLESCOUNT` TEXT,
  `AXLECONFIGURATIONID` TEXT,
  `AXLECONFIGURATION` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/vsoe.csv: 120,270 data rows
CREATE TABLE fars_stage.`vsoe` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `VEH_NO` TEXT,
  `VEVENTNUM` TEXT,
  `SOE` TEXT,
  `AOI` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/weather.csv: 36,692 data rows
CREATE TABLE fars_stage.`weather` (
  `STATE` TEXT,
  `ST_CASE` TEXT,
  `WEATHER` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/lookups/code_labels.csv: 8,892 data rows
CREATE TABLE fars_stage.`code_labels` (
  `column` TEXT,
  `code` TEXT,
  `label` TEXT,
  `source_files` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/lookups/county.csv: 2,827 data rows
CREATE TABLE fars_stage.`county` (
  `STATE` TEXT,
  `COUNTY` TEXT,
  `COUNTYNAME` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;

-- data/processed/lookups/city.csv: 5,507 data rows
CREATE TABLE fars_stage.`city` (
  `STATE` TEXT,
  `CITY` TEXT,
  `CITYNAME` TEXT
) ENGINE=MyISAM DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_bin;
