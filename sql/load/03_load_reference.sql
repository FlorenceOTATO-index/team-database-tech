-- 03_load_reference.sql
-- Phase 2: reference and lookup tables (no foreign-key parents).
-- Loads the 14 tables every later step depends on: the derived lookups
-- (calendar, death_time, vin_detail, pvin_detail, vpic_labels, state_region,
-- roadfc_inter, junc_intsec, age_band_map, ped_crash_group, bike_crash_group)
-- and the ETL lookups (code_labels, county, city).
-- Conversion rule for every load script: only an empty string becomes NULL
-- (NULLIF(x, '')); FARS codes such as 8, 9, 98, 99, 998, 999, 88.8888,
-- -99.000 and 999999999999 are stored as given. Text values go into the typed
-- fars columns under STRICT_ALL_TABLES, so a value that does not fit its
-- column stops the load with an error instead of being coerced.
--
-- Run from the repository root (see 01_load_staging_tables.sql for the full sequence):
--   mysql -u root -p < sql/load/03_load_reference.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

START TRANSACTION;

CALL fars_stage.assert_true(@@SESSION.foreign_key_checks = 1, 'foreign_key_checks must stay ON');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM fars_stage.load_log) = 39, 'Run 02_load_staging_data.sql first: staging is incomplete');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`calendar`) = 0, 'fars.calendar must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`death_time`) = 0, 'fars.death_time must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`vin_detail`) = 0, 'fars.vin_detail must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`pvin_detail`) = 0, 'fars.pvin_detail must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`vpic_labels`) = 0, 'fars.vpic_labels must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`state_region`) = 0, 'fars.state_region must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`roadfc_inter`) = 0, 'fars.roadfc_inter must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`junc_intsec`) = 0, 'fars.junc_intsec must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`age_band_map`) = 0, 'fars.age_band_map must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`ped_crash_group`) = 0, 'fars.ped_crash_group must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`bike_crash_group`) = 0, 'fars.bike_crash_group must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`code_labels`) = 0, 'fars.code_labels must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`county`) = 0, 'fars.county must be empty before loading');
CALL fars_stage.assert_true((SELECT COUNT(*) FROM `fars`.`city`) = 0, 'fars.city must be empty before loading');

-- calendar: 366 rows expected.
-- Derived: distinct (YEAR, MONTH, DAY, DAY_WEEK) from
-- data/processed/accident.csv; one row per date; (YEAR, MONTH, DAY) ->
-- DAY_WEEK. The primary key rejects any key that maps to two different
-- values.
INSERT INTO `fars`.`calendar` (
  `YEAR`, `MONTH`, `DAY`, `DAY_WEEK`
)
SELECT DISTINCT
  NULLIF(s.`YEAR`, '') AS `YEAR`,
  NULLIF(s.`MONTH`, '') AS `MONTH`,
  NULLIF(s.`DAY`, '') AS `DAY`,
  NULLIF(s.`DAY_WEEK`, '') AS `DAY_WEEK`
FROM `fars_stage`.`accident` AS s;

-- death_time: 1,457 rows expected.
-- Derived: distinct (DEATH_HR, DEATH_MN, DEATH_TM) from
-- data/processed/person.csv; (DEATH_HR, DEATH_MN) -> DEATH_TM, including the
-- 88/88 and 99/99 code pairs. The primary key rejects any key that maps to
-- two different values.
INSERT INTO `fars`.`death_time` (
  `DEATH_HR`, `DEATH_MN`, `DEATH_TM`
)
SELECT DISTINCT
  NULLIF(s.`DEATH_HR`, '') AS `DEATH_HR`,
  NULLIF(s.`DEATH_MN`, '') AS `DEATH_MN`,
  NULLIF(s.`DEATH_TM`, '') AS `DEATH_TM`
FROM `fars_stage`.`person` AS s;

