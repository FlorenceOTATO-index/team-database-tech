-- ======================================================================
-- Q16 (advanced): Are rural crash victims more likely to die at the scene
-- than urban ones?
-- Author: Ryan Williams
-- Technique: CTE, CASE buckets, GROUP BY, window function over an
-- aggregate (SUM(COUNT(*)) OVER (PARTITION BY ...)) to get each bucket's
-- share within its own area, JOIN to code_labels.
--
-- Follow-up to Q03 (EMS takes about 4 minutes longer in rural areas).
-- This asks where and when the people who died actually died.
--
-- Everyone here has INJ_SEV = 4 (fatal injury). Buckets, checked in
-- order:
--  * DOA = 7  died at the scene
--  * DOA = 8  died on the way to the hospital
--  * otherwise LAG_HRS (hours from crash to death): 0 = within the first
--    hour, 1-23 = same day, 24+ = a day or more later (FARS counts deaths
--    up to 30 days). LAG_HRS = 999 is unknown, so those people are left
--    out unless DOA already says scene or en route.
-- RUR_URB 1 = rural, 2 = urban; 6/8/9 (not in inventory / unknown) are
-- left out.
--
-- SUM(COUNT(*)) OVER (PARTITION BY RUR_URB) is the total for the whole
-- area, computed after GROUP BY, so each row can be divided by it without
-- a second query.
-- ======================================================================

USE fars;

WITH deaths AS (
  SELECT
    a.RUR_URB,
    CASE WHEN p.DOA = 7      THEN 1
         WHEN p.DOA = 8      THEN 2
         WHEN p.LAG_HRS = 0  THEN 3
         WHEN p.LAG_HRS < 24 THEN 4
         ELSE 5 END                          AS bucket
  FROM person p
  JOIN accident a
    ON a.ST_CASE = p.ST_CASE
  WHERE p.INJ_SEV = 4
    AND a.RUR_URB IN (1, 2)
    AND (p.DOA IN (7, 8) OR p.LAG_HRS < 999)
)
SELECT
  lbl.label                                           AS area,
  ELT(d.bucket, 'At the scene', 'On the way to hospital',
      'Within 1 hour (hospital)', '1-23 hours later',
      '1+ days later')                                AS when_died,
  COUNT(*)                                            AS deaths,
  ROUND(100 * COUNT(*)
            / SUM(COUNT(*)) OVER (PARTITION BY d.RUR_URB), 1)
                                                      AS pct_of_area_deaths
FROM deaths d
JOIN code_labels lbl
  ON lbl.`column` = 'RUR_URB'
 AND lbl.code     = CAST(d.RUR_URB AS CHAR)
GROUP BY d.RUR_URB, lbl.label, d.bucket
ORDER BY d.RUR_URB, d.bucket;
