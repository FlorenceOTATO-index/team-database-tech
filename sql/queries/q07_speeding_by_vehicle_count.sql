-- ======================================================================
-- Q07 (advanced): Is speeding more common among vehicles in crashes with
-- one vehicle or multiple vehicles?
-- Author: Matt
-- Technique: JOIN, WHERE filtering, CASE, conditional aggregation
-- (SUM of a condition), derived percentage.
--
-- One row per in-transport vehicle: each vehicle joins exactly one
-- accident row, so nothing is duplicated. VE_FORMS (moving vehicles in
-- the crash) sets the crash type.
-- SPEEDREL 2-5 = speeding (racing, exceeded the limit, too fast for
-- conditions, specifics unknown); 0 = not speeding. 8 (no driver or
-- unknown if driver present) and 9 (unknown) are excluded, so the
-- percentage is among vehicles with a known speeding status.
-- SPEEDREL is police-reported speeding involvement, not a finding of
-- cause. FARS has fatal crashes only, so this compares vehicles within
-- fatal crashes, not the risk of having a crash.
-- ======================================================================

USE fars;

SELECT
  CASE
    WHEN a.VE_FORMS = 1 THEN 'One vehicle'
    ELSE 'Multiple vehicles'
  END AS crash_type,
  COUNT(*) AS vehicles_known_status,
  SUM(v.SPEEDREL IN (2, 3, 4, 5)) AS vehicles_speeding,
  ROUND(
    100.0 * SUM(v.SPEEDREL IN (2, 3, 4, 5))
    / COUNT(*),
    1
  ) AS pct_vehicles_speeding
FROM accident a
JOIN vehicle v
  ON a.ST_CASE = v.ST_CASE
WHERE v.SPEEDREL IN (0, 2, 3, 4, 5)
GROUP BY crash_type
ORDER BY MIN(a.VE_FORMS);
