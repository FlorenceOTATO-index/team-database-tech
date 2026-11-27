-- ======================================================================
-- Q10 (advanced — CTE): How do school-bus-related crashes compare with
-- all other fatal crashes?
-- Author: Saida Mahmood
-- Technique: CTE (WITH) to label the crashes once, then aggregate, plus
-- a scalar subquery for the overall average to compare against.
--
-- Why it matters: school-bus crashes are rare but they are the ones the
-- public cares most about. The question is whether they are deadlier
-- than an ordinary fatal crash, or just more visible.
--
-- SCH_BUS = 1 means a school bus was involved in the crash.
-- ======================================================================

USE fars;

WITH labelled AS (
    SELECT
        CASE WHEN SCH_BUS = 1 THEN 'School bus involved'
             ELSE 'No school bus'
        END         AS crash_type,
        FATALS,
        PERSONS
    FROM accident
)
SELECT
    crash_type,
    COUNT(*)                        AS crashes,
    SUM(FATALS)                     AS deaths,
    ROUND(AVG(FATALS), 2)           AS avg_deaths,
    ROUND(AVG(PERSONS), 1)          AS avg_people_involved,
    (SELECT ROUND(AVG(FATALS), 2) FROM accident) AS overall_avg_deaths
FROM labelled
GROUP BY crash_type
ORDER BY crashes DESC;


-- ----------------------------------------------------------------------
-- How I built it:
--
--   1. The CTE labels every crash once. Without it I would have to repeat
--      the same CASE expression in the SELECT and in the GROUP BY.
--   2. The outer query aggregates those two groups.
--   3. The scalar subquery puts the overall average on every row, so the
--      comparison is visible without doing arithmetic in my head.
--
-- Why a CTE and not a subquery in the FROM clause: they do the same job
-- here. The CTE is named, so the query reads top to bottom — label the
-- rows, then summarise them — which is easier to follow on a slide.
-- ----------------------------------------------------------------------

-- RESULT (run 2026-11-27)
--
--                        crashes   deaths   avg deaths   avg people
--   No school bus         36,205   39,144      1.08         2.2
--   School bus involved       92      110      1.20         4.3
--   ---------------------------------------------------------------
--   TOTAL                 36,297   39,254     (overall avg 1.08)
--
--   School buses are in 92 crashes - one quarter of one percent.
--
-- BOTH CHECKS PASS: 36,205 + 92 = 36,297 crashes, and
-- 39,144 + 110 = 39,254 deaths, the same total Q09 produced.
--
-- THE FINDING - the two averages disagree, and that is the whole point:
--   * twice as many people involved   (4.3 against 2.2)
--   * only slightly more deaths       (1.20 against 1.08, 11% more)
--
--   So dividing deaths by people involved rather than by crashes:
--     school bus   ~110 deaths among ~395 people  ->  about 28% died
--     no bus    ~39,144 deaths among ~79,700      ->  about 49% died
--   (avg people is rounded to one decimal, so these are approximate -
--    but the gap is far too large for rounding to explain.)
--
-- Slide line: "School buses show up in 92 fatal crashes. Those crashes
-- involved twice as many people - 4.3 against 2.2 - but only 11% more
-- deaths. Counted per person instead of per crash, about 28% of the
-- people involved died, against 49% everywhere else. A bus carries a lot
-- of people and most of them walk away."
--
-- CAVEATS:
--   1. 92 crashes is a very small group. Say the number out loud so
--      nobody thinks it is a large sample.
--   2. SCH_BUS = 1 only means a school bus was involved. This query does
--      NOT say who died - the people killed may have been in the other
--      vehicle or on foot. Answering that needs the person table filtered
--      to these 92 crashes.
--
-- Note the overall_avg_deaths column reads 1.08 on BOTH rows. That is the
-- scalar subquery doing its job: one number for the whole table, repeated
-- beside each group so the comparison needs no mental arithmetic.
