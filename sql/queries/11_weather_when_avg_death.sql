USE fars;

# Plot weather conditions with an above-average death rate.
WITH w AS (
    SELECT WEATHER, COUNT(*) AS crashes, SUM(FATALS) AS deaths
    FROM accident
    GROUP BY WEATHER
)
SELECT l.label AS weather, w.crashes, w.deaths,
       ROUND(w.deaths / w.crashes, 3) AS deaths_per_crash
FROM w
LEFT JOIN code_labels l ON l.column = 'WEATHER' AND l.code = w.WEATHER
WHERE w.deaths / w.crashes > (SELECT SUM(deaths) / SUM(crashes) FROM w)
ORDER BY deaths_per_crash DESC;
