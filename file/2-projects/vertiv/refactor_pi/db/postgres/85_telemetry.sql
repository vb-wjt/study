-- =============================================================================
-- TELEMETRY: time-series datapoints + electric data aggregation.
-- This is the only table family expected to grow unbounded; partitioned by
-- timestamp and indexed for the canonical (sensor, metric, range) query.
--
-- TimescaleDB option: instead of native PG partitioning, run
--   SELECT create_hypertable('telemetry.datapoints', 'ts', chunk_time_interval => interval '7 days');
-- after creating the table without `PARTITION BY`.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- datapoints  <- Mongo: tsd.datapoints
-- Mongo stores `value` as string and `timestamp` as epoch-ms BIGINT; we promote
-- both to typed columns (numeric value + timestamptz). The conversion script
-- handles unit/string special cases.
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.datapoints (
    sensor_id           TEXT        NOT NULL,                          -- e.g. '<deviceId>::<componentId>'
    metric_name         TEXT        NOT NULL,                          -- e.g. 'val_pem_enrg_accumulated'
    ts                  TIMESTAMPTZ NOT NULL,
    value_num           DOUBLE PRECISION,                              -- nullable when raw is non-numeric
    value_text          TEXT,                                          -- preserved verbatim for non-numeric or precision-sensitive raw
    tags                JSONB       NOT NULL DEFAULT '{}'::jsonb,      -- additional tags (componentIdentifier etc.)
    PRIMARY KEY (sensor_id, metric_name, ts)
) PARTITION BY RANGE (ts);

CREATE INDEX ix_datapoints_metric_ts  ON telemetry.datapoints (metric_name, ts DESC);
CREATE INDEX ix_datapoints_ts         ON telemetry.datapoints (ts DESC);
CREATE INDEX ix_datapoints_tags       ON telemetry.datapoints USING gin (tags jsonb_path_ops);

-- Bootstrap monthly partitions; replace with pg_partman in production.
CREATE TABLE telemetry.datapoints_y2026m04 PARTITION OF telemetry.datapoints
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE telemetry.datapoints_y2026m05 PARTITION OF telemetry.datapoints
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE telemetry.datapoints_y2026m06 PARTITION OF telemetry.datapoints
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE telemetry.datapoints_default PARTITION OF telemetry.datapoints DEFAULT;

-- -----------------------------------------------------------------------------
-- electric_data  <- Mongo: electricdatas  (hourly aggregation)
-- Mongo `time` is a date string ('YYYY-MM-DD'); promoted to DATE here.
-- (originValue / consumption are kept as NUMERIC for safe arithmetic.)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.electric_data (
    id              public.oid PRIMARY KEY,
    device_id       public.oid NOT NULL REFERENCES device.base_objects(id) ON DELETE CASCADE,
    day             DATE        NOT NULL,                              -- Mongo: time
    hour            SMALLINT    NOT NULL CHECK (hour BETWEEN 0 AND 23),
    origin_value    NUMERIC(20, 6) NOT NULL,
    consumption     NUMERIC(20, 6) NOT NULL,
    type            TEXT        NOT NULL DEFAULT 'ElectricData',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['ElectricData'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_electric_data_device_day_hour ON telemetry.electric_data (device_id, day, hour);
CREATE INDEX        ix_electric_data_day             ON telemetry.electric_data (day);
CREATE INDEX        ix_electric_data_hierarchy       ON telemetry.electric_data USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- tsd_data  <- Mongo: tsddata  (currently empty; presumed legacy/deprecated)
-- Kept for parity. Drop after confirming with product/QA that no plugin writes
-- here in any deployed version.
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.tsd_data (
    id              public.oid PRIMARY KEY,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'TsdData',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['TsdData'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_tsd_data_hierarchy ON telemetry.tsd_data USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- electric_rate_configs  <- Mongo: electricrateconfigs  (currently empty)
-- -----------------------------------------------------------------------------
CREATE TABLE telemetry.electric_rate_configs (
    id              public.oid PRIMARY KEY,
    name            TEXT,
    rate            NUMERIC(20, 6),
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'ElectricRateConfig',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['ElectricRateConfig'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_electric_rate_configs_hierarchy ON telemetry.electric_rate_configs USING gin (hierarchy);
