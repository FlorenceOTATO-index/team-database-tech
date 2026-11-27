-- ======================================================================
-- Q05 (basic): How many fatal crashes happened in a road work zone, and
-- what kind of work zone was it?
-- Author: Saida Mahmood
-- Technique: single table + lookup join, WHERE filter, GROUP BY, COUNT.
--
-- Why it matters: work zones put people and traffic in the same space.
-- Knowing how many deaths happen there, and in which kind of zone,
-- tells a highway agency where to put barriers and speed enforcement.
--
-- WRK_ZONE = 0 means "not a work zone", so the filter keeps only the
-- crashes that were in one.
-- ======================================================================

USE fars;

SELECT
    cl.label        AS work_zone_type,
    COUNT(*)        AS crashes,
    SUM(a.FATALS)   AS deaths
FROM accident a
JOIN code_labels cl
  ON cl.`column` = 'WRK_ZONE'
 AND cl.code = CAST(a.WRK_ZONE AS CHAR)
WHERE a.WRK_ZONE > 0
GROUP BY cl.label
ORDER BY crashes DESC;


-- ----------------------------------------------------------------------
-- FALLBACK if code_labels has no WRK_ZONE rows (shows codes, not names):
--
--   SELECT WRK_ZONE, COUNT(*) AS crashes, SUM(FATALS) AS deaths
--   FROM accident
--   WHERE WRK_ZONE > 0
--   GROUP BY WRK_ZONE
--   ORDER BY crashes DESC;
--
-- SUPPORTING NUMBER for the slide — work-zone crashes as a share of all:
--
--   SELECT COUNT(*) AS work_zone_crashes,
--          (SELECT COUNT(*) FROM accident) AS all_crashes
--   FROM accident WHERE WRK_ZONE > 0;
-- ----------------------------------------------------------------------

-- RESULT (run 2026-11-27)
--
--   work_zone_type              crashes   deaths
--   Construction                    445      500
--   Work Zone, Type Unknown         251      272
--   Maintenance                      53       61
--   Utility                          14       17
--                                -------  -------
--   total                           763      850
--
--   763 of 36,297 fatal crashes = 2.1%
--   Construction alone is 445 of 763 = 58% of work-zone crashes.
--
-- Slide line: "763 fatal crashes happened in a work zone - 2.1% of all
-- fatal crashes - and 58% of those were construction zones."
--
-- CROSS-CHECK worth mentioning: my indexing query (Q11) reads exactly
-- 763 rows for the same filter. Two separate queries agreeing on 763 is
-- a sign the filter is doing what I think it is.
--
-- Note on 'Work Zone, Type Unknown' (251 crashes, the second biggest
-- group): that is missing data, not a kind of work zone. A third of the
-- work-zone crashes were never classified.
