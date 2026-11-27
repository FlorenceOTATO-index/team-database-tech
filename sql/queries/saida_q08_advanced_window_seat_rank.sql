-- ======================================================================
-- Q08 (advanced — WINDOW FUNCTION): Which seat is the most dangerous?
-- Author: Saida Mahmood
-- Technique: RANK() OVER (ORDER BY ...) on top of a GROUP BY, reading
-- from my view v_occupant_safety.
--
-- Why a window function: I want each seat's death rate AND its position
-- in the ranking in the same row. A plain ORDER BY sorts the rows but
-- does not give me a rank number I can show or filter on. RANK() adds
-- that number without a second query.
--
-- Run saida_q07 first — it creates the view this reads from.
-- ======================================================================

USE fars;

SELECT
    seat_label,
    COUNT(*)                                        AS people,
    SUM(died)                                       AS deaths,
    ROUND(100 * AVG(died), 1)                       AS pct_died,
    RANK() OVER (ORDER BY AVG(died) DESC)           AS risk_rank
FROM v_occupant_safety
WHERE seat_label IS NOT NULL
GROUP BY seat_label
HAVING COUNT(*) >= 500          -- rare seats give unstable percentages
ORDER BY risk_rank;


-- ----------------------------------------------------------------------
-- How I built it, step by step (for the "technical interview" part):
--
--   1. Start from the view, one row per vehicle occupant.
--   2. GROUP BY seat_label  -> one row per seat position.
--   3. AVG(died) is the death rate. In MySQL a true/false test is 1 or 0,
--      so averaging it gives the proportion directly.
--   4. RANK() OVER (ORDER BY AVG(died) DESC) numbers those groups from
--      most to least deadly. The window runs AFTER the grouping, so it
--      ranks the groups, not the individual people.
--   5. HAVING drops seats with fewer than 500 people, because a seat with
--      12 occupants can show 100% and sit at the top for no real reason.
-- ----------------------------------------------------------------------

-- RESULT (run 2026-11-27) — 7 seats with 500+ people
--
--   rank  seat                              people  deaths  % died
--    1    Front Seat, Left Side (driver)    55,857  24,680   44.2
--    2    Reported as Unknown                  691     260   37.6
--    3    Front Seat, Right Side            12,235   3,620   29.6
--    4    Second Seat, Left Side             3,562     865   24.3
--    5    Second Seat, Right Side            3,766     780   20.7
--    6    Second Seat, Middle                1,022     200   19.6
--    7    Other Passenger, enclosed area       609      68   11.2
--   ---------------------------------------------------------------
--        TOTAL                              77,742  30,473   39.2
--
--   Front row  68,092 people, 41.6% died
--   Second row  8,350 people, 22.1% died   -> front row is 1.9x deadlier
--
-- Slide line: "The driver's seat is both the most crowded and the most
-- deadly - 44% of drivers died, against 30% in the front passenger seat.
-- But the real gap is front against back: the second row is about half
-- as deadly as the front row."
--
-- WHAT THIS ADDS TO Q06, and what to say if asked:
--   Q06 counted people and the driver's seat came first. Q08 measures a
--   RATE and the driver's seat comes first again - so the ranking did not
--   flip. What changed is the SIZE of the claim, and that is the point:
--     * by count, the driver's seat holds 4.6x more people than the front
--       passenger seat
--     * by rate, a driver is only 1.5x more likely to die
--   The count was telling us where people sit, not how risky a seat is.
--   And the rate shows something counting could never show at all: the
--   back seat is roughly half as deadly as the front.
--
-- CROSS-CHECK (passes): these 7 seats hold 77,742 people. Q06 found 79,306
-- occupants in total, and the groups below 500 (Not Reported 275, Third
-- Left 222, Third Right 217 and the rest) account for the other 1,564.
-- Every seat count here matches Q06 row for row, so the view is reading
-- the person table correctly.
--
-- CAVEATS, both worth saying out loud:
--   1. This is a death rate among people already in a fatal crash. It is
--      not the risk of dying on an ordinary trip.
--   2. "Reported as Unknown" sits at rank 2 with 691 people. That is a
--      missing-data category, not a real seat - do not read anything into
--      where it ranks.
