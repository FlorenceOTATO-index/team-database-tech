"""SQL behind every dashboard chart.

Each chart runs one of the team's saved queries (sql/queries/), rewritten so
the dashboard's filters can be applied. `{f}` is replaced with the filter
clause for the accident table aliased `a`:

    a.MONTH BETWEEN %(m1)s AND %(m2)s [AND a.STATE = %(state)s] [AND a.RUR_URB = %(area)s]

Values are always passed as query parameters, never pasted into the SQL.
`state_filter: False` means the chart compares states, so the state filter
is not applied (the selected state is highlighted instead).
"""

CHARTS = {
    # ---------------------------------------------------------------- overview
    "kpis": {
        "file": "views.sql (v_crash_facts)", "member": "Ryan",
        "sql": """
SELECT
  COUNT(*)                                   AS crashes,
  COALESCE(SUM(a.FATALS), 0)                 AS deaths,
  (SELECT COUNT(*)
   FROM person p
   JOIN accident a ON a.ST_CASE = p.ST_CASE
   WHERE {f})                                AS people,
  COALESCE(SUM(a.drinking_driver), 0)        AS drinking_crashes,
  COALESCE(SUM(a.nonmotorist_killed), 0)     AS nonmotorist_crashes
FROM v_crash_facts a
WHERE {f}""",
    },
    "map": {
        "file": "views.sql (v_crash_facts)", "member": "Ryan",
        "sql": """
SELECT
  ROUND(a.LATITUDE, 3)   AS lat,
  ROUND(a.LONGITUD, 3)   AS lon,
  a.drinking_driver      AS drinking,
  a.is_dark              AS dark,
  a.nonmotorist_killed   AS nonmotorist
FROM v_crash_facts a
WHERE {f}
  AND a.LATITUDE BETWEEN 15 AND 72
  AND a.LONGITUD BETWEEN -180 AND -60""",
    },
    "calendar": {
        "file": "q17_holiday_deaths.sql", "member": "Ryan",
        "sql": """
SELECT
  c.MONTH,
  c.DAY,
  c.DAY_WEEK,
  COALESCE(SUM(a.FATALS), 0) AS deaths
FROM calendar c
LEFT JOIN accident a
  ON a.YEAR  = c.YEAR
 AND a.MONTH = c.MONTH
 AND a.DAY   = c.DAY
 AND {f}
GROUP BY c.MONTH, c.DAY, c.DAY_WEEK
ORDER BY c.MONTH, c.DAY""",
    },
    "heat": {
        "file": "q05_fatal_crashes_by_time.sql + 10_deadliest_days_of_weeks.sql",
        "member": "Tzu Yang & Jue",
        "sql": """
SELECT
  c.DAY_WEEK,
  a.HOUR,
  COUNT(*) AS crashes
FROM accident a
JOIN calendar c
  ON c.YEAR  = a.YEAR
 AND c.MONTH = a.MONTH
 AND c.DAY   = a.DAY
WHERE {f}
  AND a.HOUR <= 23
GROUP BY c.DAY_WEEK, a.HOUR""",
    },
    "monthly": {
        "file": "09_monthly_stats.sql", "member": "Jue",
        "sql": """
SELECT
  a.MONTH,
  COUNT(*)       AS crashes,
  SUM(a.FATALS)  AS deaths
FROM accident a
WHERE {f}
GROUP BY a.MONTH
ORDER BY a.MONTH""",
    },
    "vehstates": {
        "file": "saida_q2_basic.sql", "member": "Saida", "state_filter": False,
        "sql": """
SELECT
  a.STATE        AS state_code,
  st.label       AS state,
  COUNT(*)       AS vehicles
FROM vehicle v
JOIN accident a
  ON a.ST_CASE = v.ST_CASE
JOIN code_labels st
  ON st.`column` = 'STATE'
 AND st.code     = CAST(a.STATE AS CHAR)
WHERE {f}
GROUP BY a.STATE, st.label
ORDER BY vehicles DESC
LIMIT 10""",
    },
    # ---------------------------------------------------------------- behavior
    "tilemap": {
        "file": "q01_drinking_crashes_by_state.sql", "member": "Ryan", "state_filter": False,
        "sql": """
SELECT
  a.STATE                                    AS state_code,
  COUNT(*)                                   AS crashes,
  SUM(EXISTS (SELECT 1
              FROM vehicle v
              WHERE v.ST_CASE = a.ST_CASE
                AND v.DR_DRINK = 1))         AS drinking_crashes
FROM accident a
WHERE {f}
GROUP BY a.STATE""",
    },
    "wrongway": {
        "file": "q19_wrong_way_drivers.sql", "member": "Ryan",
        "sql": """
SELECT
  a.HOUR,
  COUNT(*)                                       AS wrong_way_crashes,
  SUM(EXISTS (SELECT 1
              FROM veh_aux x
              JOIN vehicle v
                ON v.ST_CASE = x.ST_CASE
               AND v.VEH_NO  = x.VEH_NO
              WHERE x.ST_CASE = a.ST_CASE
                AND x.A_WRONGWAYDRV = 1
                AND v.DR_DRINK = 1))             AS with_drinking_driver
FROM accident a
WHERE {f}
  AND a.HOUR <= 23
  AND EXISTS (SELECT 1
              FROM veh_aux x
              WHERE x.ST_CASE = a.ST_CASE
                AND x.A_WRONGWAYDRV = 1)
GROUP BY a.HOUR
ORDER BY a.HOUR""",
    },
    "dwi": {
        "file": "q14_prior_dwi_drinking.sql", "member": "Ryan",
        "sql": """
SELECT
  CASE WHEN v.PREV_DWI = 0 THEN 'No prior DWI'
       WHEN v.PREV_DWI = 1 THEN '1 prior DWI'
       ELSE '2+ prior DWIs' END                 AS dwi_history,
  COUNT(*)                                      AS drivers,
  SUM(v.DR_DRINK = 1)                           AS police_reported_drinking,
  SUM(p.ALC_RES < 995)                          AS bac_tested,
  SUM(p.ALC_RES BETWEEN 80 AND 994)             AS bac_08_plus
FROM vehicle v
JOIN person p
  ON p.ST_CASE = v.ST_CASE
 AND p.VEH_NO  = v.VEH_NO
 AND p.PER_TYP = 1
JOIN accident a
  ON a.ST_CASE = v.ST_CASE
WHERE {f}
  AND v.PREV_DWI < 99
GROUP BY dwi_history
ORDER BY MIN(v.PREV_DWI)""",
    },
    "alcdrug": {
        "file": "q20_alcohol_drug_overlap.sql", "member": "Ryan",
        "sql": """
WITH tested_both AS (
  SELECT p.ST_CASE, p.VEH_NO, p.PER_NO, p.ALC_RES
  FROM person p
  JOIN accident a ON a.ST_CASE = p.ST_CASE
  WHERE {f}
    AND p.PER_TYP = 1
    AND p.ALC_RES < 995
    AND EXISTS (SELECT 1 FROM drugs d
                WHERE d.ST_CASE = p.ST_CASE
                  AND d.VEH_NO  = p.VEH_NO
                  AND d.PER_NO  = p.PER_NO
                  AND d.DRUGRES NOT IN (0, 9995, 9997, 9999))
),
alcohol_pos AS (
  SELECT ST_CASE, VEH_NO, PER_NO FROM tested_both WHERE ALC_RES >= 80
),
drug_pos AS (
  SELECT DISTINCT t.ST_CASE, t.VEH_NO, t.PER_NO
  FROM tested_both t
  JOIN drugs d
    ON d.ST_CASE = t.ST_CASE
   AND d.VEH_NO  = t.VEH_NO
   AND d.PER_NO  = t.PER_NO
  WHERE (d.DRUGRES BETWEEN 1000 AND 7999 OR d.DRUGRES = 9998)
    AND d.DRUGRES NOT IN (3026, 3034, 3066)
)
SELECT 'Alcohol 0.08+ and drugs' AS result, COUNT(*) AS drivers
FROM (SELECT * FROM alcohol_pos INTERSECT SELECT * FROM drug_pos) AS both_pos
UNION ALL
SELECT 'Alcohol 0.08+ only', COUNT(*)
FROM (SELECT * FROM alcohol_pos EXCEPT SELECT * FROM drug_pos) AS alcohol_only
UNION ALL
SELECT 'Drugs only', COUNT(*)
FROM (SELECT * FROM drug_pos EXCEPT SELECT * FROM alcohol_pos) AS drugs_only
UNION ALL
SELECT 'Neither',
       (SELECT COUNT(*) FROM tested_both)
     - (SELECT COUNT(*) FROM (SELECT * FROM alcohol_pos
                              UNION
                              SELECT * FROM drug_pos) AS any_pos)""",
    },
    "combos": {
        "file": "q22_drinking_speeding_after_dark.sql", "member": "Ryan",
        "sql": """
WITH crashes AS (
  SELECT
    IF(a.is_dark, 'Dark', 'Daylight')                  AS light,
    CASE WHEN a.drinking_driver AND a.speeding THEN '1 Drinking + speeding'
         WHEN a.drinking_driver                THEN '2 Drinking only'
         WHEN a.speeding                       THEN '3 Speeding only'
         ELSE                                       '4 Neither' END AS combo,
    a.FATALS
  FROM v_crash_facts a
  WHERE {f}
    AND a.LGT_COND IN (1, 2, 3, 6)
)
SELECT
  IF(GROUPING(light) = 1, 'All', light)                AS light,
  IF(GROUPING(combo) = 1, 'All crashes',
     SUBSTRING(combo, 3))                              AS risk_factors,
  COUNT(*)                                             AS crashes,
  ROUND(100 * COUNT(*)
            / MAX(COUNT(*)) OVER (PARTITION BY GROUPING(light), light), 1)
                                                       AS pct_of_group
FROM crashes
GROUP BY light, combo WITH ROLLUP
ORDER BY GROUPING(light), light DESC, GROUPING(combo), combo""",
    },
    "speeding": {
        "file": "q07_speeding_by_vehicle_count.sql", "member": "Tzu Yang",
        "sql": """
SELECT
  CASE WHEN a.VE_FORMS = 1 THEN 'One vehicle'
       ELSE 'Multiple vehicles' END          AS crash_type,
  COUNT(*)                                   AS vehicles_known_status,
  SUM(v.SPEEDREL IN (2, 3, 4, 5))            AS vehicles_speeding
FROM accident a
JOIN vehicle v
  ON a.ST_CASE = v.ST_CASE
WHERE {f}
  AND v.SPEEDREL IN (0, 2, 3, 4, 5)
GROUP BY crash_type
ORDER BY MIN(a.VE_FORMS)""",
    },
    # ---------------------------------------------------------------- survival
    "seatbelt": {
        "file": "q13_seatbelt_survival.sql", "member": "Ryan",
        "sql": """
SELECT
  CASE WHEN p.REST_USE IN (1, 2, 3) THEN 'Belted'
       ELSE 'Unbelted' END                   AS restraint,
  COUNT(*)                                   AS occupants,
  SUM(p.INJ_SEV = 4)                         AS killed,
  SUM(p.EJECTION IN (1, 2, 3))               AS ejected
FROM person p
JOIN crash_unit cu
  ON cu.ST_CASE = p.ST_CASE
 AND cu.VEH_NO  = p.VEH_NO
JOIN accident a
  ON a.ST_CASE = p.ST_CASE
WHERE {f}
  AND p.PER_TYP IN (1, 2)
  AND cu.BODY_TYP BETWEEN 1 AND 49
  AND p.REST_USE IN (1, 2, 3, 20)
GROUP BY restraint""",
    },
    "vehage": {
        "file": "q15_vehicle_age_survival.sql", "member": "Ryan",
        "sql": """
WITH occupants AS (
  SELECT
    CASE WHEN cu.MOD_YEAR <= 2004 THEN 1
         WHEN cu.MOD_YEAR <= 2009 THEN 2
         WHEN cu.MOD_YEAR <= 2014 THEN 3
         WHEN cu.MOD_YEAR <= 2019 THEN 4
         ELSE 5 END                        AS band_order,
    p.REST_USE IN (1, 2, 3)                AS belted,
    p.INJ_SEV = 4                          AS killed
  FROM person p
  JOIN crash_unit cu
    ON cu.ST_CASE = p.ST_CASE
   AND cu.VEH_NO  = p.VEH_NO
  JOIN accident a
    ON a.ST_CASE = p.ST_CASE
  WHERE {f}
    AND p.PER_TYP IN (1, 2)
    AND cu.BODY_TYP BETWEEN 1 AND 49
    AND cu.MOD_YEAR BETWEEN 1950 AND 2025
    AND p.REST_USE IN (1, 2, 3, 20)
)
SELECT
  band_order,
  COUNT(*)                         AS occupants,
  SUM(belted)                      AS belted,
  SUM(killed AND belted)           AS killed_belted,
  SUM(NOT belted)                  AS unbelted,
  SUM(killed AND NOT belted)       AS killed_unbelted
FROM occupants
GROUP BY band_order
ORDER BY band_order""",
    },
    "timing": {
        "file": "q16_rural_urban_time_of_death.sql", "member": "Ryan",
        "sql": """
WITH deaths AS (
  SELECT
    a.RUR_URB,
    CASE WHEN p.DOA = 7      THEN 1
         WHEN p.DOA = 8      THEN 2
         WHEN p.LAG_HRS = 0  THEN 3
         WHEN p.LAG_HRS < 24 THEN 4
         ELSE 5 END                          AS bucket
  FROM person p
  JOIN accident a
    ON a.ST_CASE = p.ST_CASE
  WHERE {f}
    AND p.INJ_SEV = 4
    AND a.RUR_URB IN (1, 2)
    AND (p.DOA IN (7, 8) OR p.LAG_HRS < 999)
)
SELECT
  RUR_URB,
  bucket,
  COUNT(*)                                                   AS deaths,
  ROUND(100 * COUNT(*)
            / SUM(COUNT(*)) OVER (PARTITION BY RUR_URB), 1)  AS pct_of_area_deaths
FROM deaths
GROUP BY RUR_URB, bucket
ORDER BY RUR_URB, bucket""",
    },
    "ems": {
        "file": "q03_ems_response_rural_urban.sql", "member": "Ryan",
        "sql": """
WITH response AS (
  SELECT
    a.RUR_URB,
    CAST(a.ARR_HOUR * 60 + a.ARR_MIN AS SIGNED)
      - CAST(a.NOT_HOUR * 60 + a.NOT_MIN AS SIGNED) AS raw_minutes
  FROM accident a
  WHERE {f}
    AND a.RUR_URB IN (1, 2)
    AND a.NOT_HOUR <= 23 AND a.NOT_MIN <= 59
    AND a.ARR_HOUR <= 23 AND a.ARR_MIN <= 59
),
cleaned AS (
  SELECT
    RUR_URB,
    CASE WHEN raw_minutes < 0 THEN raw_minutes + 1440 ELSE raw_minutes END AS minutes
  FROM response
  WHERE raw_minutes >= 0
     OR raw_minutes + 1440 <= 120
),
ranked AS (
  SELECT
    RUR_URB,
    minutes,
    ROW_NUMBER() OVER (PARTITION BY RUR_URB ORDER BY minutes) AS rn,
    COUNT(*)     OVER (PARTITION BY RUR_URB)                  AS n
  FROM cleaned
)
SELECT
  RUR_URB,
  COUNT(*)                     AS crashes_with_valid_times,
  ROUND(AVG(minutes), 1)       AS avg_response_min,
  AVG(CASE WHEN rn IN (FLOOR((n + 1) / 2), CEIL((n + 1) / 2))
           THEN minutes END)   AS median_response_min
FROM ranked
GROUP BY RUR_URB
ORDER BY RUR_URB""",
    },
    "nonmotor": {
        "file": "saida_q4_advanced.sql", "member": "Saida",
        "sql": """
WITH classified AS (
  SELECT
    a.HOUR,
    CASE WHEN p.VEH_NO = 0 THEN 'Non-motorist' ELSE 'Occupant' END AS person_type
  FROM person p
  JOIN accident a
    ON a.ST_CASE = p.ST_CASE
  WHERE {f}
    AND a.HOUR BETWEEN 0 AND 23
)
SELECT
  CASE WHEN HOUR BETWEEN  0 AND  5 THEN 'Night (12–5 am)'
       WHEN HOUR BETWEEN  6 AND 11 THEN 'Morning (6–11 am)'
       WHEN HOUR BETWEEN 12 AND 17 THEN 'Afternoon (12–5 pm)'
       ELSE                              'Evening (6–11 pm)' END  AS time_of_day,
  COUNT(*)                                       AS people,
  SUM(person_type = 'Non-motorist')              AS non_motorists
FROM classified
GROUP BY time_of_day
ORDER BY SUM(person_type = 'Non-motorist') / COUNT(*) DESC""",
    },
    "bodies": {
        "file": "saida_q3_advanced.sql", "member": "Saida",
        "sql": """
SELECT
  cl.label   AS body_type,
  COUNT(*)   AS units_involved
FROM crash_unit cu
JOIN accident a
  ON a.ST_CASE = cu.ST_CASE
JOIN code_labels cl
  ON cl.`column` = 'BODY_TYP'
 AND cl.code     = CAST(cu.BODY_TYP AS CHAR)
WHERE {f}
  AND cu.ST_CASE IN (SELECT ST_CASE FROM person WHERE VEH_NO = 0)
GROUP BY cl.label
ORDER BY units_involved DESC
LIMIT 6""",
    },
    "weather": {
        "file": "11_weather_when_avg_death.sql", "member": "Jue",
        "sql": """
WITH w AS (
  SELECT a.WEATHER, COUNT(*) AS crashes, SUM(a.FATALS) AS deaths
  FROM accident a
  WHERE {f}
  GROUP BY a.WEATHER
)
SELECT
  l.label                                              AS weather,
  w.crashes,
  w.deaths,
  ROUND(w.deaths / w.crashes, 3)                       AS deaths_per_crash,
  ROUND((SELECT SUM(deaths) / SUM(crashes) FROM w), 3) AS overall_deaths_per_crash
FROM w
LEFT JOIN code_labels l
  ON l.`column` = 'WEATHER'
 AND l.code     = CAST(w.WEATHER AS CHAR)
WHERE w.WEATHER NOT IN (98, 99)
  AND w.crashes >= 20
ORDER BY deaths_per_crash DESC""",
    },
    "rollover": {
        "file": "q08_rollover_by_vehicle_count.sql", "member": "Tzu Yang",
        "sql": """
SELECT
  CASE WHEN a.VE_FORMS = 1 THEN 'One vehicle'
       ELSE 'Multiple vehicles' END          AS crash_type,
  COUNT(*)                                   AS vehicles_rollover_applicable,
  SUM(cu.ROLLOVER = 3)                       AS vehicles_rolled_over
FROM accident a
JOIN vehicle v
  ON a.ST_CASE = v.ST_CASE
JOIN crash_unit cu
  ON v.ST_CASE = cu.ST_CASE
 AND v.VEH_NO  = cu.VEH_NO
WHERE {f}
  AND cu.ROLLOVER IN (0, 3)
GROUP BY crash_type
ORDER BY MIN(a.VE_FORMS)""",
    },
}


