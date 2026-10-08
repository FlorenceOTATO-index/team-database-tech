-- ======================================================================
-- Q01 (basic): Which states have the most fatal crashes involving a
-- drinking driver?
-- Author: Ryan Williams
-- Technique: three-table JOIN, GROUP BY, COUNT(DISTINCT) with conditional
-- counting.
--
-- FARS only records crashes with at least one death, so every crash here
-- is a fatal crash.
--
-- DR_DRINK = 1 means police reported the driver had been drinking. It is
-- not a measured BAC and not a finding of cause: FARS records who was
-- involved, not who caused the crash. A crash counts once even if
-- several of its drivers were drinking, hence COUNT(DISTINCT ST_CASE).
-- Every crash has at least one in-transport vehicle, so the inner join
-- keeps all crashes and fatal_crashes is the state's full total.
-- ======================================================================

USE fars;

SELECT
  st.label                                              AS state,
  COUNT(DISTINCT a.ST_CASE)                             AS fatal_crashes,
  COUNT(DISTINCT CASE WHEN v.DR_DRINK = 1
                      THEN a.ST_CASE END)               AS drinking_driver_crashes,
  ROUND(100 * COUNT(DISTINCT CASE WHEN v.DR_DRINK = 1
                                  THEN a.ST_CASE END)
            / COUNT(DISTINCT a.ST_CASE), 1)             AS pct_drinking_driver
FROM accident a
JOIN vehicle v
  ON v.ST_CASE = a.ST_CASE
JOIN code_labels st
  ON st.`column` = 'STATE'
 AND st.code     = CAST(a.STATE AS CHAR)
GROUP BY st.label
ORDER BY drinking_driver_crashes DESC
LIMIT 10;
