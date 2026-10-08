-- =====================================================================
-- DATA 201 — FARS 2024 — Saida Mahmood
-- Q3  ·  Slide 22  ·  ADVANCED  ·  Subquery (IN)
--
-- Question: Which vehicle types turn up most often in crashes
--           involving a pedestrian or cyclist?
--
-- The subquery finds the crashes; the outer query looks at the units in
-- them. BODY_TYP lives on crash_unit — the supertype — so this covers
-- parked and working units too, not just moving vehicles.
--
-- "involving", not "killed": VEH_NO = 0 marks a non-motorist who was
-- present in the crash. FARS lists everyone involved in a fatal crash,
-- so some of those pedestrians survived — the person who died may have
-- been in a vehicle.
-- =====================================================================

USE fars;

SELECT
    cl.label   AS body_type,
    COUNT(*)   AS units_involved
FROM crash_unit cu
JOIN code_labels cl
  ON cl.`column` = 'BODY_TYP'
 AND cl.code = CAST(cu.BODY_TYP AS CHAR)
WHERE cu.ST_CASE IN (SELECT ST_CASE FROM person WHERE VEH_NO = 0)
GROUP BY cl.label
ORDER BY units_involved DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- RESULT (run 2026-10-08)
--
--   4-door sedan, hardtop                 2,561
--   Compact Utility (small/midsize SUV)   1,617
--   Light Pickup                          1,597
--   Large utility (full-size SUV)           754
--   Unknown body type                       739
--   Station Wagon                           416
--   Truck-tractor                           315
--   Minivan                                 250
--   5-door/4-door hatchback                 249
--   2-door sedan, hardtop, coupe            220
--                                        -------
--   top 10 total                          8,718
--
-- Slide line: "Ordinary passenger vehicles dominate — sedans, compact
-- SUVs and light pickups are 5,775 of the top 10's 8,718 units (66%).
-- Truck-tractors are only 315."
--
-- The finding: people assume large trucks. The data says the everyday
-- car and the light pickup are what pedestrians and cyclists meet.
--
-- Caveat to name before someone else does: "Unknown body type" at 739
-- is the fifth-largest category. That is a data-quality artifact, not
-- a kind of vehicle.
-- ---------------------------------------------------------------------

-- Worth saying out loud in Q&A: EXISTS would be the safer habit here,
-- because NOT IN returns nothing at all if the subquery yields a NULL
-- (Lecture 6, three-valued logic). IN is correct in this case because
-- ST_CASE is NOT NULL.
