-- ======================================================================
-- Q13 (basic): In fatal crashes, how much more likely were unbelted
-- car occupants to die than belted ones?
-- Author: Ryan Williams
-- Technique: JOIN on a composite key (ST_CASE, VEH_NO), CASE grouping,
-- conditional aggregation (AVG of a true/false test = a percentage).
--
-- Who is counted: drivers and passengers (PER_TYP 1, 2) of light
-- vehicles (BODY_TYP 1-49: cars, SUVs, vans, light pickups). Buses,
-- big trucks and motorcycles are left out because belts work differently
-- (or don't exist) there. BODY_TYP lives on crash_unit, so person joins
-- to it on both ST_CASE and VEH_NO; joining on ST_CASE alone would pair
-- every person with every vehicle in the crash.
--
-- REST_USE codes: 1/2/3 = shoulder and/or lap belt, 20 = none used.
-- Child seats (4, 10-12), "used, type unknown" (8), other (97) and
-- unknown (98, 99) are left out so the two groups are clean.
-- INJ_SEV = 4 is a fatal injury. EJECTION 1-3 = thrown fully or partly
-- out of the vehicle.
--
-- Caveat: FARS only has crashes where someone died, so this is the death
-- rate among people already in a fatal crash, not the risk of dying on
-- any trip. It still compares like with like: same crash severity, belt
-- or no belt.
-- ======================================================================

USE fars;

SELECT
  CASE WHEN p.REST_USE IN (1, 2, 3) THEN 'Wearing a seat belt'
       ELSE 'No restraint used' END             AS restraint,
  COUNT(*)                                      AS occupants,
  SUM(p.INJ_SEV = 4)                            AS killed,
  ROUND(100 * AVG(p.INJ_SEV = 4), 1)            AS pct_killed,
  ROUND(100 * AVG(p.EJECTION IN (1, 2, 3)), 1)  AS pct_ejected
FROM person p
JOIN crash_unit cu
  ON cu.ST_CASE = p.ST_CASE
 AND cu.VEH_NO  = p.VEH_NO
WHERE p.PER_TYP IN (1, 2)
  AND cu.BODY_TYP BETWEEN 1 AND 49
  AND p.REST_USE IN (1, 2, 3, 20)
GROUP BY restraint
ORDER BY pct_killed DESC;
