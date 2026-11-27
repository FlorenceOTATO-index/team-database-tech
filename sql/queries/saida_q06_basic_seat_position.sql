-- ======================================================================
-- Q06 (basic): Where were people sitting in fatal crashes?
-- Author: Saida Mahmood
-- Technique: two-table join to a lookup, WHERE filter, GROUP BY, COUNT,
-- ORDER BY, LIMIT.
--
-- Why it matters: seat position is the simplest thing a passenger can
-- control. Before we can ask which seat is safest (Q08), we need to know
-- how many people sat where.
--
-- VEH_NO > 0 keeps vehicle occupants only. VEH_NO = 0 is a non-motorist
-- (pedestrian or cyclist), who has no seat.
-- ======================================================================

USE fars;

SELECT
    cl.label    AS seat_position,
    COUNT(*)    AS people
FROM person p
JOIN code_labels cl
  ON cl.`column` = 'SEAT_POS'
 AND cl.code = CAST(p.SEAT_POS AS CHAR)
WHERE p.VEH_NO > 0
GROUP BY cl.label
ORDER BY people DESC
LIMIT 10;


-- ----------------------------------------------------------------------
-- FALLBACK if code_labels has no SEAT_POS rows (shows codes, not names):
--
--   SELECT SEAT_POS, COUNT(*) AS people
--   FROM person
--   WHERE VEH_NO > 0
--   GROUP BY SEAT_POS
--   ORDER BY people DESC
--   LIMIT 10;
-- ----------------------------------------------------------------------

-- RESULT (run 2026-11-27)
--
--   seat_position                        people    share
--   Front Seat, Left Side (driver)       55,857    70.4%
--   Front Seat, Right Side               12,235    15.4%
--   Second Seat, Right Side               3,766     4.7%
--   Second Seat, Left Side                3,562     4.5%
--   Second Seat, Middle                   1,022     1.3%
--   Reported as Unknown                     691
--   Other passenger, enclosed area          609
--   Not Reported                            275
--   Third Seat, Left Side                   222
--   Third Seat, Right Side                  217
--                                       -------
--   top 10                               78,456  of 79,306 occupants (98.9%)
--
-- Slide line: "Seven out of ten people in these crashes were in the
-- driver's seat, and 86% were in the front row."
--
-- WHY THIS SETS UP Q08: the driver's seat wins any raw count
-- automatically, because every moving vehicle has a driver and many
-- carry nobody else. So the question "which seat is most dangerous"
-- cannot be answered by counting - it needs a death RATE. That is what
-- Q08 does.
--
-- Data-quality note: 'Reported as Unknown' (691) and 'Not Reported'
-- (275) are missing values, not seats. Together about 1% of occupants.