# Where each chart's SQL comes from (paths are relative to sql/), and how the
# dashboard version differs from the saved file. Shown in each chart's SQL panel.
SOURCES = {
    "kpis": (["schema/views.sql"],
             "Counts from the saved view v_crash_facts. Its 8,990 drinking-driver crashes match q01's national total."),
    "map": (["schema/views.sql"],
            "Coordinates and risk flags straight from the saved view v_crash_facts, with the dashboard filters applied."),
    "calendar": (["queries/q17_holiday_deaths.sql"],
                 "Same daily death totals as q17. The chart compares each holiday with the average for its weekday, as q17 does."),
    "heat": (["queries/q05_fatal_crashes_by_time.sql", "queries/10_deadliest_days_of_weeks.sql"],
             "Combines q05 (crashes by hour) and q10 (by day of week) into one weekday × hour grid. "
             "Each column adds up to q05's count for that hour."),
    "monthly": (["queries/09_monthly_stats.sql"],
                "Same monthly crash counts as q09. Deaths are summed from accident directly, so each crash's deaths count once."),
    "vehstates": (["queries/saida_q2_basic.sql"],
                  "saida_q2 showing the top 10 states instead of the top 5."),
    "tilemap": (["queries/q01_drinking_crashes_by_state.sql"],
                "q01's drinking-driver share for every state (the saved file lists the top 10). "
                "It uses EXISTS once per crash instead of COUNT(DISTINCT); the counts are the same."),
    "wrongway": (["queries/q19_wrong_way_drivers.sql"],
                 "q19 broken out by hour instead of four time bands."),
    "dwi": (["queries/q14_prior_dwi_drinking.sql"],
            "q14 returning the raw counts; the chart computes the percentages."),
    "alcdrug": (["queries/q20_alcohol_drug_overlap.sql"],
                "q20's INTERSECT / EXCEPT logic, with the dashboard filters added inside tested_both."),
    "combos": (["queries/q22_drinking_speeding_after_dark.sql", "schema/views.sql"],
               "q22 as saved (on the view v_crash_facts), plus the dashboard filters."),
    "speeding": (["queries/q07_speeding_by_vehicle_count.sql"],
                 "q07 returning the raw counts; the chart computes the percentages."),
    "seatbelt": (["queries/q13_seatbelt_survival.sql"],
                 "q13 returning the raw counts; the chart computes the percentages."),
    "vehage": (["queries/q15_vehicle_age_survival.sql"],
               "q15's CTE returning counts per model-year band; the chart computes the death rates "
               "(the saved file does that step in SQL with LAG)."),
    "timing": (["queries/q16_rural_urban_time_of_death.sql"],
               "q16 as saved, plus the dashboard filters."),
    "ems": (["queries/q03_ems_response_rural_urban.sql"],
            "q03 as saved, plus the dashboard filters."),
    "nonmotor": (["queries/saida_q4_advanced.sql"],
                 "saida_q4 returning the raw counts, plus the dashboard filters."),
    "bodies": (["queries/saida_q3_advanced.sql"],
               "saida_q3 (top 6 of its top 10), plus the dashboard filters."),
    "weather": (["queries/11_weather_when_avg_death.sql"],
                "q11 showing every weather type with at least 20 crashes, with the average marked; "
                "the saved file lists only the ones above average."),
    "rollover": (["queries/q08_rollover_by_vehicle_count.sql"],
                 "q08 returning the raw counts; the chart computes the percentages."),
}
