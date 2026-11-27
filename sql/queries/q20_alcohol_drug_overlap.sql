-- ======================================================================
-- Q20 (advanced): Among drivers tested for both, how many were over the
-- legal alcohol limit, positive for drugs, or both?
-- Author: Ryan Williams
-- Technique: set operations INTERSECT and EXCEPT (MySQL 8.0.31+), CTEs,
-- correlated EXISTS, UNION ALL to stack the results.
--
-- A driver is identified by (ST_CASE, VEH_NO, PER_NO), PER_TYP = 1.
--  * Tested for alcohol: ALC_RES below 995 (995-999 = not tested /
--    unknown). Over the limit: ALC_RES >= 80, i.e. BAC 0.08+.
--  * Tested for drugs: at least one drugs row with a real result
--    (DRUGRES not 0 = not tested, 9995/9997/9999 = not reported / result
--    unknown / unknown if tested). Code 1 = tested, none found.
--  * Drug positive: a result in classes 1000-7999 (narcotics,
--    depressants, stimulants, hallucinogens, cannabinoids, dissociatives,
--    inhalants) or 9998 (positive, type unknown). Caffeine (3026),
--    nicotine (3066) and cotinine (3034) are not counted; neither are
--    over-the-counter drugs (9001-9035).
-- Only drivers tested for BOTH are used, so the four groups add up to
-- 100%.
--
-- Set operations compare whole rows, so INTERSECT keeps drivers in both
-- lists and EXCEPT keeps drivers in the first list but not the second.
--
-- Caveat: a positive drug test shows the drug was in the body, not that
-- the driver was impaired. THC in particular can show up days after use,
-- and cannabinoids are the most common class (4,245 of the 8,237
-- drug-positive drivers). The classes also include prescription
-- medicines (e.g. antidepressants and painkillers). Tested drivers are also not a random sample (police test more often
-- when they suspect impairment), so these rates are likely higher than
-- for all drivers.
-- ======================================================================

USE fars;

WITH tested_both AS (
  SELECT p.ST_CASE, p.VEH_NO, p.PER_NO, p.ALC_RES
  FROM person p
  WHERE p.PER_TYP = 1
    AND p.ALC_RES < 995
    AND EXISTS (SELECT 1
                FROM drugs d
                WHERE d.ST_CASE = p.ST_CASE
                  AND d.VEH_NO  = p.VEH_NO
                  AND d.PER_NO  = p.PER_NO
                  AND d.DRUGRES NOT IN (0, 9995, 9997, 9999))
),
alcohol_pos AS (
  SELECT ST_CASE, VEH_NO, PER_NO
  FROM tested_both
  WHERE ALC_RES >= 80
),
drug_pos AS (
  SELECT DISTINCT t.ST_CASE, t.VEH_NO, t.PER_NO
  FROM tested_both t
  JOIN drugs d
    ON d.ST_CASE = t.ST_CASE
   AND d.VEH_NO  = t.VEH_NO
   AND d.PER_NO  = t.PER_NO
  WHERE (d.DRUGRES BETWEEN 1000 AND 7999 OR d.DRUGRES = 9998)
    AND d.DRUGRES NOT IN (3026, 3034, 3066)
),
both_pos AS (
  SELECT * FROM alcohol_pos
  INTERSECT
  SELECT * FROM drug_pos
),
alcohol_only AS (
  SELECT * FROM alcohol_pos
  EXCEPT
  SELECT * FROM drug_pos
),
drugs_only AS (
  SELECT * FROM drug_pos
  EXCEPT
  SELECT * FROM alcohol_pos
),
summary AS (
            SELECT 1 AS sort_key, 'Alcohol 0.08+ and drugs' AS result, COUNT(*) AS drivers FROM both_pos
  UNION ALL SELECT 2, 'Alcohol 0.08+ only',                     COUNT(*) FROM alcohol_only
  UNION ALL SELECT 3, 'Drugs only',                             COUNT(*) FROM drugs_only
  UNION ALL SELECT 4, 'Neither',
                   (SELECT COUNT(*) FROM tested_both)
                   - (SELECT COUNT(*) FROM (SELECT * FROM alcohol_pos
                                            UNION
                                            SELECT * FROM drug_pos) AS any_pos)
)
SELECT
  result,
  drivers,
  ROUND(100 * drivers / SUM(drivers) OVER (), 1)   AS pct_of_tested_drivers
FROM summary
ORDER BY sort_key;
