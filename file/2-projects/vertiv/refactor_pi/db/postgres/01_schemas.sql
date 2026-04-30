-- =============================================================================
-- Logical schemas — group the 72 Mongo collections into 9 cohesive namespaces.
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS iam         AUTHORIZATION CURRENT_USER;  -- tenants, users, roles, permissions, relationships, certs
CREATE SCHEMA IF NOT EXISTS platform    AUTHORIZATION CURRENT_USER;  -- applications, plugins, commands, topics, queues, registry, system
CREATE SCHEMA IF NOT EXISTS metamodel   AUTHORIZATION CURRENT_USER;  -- json schemas, dictionary terms, i18n, category extensions
CREATE SCHEMA IF NOT EXISTS device      AUTHORIZATION CURRENT_USER;  -- assets, engines, protocols, detection, discovery
CREATE SCHEMA IF NOT EXISTS monitoring  AUTHORIZATION CURRENT_USER;  -- monitoring defs/specs/mappings/templates
CREATE SCHEMA IF NOT EXISTS evt         AUTHORIZATION CURRENT_USER;  -- events, event logs, audit-trail, transformation rules
CREATE SCHEMA IF NOT EXISTS alarm       AUTHORIZATION CURRENT_USER;  -- alarms, alarm actions, notifications, traps
CREATE SCHEMA IF NOT EXISTS job         AUTHORIZATION CURRENT_USER;  -- jobs, scheduled jobs, locks, persisted actions
CREATE SCHEMA IF NOT EXISTS telemetry   AUTHORIZATION CURRENT_USER;  -- tsd datapoints, electric data
CREATE SCHEMA IF NOT EXISTS file        AUTHORIZATION CURRENT_USER;  -- file metadata + GridFS shim
CREATE SCHEMA IF NOT EXISTS licensing   AUTHORIZATION CURRENT_USER;  -- licensed structures/features/products

COMMENT ON SCHEMA iam        IS 'Identity, tenants, generic relationship graph, certificates';
COMMENT ON SCHEMA platform   IS 'Plugin runtime metadata: apps, plugins, commands, topics, queues, registry';
COMMENT ON SCHEMA metamodel  IS 'JSON schema definitions, runtime dictionary terms, localized strings';
COMMENT ON SCHEMA device     IS 'Asset/engine instances, protocol configs, detection tasks, discovery';
COMMENT ON SCHEMA monitoring IS 'Monitoring definitions, specifications, product mappings, templates';
COMMENT ON SCHEMA evt        IS 'Business events, event logs, audit-trail mappings, transformation rules';
COMMENT ON SCHEMA alarm      IS 'Alarms, alarm actions, notifications, SMS, SNMP traps';
COMMENT ON SCHEMA job        IS 'Job execution history, scheduled jobs, distributed locks';
COMMENT ON SCHEMA telemetry  IS 'Time-series datapoints (partitioned), electric data aggregations';
COMMENT ON SCHEMA file       IS 'Logical file metadata + GridFS-compatible chunk storage';
COMMENT ON SCHEMA licensing  IS 'Licensed structures, features, products, internal counters';
