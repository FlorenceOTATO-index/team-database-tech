USE fars;

# Plot monthly crashes, persons involved, and deaths.
SELECT a.MONTH,
       COUNT(DISTINCT a.ST_CASE) AS crashes,
       COUNT(p.PER_NO) AS persons_involved,
       SUM(a.FATALS) AS deaths
FROM accident a
LEFT JOIN person p ON p.ST_CASE = a.ST_CASE
GROUP BY a.MONTH
ORDER BY a.MONTH;
