-- ============================================================================
-- Author: Jue Wang
-- File: sql/schema/03_create_lookups.sql  (run THIRD)
-- Purpose: code-label lookup tables. The ETL already moved every *NAME text
-- column out of the fact tables into data/processed/lookups/; these tables
-- hold them in MySQL. See data/processed/README.md ("what changed") and
-- lookups/label_conflicts.csv for spelling variants that were unified.
-- ============================================================================

USE fars2024;

-- Generic code -> label map. `column` is backticked: COLUMN is reserved.
CREATE TABLE code_labels (
    `column`    VARCHAR(32)     NOT NULL,
    code        INT             NOT NULL,
    label       VARCHAR(128)    NOT NULL,
    PRIMARY KEY (`column`, code)
) ENGINE=InnoDB;

CREATE TABLE county (
    STATE       TINYINT UNSIGNED NOT NULL,
    COUNTY      SMALLINT UNSIGNED NOT NULL,
    county_name VARCHAR(64)     NOT NULL,
    PRIMARY KEY (STATE, COUNTY)
) ENGINE=InnoDB;

-- City codes repeat across states, hence the composite key.
CREATE TABLE city (
    STATE       TINYINT UNSIGNED NOT NULL,
    CITY        INT             NOT NULL,
    city_name   VARCHAR(64)     NOT NULL,
    PRIMARY KEY (STATE, CITY)
) ENGINE=InnoDB;
