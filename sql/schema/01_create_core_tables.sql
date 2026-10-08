-- ============================================================================
-- Author: Jue Wang
-- File: sql/schema/01_create_core_tables.sql  (run FIRST)
-- Purpose: core crash/vehicle/person tables for FARS 2024.
--
-- NOTE: column lists below are representative. Before running, verify every
-- column and type against the processed CSV headers:
--   head -1 data/processed/accident.csv
--   head -1 data/processed/vehicle.csv
--   head -1 data/processed/person.csv
-- Watch for: negative codes (-1 = unknown), LATITUDE/LONGITUDE decimals,
-- and max text lengths (check with: python -c "import pandas as pd; ...").
-- ============================================================================

CREATE DATABASE IF NOT EXISTS fars2024
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE fars2024;

-- One row per crash. ST_CASE is nationally unique; leading digits encode STATE.
CREATE TABLE accident (
    ST_CASE     INT             NOT NULL,
    STATE       TINYINT UNSIGNED NOT NULL,
    -- TODO: add remaining columns from accident.csv header, e.g.
    -- COUNTY, CITY, DAY, MONTH, YEAR, HOUR, MINUTE, HARM_EV, ...
    PRIMARY KEY (ST_CASE)
) ENGINE=InnoDB;

-- One row per in-transport vehicle in a crash.
CREATE TABLE vehicle (
    ST_CASE     INT             NOT NULL,
    VEH_NO      TINYINT UNSIGNED NOT NULL,
    -- TODO: add remaining columns from vehicle.csv header
    PRIMARY KEY (ST_CASE, VEH_NO),
    CONSTRAINT fk_vehicle_accident
        FOREIGN KEY (ST_CASE) REFERENCES accident (ST_CASE)
) ENGINE=InnoDB;

-- One row per person involved.
-- VEH_NO = 0 marks non-motorists (pedestrians, cyclists): they belong to the
-- crash but to no vehicle, so there is deliberately NO foreign key from
-- person to vehicle (see docs/schema/relational-schema.md, decision D1).
CREATE TABLE person (
    ST_CASE     INT             NOT NULL,
    VEH_NO      TINYINT UNSIGNED NOT NULL,
    PER_NO      TINYINT UNSIGNED NOT NULL,
    -- TODO: add remaining columns from person.csv header
    PRIMARY KEY (ST_CASE, VEH_NO, PER_NO),
    CONSTRAINT fk_person_accident
        FOREIGN KEY (ST_CASE) REFERENCES accident (ST_CASE)
) ENGINE=InnoDB;
