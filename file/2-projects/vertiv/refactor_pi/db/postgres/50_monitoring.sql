-- =============================================================================
-- MONITORING: per-product collection rules, templates, status rules.
-- These are loaded by data plugins (taf-data-*) at startup.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- monitoring_definitions  <- Mongo: monitoringdefinitions
-- Largest avg-doc tables in the database (avg ~20 KB).
-- The bulky `components.mappings.{datapointMappings,eventMappings}` is JSONB.
-- -----------------------------------------------------------------------------
CREATE TABLE monitoring.monitoring_definitions (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    programmatic_name   TEXT        NOT NULL,
    custom              BOOLEAN     NOT NULL DEFAULT false,
    override            BOOLEAN     NOT NULL DEFAULT false,
    protocol_identifier TEXT        NOT NULL,                          -- 'snmp', ...
    version             TEXT,
    components          JSONB       NOT NULL,                          -- componentType, count, mappings...
    type                TEXT        NOT NULL DEFAULT 'MonitoringDefinition',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['MonitoringDefinition'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_monitoring_defs_progname_proto_override
    ON monitoring.monitoring_definitions (programmatic_name, protocol_identifier, override);
CREATE INDEX ix_monitoring_defs_hierarchy ON monitoring.monitoring_definitions USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- monitoring_specifications  <- Mongo: monitoringspecifications
-- Business-level wrapper: which products use which monitoring def, at which
-- reporting rate.
-- -----------------------------------------------------------------------------
CREATE TABLE monitoring.monitoring_specifications (
    id                                          public.oid PRIMARY KEY,
    name                                        TEXT        NOT NULL,
    programmatic_name                           TEXT        NOT NULL,
    description                                 TEXT,
    category                                    TEXT,
    protocol_identifier                         TEXT        NOT NULL,
    product_references                          TEXT[]      NOT NULL DEFAULT ARRAY[]::TEXT[],
    monitoring_properties                       JSONB       NOT NULL DEFAULT '{}'::jsonb,
    components                                  JSONB       NOT NULL,
    custom                                      BOOLEAN     NOT NULL DEFAULT false,
    override                                    BOOLEAN     NOT NULL DEFAULT false,
    sharable                                    BOOLEAN     NOT NULL DEFAULT true,
    product_monitoring_mapping_independent      BOOLEAN     NOT NULL DEFAULT false,
    type                                        TEXT        NOT NULL DEFAULT 'MonitoringSpecification',
    hierarchy                                   TEXT[]      NOT NULL DEFAULT ARRAY['MonitoringSpecification'],
    created_by                                  TEXT        NOT NULL DEFAULT '',
    created_at                                  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_monitoring_specs_progname_override
    ON monitoring.monitoring_specifications (programmatic_name, override);
CREATE INDEX ix_monitoring_specs_hierarchy   ON monitoring.monitoring_specifications USING gin (hierarchy);
CREATE INDEX ix_monitoring_specs_products    ON monitoring.monitoring_specifications USING gin (product_references);

-- -----------------------------------------------------------------------------
-- product_monitoring_mappings  <- Mongo: productmonitoringmappings
-- -----------------------------------------------------------------------------
CREATE TABLE monitoring.product_monitoring_mappings (
    id                                  public.oid PRIMARY KEY,
    product_programmatic_name           TEXT        NOT NULL,
    type_identifier_tag                 TEXT        NOT NULL,          -- e.g. 'LIEBERTGXE2-GENERIC'
    management_module                   TEXT,                          -- e.g. 'Unity'
    version                             TEXT        NOT NULL,
    protocol_identifier                 TEXT        NOT NULL,
    monitoring_definition_references    TEXT[]      NOT NULL,
    custom                              BOOLEAN     NOT NULL DEFAULT false,
    override                            BOOLEAN     NOT NULL DEFAULT false,
    object_type                         TEXT        NOT NULL DEFAULT 'ProductMonitoringMapping',
    hierarchy                           TEXT[]      NOT NULL DEFAULT ARRAY['ProductMonitoringMapping'],
    created_by                          TEXT        NOT NULL DEFAULT '',
    created_at                          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_pmm_product_override ON monitoring.product_monitoring_mappings
    (product_programmatic_name, override);
CREATE INDEX ix_pmm_definition_refs ON monitoring.product_monitoring_mappings
    USING gin (monitoring_definition_references);
CREATE INDEX ix_pmm_hierarchy       ON monitoring.product_monitoring_mappings USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- resource_templates  <- Mongo: resourcetemplates
-- Per-device-model command pipeline (Sample → JsonCommand → DomainServiceCall).
-- -----------------------------------------------------------------------------
CREATE TABLE monitoring.resource_templates (
    id              public.oid PRIMARY KEY,
    name            TEXT        NOT NULL,
    version         TEXT        NOT NULL,
    classifier      TEXT        NOT NULL,                              -- 'ProductTemplate' | ...
    product         JSONB       NOT NULL,
    commands        JSONB       NOT NULL,
    type            TEXT        NOT NULL DEFAULT 'ProductTemplate',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['ResourceTemplate'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_resource_templates_name_version
    ON monitoring.resource_templates (name, version);
CREATE INDEX ix_resource_templates_hierarchy ON monitoring.resource_templates USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- resource_status_rules  <- Mongo: resourcestatusrules
-- Maps an alarm state to a target resource attribute value.
-- -----------------------------------------------------------------------------
CREATE TABLE monitoring.resource_status_rules (
    id              public.oid PRIMARY KEY,
    alarm_mapping   JSONB       NOT NULL,                              -- alarmTypeProgrammaticName, alarmState
    target_resource JSONB       NOT NULL,                              -- servicePath, targetAttribute, status
    type            TEXT        NOT NULL DEFAULT 'ResourceStatusRule',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['ResourceStatusRule'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_resource_status_rules_hierarchy ON monitoring.resource_status_rules USING gin (hierarchy);
