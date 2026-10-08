-- ======================================================================
-- Q08 (advanced): Is rollover more common among vehicles in crashes with
-- one vehicle or multiple vehicles?
-- Author: Matt
-- Technique: three-table JOIN (accident -> vehicle -> crash_unit), WHERE
-- filtering, CASE, conditional aggregation, derived percentage.
--
-- ROLLOVER is stored on crash_unit (D9) and joined on the full key
-- (ST_CASE, VEH_NO), so each vehicle matches one row and nothing is
-- duplicated. Starting from vehicle keeps in-transport vehicles only.
-- ROLLOVER 3 = rollover, 0 = no rollover. 8 = not applicable (motorcycles,
-- scooters, mopeds) and is excluded, so the percentage is among vehicles
-- where rollover applies.
-- FARS has fatal crashes only, so this compares vehicles within fatal
-- crashes; it does not show that rollovers cause deaths or how often
-- vehicles roll over on the road in general.
-- ======================================================================

USE fars;

SELECT
  CASE
    WHEN a.VE_FORMS = 1 THEN 'One vehicle'
    ELSE 'Multiple vehicles'
  END AS crash_type,
  COUNT(*) AS vehicles_rollover_applicable,
  SUM(cu.ROLLOVER = 3) AS vehicles_rolled_over,
  ROUND(
    100.0 * SUM(cu.ROLLOVER = 3)
    / COUNT(*),
    1
  ) AS pct_vehicles_rolled_over
FROM accident a
JOIN vehicle v
  ON a.ST_CASE = v.ST_CASE
JOIN crash_unit cu
  ON v.ST_CASE = cu.ST_CASE
 AND v.VEH_NO = cu.VEH_NO
WHERE cu.ROLLOVER IN (0, 3)
GROUP BY crash_type
ORDER BY MIN(a.VE_FORMS);
