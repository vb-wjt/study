-- =============================================================================
-- EVENTS: business events, system event logs, audit-trail mappings,
--         declarative transformation rules.
-- The `events` table is the highest-volume row source after telemetry; we
-- partition by month to make retention DROP-PARTITION cheap.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- events  <- Mongo: events  (partitioned by month on `timestamp`)
-- -----------------------------------------------------------------------------
CREATE TABLE evt.events (
    id                              public.oid NOT NULL,
    type                            TEXT        NOT NULL,              -- 't_evt_app_deviceUpdate' etc.
    category                        TEXT        NOT NULL,              -- 'Audit' | 'SystemAdmin' | ...
    severity_programmatic_name      TEXT        NOT NULL,              -- 'Information' | 'Warning' | ...
    timestamp                       TIMESTAMPTZ NOT NULL,
    origin_id                       TEXT        NOT NULL,              -- user / system that fired it
    resource_id                     public.oid,
    resource_name                   TEXT,
    component_identifier            TEXT,
    message                         TEXT        NOT NULL,
    parameters                      JSONB,
    data                            JSONB,                             -- before/after/delta envelope
    object_type                     TEXT        NOT NULL DEFAULT 'Event',
    hierarchy                       TEXT[]      NOT NULL DEFAULT ARRAY['Event'],
    created_by                      TEXT        NOT NULL DEFAULT '',
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE INDEX ix_events_timestamp     ON evt.events (timestamp DESC);
CREATE INDEX ix_events_category      ON evt.events (category, timestamp DESC);
CREATE INDEX ix_events_resource      ON evt.events (resource_id, timestamp DESC);
CREATE INDEX ix_events_type          ON evt.events (type, timestamp DESC);
CREATE INDEX ix_events_hierarchy     ON evt.events USING gin (hierarchy);
CREATE INDEX ix_events_data          ON evt.events USING gin (data jsonb_path_ops);

-- Bootstrap partitions: previous, current and next month (operator should
-- replace this with pg_partman / a scheduled job in production).
CREATE TABLE evt.events_y2026m04 PARTITION OF evt.events
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE evt.events_y2026m05 PARTITION OF evt.events
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE evt.events_y2026m06 PARTITION OF evt.events
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
-- Default partition catches anything outside the prepared windows.
CREATE TABLE evt.events_default PARTITION OF evt.events DEFAULT;

-- -----------------------------------------------------------------------------
-- event_logs  <- Mongo: eventlogs
-- Smaller, system-init events. Not partitioned (low volume).
-- -----------------------------------------------------------------------------
CREATE TABLE evt.event_logs (
    id                  public.oid PRIMARY KEY,
    event_type          TEXT        NOT NULL,                          -- 'other' | ...
    event_name          TEXT        NOT NULL,
    source_name         TEXT,
    plugin_id           TEXT,
    timestamp           TIMESTAMPTZ NOT NULL,
    detail_data         JSONB,
    detail_data_keys    TEXT[],
    type                TEXT        NOT NULL DEFAULT 'EventLog',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['EventLog'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_event_logs_timestamp ON evt.event_logs (timestamp DESC);
CREATE INDEX ix_event_logs_event     ON evt.event_logs (event_name);
CREATE INDEX ix_event_logs_plugin    ON evt.event_logs (plugin_id);
CREATE INDEX ix_event_logs_hierarchy ON evt.event_logs USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- audit_trail_grid_mappings  <- Mongo: audittrailgridmappings
-- Tells the audit pipeline "operations of `type` on `path` go to which grid".
-- -----------------------------------------------------------------------------
CREATE TABLE evt.audit_trail_grid_mappings (
    id          public.oid PRIMARY KEY,
    type        TEXT,                                                  -- 'failedEnable', 'successfulDelete', ... (~2% of source rows lack this)
    path        TEXT,                                                  -- 'plugins', 'devices', ... (~14% of source rows lack this)
    object_type TEXT        NOT NULL DEFAULT 'AuditTrailGridMapping',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['AuditTrailGridMapping'],
    created_by  TEXT        NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_audit_grid_path ON evt.audit_trail_grid_mappings (path);
CREATE INDEX ix_audit_grid_type ON evt.audit_trail_grid_mappings (type);
CREATE INDEX ix_audit_grid_hierarchy ON evt.audit_trail_grid_mappings USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- transformation_rules  <- Mongo: transformationrules
-- "From audit event of (sourcePath, type) → emit business event with template".
-- -----------------------------------------------------------------------------
CREATE TABLE evt.transformation_rules (
    id              public.oid PRIMARY KEY,
    description     TEXT,
    type            TEXT        NOT NULL,                              -- 'successfulDelete.plugins' etc.
    source_path     TEXT        NOT NULL,
    target          JSONB       NOT NULL,                              -- target event template with $.x JSONPath placeholders
    object_type     TEXT        NOT NULL DEFAULT 'TransformationRules',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['TransformationRules'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_transformation_source_type ON evt.transformation_rules (source_path, type);
CREATE INDEX        ix_transformation_hierarchy   ON evt.transformation_rules USING gin (hierarchy);
