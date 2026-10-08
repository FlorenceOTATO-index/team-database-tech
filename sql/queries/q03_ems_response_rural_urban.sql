-- ======================================================================
-- Q03 (advanced): How much slower is EMS response in rural vs urban
-- fatal crashes?
-- Author: Ryan Williams
-- Technique: chained CTEs, derived column, window functions
-- (ROW_NUMBER / COUNT OVER) to compute a median, JOIN to code_labels.
--
-- Response time = EMS arrival - EMS notification, in minutes.
--  * 88/98/99 in the hour/minute fields mean not notified / unknown,
--    so only real clock times (hour <= 23, minute <= 59) are used.
--  * FARS stores times without dates, so an arrival after midnight looks
--    negative; those are wrapped by adding 1440 minutes (one day).
--  * A negative time is only a real midnight crossing if the wrapped
--    result is short (e.g. notified 23:54, arrived 00:03 = 9 min). The
--    other negatives are arrivals recorded before notification (data-entry
--    errors) that would wrap to 2-24 hours, so they are dropped. Genuinely
--    long responses that don't cross midnight (up to 196 min) are kept.
--  * The time columns are TINYINT UNSIGNED, and MySQL refuses an unsigned
--    subtraction that goes negative (ERROR 1690), so both sides are cast
--    to SIGNED before subtracting.
-- MySQL has no MEDIAN(), so it is computed with ROW_NUMBER()/COUNT() OVER.
-- ======================================================================

USE fars;

WITH response AS (
  SELECT
    a.RUR_URB,
    CAST(a.ARR_HOUR * 60 + a.ARR_MIN AS SIGNED)
      - CAST(a.NOT_HOUR * 60 + a.NOT_MIN AS SIGNED) AS raw_minutes
  FROM accident a
  WHERE a.RUR_URB IN (1, 2)
    AND a.NOT_HOUR <= 23 AND a.NOT_MIN <= 59
    AND a.ARR_HOUR <= 23 AND a.ARR_MIN <= 59
),
cleaned AS (
  SELECT
    RUR_URB,
    CASE WHEN raw_minutes < 0 THEN raw_minutes + 1440 ELSE raw_minutes END AS minutes
  FROM response
  WHERE raw_minutes >= 0                -- normal same-day response
     OR raw_minutes + 1440 <= 120       -- real midnight crossing
),
ranked AS (
  SELECT
    RUR_URB,
    minutes,
    ROW_NUMBER() OVER (PARTITION BY RUR_URB ORDER BY minutes) AS rn,
    COUNT(*)     OVER (PARTITION BY RUR_URB)                  AS n
  FROM cleaned
)
SELECT
  lbl.label                    AS area,
  COUNT(*)                     AS crashes_with_valid_times,
  ROUND(AVG(r.minutes), 1)     AS avg_response_min,
  AVG(CASE WHEN r.rn IN (FLOOR((r.n + 1) / 2), CEIL((r.n + 1) / 2))
           THEN r.minutes END) AS median_response_min,
  MAX(r.minutes)               AS max_response_min
FROM ranked r
JOIN code_labels lbl
  ON lbl.`column` = 'RUR_URB'
 AND lbl.code     = CAST(r.RUR_URB AS CHAR)
GROUP BY lbl.label
ORDER BY avg_response_min DESC;
