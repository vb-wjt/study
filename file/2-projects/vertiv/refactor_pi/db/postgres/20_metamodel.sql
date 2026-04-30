-- =============================================================================
-- METAMODEL: JSON Schema definitions, runtime dictionary, i18n, category exts.
-- This is the "knowledge base" that drives the rest of the app at runtime.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- core_schemas  <- Mongo: coreschemas
-- Root JSON Schema (draft-04 + custom keywords). Mongo `_id` is the schema URL.
-- -----------------------------------------------------------------------------
CREATE TABLE metamodel.core_schemas (
    id          TEXT PRIMARY KEY,                         -- e.g. http://avocent.com/schemas/core-schema-v1
    schema_text TEXT NOT NULL,                            -- raw JSON Schema string
    schema      JSONB GENERATED ALWAYS AS (schema_text::jsonb) STORED,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- -----------------------------------------------------------------------------
-- metadata_definitions  <- Mongo: metadatadefinitions
-- 541 schema documents that drive the GenericDomainService.
-- The original docs use both `id` (URL) and `path` (REST path) as keys.
-- -----------------------------------------------------------------------------
CREATE TABLE metamodel.metadata_definitions (
    id                  public.oid PRIMARY KEY,
    schema_id           TEXT        NOT NULL,             -- the URL identifier ("id" in Mongo)
    title               TEXT,
    description         TEXT,
    version             TEXT,
    type                TEXT,                             -- json schema "type"
    schema_dollar       TEXT,                             -- $schema URL
    definition_type     TEXT,                             -- 'model' | 'service' | ...
    parent              TEXT,                             -- schema parent id, when applicable
    path                TEXT,                             -- REST path, when applicable
    model_configuration JSONB,
    service_configuration JSONB,
    properties          JSONB,
    required            JSONB,
    includes            JSONB,
    definitions         JSONB,
    owner               TEXT,                             -- _owner: providing plugin
    metadata_type       TEXT        NOT NULL DEFAULT 'MetaDataDefinition',  -- _type
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['MetaDataDefinition'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_meta_def_schema_id  ON metamodel.metadata_definitions (schema_id);
CREATE INDEX ix_meta_def_path              ON metamodel.metadata_definitions (path);
CREATE INDEX ix_meta_def_collection_model  ON metamodel.metadata_definitions
    ((model_configuration ->> 'collection'), (model_configuration ->> 'modelType'));
CREATE INDEX ix_meta_def_owner             ON metamodel.metadata_definitions (owner);
CREATE INDEX ix_meta_def_hierarchy         ON metamodel.metadata_definitions USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- dictionary_terms  <- Mongo: dictionaryterms
-- 22,853 terms loaded from data plugins (taf-gdd-data etc.).
-- Subtypes: AlarmType, EventType, DatapointType, Severity, UoM, ...
-- Hybrid: stable scalar fields are columns; everything subtype-specific (e.g.
-- transitionRules, specificConstraints) goes into `payload`.
-- -----------------------------------------------------------------------------
CREATE TABLE metamodel.dictionary_terms (
    id                                public.oid PRIMARY KEY,
    programmatic_name                 TEXT        NOT NULL,
    classification                    TEXT        NOT NULL,             -- alarmType | eventType | datapointType | ...
    type                              TEXT        NOT NULL,             -- _type: AlarmType, EventType, ...
    hierarchy                         TEXT[]      NOT NULL,             -- [DataDictionaryTerm, EventType, AlarmType]
    provided_by_plugin                TEXT        NOT NULL,
    -- frequently queried fields (extracted from the Mongo flat layout):
    access                            TEXT,
    value_type                        TEXT,
    constraint_type                   TEXT,
    precision                         INTEGER,
    base_uom_programmatic_name        TEXT,
    preferred_uom_programmatic_name   TEXT,
    datapoint_source                  TEXT,
    datapoint_category_names          TEXT[],
    is_alarm_event                    BOOLEAN,
    is_threshold_event                BOOLEAN,
    active_or_clear                   TEXT,                              -- 'Active' | 'Clear'
    event_classification              TEXT,
    default_severity_programmatic_name   TEXT,
    effective_severity_programmatic_name TEXT,
    show_as_available_hover_setting   BOOLEAN,
    -- everything else (specificConstraints, transitionRules, comment, ...) stays in JSONB:
    payload                           JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_by                        TEXT        NOT NULL DEFAULT '',
    created_at                        TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_dict_class_progname  ON metamodel.dictionary_terms (classification, programmatic_name);
CREATE INDEX        ix_dict_progname        ON metamodel.dictionary_terms (programmatic_name);
CREATE INDEX        ix_dict_provider        ON metamodel.dictionary_terms (provided_by_plugin);
CREATE INDEX        ix_dict_hierarchy       ON metamodel.dictionary_terms USING gin (hierarchy);
CREATE INDEX        ix_dict_payload         ON metamodel.dictionary_terms USING gin (payload jsonb_path_ops);

-- -----------------------------------------------------------------------------
-- localized_strings  <- Mongo: localizedstrings
-- `message` is { zh_CN, zh, en, en_US } map; kept as JSONB to allow new locales.
-- -----------------------------------------------------------------------------
CREATE TABLE metamodel.localized_strings (
    id          public.oid PRIMARY KEY,
    key         TEXT        NOT NULL,
    message     JSONB       NOT NULL,                     -- { "zh_CN": "...", "en": "..." }
    type        TEXT        NOT NULL DEFAULT 'LocalizedString',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['LocalizedString'],
    created_by  TEXT        NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_localized_strings_key ON metamodel.localized_strings (key);
CREATE INDEX        ix_localized_strings_hierarchy ON metamodel.localized_strings USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- category_extensions  <- Mongo: categoryexts
-- Maps a device category (POWER_METER) to an extension subdoc (powerMeter).
-- -----------------------------------------------------------------------------
CREATE TABLE metamodel.category_extensions (
    id              public.oid PRIMARY KEY,
    category_name   TEXT        NOT NULL,
    extension_name  TEXT        NOT NULL,
    type            TEXT        NOT NULL DEFAULT 'CategoryExtMapping',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['CategoryExtMapping'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_category_ext_category ON metamodel.category_extensions (category_name);
CREATE INDEX        ix_category_ext_hierarchy ON metamodel.category_extensions USING gin (hierarchy);
