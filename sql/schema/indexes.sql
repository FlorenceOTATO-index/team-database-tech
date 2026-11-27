-- ============================================================================
-- File: sql/schema/indexes.sql   (run AFTER sql/load/*.sql)
-- Author: Ryan Williams
-- Purpose: secondary indexes for the filters our queries and dashboard use.
--
-- 01_create_tables.sql only creates primary keys, the indexes that back
-- foreign keys, and a few lookup indexes (accident date, VIN, drugs by
-- person, person death time). Every other WHERE filter scans the whole
-- table. These indexes are added after loading because maintaining them
-- during a bulk load would slow it down.
--
-- Each index is justified by a measured query; see
-- sql/queries/q21_index_performance.sql for the EXPLAIN ANALYZE evidence.
--
-- Run once:
--   mysql -u root -p < sql/schema/indexes.sql
-- Re-running fails with "Duplicate key name", which is harmless.
-- ============================================================================

USE fars;

-- Dashboard state filter (+ optional month filter). STATE comes first
-- because it's the filter used most often; a query filtering on STATE alone
-- can still use the left-most part of this index.
-- Measured: 36,297 rows scanned -> 48 for one small state.
CREATE INDEX idx_accident_state_month ON accident (STATE, MONTH);

-- Q14 (prior DWI). Only about 2.5% of vehicles have PREV_DWI >= 1, which is
-- selective enough for a range scan. The index also "covers" that part
-- of the query (it holds ST_CASE and VEH_NO, the primary key), so MySQL
-- never reads the table rows. Measured: 56,011 rows scanned -> 1,381.
CREATE INDEX idx_vehicle_prev_dwi ON vehicle (PREV_DWI);

-- Refresh the optimizer's statistics so it knows how selective the new
-- indexes are.
ANALYZE TABLE accident, vehicle;
