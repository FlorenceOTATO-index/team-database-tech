-- ============================================================================
-- Author: Jue Wang
-- File: sql/schema/02_create_child_tables.sql  (run SECOND)
-- Purpose: multi-row child tables hanging off accident / vehicle / person.
--
-- For EACH table below: verify the key columns against the processed CSV
-- (one row = one event/factor/drug/...). Template:
--
--   CREATE TABLE <name> (
--       ST_CASE  INT NOT NULL,            -- always (crash-level tables)
--       VEH_NO   TINYINT UNSIGNED NOT NULL,  -- + vehicle-level tables
--       PER_NO   TINYINT UNSIGNED NOT NULL,  -- + person-level tables
--       <seq>    ... NOT NULL,            -- sequence number if rows repeat
--       -- ... remaining columns from the CSV header
--       PRIMARY KEY (...),
--       CONSTRAINT fk_<name>_parent FOREIGN KEY (...) REFERENCES <parent> (...)
--   ) ENGINE=InnoDB;
--
-- Crash level (parent: accident): cevent, crashrf, weather, ACC_AUX, MIACC, MIDRVACC
-- Vehicle level (parent: vehicle): damage, distract, drimpair, driverrf, factor,
--   maneuver, parkwork, pvehiclesf, vehiclesf, violatn, vision, vevent, vsoe,
--   vpicdecode, vpictrailerdecode, VEH_AUX
-- Person level (parent: person): drugs, race, personrf, pbtype, safetyeq, nmcrash,
--   nmdistract, nmimpair, nmprior, PER_AUX, MIPER
--
-- Special cases (see docs/schema/relational-schema.md):
--   D2: drugs gets surrogate key drug_id (748 exact-duplicate rows).
--   D3: parkwork / pvehiclesf reference accident ONLY, not vehicle.
--   race: column ORDER renamed RACE_ORDER (ORDER is a MySQL reserved word).
-- ============================================================================

USE fars2024;

-- --- Crash-level example ----------------------------------------------------
-- TODO: verify EVENTNUM (or actual sequence column) in cevent.csv
CREATE TABLE cevent (
    ST_CASE     INT             NOT NULL,
    EVENTNUM    TINYINT UNSIGNED NOT NULL,
    -- TODO: remaining columns from cevent.csv header
    PRIMARY KEY (ST_CASE, EVENTNUM),
    CONSTRAINT fk_cevent_accident
        FOREIGN KEY (ST_CASE) REFERENCES accident (ST_CASE)
) ENGINE=InnoDB;

-- TODO: crashrf, weather, ACC_AUX, MIACC, MIDRVACC (same pattern)

-- --- Person-level: drugs needs a surrogate key (decision D2) ----------------
CREATE TABLE drugs (
    drug_id     INT             NOT NULL AUTO_INCREMENT,
    ST_CASE     INT             NOT NULL,
    VEH_NO      TINYINT UNSIGNED NOT NULL,
    PER_NO      TINYINT UNSIGNED NOT NULL,
    -- TODO: remaining columns from drugs.csv header
    PRIMARY KEY (drug_id),
    KEY idx_drugs_person (ST_CASE, VEH_NO, PER_NO),
    CONSTRAINT fk_drugs_person
        FOREIGN KEY (ST_CASE, VEH_NO, PER_NO)
        REFERENCES person (ST_CASE, VEH_NO, PER_NO)
) ENGINE=InnoDB;

-- TODO: remaining person-level tables (race, personrf, pbtype, safetyeq,
--   nmcrash, nmdistract, nmimpair, nmprior, PER_AUX, MIPER)

-- --- Vehicle-level tables ----------------------------------------------------
-- TODO: damage, distract, drimpair, driverrf, factor, maneuver, vehiclesf,
--   violatn, vision, vevent, vsoe, vpicdecode, vpictrailerdecode, VEH_AUX
--   each with FOREIGN KEY (ST_CASE, VEH_NO) REFERENCES vehicle (ST_CASE, VEH_NO)

-- --- Parked/working vehicles: accident only, NOT vehicle (decision D3) -------
-- TODO: parkwork, pvehiclesf with FOREIGN KEY (ST_CASE) REFERENCES accident (ST_CASE)