-- vin_detail: 49,396 rows expected.
-- Derived: distinct (VIN, VIN_1, VIN_2, VIN_3, VIN_4, VIN_5, VIN_6, VIN_7,
-- VIN_8, VIN_9, VIN_10, VIN_11, VIN_12) from data/processed/vehicle.csv; VIN
-- -> VIN_1..VIN_12; placeholder VINs such as 999999999999 are ordinary keys.
-- The primary key rejects any key that maps to two different values.
INSERT INTO `fars`.`vin_detail` (
  `VIN`, `VIN_1`, `VIN_2`, `VIN_3`, `VIN_4`, `VIN_5`, `VIN_6`, `VIN_7`,
  `VIN_8`, `VIN_9`, `VIN_10`, `VIN_11`, `VIN_12`
)
SELECT DISTINCT
  NULLIF(s.`VIN`, '') AS `VIN`,
  NULLIF(s.`VIN_1`, '') AS `VIN_1`,
  NULLIF(s.`VIN_2`, '') AS `VIN_2`,
  NULLIF(s.`VIN_3`, '') AS `VIN_3`,
  NULLIF(s.`VIN_4`, '') AS `VIN_4`,
  NULLIF(s.`VIN_5`, '') AS `VIN_5`,
  NULLIF(s.`VIN_6`, '') AS `VIN_6`,
  NULLIF(s.`VIN_7`, '') AS `VIN_7`,
  NULLIF(s.`VIN_8`, '') AS `VIN_8`,
  NULLIF(s.`VIN_9`, '') AS `VIN_9`,
  NULLIF(s.`VIN_10`, '') AS `VIN_10`,
  NULLIF(s.`VIN_11`, '') AS `VIN_11`,
  NULLIF(s.`VIN_12`, '') AS `VIN_12`
FROM `fars_stage`.`vehicle` AS s;

-- pvin_detail: 1,465 rows expected.
-- Derived: distinct (PVIN, PVIN_1, PVIN_2, PVIN_3, PVIN_4, PVIN_5, PVIN_6,
-- PVIN_7, PVIN_8, PVIN_9, PVIN_10, PVIN_11, PVIN_12) from
-- data/processed/parkwork.csv; PVIN -> PVIN_1..PVIN_12. The primary key
-- rejects any key that maps to two different values.
INSERT INTO `fars`.`pvin_detail` (
  `PVIN`, `PVIN_1`, `PVIN_2`, `PVIN_3`, `PVIN_4`, `PVIN_5`, `PVIN_6`,
  `PVIN_7`, `PVIN_8`, `PVIN_9`, `PVIN_10`, `PVIN_11`, `PVIN_12`
)
SELECT DISTINCT
  NULLIF(s.`PVIN`, '') AS `PVIN`,
  NULLIF(s.`PVIN_1`, '') AS `PVIN_1`,
  NULLIF(s.`PVIN_2`, '') AS `PVIN_2`,
  NULLIF(s.`PVIN_3`, '') AS `PVIN_3`,
  NULLIF(s.`PVIN_4`, '') AS `PVIN_4`,
  NULLIF(s.`PVIN_5`, '') AS `PVIN_5`,
  NULLIF(s.`PVIN_6`, '') AS `PVIN_6`,
  NULLIF(s.`PVIN_7`, '') AS `PVIN_7`,
  NULLIF(s.`PVIN_8`, '') AS `PVIN_8`,
  NULLIF(s.`PVIN_9`, '') AS `PVIN_9`,
  NULLIF(s.`PVIN_10`, '') AS `PVIN_10`,
  NULLIF(s.`PVIN_11`, '') AS `PVIN_11`,
  NULLIF(s.`PVIN_12`, '') AS `PVIN_12`
FROM `fars_stage`.`parkwork` AS s;

