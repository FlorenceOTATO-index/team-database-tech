-- ======================================================================
-- Q07 (advanced — VIEW): A reusable view of vehicle occupants, with the
-- safety columns already decoded.
-- Author: Saida Mahmood
-- Technique: CREATE OR REPLACE VIEW, then a query against the view.
--
-- Why a view: three of my queries ask about vehicle occupants and all
-- three need the same joins and the same "did this person die" test.
-- Putting that in a view means it is written once, and every query that
-- uses it is short enough to read on a slide.
--
-- This is person-level. Ryan's v_crash_facts is crash-level, so the two
-- views cover different grains and do not overlap.
--
-- A view stores the query, not the data, so it can never go stale.
-- ======================================================================

USE fars;

CREATE OR REPLACE VIEW v_occupant_safety AS
SELECT
    p.ST_CASE,
    p.VEH_NO,
    p.PER_NO,
    p.AGE,
    p.SEAT_POS,
    seat.label                      AS seat_label,
    p.REST_USE,
    rest.label                      AS restraint_label,
    p.AIR_BAG,
    bag.label                       AS airbag_label,
    p.INJ_SEV,
    (p.INJ_SEV = 4)                 AS died      -- 4 = fatal injury (K)
FROM person p
LEFT JOIN code_labels seat
       ON seat.`column` = 'SEAT_POS'
      AND seat.code = CAST(p.SEAT_POS AS CHAR)
LEFT JOIN code_labels rest
       ON rest.`column` = 'REST_USE'
      AND rest.code = CAST(p.REST_USE AS CHAR)
LEFT JOIN code_labels bag
       ON bag.`column` = 'AIR_BAG'
      AND bag.code = CAST(p.AIR_BAG AS CHAR)
WHERE p.VEH_NO > 0;          -- occupants only, not pedestrians/cyclists


-- ----------------------------------------------------------------------
-- The query that uses it:
-- Q: Did the air bag deploy, and did people in those seats survive more
--    often?
-- ----------------------------------------------------------------------
SELECT
    airbag_label,
    COUNT(*)                        AS people,
    SUM(died)                       AS deaths,
    ROUND(100 * AVG(died), 1)       AS pct_died
FROM v_occupant_safety
WHERE airbag_label IS NOT NULL
GROUP BY airbag_label
HAVING COUNT(*) >= 500           -- drop tiny categories, they are noisy
ORDER BY people DESC;


-- ----------------------------------------------------------------------
-- RUN THIS ONCE BEFORE YOU TRUST THE "died" COLUMN
-- Confirm that INJ_SEV = 4 really is the fatal code in this data:
--
--   SELECT i.INJ_SEV, cl.label, COUNT(*) AS people
--   FROM person i
--   LEFT JOIN code_labels cl
--          ON cl.`column` = 'INJ_SEV' AND cl.code = CAST(i.INJ_SEV AS CHAR)
--   GROUP BY i.INJ_SEV, cl.label
--   ORDER BY i.INJ_SEV;
--
-- The row for 4 should say "Fatal Injury (K)". If it does not, change the
-- view before using it.
-- ----------------------------------------------------------------------

-- ----------------------------------------------------------------------
-- VIEW VERIFIED (2026-11-27). I exported the first 1,000 rows of the view
-- and checked them one by one:
--
--   * died = 1 on all 445 rows where INJ_SEV = 4, and 0 on all 555 other
--     rows (codes 0, 1, 2, 3 and 9). No mismatches.
--   * (ST_CASE, VEH_NO, PER_NO) is still unique - 0 duplicates in 1,000
--     rows. THIS IS THE ONE THAT MATTERS. The view has three LEFT JOINs
--     to code_labels. If any one of them matched two label rows instead
--     of one, every person would appear twice and every count in Q07 and
--     Q08 would be inflated. It does not happen.
--   * no rows with VEH_NO = 0, so the WHERE clause really is keeping
--     pedestrians and cyclists out.
--   * no blank labels - every code found a match in code_labels.
--
-- If asked how you know the view is safe: "I checked that the joins did
-- not duplicate any rows - the person key is still unique in the view."
-- ----------------------------------------------------------------------

-- CAVEAT to say out loud: this is not a controlled comparison. Air bags
-- deploy in harder crashes, so a higher death rate where the bag went off
-- does not mean the bag caused it. The number describes who died, not why.

-- RESULT (run 2026-11-27) — 8 groups of 500+ people
--
--                                    people   deaths   % died
--   Not Deployed                     39,051   12,586    32.2
--   Deployed - Combination           17,504    8,346    47.7
--   Deployment - Unknown Location     9,510    4,245    44.6
--   Deployed - Front                  6,574    3,077    46.8
--   Reported as Deployment Unknown    2,414    1,072    44.4
--   Not Reported                      2,107      650    30.8
--   Deployed - Side (door, seatback)  1,220      463    38.0
--   Deployed - Curtain (roof)           864      302    35.0
--   ------------------------------------------------------
--   TOTAL                            79,244   30,741    38.8
--
--   Grouping the four known "Deployed -" rows together:
--     air bag deployed      26,162 people,  46.6% died
--     air bag not deployed  39,051 people,  32.2% died
--     gap = 14.4 percentage points, the WRONG way round
--
-- Slide line: "People whose air bag deployed died more often - 47% against
-- 32%. That is not the air bag failing. An air bag only fires in a hard
-- enough impact, so the two groups were never in the same kind of crash."
--
-- CROSS-CHECKS (both pass):
--   * 79,244 people here + 62 people in groups the HAVING dropped
--     = 79,306, exactly the occupant count from Q06. The view is not
--     losing or duplicating anyone.
--   * 30,741 occupant deaths. FARS 2024 has about 39,000 deaths in total,
--     and 9,020 of the people in this data are non-motorists (pedestrians
--     and cyclists), nearly all of whom die. 30,741 + ~8,600 lands on the
--     right total, which is good evidence that INJ_SEV = 4 really is the
--     fatal code. Still run the check below once so you can say it.
