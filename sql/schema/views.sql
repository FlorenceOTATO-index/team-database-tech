-- ============================================================================
-- File: sql/schema/views.sql   (run AFTER sql/load/*.sql)
-- Author: Ryan Williams
-- Purpose: saved views that queries and the dashboard can reuse.
--
-- v_crash_facts: one row per fatal crash (36,297 rows) with the date,
-- place and conditions already decoded, plus yes/no flags for the risk
-- factors we keep asking about. The flags come from the vehicle and
-- person tables, so without the view every query would repeat the same
-- EXISTS subqueries.
--
-- A view stores the query, not the data: every SELECT on it runs the
-- query again on the current tables, so it can never go stale. Reading
-- the whole view takes well under a second.
--
-- Run (safe to re-run, CREATE OR REPLACE):
--   mysql -u root -p < sql/schema/views.sql
-- ============================================================================

USE fars;

CREATE OR REPLACE VIEW v_crash_facts AS
SELECT
  a.ST_CASE,
  a.STATE,
  st.label                                   AS state_name,
  a.MONTH,
  a.DAY,
  c.DAY_WEEK,                                -- 1 = Sunday ... 7 = Saturday
  a.HOUR,                                    -- 99 = unknown
  a.RUR_URB,                                 -- 1 = rural, 2 = urban
  a.LGT_COND,
  a.WEATHER,
  a.LATITUDE,
  a.LONGITUD,
  a.FATALS,
  a.LGT_COND IN (2, 3, 6)                    AS is_dark,
  EXISTS (SELECT 1 FROM vehicle v
          WHERE v.ST_CASE = a.ST_CASE
            AND v.DR_DRINK = 1)              AS drinking_driver,
  EXISTS (SELECT 1 FROM vehicle v
          WHERE v.ST_CASE = a.ST_CASE
            AND v.SPEEDREL IN (2, 3, 4, 5))  AS speeding,
  EXISTS (SELECT 1 FROM vehicle v
          WHERE v.ST_CASE = a.ST_CASE
            AND v.HIT_RUN = 1)               AS hit_and_run,
  EXISTS (SELECT 1 FROM person p
          WHERE p.ST_CASE = a.ST_CASE
            AND p.PER_TYP IN (5, 6, 7)
            AND p.INJ_SEV = 4)               AS nonmotorist_killed,
  EXISTS (SELECT 1 FROM person p
          JOIN crash_unit cu
            ON cu.ST_CASE = p.ST_CASE
           AND cu.VEH_NO  = p.VEH_NO
          WHERE p.ST_CASE = a.ST_CASE
            AND p.PER_TYP IN (1, 2)
            AND cu.BODY_TYP BETWEEN 1 AND 49
            AND p.REST_USE = 20
            AND p.INJ_SEV = 4)               AS unbelted_death
FROM accident a
JOIN calendar c
  ON c.YEAR  = a.YEAR
 AND c.MONTH = a.MONTH
 AND c.DAY   = a.DAY
JOIN code_labels st
  ON st.`column` = 'STATE'
 AND st.code     = CAST(a.STATE AS CHAR);
