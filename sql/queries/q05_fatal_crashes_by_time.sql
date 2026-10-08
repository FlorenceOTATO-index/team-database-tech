-- ======================================================================
-- Q05 (basic): What times of day have the most fatal crashes?
-- Author: Matt
-- Technique: JOIN to code_labels, WHERE filtering, GROUP BY, COUNT,
-- scalar subquery for a percentage.
--
-- HOUR is the hour the crash happened (0-23). 99 means "Unknown Hours"
-- (253 crashes), so those are left out and the percentage is a share of
-- the crashes with a known hour.
-- These are counts of fatal crashes only, not adjusted for how much
-- traffic is on the road at each hour, so an hour with more crashes is
-- not necessarily a riskier hour per trip.
-- code_labels has one row per (column, code), so the join cannot
-- duplicate a crash.
-- ======================================================================

USE fars;

SELECT
  a.HOUR                                                AS crash_hour,
  hr.label                                              AS time_of_day,
  COUNT(*)                                              AS fatal_crashes,
  ROUND(100 * COUNT(*)
            / (SELECT COUNT(*) FROM accident
                WHERE HOUR <> 99), 1)                   AS pct_of_known_hour_crashes
FROM accident a
JOIN code_labels hr
  ON hr.`column` = 'HOUR'
 AND hr.code     = CAST(a.HOUR AS CHAR)
WHERE a.HOUR <> 99
GROUP BY a.HOUR, hr.label
ORDER BY fatal_crashes DESC;
