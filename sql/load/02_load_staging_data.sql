-- 02_load_staging_data.sql
-- Phase 1 of the load: copy all 39 CSVs, unchanged, into fars_stage.
--
-- Every value arrives as text: no type conversion, no NULL conversion, no
-- deduplication (the staging tables have no unique keys). CSV format of the
-- processed files: UTF-8, comma-separated, fields optionally enclosed in
-- double quotes (embedded quotes doubled), LF line endings, one header row,
-- no backslashes. ESCAPED BY '' keeps every byte literal.
--
-- Requirements:
--   1. The server must allow local files: SET PERSIST local_infile = 1; (or
--   local_infile=1 in my.cnf).
--   2. The client must allow them too: start mysql with --local-infile=1.
--   3. Run from the repository root: the file paths below are relative to the
--   client's working directory. MySQL Workbench resolves relative paths
--   differently, so use the mysql command-line client for this step.
--
--   mysql -u root -p --local-infile=1 < sql/load/02_load_staging_data.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM fars_stage.load_log) = 0,
  'fars_stage already holds loaded data: rerun 01_load_staging_tables.sql first');

LOAD DATA LOCAL INFILE 'data/processed/acc_aux.csv'
  INTO TABLE fars_stage.`acc_aux`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`YEAR`, `STATE`, `ST_CASE`, `FATALS`, `A_CRAINJ`, `A_REGION`, `A_RU`,
   `A_INTER`, `A_RELRD`, `A_INTSEC`, `A_ROADFC`, `A_JUNC`, `A_MANCOL`,
   `A_TOD`, `A_DOW`, `A_CT`, `A_WEATHER`, `A_LT`, `A_MC`, `A_SBUSCR`,
   `A_SPCRA`, `A_PED`, `A_PED_F`, `A_PEDAL`, `A_PEDAL_F`, `A_ROLL`,
   `A_POLPUR`, `A_POSBAC`, `A_D15_19`, `A_D16_19`, `A_D15_20`, `A_D16_20`,
   `A_D65PLS`, `A_D21_24`, `A_D16_24`, `A_RD`, `A_HR`, `A_DIST`, `A_DROWSY`,
   `A_WRONGWAY`, `BIA`, `SPJ_INDIAN`, `INDIAN_RES`, `CENSUS_2020_TRACT_FIPS`,
   `TRACT`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('acc_aux', 'data/processed/acc_aux.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/accident.csv'
  INTO TABLE fars_stage.`accident`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `PEDS`, `PERNOTMVIT`, `VE_TOTAL`, `VE_FORMS`,
   `PVH_INVL`, `PERSONS`, `PERMVIT`, `COUNTY`, `CITY`, `MONTH`, `DAY`,
   `DAY_WEEK`, `YEAR`, `HOUR`, `MINUTE`, `TWAY_ID`, `TWAY_ID2`, `ROUTE`,
   `RUR_URB`, `FUNC_SYS`, `RD_OWNER`, `NHS`, `SP_JUR`, `MILEPT`, `LATITUDE`,
   `LONGITUD`, `HARM_EV`, `MAN_COLL`, `RELJCT1`, `RELJCT2`, `TYP_INT`,
   `REL_ROAD`, `WRK_ZONE`, `LGT_COND`, `WEATHER`, `SCH_BUS`, `RAIL`,
   `NOT_HOUR`, `NOT_MIN`, `ARR_HOUR`, `ARR_MIN`, `HOSP_HR`, `HOSP_MN`,
   `FATALS`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('accident', 'data/processed/accident.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/cevent.csv'
  INTO TABLE fars_stage.`cevent`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `EVENTNUM`, `VNUMBER1`, `AOI1`, `SOE`, `VNUMBER2`,
   `AOI2`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('cevent', 'data/processed/cevent.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/crashrf.csv'
  INTO TABLE fars_stage.`crashrf`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `CRASHRF`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('crashrf', 'data/processed/crashrf.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/damage.csv'
  INTO TABLE fars_stage.`damage`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `DAMAGE`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('damage', 'data/processed/damage.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/distract.csv'
  INTO TABLE fars_stage.`distract`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `DRDISTRACT`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('distract', 'data/processed/distract.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/drimpair.csv'
  INTO TABLE fars_stage.`drimpair`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `DRIMPAIR`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('drimpair', 'data/processed/drimpair.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/driverrf.csv'
  INTO TABLE fars_stage.`driverrf`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `DRIVERRF`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('driverrf', 'data/processed/driverrf.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/drugs.csv'
  INTO TABLE fars_stage.`drugs`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `DRUGSPEC`, `DRUGMETHOD`,
   `DRUGRES`, `DRUGQTY`, `DRUGACTQTY`, `DRUGUOM`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('drugs', 'data/processed/drugs.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/factor.csv'
  INTO TABLE fars_stage.`factor`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VEHICLECC`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('factor', 'data/processed/factor.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/maneuver.csv'
  INTO TABLE fars_stage.`maneuver`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `MANEUVER`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('maneuver', 'data/processed/maneuver.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/miacc.csv'
  INTO TABLE fars_stage.`miacc`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`ST_CASE`, `A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, `A8`, `A9`, `A10`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('miacc', 'data/processed/miacc.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/midrvacc.csv'
  INTO TABLE fars_stage.`midrvacc`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`ST_CASE`, `A1`, `A2`, `A3`, `A4`, `A5`, `A6`, `A7`, `A8`, `A9`, `A10`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('midrvacc', 'data/processed/midrvacc.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/miper.csv'
  INTO TABLE fars_stage.`miper`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`ST_CASE`, `VEH_NO`, `PER_NO`, `P1`, `P2`, `P3`, `P4`, `P5`, `P6`, `P7`,
   `P8`, `P9`, `P10`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('miper', 'data/processed/miper.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/nmcrash.csv'
  INTO TABLE fars_stage.`nmcrash`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `NMCC`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('nmcrash', 'data/processed/nmcrash.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/nmdistract.csv'
  INTO TABLE fars_stage.`nmdistract`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `NMDISTRACT`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('nmdistract', 'data/processed/nmdistract.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/nmimpair.csv'
  INTO TABLE fars_stage.`nmimpair`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `NMIMPAIR`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('nmimpair', 'data/processed/nmimpair.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/nmprior.csv'
  INTO TABLE fars_stage.`nmprior`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `NMACTION`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('nmprior', 'data/processed/nmprior.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/parkwork.csv'
  INTO TABLE fars_stage.`parkwork`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PVE_FORMS`, `PMONTH`, `PDAY`, `PHOUR`,
   `PMINUTE`, `PHARM_EV`, `PMAN_COLL`, `PNUMOCCS`, `PTYPE`, `PHIT_RUN`,
   `PREG_STAT`, `POWNER`, `PVIN`, `PMODYEAR`, `PVPICMAKE`, `PVPICMODEL`,
   `PVPICBODYCLASS`, `PMAKE`, `PMODEL`, `PBODYTYP`, `PICFINALBODY`,
   `PGVWR_FROM`, `PGVWR_TO`, `PTRAILER`, `PTRLR1VIN`, `PTRLR2VIN`,
   `PTRLR3VIN`, `PTRLR1GVWR`, `PTRLR2GVWR`, `PTRLR3GVWR`, `PMCARR_ID`,
   `PMCARR_I1`, `PMCARR_I2`, `PV_CONFIG`, `PCARGTYP`, `PHAZ_INV`, `PHAZPLAC`,
   `PHAZ_ID`, `PHAZ_CNO`, `PHAZ_REL`, `PBUS_USE`, `PSP_USE`, `PEM_USE`,
   `PUNDEROVERRIDE`, `PIMPACT1`, `PVEH_SEV`, `PTOWED`, `PM_HARM`, `PFIRE`,
   `PMAK_MOD`, `PVIN_1`, `PVIN_2`, `PVIN_3`, `PVIN_4`, `PVIN_5`, `PVIN_6`,
   `PVIN_7`, `PVIN_8`, `PVIN_9`, `PVIN_10`, `PVIN_11`, `PVIN_12`, `PDEATHS`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('parkwork', 'data/processed/parkwork.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/pbtype.csv'
  INTO TABLE fars_stage.`pbtype`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `PBAGE`, `PBSEX`, `PBPTYPE`,
   `PBCWALK`, `PBSWALK`, `PBSZONE`, `PEDCTYPE`, `BIKECTYPE`, `PEDLOC`,
   `BIKELOC`, `PEDPOS`, `BIKEPOS`, `PEDDIR`, `BIKEDIR`, `MOTDIR`, `MOTMAN`,
   `PEDLEG`, `PEDSNR`, `PEDCGP`, `BIKECGP`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('pbtype', 'data/processed/pbtype.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/per_aux.csv'
  INTO TABLE fars_stage.`per_aux`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`A_AGE1`, `A_AGE2`, `A_AGE3`, `A_AGE4`, `A_AGE5`, `A_AGE6`, `A_AGE7`,
   `A_AGE8`, `A_AGE9`, `STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `YEAR`,
   `A_PTYPE`, `A_RESTUSE`, `A_HELMUSE`, `A_ALCTES`, `A_HISP`, `A_RCAT`,
   `A_HRACE`, `A_EJECT`, `A_PERINJ`, `A_LOC`, `A_DOA`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('per_aux', 'data/processed/per_aux.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/person.csv'
  INTO TABLE fars_stage.`person`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `VE_FORMS`, `COUNTY`, `MONTH`,
   `DAY`, `HOUR`, `MINUTE`, `HARM_EV`, `MAN_COLL`, `SCH_BUS`, `RUR_URB`,
   `FUNC_SYS`, `MOD_YEAR`, `VPICMAKE`, `VPICMODEL`, `VPICBODYCLASS`, `MAKE`,
   `BODY_TYP`, `ICFINALBODY`, `GVWR_FROM`, `GVWR_TO`, `TOW_VEH`, `SPEC_USE`,
   `EMER_USE`, `ROLLOVER`, `IMPACT1`, `FIRE_EXP`, `MAK_MOD`, `AGE`, `SEX`,
   `PER_TYP`, `INJ_SEV`, `SEAT_POS`, `REST_USE`, `REST_MIS`, `HELM_USE`,
   `HELM_MIS`, `AIR_BAG`, `EJECTION`, `EJ_PATH`, `EXTRICAT`, `DRINKING`,
   `ALC_STATUS`, `ATST_TYP`, `ALC_RES`, `DRUGS`, `DSTATUS`, `HOSPITAL`,
   `DOA`, `DEATH_MO`, `DEATH_DA`, `DEATH_YR`, `DEATH_TM`, `DEATH_HR`,
   `DEATH_MN`, `LAG_HRS`, `LAG_MINS`, `STR_VEH`, `DEVTYPE`, `DEVMOTOR`,
   `LOCATION`, `WORK_INJ`, `HISPANIC`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('person', 'data/processed/person.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/personrf.csv'
  INTO TABLE fars_stage.`personrf`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `PERSONRF`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('personrf', 'data/processed/personrf.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/pvehiclesf.csv'
  INTO TABLE fars_stage.`pvehiclesf`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PVEHICLESF`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('pvehiclesf', 'data/processed/pvehiclesf.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/race.csv'
  INTO TABLE fars_stage.`race`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `RACE`, `RACE_ORDER`, `MULTRACE`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('race', 'data/processed/race.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/safetyeq.csv'
  INTO TABLE fars_stage.`safetyeq`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `PER_NO`, `NMHELMET`, `NMPROPAD`,
   `NMOTHPRO`, `NMREFCLO`, `NMLIGHT`, `NMOTHPRE`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('safetyeq', 'data/processed/safetyeq.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/veh_aux.csv'
  INTO TABLE fars_stage.`veh_aux`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`YEAR`, `STATE`, `ST_CASE`, `VEH_NO`, `A_WRONGWAYDRV`, `A_DRDIS`,
   `A_DRDRO`, `A_VRD`, `A_BODY`, `A_IMP1`, `A_VROLL`, `A_LIC_S`, `A_LIC_C`,
   `A_CDL_S`, `A_MC_L_S`, `A_SPVEH`, `A_SBUS`, `A_MOD_YR`, `A_FIRE_EXP`,
   `A_TOWED`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('veh_aux', 'data/processed/veh_aux.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vehicle.csv'
  INTO TABLE fars_stage.`vehicle`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VE_FORMS`, `MONTH`, `DAY`, `HOUR`,
   `MINUTE`, `HARM_EV`, `MAN_COLL`, `NUMOCCS`, `UNITTYPE`, `HIT_RUN`,
   `REG_STAT`, `OWNER`, `VIN`, `MOD_YEAR`, `VPICMAKE`, `VPICMODEL`,
   `VPICBODYCLASS`, `MAKE`, `MODEL`, `BODY_TYP`, `ICFINALBODY`, `GVWR_FROM`,
   `GVWR_TO`, `TOW_VEH`, `TRLR1VIN`, `TRLR2VIN`, `TRLR3VIN`, `TRLR1GVWR`,
   `TRLR2GVWR`, `TRLR3GVWR`, `J_KNIFE`, `MCARR_ID`, `MCARR_I1`, `MCARR_I2`,
   `V_CONFIG`, `CARGO_BT`, `HAZ_INV`, `HAZ_PLAC`, `HAZ_ID`, `HAZ_CNO`,
   `HAZ_REL`, `BUS_USE`, `SPEC_USE`, `EMER_USE`, `TRAV_SP`, `UNDEROVERRIDE`,
   `ROLLOVER`, `ROLINLOC`, `IMPACT1`, `DEFORMED`, `TOWED`, `M_HARM`,
   `FIRE_EXP`, `MAK_MOD`, `VIN_1`, `VIN_2`, `VIN_3`, `VIN_4`, `VIN_5`,
   `VIN_6`, `VIN_7`, `VIN_8`, `VIN_9`, `VIN_10`, `VIN_11`, `VIN_12`,
   `DEATHS`, `DR_DRINK`, `DR_PRES`, `L_STATE`, `DR_ZIP`, `L_TYPE`,
   `L_STATUS`, `CDL_STAT`, `L_ENDORS`, `L_COMPL`, `L_RESTRI`, `DR_HGT`,
   `DR_WGT`, `PREV_ACC`, `PREV_SUS1`, `PREV_SUS2`, `PREV_SUS3`, `PREV_DWI`,
   `PREV_SPD`, `PREV_OTH`, `FIRST_MO`, `FIRST_YR`, `LAST_MO`, `LAST_YR`,
   `SPEEDREL`, `VTRAFWAY`, `VNUM_LAN`, `VSPD_LIM`, `VALIGN`, `VPROFILE`,
   `VPAVETYP`, `VSURCOND`, `VTRAFCON`, `VTCONT_F`, `P_CRASH1`, `P_CRASH2`,
   `P_CRASH3`, `PCRASH4`, `PCRASH5`, `ACC_TYPE`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vehicle', 'data/processed/vehicle.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vehiclesf.csv'
  INTO TABLE fars_stage.`vehiclesf`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VEHICLESF`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vehiclesf', 'data/processed/vehiclesf.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vevent.csv'
  INTO TABLE fars_stage.`vevent`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `EVENTNUM`, `VEH_NO`, `VEVENTNUM`, `VNUMBER1`, `AOI1`,
   `SOE`, `VNUMBER2`, `AOI2`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vevent', 'data/processed/vevent.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/violatn.csv'
  INTO TABLE fars_stage.`violatn`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VIOLATION`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('violatn', 'data/processed/violatn.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vision.csv'
  INTO TABLE fars_stage.`vision`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VISION`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vision', 'data/processed/vision.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vpicdecode.csv'
  INTO TABLE fars_stage.`vpicdecode`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VEHICLEDESCRIPTOR`, `VINDECODEDON`,
   `VINDECODEERROR`, `VEHICLETYPEID`, `VEHICLETYPE`,
   `MANUFACTURERFULLNAMEID`, `MANUFACTURERFULLNAME`, `MAKEID`, `MAKE`,
   `MODELID`, `MODEL`, `MODELYEAR`, `SERIES`, `TRIM`, `SERIES2`, `TRIM2`,
   `PLANTCOUNTRYID`, `PLANTCOUNTRY`, `PLANTSTATE`, `PLANTCITY`,
   `PLANTCOMPANYNAME`, `DESTINATIONMARKETID`, `DESTINATIONMARKET`,
   `BASEPRICE`, `NOTE`, `BODYCLASSID`, `BODYCLASS`, `DOORSCOUNT`, `WINDOWS`,
   `WHEELBASETYPEID`, `WHEELBASETYPE`, `TRACKWIDTHIN`,
   `GROSSVEHICLEWEIGHTRATINGFROMID`, `GROSSVEHICLEWEIGHTRATINGFROM`,
   `GROSSVEHICLEWEIGHTRATINGTOID`, `GROSSVEHICLEWEIGHTRATINGTO`,
   `CURBWEIGHTLB`, `WHEELBASEIN_FROM`, `WHEELBASEIN_TO`, `WHEELSCOUNT`,
   `WHEELSIZEFRONTIN`, `WHEELSIZEREARIN`, `TRUCKBODYCABTYPEID`,
   `TRUCKBODYCABTYPE`, `TRUCKBEDTYPEID`, `TRUCKBEDTYPE`, `TRUCKBEDLENGTHIN`,
   `BUSTYPEID`, `BUSTYPE`, `BUSFLOORCONFIGURATIONTYPEID`,
   `BUSFLOORCONFIGURATIONTYPE`, `BUSLENGTHFT`, `OTHERBUSINFO`,
   `CUSTOMMOTORCYCLETYPEID`, `CUSTOMMOTORCYCLETYPE`,
   `MOTORCYCLESUSPENSIONTYPEID`, `MOTORCYCLESUSPENSIONTYPE`,
   `MOTORCYCLECHASSISTYPEID`, `MOTORCYCLECHASSISTYPE`, `OTHERMOTORCYCLEINFO`,
   `STEERINGLOCATIONID`, `STEERINGLOCATION`, `ENTERTAINMENTSYSTEMID`,
   `ENTERTAINMENTSYSTEM`, `SEATSCOUNT`, `SEATROWSCOUNT`,
   `TRANSMISSIONSPEEDS`, `TRANSMISSIONSTYLEID`, `TRANSMISSIONSTYLE`,
   `DRIVETYPEID`, `DRIVETYPE`, `AXLESCOUNT`, `AXLECONFIGURATIONID`,
   `AXLECONFIGURATION`, `BRAKESYSTEMTYPEID`, `BRAKESYSTEMTYPE`,
   `BRAKESYSTEMDESC`, `EVDRIVEUNITID`, `EVDRIVEUNIT`, `BATTERYKWH_FROM`,
   `BATTERYKWH_TO`, `BATTERYV_FROM`, `BATTERYV_TO`, `BATTERYA_FROM`,
   `BATTERYPACKSPERVEHICLE`, `BATTERYMODULESPERPACK`,
   `BATTERYCELLSPERMODULE`, `BATTERYTYPEID`, `BATTERYTYPE`,
   `OTHERBATTERYINFO`, `CHARGERLEVELID`, `CHARGERLEVEL`, `CHARGERPOWERKW`,
   `ENGINEMANUFACTURER`, `ENGINEMODEL`, `ENGINECONFIGURATIONID`,
   `ENGINECONFIGURATION`, `ENGINEPOWERKW`, `ENGINESTROKECYCLES`,
   `ENGINECYLINDERSCOUNT`, `ENGINEBRAKEHP_FROM`, `ENGINEBRAKEHP_TO`,
   `ENGINECOOLINGTYPEID`, `ENGINECOOLINGTYPE`, `DISPLACEMENTCI`,
   `DISPLACEMENTCC`, `DISPLACEMENTL`, `FUELTYPEPRIMARYID`, `FUELTYPEPRIMARY`,
   `FUELTYPESECONDARYID`, `FUELTYPESECONDARY`, `FUELDELIVERYINJECTIONTYPEID`,
   `FUELDELIVERYINJECTIONTYPE`, `ENGINEVALVETRAINDESIGNID`,
   `ENGINEVALVETRAINDESIGN`, `ENGINEELECTRIFICATIONLEVELID`,
   `ENGINEELECTRIFICATIONLEVEL`, `ENGINETURBOID`, `ENGINETURBO`,
   `TOPSPEEDMPH`, `OTHERENGINEINFO`, `SEATBELTTYPEID`, `SEATBELTTYPE`,
   `PRETENSIONERID`, `PRETENSIONER`, `AIRBAGLOCFRONTID`, `AIRBAGLOCFRONT`,
   `AIRBAGLOCKNEEID`, `AIRBAGLOCKNEE`, `AIRBAGLOCSIDEID`, `AIRBAGLOCSIDE`,
   `AIRBAGLOCCURTAINID`, `AIRBAGLOCCURTAIN`, `AIRBAGLOCSEATCUSHIONID`,
   `AIRBAGLOCSEATCUSHION`, `OTHERRESTRAINTSYSTEMINFO`,
   `FORWARDCOLLISIONWARNINGID`, `FORWARDCOLLISIONWARNING`,
   `DYNAMICBRAKESUPPORTID`, `DYNAMICBRAKESUPPORT`, `CRASHIMMINENTBRAKINGID`,
   `CRASHIMMINENTBRAKING`, `PEDESTRIANAUTOEMERGENCYBRAKINGID`,
   `PEDESTRIANAUTOEMERGENCYBRAKING`, `BLINDSPOTWARNINGID`,
   `BLINDSPOTWARNING`, `BLINDSPOTINTERVENTIONID`, `BLINDSPOTINTERVENTION`,
   `LANEDEPARTUREWARNINGID`, `LANEDEPARTUREWARNING`,
   `LANEKEEPINGASSISTANCEID`, `LANEKEEPINGASSISTANCE`,
   `LANECENTERINGASSISTANCEID`, `LANECENTERINGASSISTANCE`, `BACKUPCAMERAID`,
   `BACKUPCAMERA`, `REARCROSSTRAFFICALERTID`, `REARCROSSTRAFFICALERT`,
   `REARAUTOMATICEMERGENCYBRAKINGID`, `REARAUTOMATICEMERGENCYBRAKING`,
   `PARKASSISTID`, `PARKASSIST`, `DAYTIMERUNNINGLIGHTID`,
   `DAYTIMERUNNINGLIGHT`, `HEADLAMPLIGHTSOURCEID`, `HEADLAMPLIGHTSOURCE`,
   `SEMIAUTOHEADLAMPBEAMSWITCHINGID`, `SEMIAUTOHEADLAMPBEAMSWITCHING`,
   `ADAPTIVEDRIVINGBEAMID`, `ADAPTIVEDRIVINGBEAM`, `ADAPTIVECRUISECONTROLID`,
   `ADAPTIVECRUISECONTROL`, `ANTILOCKBRAKESYSTEMID`, `ANTILOCKBRAKESYSTEM`,
   `ELECTRONICSTABILITYCONTROLID`, `ELECTRONICSTABILITYCONTROL`, `TPMSID`,
   `TPMS`, `AUTOMATICCRASHNOTIFICATIONID`, `AUTOMATICCRASHNOTIFICATION`,
   `EVENTDATARECORDERID`, `EVENTDATARECORDER`, `TRACTIONCONTROLID`,
   `TRACTIONCONTROL`, `AUTOPEDESTRIANALERTINGSOUNDID`,
   `AUTOPEDESTRIANALERTINGSOUND`, `KEYLESSIGNITIONID`, `KEYLESSIGNITION`,
   `SAEAUTOMATIONLEVEL_FROM`, `AUTOREVERSESYSTEMID`, `AUTOREVERSESYSTEM`,
   `ACTIVESAFETYSYSNOTE`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vpicdecode', 'data/processed/vpicdecode.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vpictrailerdecode.csv'
  INTO TABLE fars_stage.`vpictrailerdecode`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `TRAILER_NO`, `VEHICLEDESCRIPTOR`,
   `VINDECODEDON`, `VINDECODEERROR`, `VEHICLETYPEID`, `VEHICLETYPE`,
   `MANUFACTURERFULLNAMEID`, `MANUFACTURERFULLNAME`, `MAKEID`, `MAKE`,
   `MODELID`, `MODEL`, `MODELYEAR`, `SERIES`, `TRIM`, `PLANTCOUNTRYID`,
   `PLANTCOUNTRY`, `PLANTSTATE`, `PLANTCITY`, `PLANTCOMPANYNAME`, `NOTE`,
   `BODYCLASSID`, `BODYCLASS`, `GROSSVEHICLEWEIGHTRATINGFROMID`,
   `GROSSVEHICLEWEIGHTRATINGFROM`, `GROSSVEHICLEWEIGHTRATINGTOID`,
   `GROSSVEHICLEWEIGHTRATINGTO`, `TRAILERBODYTYPEID`, `TRAILERBODYTYPE`,
   `TRAILERTYPECONNECTIONID`, `TRAILERTYPECONNECTION`, `TRAILERLENGTHFT`,
   `OTHERTRAILERINFO`, `AXLESCOUNT`, `AXLECONFIGURATIONID`,
   `AXLECONFIGURATION`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vpictrailerdecode', 'data/processed/vpictrailerdecode.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/vsoe.csv'
  INTO TABLE fars_stage.`vsoe`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `VEH_NO`, `VEVENTNUM`, `SOE`, `AOI`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('vsoe', 'data/processed/vsoe.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/weather.csv'
  INTO TABLE fars_stage.`weather`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `ST_CASE`, `WEATHER`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('weather', 'data/processed/weather.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/lookups/code_labels.csv'
  INTO TABLE fars_stage.`code_labels`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`column`, `code`, `label`, `source_files`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('code_labels', 'data/processed/lookups/code_labels.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/lookups/county.csv'
  INTO TABLE fars_stage.`county`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `COUNTY`, `COUNTYNAME`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('county', 'data/processed/lookups/county.csv', @rows_reported, @conditions);

LOAD DATA LOCAL INFILE 'data/processed/lookups/city.csv'
  INTO TABLE fars_stage.`city`
  CHARACTER SET utf8mb4
  FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"' ESCAPED BY ''
  LINES TERMINATED BY '\n'
  IGNORE 1 LINES
  (`STATE`, `CITY`, `CITYNAME`);
GET DIAGNOSTICS @rows_reported = ROW_COUNT, @conditions = NUMBER;
INSERT INTO fars_stage.load_log (staging_table, source_file, rows_reported, conditions)
  VALUES ('city', 'data/processed/lookups/city.csv', @rows_reported, @conditions);

-- ------------------------------------------------------------------------
-- Check: every CSV loaded completely and without warnings
-- ------------------------------------------------------------------------

CREATE TABLE fars_stage.staging_counts (
  staging_table VARCHAR(64) NOT NULL PRIMARY KEY,
  actual_rows   BIGINT      NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO fars_stage.staging_counts (staging_table, actual_rows)
SELECT 'acc_aux', COUNT(*) FROM fars_stage.`acc_aux`
UNION ALL SELECT 'accident', COUNT(*) FROM fars_stage.`accident`
UNION ALL SELECT 'cevent', COUNT(*) FROM fars_stage.`cevent`
UNION ALL SELECT 'crashrf', COUNT(*) FROM fars_stage.`crashrf`
UNION ALL SELECT 'damage', COUNT(*) FROM fars_stage.`damage`
UNION ALL SELECT 'distract', COUNT(*) FROM fars_stage.`distract`
UNION ALL SELECT 'drimpair', COUNT(*) FROM fars_stage.`drimpair`
UNION ALL SELECT 'driverrf', COUNT(*) FROM fars_stage.`driverrf`
UNION ALL SELECT 'drugs', COUNT(*) FROM fars_stage.`drugs`
UNION ALL SELECT 'factor', COUNT(*) FROM fars_stage.`factor`
UNION ALL SELECT 'maneuver', COUNT(*) FROM fars_stage.`maneuver`
UNION ALL SELECT 'miacc', COUNT(*) FROM fars_stage.`miacc`
UNION ALL SELECT 'midrvacc', COUNT(*) FROM fars_stage.`midrvacc`
UNION ALL SELECT 'miper', COUNT(*) FROM fars_stage.`miper`
UNION ALL SELECT 'nmcrash', COUNT(*) FROM fars_stage.`nmcrash`
UNION ALL SELECT 'nmdistract', COUNT(*) FROM fars_stage.`nmdistract`
UNION ALL SELECT 'nmimpair', COUNT(*) FROM fars_stage.`nmimpair`
UNION ALL SELECT 'nmprior', COUNT(*) FROM fars_stage.`nmprior`
UNION ALL SELECT 'parkwork', COUNT(*) FROM fars_stage.`parkwork`
UNION ALL SELECT 'pbtype', COUNT(*) FROM fars_stage.`pbtype`
UNION ALL SELECT 'per_aux', COUNT(*) FROM fars_stage.`per_aux`
UNION ALL SELECT 'person', COUNT(*) FROM fars_stage.`person`
UNION ALL SELECT 'personrf', COUNT(*) FROM fars_stage.`personrf`
UNION ALL SELECT 'pvehiclesf', COUNT(*) FROM fars_stage.`pvehiclesf`
UNION ALL SELECT 'race', COUNT(*) FROM fars_stage.`race`
UNION ALL SELECT 'safetyeq', COUNT(*) FROM fars_stage.`safetyeq`
UNION ALL SELECT 'veh_aux', COUNT(*) FROM fars_stage.`veh_aux`
UNION ALL SELECT 'vehicle', COUNT(*) FROM fars_stage.`vehicle`
UNION ALL SELECT 'vehiclesf', COUNT(*) FROM fars_stage.`vehiclesf`
UNION ALL SELECT 'vevent', COUNT(*) FROM fars_stage.`vevent`
UNION ALL SELECT 'violatn', COUNT(*) FROM fars_stage.`violatn`
UNION ALL SELECT 'vision', COUNT(*) FROM fars_stage.`vision`
UNION ALL SELECT 'vpicdecode', COUNT(*) FROM fars_stage.`vpicdecode`
UNION ALL SELECT 'vpictrailerdecode', COUNT(*) FROM fars_stage.`vpictrailerdecode`
UNION ALL SELECT 'vsoe', COUNT(*) FROM fars_stage.`vsoe`
UNION ALL SELECT 'weather', COUNT(*) FROM fars_stage.`weather`
UNION ALL SELECT 'code_labels', COUNT(*) FROM fars_stage.`code_labels`
UNION ALL SELECT 'county', COUNT(*) FROM fars_stage.`county`
UNION ALL SELECT 'city', COUNT(*) FROM fars_stage.`city`;

SELECT e.object_name AS staging_table, e.expected_rows, c.actual_rows,
       l.conditions AS load_warnings,
       IF(e.expected_rows <=> c.actual_rows AND l.conditions <=> 0, 'PASS', 'FAIL') AS status
FROM fars_stage.expected_rows AS e
LEFT JOIN fars_stage.staging_counts AS c ON c.staging_table = e.object_name
LEFT JOIN fars_stage.load_log AS l ON l.staging_table = e.object_name
WHERE e.object_type = 'staging'
ORDER BY e.object_name;

CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM fars_stage.expected_rows AS e
    LEFT JOIN fars_stage.staging_counts AS c ON c.staging_table = e.object_name
    LEFT JOIN fars_stage.load_log AS l ON l.staging_table = e.object_name
    WHERE e.object_type = 'staging'
      AND NOT (e.expected_rows <=> c.actual_rows AND l.conditions <=> 0)) = 0,
  'Staging row counts or LOAD DATA warnings differ from expected; see the FAIL rows above');
