-- ======================================================================
-- Q21 (advanced, indexing/performance): How much faster do two of our
-- common filters run once they have an index?
-- Author: Ryan Williams
-- Technique: EXPLAIN ANALYZE, secondary indexes, IGNORE INDEX hint to
-- compare the same query with and without its index.
--
-- Run sql/schema/indexes.sql first. Then this file shows each query
-- twice: once with IGNORE INDEX (MySQL pretends the index isn't there,
-- the "before") and once normally (the "after"). Using the hint means
-- nothing has to be dropped and re-created, so the file can be rerun.
--
-- What to read in the EXPLAIN ANALYZE output:
--  * "Table scan on a ... rows=36297" means every row was read.
--  * "Index lookup ... rows=48" / "range scan" means only matching rows
--    were read.
--  * "actual time=x..y" is in milliseconds (y = time to the last row).
--
-- Results on our machine (times change slightly run to run, row counts
-- don't):
--  1. Dashboard state filter (Rhode Island, STATE = 44):
--       before: table scan, 36,297 rows read, about 9.6 ms
--       after:  index lookup on idx_accident_state_month, 48 rows read,
--               about 0.15 ms (roughly 60x faster)
--     The gain is biggest for small states. For California (about 10% of
--     crashes) the index still helps, but less.
--  2. Q14 prior-DWI drivers (PREV_DWI 1-98):
--       before: table scan, 56,011 rows read, about 22 ms
--       after:  covering index range scan on idx_vehicle_prev_dwi,
--               1,381 rows read, about 2.7 ms (roughly 8x faster)
--
-- Why not index everything: an index on a column like DR_DRINK (17% yes)
-- or PER_TYP (63% drivers) doesn't help, because reading most of the
-- table through an index is slower than scanning it. MySQL ignores
-- such indexes, and every extra index slows down inserts. So we only
-- index selective columns that our queries actually filter on.
-- ======================================================================

USE fars;

-- 1a. BEFORE: state filter without the index
EXPLAIN ANALYZE
SELECT a.MONTH,
       COUNT(*)              AS vehicles,
       SUM(a.FATALS)         AS deaths_summed_per_vehicle,
       SUM(v.DR_DRINK = 1)   AS drinking_drivers
FROM accident a IGNORE INDEX (idx_accident_state_month)
JOIN vehicle v
  ON v.ST_CASE = a.ST_CASE
WHERE a.STATE = 44
GROUP BY a.MONTH;

-- 1b. AFTER: same query, index allowed
EXPLAIN ANALYZE
SELECT a.MONTH,
       COUNT(*)              AS vehicles,
       SUM(a.FATALS)         AS deaths_summed_per_vehicle,
       SUM(v.DR_DRINK = 1)   AS drinking_drivers
FROM accident a
JOIN vehicle v
  ON v.ST_CASE = a.ST_CASE
WHERE a.STATE = 44
GROUP BY a.MONTH;

-- 2a. BEFORE: drivers with a prior DWI, without the index
EXPLAIN ANALYZE
SELECT COUNT(*)                              AS drivers,
       AVG(p.ALC_RES BETWEEN 80 AND 994)     AS share_bac_08_plus
FROM vehicle v IGNORE INDEX (idx_vehicle_prev_dwi)
JOIN person p
  ON p.ST_CASE = v.ST_CASE
 AND p.VEH_NO  = v.VEH_NO
 AND p.PER_TYP = 1
WHERE v.PREV_DWI BETWEEN 1 AND 98;

-- 2b. AFTER: same query, index allowed
EXPLAIN ANALYZE
SELECT COUNT(*)                              AS drivers,
       AVG(p.ALC_RES BETWEEN 80 AND 994)     AS share_bac_08_plus
FROM vehicle v
JOIN person p
  ON p.ST_CASE = v.ST_CASE
 AND p.VEH_NO  = v.VEH_NO
 AND p.PER_TYP = 1
WHERE v.PREV_DWI BETWEEN 1 AND 98;
