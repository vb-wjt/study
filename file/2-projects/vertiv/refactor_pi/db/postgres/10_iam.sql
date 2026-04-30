-- =============================================================================
-- IAM: tenants, users, roles, permissions, relationship graph, certificates,
--      API keys.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- tenants  <- Mongo: tenants
-- -----------------------------------------------------------------------------
CREATE TABLE iam.tenants (
    id                  public.oid PRIMARY KEY,
    tenant_name         TEXT        NOT NULL,
    description         TEXT,
    contact             TEXT,
    parent_id           TEXT,                     -- 'top' or another tenant id
    descendant_access   BOOLEAN     NOT NULL DEFAULT false,
    type                TEXT        NOT NULL DEFAULT 'Tenant',         -- _type
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['Tenant'],  -- _hierarchy
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by         TEXT,
    modified_at         TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_tenants_name ON iam.tenants (tenant_name);
CREATE INDEX ix_tenants_hierarchy   ON iam.tenants USING gin (hierarchy);
CREATE INDEX ix_tenants_parent      ON iam.tenants (parent_id);

-- -----------------------------------------------------------------------------
-- users    <- Mongo: users
-- -----------------------------------------------------------------------------
CREATE TABLE iam.users (
    id                  public.oid PRIMARY KEY,
    username            citext      NOT NULL,
    programmatic_name   TEXT        NOT NULL,
    password_hash       TEXT        NOT NULL,             -- BCrypt; never PII
    email               citext,
    temporary_password  BOOLEAN     NOT NULL DEFAULT false,
    provider_type       TEXT        NOT NULL,             -- 'Internal', 'LDAP', ...
    category            TEXT        NOT NULL,             -- 'builtin' | 'user'
    tenant_id           public.oid  NOT NULL REFERENCES iam.tenants(id) ON DELETE RESTRICT,
    type                TEXT        NOT NULL DEFAULT 'User',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['User'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by         TEXT,
    modified_at         TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_users_username           ON iam.users (username);
CREATE UNIQUE INDEX ux_users_programmatic_name  ON iam.users (programmatic_name);
CREATE INDEX        ix_users_tenant             ON iam.users (tenant_id);
CREATE INDEX        ix_users_hierarchy          ON iam.users USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- roles    <- Mongo: roles
-- -----------------------------------------------------------------------------
CREATE TABLE iam.roles (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    programmatic_name   TEXT        NOT NULL,
    description         TEXT,
    category            TEXT        NOT NULL,             -- 'applicationDefined', 'custom'
    type                TEXT        NOT NULL DEFAULT 'Role',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['Role'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by         TEXT,
    modified_at         TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_roles_name              ON iam.roles (name);
CREATE UNIQUE INDEX ux_roles_programmatic_name ON iam.roles (programmatic_name);
CREATE INDEX        ix_roles_hierarchy         ON iam.roles USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- permissions  <- Mongo: permissions
-- 248 fine-grained permissions like `feature.taf-monitor.pdu.view`
-- -----------------------------------------------------------------------------
CREATE TABLE iam.permissions (
    id                  public.oid PRIMARY KEY,
    programmatic_name   TEXT        NOT NULL,
    category            TEXT        NOT NULL,
    type                TEXT        NOT NULL DEFAULT 'Permission',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['Permission'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_permissions_programmatic_name ON iam.permissions (programmatic_name);
CREATE INDEX        ix_permissions_hierarchy         ON iam.permissions USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- relationships  <- Mongo: relationships
-- Generic many-to-many graph table (462 rows). The `context` field discriminates
-- the semantics ('uiapipermissiongrants', 'userRoles', ...).
-- After migration, recommended follow-up is to split per `context` into typed
-- association tables; until then this preserves 1:1 fidelity.
-- -----------------------------------------------------------------------------
CREATE TABLE iam.relationships (
    id                  public.oid PRIMARY KEY,
    source_id           public.oid NOT NULL,
    target_id           public.oid NOT NULL,
    context             TEXT        NOT NULL,
    type                TEXT        NOT NULL,             -- _type, e.g. 'uiapipermissiongrants'
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['AbstractRelationship'],
    parent_ids          TEXT[],
    priority            INTEGER,
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_rel_target_source_context ON iam.relationships (target_id, source_id, context);
CREATE INDEX ix_rel_source                ON iam.relationships (source_id);
CREATE INDEX ix_rel_type                  ON iam.relationships (type);
CREATE INDEX ix_rel_hierarchy             ON iam.relationships USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- api_keys  <- Mongo: apikey  (currently 0 rows; index pattern preserved)
-- -----------------------------------------------------------------------------
CREATE TABLE iam.api_keys (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    api_key_hash        TEXT        NOT NULL,             -- HMAC of the secret
    owner_user_id       public.oid REFERENCES iam.users(id) ON DELETE CASCADE,
    enabled             BOOLEAN     NOT NULL DEFAULT true,
    expires_at          TIMESTAMPTZ,
    type                TEXT        NOT NULL DEFAULT 'ApiKey',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['ApiKey'],
    properties          JSONB       NOT NULL DEFAULT '{}'::jsonb,
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by         TEXT,
    modified_at         TIMESTAMPTZ
);
CREATE INDEX ix_apikey_hierarchy ON iam.api_keys USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- trust_certificates  <- Mongo: trustcertificates
-- Mongo stored raw bytes via `fileData` (BinData). PG keeps it as BYTEA.
-- -----------------------------------------------------------------------------
CREATE TABLE iam.trust_certificates (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    cert_type           TEXT        NOT NULL,             -- 'crt', 'p12', ...
    size                INTEGER     NOT NULL,
    category            TEXT        NOT NULL,             -- 'applicationDefined' | 'user'
    file_data           BYTEA       NOT NULL,
    details             JSONB       NOT NULL,             -- subject/issuer/sha256/...
    type                TEXT        NOT NULL DEFAULT 'CertMetadata',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['CertMetadata'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_certs_hierarchy ON iam.trust_certificates USING gin (hierarchy);
CREATE INDEX ix_certs_name      ON iam.trust_certificates (name);
