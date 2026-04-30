-- =============================================================================
-- JOBS / SCHEDULES / LOCKS
-- jobs is the busiest live table (Mongo: 836 rows in 1 day for a 2-min cron).
-- Partition monthly so retention can DROP partitions cheaply.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- jobs  <- Mongo: jobs   (PARTITIONED on `created_at`)
-- -----------------------------------------------------------------------------
CREATE TABLE job.jobs (
    id                          public.oid NOT NULL,
    command_programmatic_name   TEXT        NOT NULL,
    scheduled_job_id            public.oid,
    run_mode                    TEXT        NOT NULL,                  -- 'sync' | 'async'
    state                       TEXT        NOT NULL,                  -- 'Pending' | 'Running' | 'Completed' | 'Failed'
    status                      TEXT        NOT NULL,                  -- 'OK' | 'Error' | 'Timeout'
    active                      BOOLEAN     NOT NULL DEFAULT false,
    run_on_create               BOOLEAN     NOT NULL DEFAULT false,
    priority                    INTEGER     NOT NULL DEFAULT 4,
    time_to_live_hours          INTEGER     NOT NULL,                  -- application-level TTL
    parent_jobs                 TEXT[]      NOT NULL DEFAULT ARRAY[]::TEXT[],
    run_as_execution_context    JSONB       NOT NULL,                  -- { tenantId, principal }
    results                     JSONB,                                 -- per-node outcome list
    parameter_data              JSONB,
    start_time                  TIMESTAMPTZ,
    end_time                    TIMESTAMPTZ,
    type                        TEXT        NOT NULL DEFAULT 'Job',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['Job'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                 TEXT,
    modified_at                 TIMESTAMPTZ,
    PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

CREATE INDEX ix_jobs_created_at      ON job.jobs (created_at DESC);
CREATE INDEX ix_jobs_command         ON job.jobs (command_programmatic_name, created_at DESC);
CREATE INDEX ix_jobs_scheduled       ON job.jobs (scheduled_job_id, created_at DESC);
CREATE INDEX ix_jobs_state           ON job.jobs (state) WHERE state IN ('Pending', 'Running');
CREATE INDEX ix_jobs_active          ON job.jobs (active) WHERE active;
CREATE INDEX ix_jobs_hierarchy       ON job.jobs USING gin (hierarchy);

CREATE TABLE job.jobs_y2026m04 PARTITION OF job.jobs
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE job.jobs_y2026m05 PARTITION OF job.jobs
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE job.jobs_y2026m06 PARTITION OF job.jobs
    FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');
CREATE TABLE job.jobs_default PARTITION OF job.jobs DEFAULT;

-- -----------------------------------------------------------------------------
-- scheduled_jobs  <- Mongo: scheduledjobs
-- -----------------------------------------------------------------------------
CREATE TABLE job.scheduled_jobs (
    id                          public.oid PRIMARY KEY,
    name                        TEXT,
    command_programmatic_name   TEXT        NOT NULL,
    schedule                    JSONB       NOT NULL,                  -- { startTime, endTime, cronExpression }
    type                        TEXT        NOT NULL DEFAULT 'Scheduler',
    schedule_type               TEXT        NOT NULL,                  -- 'system' | 'user'
    active                      BOOLEAN     NOT NULL DEFAULT true,
    state                       TEXT        NOT NULL DEFAULT 'enabled',
    execution_history           BOOLEAN     NOT NULL DEFAULT false,
    execution_context           JSONB       NOT NULL,                  -- { tenantId, principal }
    parameter_data              JSONB,
    last_execution_id           public.oid,
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['Scheduler'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                 TEXT,
    modified_at                 TIMESTAMPTZ
);
CREATE INDEX ix_scheduled_jobs_command   ON job.scheduled_jobs (command_programmatic_name);
CREATE INDEX ix_scheduled_jobs_active    ON job.scheduled_jobs (active) WHERE active;
CREATE INDEX ix_scheduled_jobs_hierarchy ON job.scheduled_jobs USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- locks  <- Mongo: locks   (Quartz / Hazelcast cluster locks)
-- -----------------------------------------------------------------------------
CREATE TABLE job.locks (
    id              TEXT PRIMARY KEY,                                  -- the original Mongo `_id` is the lock key
    locked_by       TEXT,
    locked_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ
);
