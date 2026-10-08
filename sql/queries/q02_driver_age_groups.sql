-- ======================================================================
-- Q02 (basic): Which driver age group is involved in the most fatal
-- crashes?
-- Author: Ryan Williams
-- Technique: CASE to bucket ages, WHERE filtering, GROUP BY, COUNT.
--
-- Drivers only (PER_TYP = 1). AGE 998/999 are "not reported"/"unknown"
-- and would otherwise show up as a fake age group.
-- ======================================================================

USE fars;

SELECT
  CASE
    WHEN AGE < 16 THEN 'Under 16'
    WHEN AGE <= 20 THEN '16-20'
    WHEN AGE <= 24 THEN '21-24'
    WHEN AGE <= 34 THEN '25-34'
    WHEN AGE <= 44 THEN '35-44'
    WHEN AGE <= 54 THEN '45-54'
    WHEN AGE <= 64 THEN '55-64'
    WHEN AGE <= 74 THEN '65-74'
    ELSE '75+'
  END        AS age_group,
  COUNT(*)   AS drivers_in_fatal_crashes
FROM person
WHERE PER_TYP = 1
  AND AGE NOT IN (998, 999)
GROUP BY age_group
ORDER BY drivers_in_fatal_crashes DESC;
