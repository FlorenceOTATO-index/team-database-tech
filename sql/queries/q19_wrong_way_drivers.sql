-- ======================================================================
-- Q19 (advanced): When do wrong-way crashes happen, and how often is the
-- wrong-way driver drinking?
-- Author: Ryan Williams
-- Technique: correlated subqueries with EXISTS (one per flag), CASE time
-- bands, conditional aggregation, scalar subquery for a baseline.
--
-- Wrong-way driver: veh_aux.A_WRONGWAYDRV = 1 (NHTSA-derived flag;
-- 2 = no). veh_aux has one row per vehicle, so it joins to vehicle on
-- ST_CASE and VEH_NO.
-- For each crash, two EXISTS tests run against that crash's vehicles
-- (correlated on a.ST_CASE):
--  * was any driver going the wrong way?
--  * was a wrong-way driver also reported drinking (DR_DRINK = 1)?
-- EXISTS stops at the first match and returns true/false, so a crash with
-- two wrong-way vehicles still counts once.
--
-- HOUR = 99 (unknown) is left out. pct_wrong_way_drinking is out of
-- wrong-way crashes in that band. The baseline column is the share of all
-- drivers in fatal crashes reported drinking (about 17%), to compare.
-- ======================================================================

USE fars;

WITH flagged AS (
  SELECT
    CASE WHEN a.HOUR BETWEEN 0  AND 4  THEN 1
         WHEN a.HOUR BETWEEN 5  AND 11 THEN 2
         WHEN a.HOUR BETWEEN 12 AND 17 THEN 3
         ELSE 4 END                                    AS band_order,
    EXISTS (SELECT 1
            FROM veh_aux x
            WHERE x.ST_CASE = a.ST_CASE
              AND x.A_WRONGWAYDRV = 1)                 AS wrong_way,
    EXISTS (SELECT 1
            FROM veh_aux x
            JOIN vehicle v
              ON v.ST_CASE = x.ST_CASE
             AND v.VEH_NO  = x.VEH_NO
            WHERE x.ST_CASE = a.ST_CASE
              AND x.A_WRONGWAYDRV = 1
              AND v.DR_DRINK = 1)                      AS wrong_way_drinking
  FROM accident a
  WHERE a.HOUR <= 23
)
SELECT
  ELT(band_order, 'Midnight-5 am', '5 am-noon',
                  'Noon-6 pm', '6 pm-midnight')        AS time_of_day,
  COUNT(*)                                             AS fatal_crashes,
  SUM(wrong_way)                                       AS wrong_way_crashes,
  ROUND(100 * AVG(wrong_way), 1)                       AS pct_wrong_way,
  ROUND(100 * SUM(wrong_way_drinking)
            / SUM(wrong_way), 1)                       AS pct_wrong_way_drinking,
  (SELECT ROUND(100 * AVG(DR_DRINK = 1), 1)
   FROM vehicle
   WHERE DR_PRES = 1)                                  AS all_drivers_pct_drinking
FROM flagged
GROUP BY band_order
ORDER BY band_order;
