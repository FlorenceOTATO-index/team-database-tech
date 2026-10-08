-- ======================================================================
-- Q04 (advanced): Which driver age groups have an above-average rate of
-- drunk driving (BAC >= 0.08)?
-- Author: Ryan Williams
-- Technique: CTE, conditional aggregation, scalar subqueries in SELECT
-- and HAVING.
--
-- ALC_RES is BAC in thousandths (80 = 0.08). 995-999 mean not reported,
-- not tested or unknown result, so rates use tested drivers only.
-- Only groups above the overall rate are returned, so expect fewer rows
-- than age groups.
-- ======================================================================

USE fars;

WITH tested_drivers AS (
  SELECT
    CASE
      WHEN AGE < 16 THEN 'Under 16'
      WHEN AGE <= 20 THEN '16-20'
      WHEN AGE <= 24 THEN '21-24'
      WHEN AGE <= 34 THEN '25-34'
      WHEN AGE <= 44 THEN '35-44'
      WHEN AGE <= 54 THEN '45-54'
      WHEN AGE <= 64 THEN '55-64'
      WHEN AGE <= 74 THEN '65-74'
      ELSE '75+'
    END AS age_group,
    ALC_RES
  FROM person
  WHERE PER_TYP = 1
    AND AGE NOT IN (998, 999)
    AND ALC_RES < 995
)
SELECT
  age_group,
  COUNT(*)                                            AS tested_drivers,
  SUM(ALC_RES >= 80)                                  AS drivers_bac_080_plus,
  ROUND(100 * AVG(ALC_RES >= 80), 1)                  AS pct_bac_080_plus,
  (SELECT ROUND(100 * AVG(ALC_RES >= 80), 1)
     FROM tested_drivers)                             AS overall_pct
FROM tested_drivers
GROUP BY age_group
HAVING AVG(ALC_RES >= 80) > (SELECT AVG(ALC_RES >= 80) FROM tested_drivers)
ORDER BY pct_bac_080_plus DESC;
