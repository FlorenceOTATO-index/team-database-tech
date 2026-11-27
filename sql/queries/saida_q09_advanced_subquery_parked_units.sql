-- ======================================================================
-- Q09 (advanced — SUBQUERY): Are crashes that involve a parked or
-- working vehicle deadlier than other crashes?
-- Author: Saida Mahmood
-- Technique: subquery with IN inside a CASE expression, GROUP BY,
-- AVG and SUM.
--
-- Why it matters: a parked or working vehicle (a stopped truck, a
-- maintenance vehicle) is a stationary obstacle. This asks whether
-- hitting one is worse than a crash with only moving vehicles.
--
-- This is the one part of the schema I added: parkwork and vehicle are
-- the two subtypes of crash_unit, and parkwork holds the 1,526 units
-- that were not in transport. Nobody else's query touches that table.
-- ======================================================================

USE fars;

SELECT
    CASE WHEN a.ST_CASE IN (SELECT ST_CASE FROM parkwork)
         THEN 'Parked or working vehicle involved'
         ELSE 'Moving vehicles only'
    END                             AS crash_type,
    COUNT(*)                        AS crashes,
    SUM(a.FATALS)                   AS deaths,
    ROUND(AVG(a.FATALS), 2)         AS avg_deaths_per_crash
FROM accident a
GROUP BY crash_type
ORDER BY crashes DESC;


-- ----------------------------------------------------------------------
-- How I built it:
--
--   1. The subquery (SELECT ST_CASE FROM parkwork) is the list of crashes
--      that had at least one parked or working unit.
--   2. IN tests each accident against that list, and CASE turns the
--      true/false into a readable label.
--   3. GROUP BY that label gives two rows: with and without.
--
-- Why IN and not EXISTS: both work here. EXISTS is the safer habit,
-- because NOT IN returns nothing at all if the subquery ever yields a
-- NULL. ST_CASE is NOT NULL in parkwork, so IN is safe in this case.
--
-- The EXISTS version, if you are asked for it:
--
--   CASE WHEN EXISTS (SELECT 1 FROM parkwork pw
--                     WHERE pw.ST_CASE = a.ST_CASE)
--        THEN 'Parked or working vehicle involved'
--        ELSE 'Moving vehicles only' END
-- ----------------------------------------------------------------------

-- CHECK: the two crash counts must add up to 36,297.

-- RESULT (run 2026-11-27)
--
--                                    crashes   deaths   avg deaths
--   Moving vehicles only              35,227   38,075      1.08
--   Parked or working vehicle          1,070    1,179      1.10
--   -------------------------------------------------------------
--   TOTAL                             36,297   39,254
--
--   Parked or working vehicles are in 2.9% of all fatal crashes.
--   The difference in average deaths is 0.02 - effectively nothing.
--
-- CHECK PASSES: 35,227 + 1,070 = 36,297, the full crash count. Every
-- crash is counted once and only once.
--
-- Slide line: "About 3% of fatal crashes involved a parked or working
-- vehicle - 1,070 crashes. They were no deadlier than ordinary ones:
-- 1.10 deaths against 1.08. The point is that we can ask the question
-- at all, because parkwork only exists after we split crash units into
-- moving and non-moving in the schema design."
--
-- THIS IS A NULL RESULT, AND THAT IS FINE. Say so plainly. Two honest
-- reasons the numbers are so close:
--   1. FARS only holds crashes that killed someone, so every crash here
--      already has at least 1 death. Average deaths per crash can only
--      run upward from 1, and the overall average is 1.08. There is
--      almost no room for the measure to move.
--   2. The two groups are not the same kind of crash, so even a real
--      difference would describe the groups - it would not prove the
--      parked vehicle made the crash worse.
--
-- Worth knowing: parkwork holds 1,526 units but they fall in only 1,070
-- distinct crashes, so some crashes involved more than one parked or
-- working vehicle.
--
-- THIS CLOSES THE Q07 QUESTION. Total deaths here = 39,254. Q07 found
-- 30,741 occupant deaths, which leaves 8,513 deaths among the 9,020
-- non-motorists - 94%, which is what you expect, since a pedestrian in a
-- fatal crash almost always dies. The INJ_SEV = 4 flag in the view is
-- correct.
