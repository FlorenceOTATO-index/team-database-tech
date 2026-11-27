-- ======================================================================
-- Q17 (advanced): Which holidays are deadlier on the road than an
-- ordinary day?
-- Author: Ryan Williams
-- Technique: derived table built with UNION ALL, chained CTEs, LEFT JOIN
-- from calendar, window functions AVG() OVER (PARTITION BY ...) and
-- RANK() OVER (ORDER BY ...).
--
-- The fair comparison for a holiday is the same weekday on a normal week:
-- July 4, 2024 was a Thursday, and weekends are deadlier than weekdays
-- anyway (see query 10). So each holiday is compared with the average of
-- all 2024 days that fall on the same DAY_WEEK (1 = Sunday ... 7 =
-- Saturday). The average includes the holiday itself, which slightly
-- understates the gap.
--
-- Holidays are typed in for 2024 (Memorial Day = May 27, Labor Day =
-- Sept 2, Thanksgiving = Nov 28). calendar has all 366 dates of 2024, and
-- the LEFT JOIN keeps a date even if it had no crashes (none did; the
-- quietest day still had 62 deaths).
--
-- Caveat: crashes are dated by when they happened, so a New Year's Eve
-- party crash at 1 a.m. counts as January 1. That's why New Year's Eve
-- looks safe and New Year's Day doesn't.
-- ======================================================================

USE fars;

WITH holidays AS (
            SELECT 'New Year''s Day'  AS holiday,  1 AS m,  1 AS d
  UNION ALL SELECT 'Memorial Day',                 5,      27
  UNION ALL SELECT 'Independence Day',             7,       4
  UNION ALL SELECT 'Labor Day',                    9,       2
  UNION ALL SELECT 'Halloween',                   10,      31
  UNION ALL SELECT 'Thanksgiving',                11,      28
  UNION ALL SELECT 'Christmas Day',               12,      25
  UNION ALL SELECT 'New Year''s Eve',             12,      31
),
daily AS (
  SELECT
    c.MONTH,
    c.DAY,
    c.DAY_WEEK,
    COALESCE(SUM(a.FATALS), 0)             AS deaths
  FROM calendar c
  LEFT JOIN accident a
    ON a.YEAR  = c.YEAR
   AND a.MONTH = c.MONTH
   AND a.DAY   = c.DAY
  GROUP BY c.MONTH, c.DAY, c.DAY_WEEK
),
compared AS (
  SELECT
    daily.*,
    AVG(deaths) OVER (PARTITION BY DAY_WEEK)  AS same_weekday_avg,
    RANK()      OVER (ORDER BY deaths DESC)   AS rank_of_366_days
  FROM daily
)
SELECT
  h.holiday,
  DATE_FORMAT(MAKEDATE(2024, 1) + INTERVAL (h.m - 1) MONTH
              + INTERVAL (h.d - 1) DAY, '%a %b %e')   AS date_2024,
  c.deaths,
  ROUND(c.same_weekday_avg, 1)                        AS same_weekday_avg,
  ROUND(100 * (c.deaths - c.same_weekday_avg)
            / c.same_weekday_avg, 1)                  AS pct_above_normal,
  c.rank_of_366_days
FROM holidays h
JOIN compared c
  ON c.MONTH = h.m
 AND c.DAY   = h.d
ORDER BY pct_above_normal DESC;
