-- =====================================================================
-- DATA 201 — FARS 2024 — Saida Mahmood
-- Q2  ·  Slide 21  ·  BASIC     ·  Multi-table JOIN + COUNT
--
-- Question: Which 5 states had the most vehicles involved in fatal
--           crashes?
--
-- Three tables, one COUNT:
--   vehicle      -> the rows being counted
--   accident     -> carries the state code for each crash
--   code_labels  -> turns that code into a readable state name
--
-- No fan-out risk: every vehicle belongs to exactly one crash, so the
-- join cannot duplicate rows. That is why the count is trustworthy.
-- =====================================================================

USE fars;

SELECT
    cl.label   AS state,
    COUNT(*)   AS vehicles_involved
FROM vehicle v
JOIN accident a
  ON a.ST_CASE = v.ST_CASE
JOIN code_labels cl
  ON cl.`column` = 'STATE'
 AND cl.code = CAST(a.STATE AS CHAR)
GROUP BY cl.label
ORDER BY vehicles_involved DESC
LIMIT 5;


-- ---------------------------------------------------------------------
-- RESULT (run 2026-10-08)
--
--   Texas            6,018
--   California       5,390
--   Florida          4,620
--   North Carolina   2,328
--   Georgia          1,983
--
--   top 5 total = 20,339 of 56,011 vehicles  (36.3%)
--
-- Slide line: "Texas leads with 6,018 vehicles involved in fatal
-- crashes; the top 5 states account for 20,339 of 56,011 — 36%."
--
-- Second observation worth making: the top three are a tier of their
-- own. Florida has 4,620, then North Carolina drops to 2,328 — roughly
-- half. The ranking tracks population, so this is a raw count, not a
-- rate: it says where the most crashes happen, not where driving is
-- most dangerous.
-- ---------------------------------------------------------------------
