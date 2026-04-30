-- =============================================================================
-- Master script — run from psql, in order.
-- Example:
--   createdb -h localhost -U pi pi_refactor
--   psql -h localhost -U pi -d pi_refactor -v ON_ERROR_STOP=1 -f db/postgres/99_run_all.sql
-- =============================================================================

\echo '== 00_extensions =='
\i 00_extensions.sql
\echo '== 01_schemas =='
\i 01_schemas.sql
\echo '== 02_common =='
\i 02_common.sql

\echo '== 10_iam =='
\i 10_iam.sql
\echo '== 20_metamodel =='
\i 20_metamodel.sql
\echo '== 30_platform =='
\i 30_platform.sql
\echo '== 40_device =='
\i 40_device.sql
\echo '== 50_monitoring =='
\i 50_monitoring.sql
\echo '== 60_event =='
\i 60_event.sql
\echo '== 70_alarm =='
\i 70_alarm.sql
\echo '== 80_job =='
\i 80_job.sql
\echo '== 85_telemetry =='
\i 85_telemetry.sql
\echo '== 90_file =='
\i 90_file.sql
\echo '== 95_licensing =='
\i 95_licensing.sql

\echo '== Done =='
