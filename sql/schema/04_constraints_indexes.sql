-- ============================================================================
-- Author: Jue Wang
-- File: sql/schema/04_constraints_indexes.sql  (run AFTER sql/load/*.sql)
-- Purpose: foreign keys that were deferred so bulk LOAD DATA isn't slowed by
-- constraint checks (decision D4), plus indexes for the query patterns the
-- team plans to use. Core-table FKs live in 01_create_core_tables.sql;
-- add here any child-table FK you chose to defer, following the same pattern.
-- ============================================================================

USE fars2024;

-- Example (uncomment/extend once child tables exist):
-- ALTER TABLE crashrf
--     ADD CONSTRAINT fk_crashrf_accident FOREIGN KEY (ST_CASE)
--     REFERENCES accident (ST_CASE);

-- Indexes for common analysis filters. Adjust to the team's actual queries.
CREATE INDEX idx_accident_state ON accident (STATE);
-- TODO: e.g. CREATE INDEX idx_accident_ym ON accident (YEAR, MONTH);
CREATE INDEX idx_vehicle_case ON vehicle (ST_CASE);
CREATE INDEX idx_person_case ON person (ST_CASE, VEH_NO);

-- Sanity checks after load (expect 0 rows back):
-- SELECT COUNT(*) FROM vehicle v LEFT JOIN accident a ON a.ST_CASE = v.ST_CASE
--   WHERE a.ST_CASE IS NULL;
-- SELECT COUNT(*) FROM person p LEFT JOIN accident a ON a.ST_CASE = p.ST_CASE
--   WHERE a.ST_CASE IS NULL;
