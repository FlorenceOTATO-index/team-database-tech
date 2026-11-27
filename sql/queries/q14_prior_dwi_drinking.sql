-- ======================================================================
-- Q14 (basic): Are drivers with a prior DWI conviction more likely to be
-- drunk in their fatal crash?
-- Author: Ryan Williams
-- Technique: JOIN vehicle to person on a composite key, CASE grouping,
-- conditional aggregation with two different denominators.
--
-- PREV_DWI (vehicle table) = number of prior DWI convictions on the
-- driver's record. 99 = unknown and 998 = no driver present, so both are
-- left out.
--
-- Two measures of drinking:
--  * DR_DRINK = 1: police reported the driver had been drinking. Known
--    for every driver.
--  * ALC_RES >= 80: measured BAC of 0.08 or more (ALC_RES is in
--    thousandths, so 80 = 0.080). Only about a third of drivers were
--    tested; 995-999 mean not tested / unknown, so the BAC rate is out of
--    tested drivers only.
-- The driver's person row is PER_TYP = 1 in the same vehicle, so the join
-- matches on ST_CASE and VEH_NO and returns one row per driver.
-- ======================================================================

USE fars;

SELECT
  CASE WHEN v.PREV_DWI = 0 THEN 'No prior DWI'
       WHEN v.PREV_DWI = 1 THEN '1 prior DWI'
       ELSE '2+ prior DWIs' END                       AS dwi_history,
  COUNT(*)                                            AS drivers,
  ROUND(100 * AVG(v.DR_DRINK = 1), 1)                 AS pct_police_reported_drinking,
  SUM(p.ALC_RES < 995)                                AS bac_tested,
  ROUND(100 * SUM(p.ALC_RES BETWEEN 80 AND 994)
            / SUM(p.ALC_RES < 995), 1)                AS pct_tested_bac_08_plus
FROM vehicle v
JOIN person p
  ON p.ST_CASE = v.ST_CASE
 AND p.VEH_NO  = v.VEH_NO
 AND p.PER_TYP = 1
WHERE v.PREV_DWI < 99
GROUP BY dwi_history
ORDER BY MIN(v.PREV_DWI);
