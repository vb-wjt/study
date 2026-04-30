-- =============================================================================
-- DEVICE: asset/engine instances, protocol configs, detection, discovery.
-- The "real product" tables. base_objects is the polymorphic root.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- asset_classifications  <- Mongo: assetclassifications
-- -----------------------------------------------------------------------------
CREATE TABLE device.asset_classifications (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    programmatic_name   TEXT        NOT NULL,
    type                TEXT        NOT NULL DEFAULT 'AssetClassification',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['AssetClassification'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_asset_classifications_name      ON device.asset_classifications (name);
CREATE UNIQUE INDEX ux_asset_classifications_progname  ON device.asset_classifications (programmatic_name);
CREATE INDEX        ix_asset_classifications_hierarchy ON device.asset_classifications USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- protocol_configurations  <- Mongo: protocolconfigurations
-- snmp / modbus / etc. The variant payload (snmp v2/v3, modbus tcp/rtu, ...)
-- stays in JSONB. Sensitive credentials remain APP-encrypted strings.
-- -----------------------------------------------------------------------------
CREATE TABLE device.protocol_configurations (
    id                          public.oid PRIMARY KEY,
    name                        TEXT        NOT NULL,
    protocol_programmatic_name  TEXT        NOT NULL,                 -- 'snmp' | 'modbus' | ...
    enable_discovery_use        BOOLEAN     NOT NULL DEFAULT false,
    communication_properties    JSONB       NOT NULL,                 -- port/transport/timeout/retries
    snmp                        JSONB,                                -- encrypted communities (app-side AES)
    discovery                   JSONB,
    type                        TEXT        NOT NULL DEFAULT 'ProtocolConfiguration',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['ProtocolConfiguration'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                 TEXT,
    modified_at                 TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_protocol_configs_name ON device.protocol_configurations (name);
CREATE INDEX        ix_protocol_configs_proto_name ON device.protocol_configurations (protocol_programmatic_name);
CREATE INDEX        ix_protocol_configs_hierarchy ON device.protocol_configurations USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- base_objects  <- Mongo: baseobjects
-- Polymorphic table for everything implementing BaseObject:
--   * Asset / BasicDevice / Device      (e.g. RACK_PDU)
--   * Asset / Engine / IntelligentEngine
-- The hot, queryable bits get real columns. Subtype-specific structures stay
-- in JSONB partitions.
-- -----------------------------------------------------------------------------
CREATE TABLE device.base_objects (
    id                                  public.oid PRIMARY KEY,
    name                                TEXT        NOT NULL,
    type                                TEXT        NOT NULL,         -- e.g. 'Device', 'IntelligentEngine'
    hierarchy                           TEXT[]      NOT NULL,         -- ['BaseObject', ...]
    -- Device-specific (nullable for non-device subtypes):
    primary_category_programmatic_name  TEXT,                         -- 'RACK_PDU'
    obwi_url                            TEXT,
    categories                          TEXT[],
    product                             JSONB,                        -- manufacturer/model/...
    images                              JSONB,
    specific_properties                 JSONB,                        -- per-category bag (pdu, ups, ...)
    agent_identifications               JSONB,
    monitoring_configuration            JSONB,
    signal_template                     JSONB,
    user_defined_properties             JSONB,
    status                              JSONB,                        -- overallStatusActual etc.
    -- Engine-specific (nullable for non-engine subtypes):
    identification                      JSONB,                        -- {address, type}
    communication_properties            JSONB,
    platform_identification             JSONB,
    platform_communication_properties   JSONB,
    operational_state                   JSONB,                        -- { state: 'Registered' }
    engine_type_programmatic_name       TEXT,
    custom_status_updates               BOOLEAN,
    requests_registration_retries       BOOLEAN,
    -- Catch-all for anything not promoted above:
    extra                               JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_by                          TEXT        NOT NULL DEFAULT '',
    created_at                          TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                         TEXT,
    modified_at                         TIMESTAMPTZ
);
CREATE INDEX ix_base_objects_type            ON device.base_objects (type);
CREATE INDEX ix_base_objects_hierarchy       ON device.base_objects USING gin (hierarchy);
CREATE INDEX ix_base_objects_name_trgm       ON device.base_objects USING gin (name gin_trgm_ops);
CREATE INDEX ix_base_objects_primary_cat     ON device.base_objects (primary_category_programmatic_name);
CREATE INDEX ix_base_objects_categories      ON device.base_objects USING gin (categories);
CREATE INDEX ix_base_objects_specific_props  ON device.base_objects USING gin (specific_properties jsonb_path_ops);

-- -----------------------------------------------------------------------------
-- monitored_objects  <- Mongo: monitoredobjects
-- Snapshot of monitoring state for a device (engine-side state).
-- -----------------------------------------------------------------------------
CREATE TABLE device.monitored_objects (
    id                                          public.oid PRIMARY KEY,
    object_id                                   public.oid NOT NULL REFERENCES device.base_objects(id) ON DELETE CASCADE,
    object_classification_programmatic_name     TEXT        NOT NULL,
    object_name                                 TEXT        NOT NULL,
    request_time                                TIMESTAMPTZ NOT NULL,
    distribution_status                         TEXT        NOT NULL,  -- 'Distributed' | 'Pending' | ...
    waiting_for_engine                          BOOLEAN     NOT NULL DEFAULT false,
    retry_count                                 INTEGER     NOT NULL DEFAULT 0,
    engine_id                                   public.oid REFERENCES device.base_objects(id) ON DELETE SET NULL,
    dependencies                                JSONB       NOT NULL,  -- referenced specs/defs/configs
    monitoring_configuration                    JSONB       NOT NULL,
    agent                                       JSONB       NOT NULL,
    components                                  JSONB       NOT NULL,
    type                                        TEXT        NOT NULL DEFAULT 'MonitoredObject',
    hierarchy                                   TEXT[]      NOT NULL DEFAULT ARRAY['MonitoredObject'],
    created_by                                  TEXT        NOT NULL DEFAULT '',
    created_at                                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                                 TEXT,
    modified_at                                 TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_monitored_objects_obj_class_dist ON device.monitored_objects
    (object_id, object_classification_programmatic_name, distribution_status);
CREATE INDEX ix_monitored_objects_engine    ON device.monitored_objects (engine_id);
CREATE INDEX ix_monitored_objects_hierarchy ON device.monitored_objects USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- detection_tasks  <- Mongo: detectiontasks
-- -----------------------------------------------------------------------------
CREATE TABLE device.detection_tasks (
    id                                              public.oid PRIMARY KEY,
    name                                            TEXT        NOT NULL,
    detection_type                                  TEXT        NOT NULL,  -- 'AssetInterrogation' | ...
    command_programmatic_name                       TEXT        NOT NULL,
    assigning_classification_programmatic_name      TEXT        NOT NULL,
    configuration_programmatic_name                 TEXT,
    adding_properties                               JSONB,
    detection_rules                                 JSONB,
    type                                            TEXT        NOT NULL DEFAULT 'DetectionTask',
    hierarchy                                       TEXT[]      NOT NULL DEFAULT ARRAY['DetectionTask'],
    created_by                                      TEXT        NOT NULL DEFAULT '',
    created_at                                      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_detection_tasks_name      ON device.detection_tasks (name);
CREATE INDEX        ix_detection_tasks_hierarchy ON device.detection_tasks USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- discovery / discovery_constraints / discovered_objects
-- All currently empty in Mongo; tables created with index parity.
-- -----------------------------------------------------------------------------
CREATE TABLE device.discoveries (
    id              public.oid PRIMARY KEY,
    name            TEXT,
    state           TEXT,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'Discovery',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['Discovery'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by     TEXT,
    modified_at     TIMESTAMPTZ
);
CREATE INDEX ix_discoveries_hierarchy ON device.discoveries USING gin (hierarchy);

CREATE TABLE device.discovery_constraints (
    id              public.oid PRIMARY KEY,
    name            TEXT        NOT NULL,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'DiscoveryConstraint',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['DiscoveryConstraint'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_discovery_constraints_name ON device.discovery_constraints (name);
CREATE INDEX        ix_discovery_constraints_hierarchy ON device.discovery_constraints USING gin (hierarchy);

CREATE TABLE device.discovered_objects (
    id                          public.oid PRIMARY KEY,
    identification_address      TEXT,                                  -- mirrored Mongo: identification.address
    mac_address                 TEXT,
    payload                     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type                        TEXT        NOT NULL DEFAULT 'DiscoveredObject',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['DiscoveredObject'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_discovered_objects_address   ON device.discovered_objects (identification_address);
CREATE INDEX ix_discovered_objects_mac       ON device.discovered_objects (mac_address);
CREATE INDEX ix_discovered_objects_hierarchy ON device.discovered_objects USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- Empty placeholder collections (currently 0 rows). Kept for parity; review
-- with product whether they are dead features before going live.
-- -----------------------------------------------------------------------------
CREATE TABLE device.device_managements (
    id          public.oid PRIMARY KEY,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type        TEXT        NOT NULL DEFAULT 'DeviceMgm',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['DeviceMgm'],
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_device_managements_hierarchy ON device.device_managements USING gin (hierarchy);

CREATE TABLE device.device_modules (
    id          public.oid PRIMARY KEY,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type        TEXT        NOT NULL DEFAULT 'DeviceModule',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['DeviceModule'],
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_device_modules_hierarchy ON device.device_modules USING gin (hierarchy);

CREATE TABLE device.server_managements (
    id          public.oid PRIMARY KEY,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type        TEXT        NOT NULL DEFAULT 'ServerMgm',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['ServerMgm'],
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_server_managements_hierarchy ON device.server_managements USING gin (hierarchy);

CREATE TABLE device.trellis_agents (
    id          public.oid PRIMARY KEY,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type        TEXT        NOT NULL DEFAULT 'TrellisAgent',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['TrellisAgent'],
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_trellis_agents_hierarchy ON device.trellis_agents USING gin (hierarchy);
