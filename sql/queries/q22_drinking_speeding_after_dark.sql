-- ======================================================================
-- Q22 (advanced, view): How often do drinking and speeding show up
-- together in fatal crashes, and is that combination more common after
-- dark?
-- Author: Ryan Williams
-- Technique: querying a saved VIEW (v_crash_facts), CTE, GROUP BY ...
-- WITH ROLLUP for subtotals, GROUPING() to label the subtotal rows,
-- window function over the grouped result for percentages.
--
-- Run sql/schema/views.sql first. v_crash_facts already has one yes/no
-- flag per crash:
--  * drinking_driver: any driver police-reported as drinking (DR_DRINK)
--  * speeding: any vehicle speed-related (SPEEDREL 2-5)
--  * is_dark: LGT_COND 2/3/6 (dark, lit or unlit)
-- Dawn/dusk (4, 5) and unknown light (7-9) are left out so the two light
-- groups are clean.
--
-- WITH ROLLUP adds a subtotal row for each light condition and a grand
-- total row at the end. In those rows the rolled-up column is NULL, so
-- GROUPING(col) = 1 tells us it's a subtotal and we print "All" instead.
-- pct_of_group divides each row by its light group's total. The subtotal
-- row is the largest row in its group, so MAX(COUNT(*)) OVER the group
-- finds it.
-- ======================================================================

USE fars;

WITH crashes AS (
  SELECT
    IF(is_dark, 'Dark', 'Daylight')                   AS light,
    CASE WHEN drinking_driver AND speeding THEN '1 Drinking + speeding'
         WHEN drinking_driver              THEN '2 Drinking only'
         WHEN speeding                     THEN '3 Speeding only'
         ELSE                                   '4 Neither' END AS combo,
    FATALS
  FROM v_crash_facts
  WHERE LGT_COND IN (1, 2, 3, 6)
)
SELECT
  IF(GROUPING(light) = 1, 'All', light)               AS light,
  IF(GROUPING(combo) = 1, 'All crashes',
     SUBSTRING(combo, 3))                             AS risk_factors,
  COUNT(*)                                            AS crashes,
  ROUND(100 * COUNT(*)
            / MAX(COUNT(*)) OVER (PARTITION BY GROUPING(light), light), 1)
                                                      AS pct_of_group,
  SUM(FATALS)                                         AS deaths,
  ROUND(AVG(FATALS), 3)                               AS deaths_per_crash
FROM crashes
GROUP BY light, combo WITH ROLLUP
ORDER BY GROUPING(light), light DESC, GROUPING(combo), combo;
