# Plot days of the week that are deadlier than the weekly average.

WITH d AS (
    SELECT c.DAY_WEEK,
           COUNT(*) AS crashes,
           SUM(a.FATALS) AS deaths
    FROM accident a
    JOIN calendar c
      ON c.YEAR = a.YEAR AND c.MONTH = a.MONTH AND c.DAY = a.DAY
    GROUP BY c.DAY_WEEK
)
SELECT d.DAY_WEEK,
       l.label AS day_name,
       d.crashes,
       d.deaths,
       ROUND(d.deaths / d.crashes, 3) AS deaths_per_crash
FROM d
LEFT JOIN code_labels l ON l.column = 'DAY_WEEK' AND l.code = d.DAY_WEEK
WHERE d.deaths / d.crashes > (SELECT SUM(deaths) / SUM(crashes) FROM d)
ORDER BY deaths_per_crash DESC;


