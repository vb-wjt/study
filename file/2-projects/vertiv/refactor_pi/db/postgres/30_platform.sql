-- =============================================================================
-- PLATFORM: applications, plugins, commands, functions, topics, queues,
--           registry, system settings, exports.
-- These are the runtime metadata that PluginLoader translates into Spring beans
-- and Hazelcast resources at boot time.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- applications  <- Mongo: applications  (currently 1 row: power-insight)
-- -----------------------------------------------------------------------------
CREATE TABLE platform.applications (
    id                   public.oid PRIMARY KEY,
    app_identifier       TEXT        NOT NULL,
    display_name         TEXT        NOT NULL,
    description          TEXT,
    version              TEXT        NOT NULL,
    product_version      TEXT,
    platform_version     TEXT,
    vendor               TEXT,
    default_locale       TEXT,
    license_agreement    TEXT,
    configuration_class  TEXT,
    dependencies         JSONB       NOT NULL DEFAULT '[]'::jsonb,
    type                 TEXT        NOT NULL DEFAULT 'Application',
    hierarchy            TEXT[]      NOT NULL DEFAULT ARRAY['Application'],
    created_by           TEXT        NOT NULL DEFAULT '',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_applications_app_identifier ON platform.applications (app_identifier);
CREATE INDEX        ix_applications_hierarchy      ON platform.applications USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- plugin_classifications  <- Mongo: pluginclassifications
-- -----------------------------------------------------------------------------
CREATE TABLE platform.plugin_classifications (
    id                                       public.oid PRIMARY KEY,
    classification_name                      TEXT        NOT NULL,
    allow_delete                             BOOLEAN     NOT NULL,
    allow_disable                            BOOLEAN     NOT NULL,
    allow_stop                               BOOLEAN     NOT NULL,
    allow_multiple_plugins                   BOOLEAN     NOT NULL,
    delete_after_add                         BOOLEAN     NOT NULL,
    delete_zip_after_add                     BOOLEAN     NOT NULL,
    classification_properties_schema_id      TEXT,
    static_resource_mappings                 JSONB,
    type                                     TEXT        NOT NULL DEFAULT 'PluginClassification',
    hierarchy                                TEXT[]      NOT NULL DEFAULT ARRAY['PluginClassification'],
    created_by                               TEXT        NOT NULL DEFAULT '',
    created_at                               TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_plugin_class_name      ON platform.plugin_classifications (classification_name);
CREATE INDEX        ix_plugin_class_hierarchy ON platform.plugin_classifications USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- plugins  <- Mongo: plugins   (42 rows, avg ~1.4 KB)
-- The nested `commands / topics / queues / handlers` arrays stay JSONB because
-- they're plugin-specific descriptors processed by Java at startup only.
-- -----------------------------------------------------------------------------
CREATE TABLE platform.plugins (
    id                          public.oid PRIMARY KEY,
    name                        TEXT        NOT NULL,
    version                     TEXT        NOT NULL,
    platform_version            TEXT,
    vendor                      TEXT,
    description                 TEXT,
    classification              TEXT        NOT NULL REFERENCES platform.plugin_classifications(classification_name)
                                            DEFERRABLE INITIALLY DEFERRED,
    configuration_class         TEXT,
    administration_state        TEXT        NOT NULL,    -- ENABLED | DISABLED
    installation_state          TEXT        NOT NULL,    -- READY | INSTALLING | FAILED
    installation_originator     TEXT        NOT NULL,    -- SYSTEM | USER
    autoupgrade                 JSONB,
    dependencies                JSONB,
    handlers                    JSONB,
    topics                      JSONB,
    topic_listeners             JSONB,
    queues                      JSONB,
    queue_listeners             JSONB,
    commands                    JSONB,
    type                        TEXT        NOT NULL DEFAULT 'Plugin',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['Plugin'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                 TEXT,
    modified_at                 TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_plugins_name          ON platform.plugins (name);
CREATE INDEX        ix_plugins_classification ON platform.plugins (classification);
CREATE INDEX        ix_plugins_hierarchy      ON platform.plugins USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- commands  <- Mongo: commands
-- -----------------------------------------------------------------------------
CREATE TABLE platform.commands (
    id                          public.oid PRIMARY KEY,
    name                        TEXT        NOT NULL,
    programmatic_name           TEXT        NOT NULL,                  -- '<plugin>.<name>'
    owner                       TEXT        NOT NULL,                  -- providing plugin
    version                     TEXT        NOT NULL,
    description                 TEXT,
    help                        TEXT,
    parameter_schema_id         TEXT,
    return_schema_id            TEXT,
    on_execute_command          JSONB       NOT NULL,                  -- { type, code, sequence }
    cluster_selector            JSONB       NOT NULL,                  -- { location, ... }
    execution_timeout_seconds   INTEGER     NOT NULL,
    expected_completion_seconds INTEGER     NOT NULL,
    top_tenant_execution_only   BOOLEAN     NOT NULL DEFAULT false,
    type                        TEXT        NOT NULL DEFAULT 'Command',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['Command'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_commands_progname ON platform.commands (programmatic_name);
CREATE UNIQUE INDEX ux_commands_owner_name ON platform.commands (owner, name);
CREATE INDEX        ix_commands_hierarchy ON platform.commands USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- functions  <- Mongo: functions
-- -----------------------------------------------------------------------------
CREATE TABLE platform.functions (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    programmatic_name   TEXT        NOT NULL,
    description         TEXT,
    parameters          JSONB       NOT NULL,                          -- { name -> {direction,defaultValue,...} }
    expressions         JSONB       NOT NULL,                          -- [{type, expression}, ...]
    type                TEXT        NOT NULL DEFAULT 'Function',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['Function'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_functions_name      ON platform.functions (name);
CREATE UNIQUE INDEX ux_functions_progname  ON platform.functions (programmatic_name);
CREATE INDEX        ix_functions_hierarchy ON platform.functions USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- topics, topic_listeners, ws_topic_listeners  <- Mongo: topics/topiclisteners/wstopiclisteners
-- -----------------------------------------------------------------------------
CREATE TABLE platform.topics (
    id                      public.oid PRIMARY KEY,
    name                    TEXT        NOT NULL,
    owner                   TEXT        NOT NULL,
    topic_item_schema_id    TEXT,
    type                    TEXT        NOT NULL DEFAULT 'Topic',
    hierarchy               TEXT[]      NOT NULL DEFAULT ARRAY['Topic'],
    created_by              TEXT        NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_topics_name      ON platform.topics (name);
CREATE INDEX        ix_topics_hierarchy ON platform.topics USING gin (hierarchy);

CREATE TABLE platform.topic_listeners (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    topic_name          TEXT        NOT NULL,
    owner               TEXT        NOT NULL,
    local               BOOLEAN     NOT NULL DEFAULT false,
    on_topic_message    JSONB       NOT NULL,                          -- { type, code, sequence }
    type                TEXT        NOT NULL DEFAULT 'TopicListener',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['TopicListener'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_topic_listeners_name      ON platform.topic_listeners (name);
CREATE INDEX        ix_topic_listeners_topic     ON platform.topic_listeners (topic_name);
CREATE INDEX        ix_topic_listeners_hierarchy ON platform.topic_listeners USING gin (hierarchy);

CREATE TABLE platform.ws_topic_listeners (
    id              public.oid PRIMARY KEY,
    ws_session_id   TEXT        NOT NULL,                              -- ephemeral; consider TTL
    topic_name      TEXT        NOT NULL,
    type            TEXT        NOT NULL DEFAULT 'WsTopicListener',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['WsTopicListener'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_ws_topic_listeners_topic_session ON platform.ws_topic_listeners (topic_name, ws_session_id);
CREATE INDEX        ix_ws_topic_listeners_hierarchy     ON platform.ws_topic_listeners USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- queues, queue_listeners  <- Mongo: queues/queuelisteners
-- -----------------------------------------------------------------------------
CREATE TABLE platform.queues (
    id                      public.oid PRIMARY KEY,
    name                    TEXT        NOT NULL,
    owner                   TEXT        NOT NULL,
    queue_item_schema_id    TEXT,
    timeout_seconds         INTEGER     NOT NULL,
    max_size                INTEGER     NOT NULL,
    backup_count            INTEGER     NOT NULL,
    async_backup_count      INTEGER     NOT NULL,
    empty_queue_ttl_seconds INTEGER     NOT NULL,                      -- -1 = never
    type                    TEXT        NOT NULL DEFAULT 'Queue',
    hierarchy               TEXT[]      NOT NULL DEFAULT ARRAY['Queue'],
    created_by              TEXT        NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_queues_name      ON platform.queues (name);
CREATE INDEX        ix_queues_hierarchy ON platform.queues USING gin (hierarchy);

CREATE TABLE platform.queue_listeners (
    id                      public.oid PRIMARY KEY,
    name                    TEXT        NOT NULL,
    queue_name              TEXT        NOT NULL,
    owner                   TEXT        NOT NULL,
    local                   BOOLEAN     NOT NULL DEFAULT false,
    on_queue_entry_added    JSONB       NOT NULL,
    type                    TEXT        NOT NULL DEFAULT 'QueueListener',
    hierarchy               TEXT[]      NOT NULL DEFAULT ARRAY['QueueListener'],
    created_by              TEXT        NOT NULL DEFAULT '',
    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_queue_listeners_name      ON platform.queue_listeners (name);
CREATE INDEX        ix_queue_listeners_queue     ON platform.queue_listeners (queue_name);
CREATE INDEX        ix_queue_listeners_hierarchy ON platform.queue_listeners USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- registry  <- Mongo: registry
-- KV with optional encryption flag.
-- -----------------------------------------------------------------------------
CREATE TABLE platform.registry (
    id              public.oid PRIMARY KEY,
    category        TEXT        NOT NULL,                              -- 'Globals', ...
    key             TEXT        NOT NULL,
    entry_type      TEXT        NOT NULL,                              -- 'String' | 'Integer' | ...
    entry_value     TEXT        NOT NULL,
    encrypted       BOOLEAN     NOT NULL DEFAULT false,
    type            TEXT        NOT NULL DEFAULT 'Registry',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['Registry'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_registry_category_key ON platform.registry (category, key);
CREATE INDEX        ix_registry_hierarchy    ON platform.registry USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- system_settings  <- Mongo: systemsettings  (singleton)
-- -----------------------------------------------------------------------------
CREATE TABLE platform.system_settings (
    id                       public.oid PRIMARY KEY,
    system_version           TEXT        NOT NULL,
    db_state                 TEXT        NOT NULL,                     -- 'OK' | 'UPGRADE_REQUIRED' | ...
    upgrade_report           JSONB       NOT NULL,
    licensing_configuration  JSONB       NOT NULL,
    singleton                BOOLEAN     NOT NULL DEFAULT true
);
CREATE UNIQUE INDEX ux_system_settings_singleton ON platform.system_settings (singleton)
    WHERE singleton;

-- -----------------------------------------------------------------------------
-- default_config  <- Mongo: defaultconfig
-- Key/value config bag (currently empty but indexed in Mongo).
-- -----------------------------------------------------------------------------
CREATE TABLE platform.default_config (
    id          public.oid PRIMARY KEY,
    config_key  TEXT        NOT NULL,
    payload     JSONB       NOT NULL,
    type        TEXT        NOT NULL DEFAULT 'DefaultConfig',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['DefaultConfig'],
    created_by  TEXT        NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_default_config_key ON platform.default_config (config_key);

-- -----------------------------------------------------------------------------
-- Export configuration  <- Mongo: exporttransformations / exportdatamappings
-- -----------------------------------------------------------------------------
CREATE TABLE platform.export_transformations (
    id                  public.oid PRIMARY KEY,
    service_name        TEXT        NOT NULL,
    banned_projections  TEXT[]      NOT NULL DEFAULT ARRAY[]::TEXT[],
    transformations     JSONB       NOT NULL,
    type                TEXT        NOT NULL DEFAULT 'ExportTransformations',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['ExportTransformations'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_export_transformations_service ON platform.export_transformations (service_name);

CREATE TABLE platform.export_data_mappings (
    id                              public.oid PRIMARY KEY,
    mapping_name                    TEXT        NOT NULL,
    column_name_to_source_mapping   JSONB       NOT NULL,
    type                            TEXT        NOT NULL DEFAULT 'ExportDataMapping',
    hierarchy                       TEXT[]      NOT NULL DEFAULT ARRAY['ExportDataMapping'],
    created_by                      TEXT        NOT NULL DEFAULT '',
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_export_data_mappings_name ON platform.export_data_mappings (mapping_name);
