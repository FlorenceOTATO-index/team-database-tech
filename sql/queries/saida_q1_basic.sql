-- =====================================================================
-- DATA 201 — FARS 2024 — Saida Mahmood
-- Q1  ·  Slide 20  ·  BASIC     ·  SELECT + WHERE (BETWEEN)
--
-- Question: How common are crashes that kill 3 to 5 people?
--
-- FATALS is the number of people who died in that crash, so both bounds
-- are part of the question. That is why BETWEEN is the right operator
-- here rather than a one-sided comparison.
-- =====================================================================

USE fars;

SELECT COUNT(*) AS crashes_killing_3_to_5
FROM accident
WHERE FATALS BETWEEN 3 AND 5;


-- ---------------------------------------------------------------------
-- RESULT (run 2026-10-08)
--
--   crashes_killing_3_to_5 = 400     (1.1% of 36,297 fatal crashes)
--
-- Slide line:
--   "400 of 36,297 fatal crashes killed 3 to 5 people — just 1.1%."
--
-- Takeaway: multi-fatality crashes are rare. Almost every fatal crash
-- kills one or two people; the 3-to-5 band is the tail of the
-- distribution.
-- ---------------------------------------------------------------------
