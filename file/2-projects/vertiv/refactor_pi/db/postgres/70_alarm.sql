-- =============================================================================
-- ALARMS / NOTIFICATIONS / TRAPS
-- All Mongo collections here are currently empty (skeleton); structure mirrors
-- the indexes that already exist in Mongo so the column shape is informed but
-- not authoritative. Review with product before treating as final.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- alarms  <- Mongo: alarms  (PARTITIONED on `timestamp` like events)
-- -----------------------------------------------------------------------------
CREATE TABLE alarm.alarms (
    id                              public.oid NOT NULL,
    alarm_type_programmatic_name    TEXT        NOT NULL,
    severity_programmatic_name      TEXT,
    state                           TEXT,                              -- 'Active' | 'Cleared' | 'Acknowledged'
    resource_id                     public.oid,
    resource_name                   TEXT,
    component_identifier            TEXT,
    timestamp                       TIMESTAMPTZ NOT NULL,
    cleared_at                      TIMESTAMPTZ,
    acknowledged_by                 TEXT,
    acknowledged_at                 TIMESTAMPTZ,
    transitions                     JSONB,                             -- alarm transition history
    notes                           JSONB,                             -- alarm notes (createdBy, time, note)
    data                            JSONB,
    object_type                     TEXT        NOT NULL DEFAULT 'Alarm',
    hierarchy                       TEXT[]      NOT NULL DEFAULT ARRAY['Alarm'],
    created_by                      TEXT        NOT NULL DEFAULT '',
    created_at                      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by                     TEXT,
    modified_at                     TIMESTAMPTZ,
    PRIMARY KEY (id, timestamp)
) PARTITION BY RANGE (timestamp);

CREATE INDEX ix_alarms_alarm_type    ON alarm.alarms (alarm_type_programmatic_name, timestamp DESC);
CREATE INDEX ix_alarms_resource      ON alarm.alarms (resource_id, timestamp DESC);
CREATE INDEX ix_alarms_state         ON alarm.alarms (state, timestamp DESC);
CREATE INDEX ix_alarms_hierarchy     ON alarm.alarms USING gin (hierarchy);

CREATE TABLE alarm.alarms_y2026m04 PARTITION OF alarm.alarms
    FOR VALUES FROM ('2026-04-01') TO ('2026-05-01');
CREATE TABLE alarm.alarms_y2026m05 PARTITION OF alarm.alarms
    FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE alarm.alarms_default PARTITION OF alarm.alarms DEFAULT;

-- -----------------------------------------------------------------------------
-- alarm_action_configs / alarm_action_nodes / alarm_action_jobs
-- -----------------------------------------------------------------------------
CREATE TABLE alarm.alarm_action_configs (
    id              public.oid PRIMARY KEY,
    name            TEXT,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'AlarmActionConfig',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['AlarmActionConfig'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_alarm_action_configs_hierarchy ON alarm.alarm_action_configs USING gin (hierarchy);

CREATE TABLE alarm.alarm_action_nodes (
    id              public.oid PRIMARY KEY,
    node_id         TEXT        NOT NULL,
    config_id       public.oid REFERENCES alarm.alarm_action_configs(id) ON DELETE CASCADE,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'AlarmActionNode',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['AlarmActionNode'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_alarm_action_nodes_node_id    ON alarm.alarm_action_nodes (node_id);
CREATE INDEX ix_alarm_action_nodes_config     ON alarm.alarm_action_nodes (config_id);
CREATE INDEX ix_alarm_action_nodes_hierarchy  ON alarm.alarm_action_nodes USING gin (hierarchy);

CREATE TABLE alarm.alarm_action_jobs (
    id              public.oid PRIMARY KEY,
    alarm_id_list   TEXT[]      NOT NULL,
    state           TEXT,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'AlarmActionJob',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['AlarmActionJob'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_alarm_action_jobs_alarm_ids ON alarm.alarm_action_jobs USING gin (alarm_id_list);
CREATE INDEX ix_alarm_action_jobs_hierarchy ON alarm.alarm_action_jobs USING gin (hierarchy);

CREATE TABLE alarm.actions_persisted (
    id              public.oid PRIMARY KEY,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'PersistedAction',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['PersistedAction'],
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_actions_persisted_hierarchy ON alarm.actions_persisted USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- notification_configs / notification_jobs / sms_providers
-- -----------------------------------------------------------------------------
CREATE TABLE alarm.notification_configs (
    id              public.oid PRIMARY KEY,
    name            TEXT,
    enabled         BOOLEAN     NOT NULL DEFAULT true,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'NotificationConfig',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['NotificationConfig'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_notif_configs_hierarchy ON alarm.notification_configs USING gin (hierarchy);

CREATE TABLE alarm.notification_jobs (
    id              public.oid PRIMARY KEY,
    alarm_id        public.oid,
    trigger_time    TIMESTAMPTZ,
    state           TEXT,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'NotificationJob',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['NotificationJob'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_notif_jobs_alarm     ON alarm.notification_jobs (alarm_id);
CREATE INDEX ix_notif_jobs_trigger   ON alarm.notification_jobs (trigger_time);
CREATE INDEX ix_notif_jobs_hierarchy ON alarm.notification_jobs USING gin (hierarchy);

CREATE TABLE alarm.sms_providers (
    id              public.oid PRIMARY KEY,
    service_path    TEXT        NOT NULL,                              -- e.g. 'modemsmsmessages'
    enabled         BOOLEAN     NOT NULL DEFAULT true,
    settings        JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'SmsProvider',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['SmsProvider'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_sms_providers_service_path ON alarm.sms_providers (service_path);
CREATE INDEX        ix_sms_providers_hierarchy    ON alarm.sms_providers USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- trap_constraints / trap_destinations  (SNMP traps; currently empty)
-- -----------------------------------------------------------------------------
CREATE TABLE alarm.trap_constraints (
    id          public.oid PRIMARY KEY,
    name        TEXT        NOT NULL,
    payload     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type        TEXT        NOT NULL DEFAULT 'TrapConstraint',
    hierarchy   TEXT[]      NOT NULL DEFAULT ARRAY['TrapConstraint'],
    created_by  TEXT        NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_trap_constraints_name ON alarm.trap_constraints (name);
CREATE INDEX        ix_trap_constraints_hierarchy ON alarm.trap_constraints USING gin (hierarchy);

CREATE TABLE alarm.trap_destinations (
    id                          public.oid PRIMARY KEY,
    destination_ipv4_address    TEXT,
    destination_ipv6_address    TEXT,
    payload                     JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type                        TEXT        NOT NULL DEFAULT 'TrapDestination',
    hierarchy                   TEXT[]      NOT NULL DEFAULT ARRAY['TrapDestination'],
    created_by                  TEXT        NOT NULL DEFAULT '',
    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_trap_dest_addrs ON alarm.trap_destinations
    (destination_ipv4_address, destination_ipv6_address);
CREATE INDEX        ix_trap_dest_hierarchy ON alarm.trap_destinations USING gin (hierarchy);
