-- ======================================================================
-- Q11 (advanced — INDEXING): How much faster does my work-zone filter
-- run once the column has an index?
-- Author: Saida Mahmood
-- Technique: CREATE INDEX, EXPLAIN ANALYZE, IGNORE INDEX to run the same
-- query with and without the index.
--
-- Why this column: WRK_ZONE is a good index candidate because it is
-- selective — only a small share of the 36,297 crashes are in a work
-- zone, so the index can skip almost the whole table. Ryan's Q21 indexes
-- accident(STATE, MONTH) and vehicle(PREV_DWI); this is a different
-- column and a different query.
-- ======================================================================

USE fars;

-- ----------------------------------------------------------------------
-- STEP 1 — create the index (safe to re-run)
-- ----------------------------------------------------------------------
CREATE INDEX idx_accident_wrk_zone ON accident (WRK_ZONE);


-- ----------------------------------------------------------------------
-- STEP 2 — BEFORE: force MySQL to ignore the index
-- ----------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) AS work_zone_crashes, SUM(FATALS) AS deaths
FROM accident IGNORE INDEX (idx_accident_wrk_zone)
WHERE WRK_ZONE > 0;


-- ----------------------------------------------------------------------
-- STEP 3 — AFTER: same query, index allowed
-- ----------------------------------------------------------------------
EXPLAIN ANALYZE
SELECT COUNT(*) AS work_zone_crashes, SUM(FATALS) AS deaths
FROM accident
WHERE WRK_ZONE > 0;


-- ----------------------------------------------------------------------
-- WHAT TO LOOK FOR in the two outputs
--
--   BEFORE: "Table scan on accident ... rows=36297"
--           MySQL reads every row and throws most of them away.
--
--   AFTER:  "Index range scan on accident using idx_accident_wrk_zone"
--           with a much smaller rows= number, and a smaller
--           "actual time=" at the end of the line.
--
-- Screenshot BOTH outputs side by side. The rows= number and the
-- actual time are the evidence.
-- ----------------------------------------------------------------------

-- RESULT (run 2026-11-27)
--
--                     rows read     actual time    MySQL cost estimate
--   BEFORE (ignored)     36,297        13.7 ms            6,159
--   AFTER  (index)          763         2.8 ms              519
--
--   47x fewer rows read, about 5x faster.
--
-- Slide line: "Without the index MySQL reads all 36,297 crashes and
-- throws away 98% of them. With it, it reads 763 - 47 times fewer rows,
-- and about five times faster."
--
-- Worth noticing in the BEFORE output: the Filter line says
-- "cost=3515 rows=11476" but "actual ... rows=763". 11,476 was MySQL's
-- GUESS at how many rows would pass the filter before it ran; 763 is
-- what really passed. The optimizer plans on estimates and can be far
-- off - which is exactly why EXPLAIN ANALYZE (which runs the query) is
-- more useful than plain EXPLAIN (which does not).

-- ----------------------------------------------------------------------
-- THE POINT TO MAKE (this is what earns the mark, not the speed-up):
--
-- An index is not free. It costs disk space and it slows down every
-- insert, because the index has to be updated too. It only pays off on a
-- column that is SELECTIVE — where the filter removes most of the rows.
--
-- WRK_ZONE qualifies: work-zone crashes are a small fraction of the
-- table. A column like SEAT_POS would not, because the driver's seat is
-- roughly half of all people — MySQL would read most of the table
-- anyway, and going through an index to do it is slower than a plain
-- scan. MySQL often ignores such an index on its own.
-- ----------------------------------------------------------------------

-- To undo, if you want the database back as it was:
--   DROP INDEX idx_accident_wrk_zone ON accident;