-- vpic_labels: 3,170 rows expected.
-- Derived from the 68 *ID / label column pairs in vpicdecode.csv (MAKEID /
-- MAKE, ...). attribute is the label column name (MAKE, not MAKEID). Rows
-- with a blank ID are skipped; label text is kept exactly. Each branch is
-- distinct within its attribute, and the primary key rejects an ID that
-- carries two different labels.
INSERT INTO `fars`.`vpic_labels` (`attribute`, `id`, `label`)
SELECT DISTINCT 'VEHICLETYPE' AS `attribute`, NULLIF(s.`VEHICLETYPEID`, '') AS `id`, NULLIF(s.`VEHICLETYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`VEHICLETYPEID` <> ''
UNION ALL
SELECT DISTINCT 'MANUFACTURERFULLNAME' AS `attribute`, NULLIF(s.`MANUFACTURERFULLNAMEID`, '') AS `id`, NULLIF(s.`MANUFACTURERFULLNAME`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`MANUFACTURERFULLNAMEID` <> ''
UNION ALL
SELECT DISTINCT 'MAKE' AS `attribute`, NULLIF(s.`MAKEID`, '') AS `id`, NULLIF(s.`MAKE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`MAKEID` <> ''
UNION ALL
SELECT DISTINCT 'MODEL' AS `attribute`, NULLIF(s.`MODELID`, '') AS `id`, NULLIF(s.`MODEL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`MODELID` <> ''
UNION ALL
SELECT DISTINCT 'PLANTCOUNTRY' AS `attribute`, NULLIF(s.`PLANTCOUNTRYID`, '') AS `id`, NULLIF(s.`PLANTCOUNTRY`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`PLANTCOUNTRYID` <> ''
UNION ALL
SELECT DISTINCT 'DESTINATIONMARKET' AS `attribute`, NULLIF(s.`DESTINATIONMARKETID`, '') AS `id`, NULLIF(s.`DESTINATIONMARKET`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`DESTINATIONMARKETID` <> ''
UNION ALL
SELECT DISTINCT 'BODYCLASS' AS `attribute`, NULLIF(s.`BODYCLASSID`, '') AS `id`, NULLIF(s.`BODYCLASS`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BODYCLASSID` <> ''
UNION ALL
SELECT DISTINCT 'WHEELBASETYPE' AS `attribute`, NULLIF(s.`WHEELBASETYPEID`, '') AS `id`, NULLIF(s.`WHEELBASETYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`WHEELBASETYPEID` <> ''
UNION ALL
SELECT DISTINCT 'GROSSVEHICLEWEIGHTRATINGFROM' AS `attribute`, NULLIF(s.`GROSSVEHICLEWEIGHTRATINGFROMID`, '') AS `id`, NULLIF(s.`GROSSVEHICLEWEIGHTRATINGFROM`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`GROSSVEHICLEWEIGHTRATINGFROMID` <> ''
UNION ALL
SELECT DISTINCT 'GROSSVEHICLEWEIGHTRATINGTO' AS `attribute`, NULLIF(s.`GROSSVEHICLEWEIGHTRATINGTOID`, '') AS `id`, NULLIF(s.`GROSSVEHICLEWEIGHTRATINGTO`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`GROSSVEHICLEWEIGHTRATINGTOID` <> ''
UNION ALL
SELECT DISTINCT 'TRUCKBODYCABTYPE' AS `attribute`, NULLIF(s.`TRUCKBODYCABTYPEID`, '') AS `id`, NULLIF(s.`TRUCKBODYCABTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`TRUCKBODYCABTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'TRUCKBEDTYPE' AS `attribute`, NULLIF(s.`TRUCKBEDTYPEID`, '') AS `id`, NULLIF(s.`TRUCKBEDTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`TRUCKBEDTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'BUSTYPE' AS `attribute`, NULLIF(s.`BUSTYPEID`, '') AS `id`, NULLIF(s.`BUSTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BUSTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'BUSFLOORCONFIGURATIONTYPE' AS `attribute`, NULLIF(s.`BUSFLOORCONFIGURATIONTYPEID`, '') AS `id`, NULLIF(s.`BUSFLOORCONFIGURATIONTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BUSFLOORCONFIGURATIONTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'CUSTOMMOTORCYCLETYPE' AS `attribute`, NULLIF(s.`CUSTOMMOTORCYCLETYPEID`, '') AS `id`, NULLIF(s.`CUSTOMMOTORCYCLETYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`CUSTOMMOTORCYCLETYPEID` <> ''
UNION ALL
SELECT DISTINCT 'MOTORCYCLESUSPENSIONTYPE' AS `attribute`, NULLIF(s.`MOTORCYCLESUSPENSIONTYPEID`, '') AS `id`, NULLIF(s.`MOTORCYCLESUSPENSIONTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`MOTORCYCLESUSPENSIONTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'MOTORCYCLECHASSISTYPE' AS `attribute`, NULLIF(s.`MOTORCYCLECHASSISTYPEID`, '') AS `id`, NULLIF(s.`MOTORCYCLECHASSISTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`MOTORCYCLECHASSISTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'STEERINGLOCATION' AS `attribute`, NULLIF(s.`STEERINGLOCATIONID`, '') AS `id`, NULLIF(s.`STEERINGLOCATION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`STEERINGLOCATIONID` <> ''
UNION ALL
SELECT DISTINCT 'ENTERTAINMENTSYSTEM' AS `attribute`, NULLIF(s.`ENTERTAINMENTSYSTEMID`, '') AS `id`, NULLIF(s.`ENTERTAINMENTSYSTEM`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENTERTAINMENTSYSTEMID` <> ''
UNION ALL
SELECT DISTINCT 'TRANSMISSIONSTYLE' AS `attribute`, NULLIF(s.`TRANSMISSIONSTYLEID`, '') AS `id`, NULLIF(s.`TRANSMISSIONSTYLE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`TRANSMISSIONSTYLEID` <> ''
UNION ALL
SELECT DISTINCT 'DRIVETYPE' AS `attribute`, NULLIF(s.`DRIVETYPEID`, '') AS `id`, NULLIF(s.`DRIVETYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`DRIVETYPEID` <> ''
UNION ALL
SELECT DISTINCT 'AXLECONFIGURATION' AS `attribute`, NULLIF(s.`AXLECONFIGURATIONID`, '') AS `id`, NULLIF(s.`AXLECONFIGURATION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AXLECONFIGURATIONID` <> ''
UNION ALL
SELECT DISTINCT 'BRAKESYSTEMTYPE' AS `attribute`, NULLIF(s.`BRAKESYSTEMTYPEID`, '') AS `id`, NULLIF(s.`BRAKESYSTEMTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BRAKESYSTEMTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'EVDRIVEUNIT' AS `attribute`, NULLIF(s.`EVDRIVEUNITID`, '') AS `id`, NULLIF(s.`EVDRIVEUNIT`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`EVDRIVEUNITID` <> ''
UNION ALL
SELECT DISTINCT 'BATTERYTYPE' AS `attribute`, NULLIF(s.`BATTERYTYPEID`, '') AS `id`, NULLIF(s.`BATTERYTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BATTERYTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'CHARGERLEVEL' AS `attribute`, NULLIF(s.`CHARGERLEVELID`, '') AS `id`, NULLIF(s.`CHARGERLEVEL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`CHARGERLEVELID` <> ''
UNION ALL
SELECT DISTINCT 'ENGINECONFIGURATION' AS `attribute`, NULLIF(s.`ENGINECONFIGURATIONID`, '') AS `id`, NULLIF(s.`ENGINECONFIGURATION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENGINECONFIGURATIONID` <> ''
UNION ALL
SELECT DISTINCT 'ENGINECOOLINGTYPE' AS `attribute`, NULLIF(s.`ENGINECOOLINGTYPEID`, '') AS `id`, NULLIF(s.`ENGINECOOLINGTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENGINECOOLINGTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'FUELTYPEPRIMARY' AS `attribute`, NULLIF(s.`FUELTYPEPRIMARYID`, '') AS `id`, NULLIF(s.`FUELTYPEPRIMARY`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`FUELTYPEPRIMARYID` <> ''
UNION ALL
SELECT DISTINCT 'FUELTYPESECONDARY' AS `attribute`, NULLIF(s.`FUELTYPESECONDARYID`, '') AS `id`, NULLIF(s.`FUELTYPESECONDARY`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`FUELTYPESECONDARYID` <> ''
UNION ALL
SELECT DISTINCT 'FUELDELIVERYINJECTIONTYPE' AS `attribute`, NULLIF(s.`FUELDELIVERYINJECTIONTYPEID`, '') AS `id`, NULLIF(s.`FUELDELIVERYINJECTIONTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`FUELDELIVERYINJECTIONTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'ENGINEVALVETRAINDESIGN' AS `attribute`, NULLIF(s.`ENGINEVALVETRAINDESIGNID`, '') AS `id`, NULLIF(s.`ENGINEVALVETRAINDESIGN`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENGINEVALVETRAINDESIGNID` <> ''
UNION ALL
SELECT DISTINCT 'ENGINEELECTRIFICATIONLEVEL' AS `attribute`, NULLIF(s.`ENGINEELECTRIFICATIONLEVELID`, '') AS `id`, NULLIF(s.`ENGINEELECTRIFICATIONLEVEL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENGINEELECTRIFICATIONLEVELID` <> ''
UNION ALL
SELECT DISTINCT 'ENGINETURBO' AS `attribute`, NULLIF(s.`ENGINETURBOID`, '') AS `id`, NULLIF(s.`ENGINETURBO`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ENGINETURBOID` <> ''
UNION ALL
SELECT DISTINCT 'SEATBELTTYPE' AS `attribute`, NULLIF(s.`SEATBELTTYPEID`, '') AS `id`, NULLIF(s.`SEATBELTTYPE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`SEATBELTTYPEID` <> ''
UNION ALL
SELECT DISTINCT 'PRETENSIONER' AS `attribute`, NULLIF(s.`PRETENSIONERID`, '') AS `id`, NULLIF(s.`PRETENSIONER`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`PRETENSIONERID` <> ''
UNION ALL
SELECT DISTINCT 'AIRBAGLOCFRONT' AS `attribute`, NULLIF(s.`AIRBAGLOCFRONTID`, '') AS `id`, NULLIF(s.`AIRBAGLOCFRONT`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AIRBAGLOCFRONTID` <> ''
UNION ALL
SELECT DISTINCT 'AIRBAGLOCKNEE' AS `attribute`, NULLIF(s.`AIRBAGLOCKNEEID`, '') AS `id`, NULLIF(s.`AIRBAGLOCKNEE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AIRBAGLOCKNEEID` <> ''
UNION ALL
SELECT DISTINCT 'AIRBAGLOCSIDE' AS `attribute`, NULLIF(s.`AIRBAGLOCSIDEID`, '') AS `id`, NULLIF(s.`AIRBAGLOCSIDE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AIRBAGLOCSIDEID` <> ''
UNION ALL
SELECT DISTINCT 'AIRBAGLOCCURTAIN' AS `attribute`, NULLIF(s.`AIRBAGLOCCURTAINID`, '') AS `id`, NULLIF(s.`AIRBAGLOCCURTAIN`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AIRBAGLOCCURTAINID` <> ''
UNION ALL
SELECT DISTINCT 'AIRBAGLOCSEATCUSHION' AS `attribute`, NULLIF(s.`AIRBAGLOCSEATCUSHIONID`, '') AS `id`, NULLIF(s.`AIRBAGLOCSEATCUSHION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AIRBAGLOCSEATCUSHIONID` <> ''
UNION ALL
SELECT DISTINCT 'FORWARDCOLLISIONWARNING' AS `attribute`, NULLIF(s.`FORWARDCOLLISIONWARNINGID`, '') AS `id`, NULLIF(s.`FORWARDCOLLISIONWARNING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`FORWARDCOLLISIONWARNINGID` <> ''
UNION ALL
SELECT DISTINCT 'DYNAMICBRAKESUPPORT' AS `attribute`, NULLIF(s.`DYNAMICBRAKESUPPORTID`, '') AS `id`, NULLIF(s.`DYNAMICBRAKESUPPORT`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`DYNAMICBRAKESUPPORTID` <> ''
UNION ALL
SELECT DISTINCT 'CRASHIMMINENTBRAKING' AS `attribute`, NULLIF(s.`CRASHIMMINENTBRAKINGID`, '') AS `id`, NULLIF(s.`CRASHIMMINENTBRAKING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`CRASHIMMINENTBRAKINGID` <> ''
UNION ALL
SELECT DISTINCT 'PEDESTRIANAUTOEMERGENCYBRAKING' AS `attribute`, NULLIF(s.`PEDESTRIANAUTOEMERGENCYBRAKINGID`, '') AS `id`, NULLIF(s.`PEDESTRIANAUTOEMERGENCYBRAKING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`PEDESTRIANAUTOEMERGENCYBRAKINGID` <> ''
UNION ALL
SELECT DISTINCT 'BLINDSPOTWARNING' AS `attribute`, NULLIF(s.`BLINDSPOTWARNINGID`, '') AS `id`, NULLIF(s.`BLINDSPOTWARNING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BLINDSPOTWARNINGID` <> ''
UNION ALL
SELECT DISTINCT 'BLINDSPOTINTERVENTION' AS `attribute`, NULLIF(s.`BLINDSPOTINTERVENTIONID`, '') AS `id`, NULLIF(s.`BLINDSPOTINTERVENTION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BLINDSPOTINTERVENTIONID` <> ''
UNION ALL
SELECT DISTINCT 'LANEDEPARTUREWARNING' AS `attribute`, NULLIF(s.`LANEDEPARTUREWARNINGID`, '') AS `id`, NULLIF(s.`LANEDEPARTUREWARNING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`LANEDEPARTUREWARNINGID` <> ''
UNION ALL
SELECT DISTINCT 'LANEKEEPINGASSISTANCE' AS `attribute`, NULLIF(s.`LANEKEEPINGASSISTANCEID`, '') AS `id`, NULLIF(s.`LANEKEEPINGASSISTANCE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`LANEKEEPINGASSISTANCEID` <> ''
UNION ALL
SELECT DISTINCT 'LANECENTERINGASSISTANCE' AS `attribute`, NULLIF(s.`LANECENTERINGASSISTANCEID`, '') AS `id`, NULLIF(s.`LANECENTERINGASSISTANCE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`LANECENTERINGASSISTANCEID` <> ''
UNION ALL
SELECT DISTINCT 'BACKUPCAMERA' AS `attribute`, NULLIF(s.`BACKUPCAMERAID`, '') AS `id`, NULLIF(s.`BACKUPCAMERA`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`BACKUPCAMERAID` <> ''
UNION ALL
SELECT DISTINCT 'REARCROSSTRAFFICALERT' AS `attribute`, NULLIF(s.`REARCROSSTRAFFICALERTID`, '') AS `id`, NULLIF(s.`REARCROSSTRAFFICALERT`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`REARCROSSTRAFFICALERTID` <> ''
UNION ALL
SELECT DISTINCT 'REARAUTOMATICEMERGENCYBRAKING' AS `attribute`, NULLIF(s.`REARAUTOMATICEMERGENCYBRAKINGID`, '') AS `id`, NULLIF(s.`REARAUTOMATICEMERGENCYBRAKING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`REARAUTOMATICEMERGENCYBRAKINGID` <> ''
UNION ALL
SELECT DISTINCT 'PARKASSIST' AS `attribute`, NULLIF(s.`PARKASSISTID`, '') AS `id`, NULLIF(s.`PARKASSIST`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`PARKASSISTID` <> ''
UNION ALL
SELECT DISTINCT 'DAYTIMERUNNINGLIGHT' AS `attribute`, NULLIF(s.`DAYTIMERUNNINGLIGHTID`, '') AS `id`, NULLIF(s.`DAYTIMERUNNINGLIGHT`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`DAYTIMERUNNINGLIGHTID` <> ''
UNION ALL
SELECT DISTINCT 'HEADLAMPLIGHTSOURCE' AS `attribute`, NULLIF(s.`HEADLAMPLIGHTSOURCEID`, '') AS `id`, NULLIF(s.`HEADLAMPLIGHTSOURCE`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`HEADLAMPLIGHTSOURCEID` <> ''
UNION ALL
SELECT DISTINCT 'SEMIAUTOHEADLAMPBEAMSWITCHING' AS `attribute`, NULLIF(s.`SEMIAUTOHEADLAMPBEAMSWITCHINGID`, '') AS `id`, NULLIF(s.`SEMIAUTOHEADLAMPBEAMSWITCHING`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`SEMIAUTOHEADLAMPBEAMSWITCHINGID` <> ''
UNION ALL
SELECT DISTINCT 'ADAPTIVEDRIVINGBEAM' AS `attribute`, NULLIF(s.`ADAPTIVEDRIVINGBEAMID`, '') AS `id`, NULLIF(s.`ADAPTIVEDRIVINGBEAM`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ADAPTIVEDRIVINGBEAMID` <> ''
UNION ALL
SELECT DISTINCT 'ADAPTIVECRUISECONTROL' AS `attribute`, NULLIF(s.`ADAPTIVECRUISECONTROLID`, '') AS `id`, NULLIF(s.`ADAPTIVECRUISECONTROL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ADAPTIVECRUISECONTROLID` <> ''
UNION ALL
SELECT DISTINCT 'ANTILOCKBRAKESYSTEM' AS `attribute`, NULLIF(s.`ANTILOCKBRAKESYSTEMID`, '') AS `id`, NULLIF(s.`ANTILOCKBRAKESYSTEM`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ANTILOCKBRAKESYSTEMID` <> ''
UNION ALL
SELECT DISTINCT 'ELECTRONICSTABILITYCONTROL' AS `attribute`, NULLIF(s.`ELECTRONICSTABILITYCONTROLID`, '') AS `id`, NULLIF(s.`ELECTRONICSTABILITYCONTROL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`ELECTRONICSTABILITYCONTROLID` <> ''
UNION ALL
SELECT DISTINCT 'TPMS' AS `attribute`, NULLIF(s.`TPMSID`, '') AS `id`, NULLIF(s.`TPMS`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`TPMSID` <> ''
UNION ALL
SELECT DISTINCT 'AUTOMATICCRASHNOTIFICATION' AS `attribute`, NULLIF(s.`AUTOMATICCRASHNOTIFICATIONID`, '') AS `id`, NULLIF(s.`AUTOMATICCRASHNOTIFICATION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AUTOMATICCRASHNOTIFICATIONID` <> ''
UNION ALL
SELECT DISTINCT 'EVENTDATARECORDER' AS `attribute`, NULLIF(s.`EVENTDATARECORDERID`, '') AS `id`, NULLIF(s.`EVENTDATARECORDER`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`EVENTDATARECORDERID` <> ''
UNION ALL
SELECT DISTINCT 'TRACTIONCONTROL' AS `attribute`, NULLIF(s.`TRACTIONCONTROLID`, '') AS `id`, NULLIF(s.`TRACTIONCONTROL`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`TRACTIONCONTROLID` <> ''
UNION ALL
SELECT DISTINCT 'AUTOPEDESTRIANALERTINGSOUND' AS `attribute`, NULLIF(s.`AUTOPEDESTRIANALERTINGSOUNDID`, '') AS `id`, NULLIF(s.`AUTOPEDESTRIANALERTINGSOUND`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AUTOPEDESTRIANALERTINGSOUNDID` <> ''
UNION ALL
SELECT DISTINCT 'KEYLESSIGNITION' AS `attribute`, NULLIF(s.`KEYLESSIGNITIONID`, '') AS `id`, NULLIF(s.`KEYLESSIGNITION`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`KEYLESSIGNITIONID` <> ''
UNION ALL
SELECT DISTINCT 'AUTOREVERSESYSTEM' AS `attribute`, NULLIF(s.`AUTOREVERSESYSTEMID`, '') AS `id`, NULLIF(s.`AUTOREVERSESYSTEM`, '') AS `label`
  FROM `fars_stage`.`vpicdecode` AS s WHERE s.`AUTOREVERSESYSTEMID` <> '';

-- state_region: 51 rows expected.
-- Derived: distinct (STATE, A_REGION) from data/processed/acc_aux.csv; STATE
-- -> A_REGION. The primary key rejects any key that maps to two different
-- values.
INSERT INTO `fars`.`state_region` (
  `STATE`, `A_REGION`
)
SELECT DISTINCT
  NULLIF(s.`STATE`, '') AS `STATE`,
  NULLIF(s.`A_REGION`, '') AS `A_REGION`
FROM `fars_stage`.`acc_aux` AS s;

-- roadfc_inter: 7 rows expected.
-- Derived: distinct (A_ROADFC, A_INTER) from data/processed/acc_aux.csv;
-- A_ROADFC -> A_INTER. The primary key rejects any key that maps to two
-- different values.
INSERT INTO `fars`.`roadfc_inter` (
  `A_ROADFC`, `A_INTER`
)
SELECT DISTINCT
  NULLIF(s.`A_ROADFC`, '') AS `A_ROADFC`,
  NULLIF(s.`A_INTER`, '') AS `A_INTER`
FROM `fars_stage`.`acc_aux` AS s;

-- junc_intsec: 4 rows expected.
-- Derived: distinct (A_JUNC, A_INTSEC) from data/processed/acc_aux.csv;
-- A_JUNC -> A_INTSEC. The primary key rejects any key that maps to two
-- different values.
INSERT INTO `fars`.`junc_intsec` (
  `A_JUNC`, `A_INTSEC`
)
SELECT DISTINCT
  NULLIF(s.`A_JUNC`, '') AS `A_JUNC`,
  NULLIF(s.`A_INTSEC`, '') AS `A_INTSEC`
FROM `fars_stage`.`acc_aux` AS s;

-- age_band_map: 13 rows expected.
-- Derived: distinct (A_AGE3, A_AGE1, A_AGE2, A_AGE4, A_AGE5, A_AGE9) from
-- data/processed/per_aux.csv; A_AGE3 -> A_AGE1, A_AGE2, A_AGE4, A_AGE5,
-- A_AGE9. The primary key rejects any key that maps to two different values.
INSERT INTO `fars`.`age_band_map` (
  `A_AGE3`, `A_AGE1`, `A_AGE2`, `A_AGE4`, `A_AGE5`, `A_AGE9`
)
SELECT DISTINCT
  NULLIF(s.`A_AGE3`, '') AS `A_AGE3`,
  NULLIF(s.`A_AGE1`, '') AS `A_AGE1`,
  NULLIF(s.`A_AGE2`, '') AS `A_AGE2`,
  NULLIF(s.`A_AGE4`, '') AS `A_AGE4`,
  NULLIF(s.`A_AGE5`, '') AS `A_AGE5`,
  NULLIF(s.`A_AGE9`, '') AS `A_AGE9`
FROM `fars_stage`.`per_aux` AS s;

-- ped_crash_group: 51 rows expected.
-- Derived: distinct (PEDCTYPE, PEDCGP) from data/processed/pbtype.csv;
-- PEDCTYPE -> PEDCGP. The primary key rejects any key that maps to two
-- different values.
INSERT INTO `fars`.`ped_crash_group` (
  `PEDCTYPE`, `PEDCGP`
)
SELECT DISTINCT
  NULLIF(s.`PEDCTYPE`, '') AS `PEDCTYPE`,
  NULLIF(s.`PEDCGP`, '') AS `PEDCGP`
FROM `fars_stage`.`pbtype` AS s;

-- bike_crash_group: 66 rows expected.
-- Derived: distinct (BIKECTYPE, BIKECGP) from data/processed/pbtype.csv;
-- BIKECTYPE -> BIKECGP. The primary key rejects any key that maps to two
-- different values.
INSERT INTO `fars`.`bike_crash_group` (
  `BIKECTYPE`, `BIKECGP`
)
SELECT DISTINCT
  NULLIF(s.`BIKECTYPE`, '') AS `BIKECTYPE`,
  NULLIF(s.`BIKECGP`, '') AS `BIKECGP`
FROM `fars_stage`.`pbtype` AS s;

-- code_labels: 8,892 rows expected.
-- Not loaded from data/processed/lookups/code_labels.csv: source_files.
-- Reason: source_files is ETL provenance, not part of the schema.
INSERT INTO `fars`.`code_labels` (
  `column`, `code`, `label`
)
SELECT
  NULLIF(s.`column`, '') AS `column`,
  NULLIF(s.`code`, '') AS `code`,
  NULLIF(s.`label`, '') AS `label`
FROM `fars_stage`.`code_labels` AS s;

-- county: 2,827 rows expected.
-- Renamed: COUNTYNAME -> county_name.
INSERT INTO `fars`.`county` (
  `STATE`, `COUNTY`, `county_name`
)
SELECT
  NULLIF(s.`STATE`, '') AS `STATE`,
  NULLIF(s.`COUNTY`, '') AS `COUNTY`,
  NULLIF(s.`COUNTYNAME`, '') AS `county_name`
FROM `fars_stage`.`county` AS s;

-- city: 5,507 rows expected.
-- Renamed: CITYNAME -> city_name.
INSERT INTO `fars`.`city` (
  `STATE`, `CITY`, `city_name`
)
SELECT
  NULLIF(s.`STATE`, '') AS `STATE`,
  NULLIF(s.`CITY`, '') AS `CITY`,
  NULLIF(s.`CITYNAME`, '') AS `city_name`
FROM `fars_stage`.`city` AS s;

COMMIT;
