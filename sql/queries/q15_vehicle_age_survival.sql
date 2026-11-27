-- ======================================================================
-- Q15 (advanced): Are people in older cars more likely to die in a fatal
-- crash, even when they're wearing a seat belt?
-- Author: Ryan Williams
-- Technique: CTE, conditional aggregation used as a pivot (belted and
-- unbelted side by side), window function LAG() to show the change from
-- one model-year band to the next.
--
-- Same occupants as Q13: drivers and passengers of light vehicles
-- (BODY_TYP 1-49) with a known belt status (REST_USE 1-3 = belt,
-- 20 = none). MOD_YEAR 9998/9999 = unknown, so only real years are kept.
--
-- Why split by belt use: newer cars are also more often occupied by
-- belted people (84% for 2020-2025 vs 58% for 2004 or older), so a single
-- death rate per band would mix the car's safety with the occupant's
-- behavior. Comparing belted people only isolates the car.
--
-- LAG(...) OVER (ORDER BY band_order) reads the previous (older) band's
-- value, so change_vs_older_band is "how many points lower than the band
-- before it". It is NULL for the oldest band because there's nothing
-- before it.
-- ======================================================================

USE fars;

WITH occupants AS (
  SELECT
    CASE WHEN cu.MOD_YEAR <= 2004 THEN 1
         WHEN cu.MOD_YEAR <= 2009 THEN 2
         WHEN cu.MOD_YEAR <= 2014 THEN 3
         WHEN cu.MOD_YEAR <= 2019 THEN 4
         ELSE 5 END                       AS band_order,
    p.REST_USE IN (1, 2, 3)               AS belted,
    p.INJ_SEV = 4                         AS killed
  FROM person p
  JOIN crash_unit cu
    ON cu.ST_CASE = p.ST_CASE
   AND cu.VEH_NO  = p.VEH_NO
  WHERE p.PER_TYP IN (1, 2)
    AND cu.BODY_TYP BETWEEN 1 AND 49
    AND cu.MOD_YEAR BETWEEN 1950 AND 2025
    AND p.REST_USE IN (1, 2, 3, 20)
),
bands AS (
  SELECT
    band_order,
    COUNT(*)                                              AS occupants,
    ROUND(100 * AVG(belted), 1)                           AS pct_belted,
    ROUND(100 * SUM(killed AND belted) / SUM(belted), 1)  AS pct_killed_belted,
    ROUND(100 * SUM(killed AND NOT belted)
              / SUM(NOT belted), 1)                       AS pct_killed_unbelted
  FROM occupants
  GROUP BY band_order
)
SELECT
  ELT(band_order, '2004 or older', '2005-2009', '2010-2014',
                  '2015-2019', '2020-2025')               AS model_years,
  occupants,
  pct_belted,
  pct_killed_belted,
  ROUND(pct_killed_belted
        - LAG(pct_killed_belted) OVER (ORDER BY band_order), 1)
                                                          AS change_vs_older_band,
  pct_killed_unbelted
FROM bands
ORDER BY band_order;
