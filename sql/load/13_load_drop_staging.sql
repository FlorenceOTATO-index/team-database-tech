-- 13_load_drop_staging.sql
-- Final step: drop the staging database fars_stage once verification has passed.
--
-- Refuses to run unless 12_load_verify.sql has completed with no failed
-- checks. Only fars_stage is dropped; the fars database is never touched. To
-- discard staging after a failed run instead, rerun
-- 01_load_staging_tables.sql (it recreates fars_stage) or drop fars_stage by
-- hand.
--
--   mysql -u root -p < sql/load/13_load_drop_staging.sql

SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
SET SESSION sql_mode = 'STRICT_ALL_TABLES,ONLY_FULL_GROUP_BY,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CALL fars_stage.assert_true(
  (SELECT COUNT(*) FROM fars_stage.verify_results) > 0
  AND (SELECT COUNT(*) FROM fars_stage.verify_results WHERE status = 'FAIL') = 0,
  'Run 12_load_verify.sql successfully before dropping fars_stage');

DROP DATABASE fars_stage;
