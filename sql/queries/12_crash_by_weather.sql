USE fars;

# Plot crashes and deaths by weather condition.
SELECT l.label AS weather,
       COUNT(*) AS crashes,
       SUM(a.FATALS) AS deaths
FROM accident a
LEFT JOIN code_labels l ON l.column = 'WEATHER' AND l.code = a.WEATHER
GROUP BY l.label
ORDER BY crashes DESC;
