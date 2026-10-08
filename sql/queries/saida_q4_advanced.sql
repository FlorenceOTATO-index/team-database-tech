-- =====================================================================
-- DATA 201 — FARS 2024 — Saida Mahmood
-- Q4  ·  Slide 23  ·  ADVANCED  ·  CTE + CASE
--
-- Question: Are pedestrians and cyclists a bigger share of the people
--           in fatal crashes after dark?
--
-- The CTE labels every person as occupant or non-motorist; the outer
-- query buckets the hour and measures the share.
--
-- "people in fatal crashes", not "deaths": the person table lists
-- everyone involved in a fatal crash, not only those who died.
--
-- HOUR = 99 means unknown in FARS, so BETWEEN 0 AND 23 drops it.
-- =====================================================================

USE fars;

WITH classified AS (
    SELECT
        a.HOUR,
        CASE WHEN p.VEH_NO = 0 THEN 'Non-motorist' ELSE 'Occupant' END AS person_type
    FROM person p
    JOIN accident a
      ON a.ST_CASE = p.ST_CASE
    WHERE a.HOUR BETWEEN 0 AND 23
)
SELECT
    CASE WHEN HOUR BETWEEN  0 AND  5 THEN 'Night (00-05)'
         WHEN HOUR BETWEEN  6 AND 11 THEN 'Morning (06-11)'
         WHEN HOUR BETWEEN 12 AND 17 THEN 'Afternoon (12-17)'
         ELSE                              'Evening (18-23)'
    END                                               AS time_of_day,
    COUNT(*)                                          AS people,
    SUM(person_type = 'Non-motorist')                 AS non_motorists,
    ROUND(100 * AVG(person_type = 'Non-motorist'), 1) AS pct_non_motorist
FROM classified
GROUP BY time_of_day
ORDER BY pct_non_motorist DESC;


-- ---------------------------------------------------------------------
-- RESULT (run 2026-10-08)
--
--   time_of_day         people   non_motorists   pct
--   Evening (18-23)     29,691           4,178   14.1
--   Night   (00-05)     16,492           2,146   13.0
--   Morning (06-11)     15,795           1,244    7.9
--   Afternoon (12-17)   25,972           1,398    5.4
--                       ------          ------
--   total               87,950           8,966
--
-- Answer: yes. Non-motorists are 14.1% of people in evening crashes and
-- 13.0% overnight, against 5.4% in the afternoon — about 2.6x
-- over-represented after dark.
--
-- Slide line: "Pedestrians and cyclists are 14.1% of people in evening
-- fatal crashes and 13.0% overnight, but only 5.4% in the afternoon."
--
-- CONSISTENCY CHECK (good answer if asked what the filter cost):
--   person table totals     88,326 people / 9,020 non-motorists
--   rows above               87,950 people / 8,966 non-motorists
--   difference                  376 people /    54 non-motorists
--   = the HOUR = 99 "unknown time" rows the WHERE clause drops.
--
-- Caveat to have ready: this is a share, not a rate. It says
-- non-motorists make up more of the people in after-dark crashes — not
-- that walking at night is 2.6x more dangerous, because we do not know
-- how many people were out walking at each hour.
-- ---------------------------------------------------------------------
