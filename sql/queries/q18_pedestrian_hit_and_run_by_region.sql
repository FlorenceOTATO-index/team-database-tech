-- ======================================================================
-- Q18 (advanced): When a pedestrian or cyclist is killed, how often does
-- the driver flee, and which state is worst in each region?
-- Author: Ryan Williams
-- Technique: subquery with IN, chained CTEs, per-crash flag with MAX(),
-- HAVING, window function DENSE_RANK() OVER (PARTITION BY region),
-- JOINs to state_region and code_labels.
--
-- Crashes counted: at least one pedestrian (PER_TYP 5), bicyclist (6) or
-- other pedalcyclist (7) died (INJ_SEV = 4). The IN subquery finds those
-- crashes.
-- Hit-and-run: any vehicle in the crash has HIT_RUN = 1. MAX(HIT_RUN = 1)
-- turns several vehicle rows into one yes/no per crash, so a crash is
-- never counted twice.
--
-- Regions are NHTSA's 10 regions (state_region.A_REGION). States with
-- fewer than 30 such crashes are dropped (HAVING) because a rate from a
-- handful of crashes swings wildly. DENSE_RANK restarts at 1 in every
-- region (PARTITION BY), and the outer query keeps each region's top 2.
-- For comparison, only about 7% of all fatal crashes are hit-and-runs.
-- ======================================================================

USE fars;

WITH nonmotorist_crashes AS (
  SELECT
    a.ST_CASE,
    a.STATE,
    MAX(v.HIT_RUN = 1)                          AS hit_and_run
  FROM accident a
  JOIN vehicle v
    ON v.ST_CASE = a.ST_CASE
  WHERE a.ST_CASE IN (SELECT ST_CASE
                      FROM person
                      WHERE PER_TYP IN (5, 6, 7)
                        AND INJ_SEV = 4)
  GROUP BY a.ST_CASE, a.STATE
),
by_state AS (
  SELECT
    sr.A_REGION,
    nc.STATE,
    COUNT(*)                                    AS crashes,
    SUM(nc.hit_and_run)                         AS hit_and_runs,
    ROUND(100 * AVG(nc.hit_and_run), 1)         AS pct_hit_and_run
  FROM nonmotorist_crashes nc
  JOIN state_region sr
    ON sr.STATE = nc.STATE
  GROUP BY sr.A_REGION, nc.STATE
  HAVING COUNT(*) >= 30
),
ranked AS (
  SELECT
    by_state.*,
    DENSE_RANK() OVER (PARTITION BY A_REGION
                       ORDER BY pct_hit_and_run DESC) AS rank_in_region
  FROM by_state
)
SELECT
  CONCAT(r.A_REGION, ' - ',
         ELT(r.A_REGION, 'New England', 'Eastern', 'Mid-Atlantic',
             'Southeast', 'Great Lakes', 'South Central', 'Central',
             'Rocky Mountain', 'Western', 'Northwest')) AS nhtsa_region,
  st.label                                      AS state,
  r.crashes,
  r.hit_and_runs,
  r.pct_hit_and_run,
  r.rank_in_region
FROM ranked r
JOIN code_labels st
  ON st.`column` = 'STATE'
 AND st.code     = CAST(r.STATE AS CHAR)
WHERE r.rank_in_region <= 2
ORDER BY r.A_REGION, r.rank_in_region;
