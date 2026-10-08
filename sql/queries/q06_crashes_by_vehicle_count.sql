-- ======================================================================
-- Q06 (basic): Do fatal crashes more often involve one vehicle or
-- multiple vehicles?
-- Author: Matt
-- Technique: CASE to classify crashes, GROUP BY, COUNT, scalar subquery
-- for a percentage.
--
-- VE_FORMS is the number of in-transport (moving) vehicles in the crash;
-- it equals the number of rows in vehicle for every crash, so reading it
-- from accident keeps one row per crash with no join.
-- Parked and working vehicles are not counted, so one moving car that
-- hits a parked car is a one-vehicle crash. One-vehicle crashes also
-- include crashes with a pedestrian, cyclist or other non-motorist.
-- FARS has fatal crashes only, so this is a share of fatal crashes, not
-- which kind of crash is more likely to turn fatal.
-- ======================================================================

USE fars;

SELECT
  CASE
    WHEN VE_FORMS = 1 THEN 'One vehicle'
    WHEN VE_FORMS >= 2 THEN 'Multiple vehicles'
  END AS crash_type,
  COUNT(*) AS fatal_crashes,
  ROUND(
    100 * COUNT(*) /
    (SELECT COUNT(*) FROM accident),
    1
  ) AS pct_of_fatal_crashes
FROM accident
GROUP BY crash_type
ORDER BY fatal_crashes DESC;
