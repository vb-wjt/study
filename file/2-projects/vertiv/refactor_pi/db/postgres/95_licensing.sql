-- =============================================================================
-- LICENSING
-- Stores licensed structures (what is licensable), features (current activation
-- state), products and internal counters (e.g. CREATE_DEVICE quota).
-- =============================================================================

-- -----------------------------------------------------------------------------
-- licensed_structures  <- Mongo: licensedstructures
-- -----------------------------------------------------------------------------
CREATE TABLE licensing.licensed_structures (
    id              public.oid PRIMARY KEY,
    name            TEXT        NOT NULL,
    feature_type    TEXT        NOT NULL,                              -- 'COUNTED' | 'BOOLEAN'
    model           TEXT        NOT NULL,                              -- 'User' | 'Device' | ...
    operation       TEXT,                                              -- 'CREATE' | 'UPDATE' | ...
    action_name     TEXT,
    type            TEXT        NOT NULL DEFAULT 'BasicLicensedStructure',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['BasicLicensedStructure'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_licensed_structures_name      ON licensing.licensed_structures (name);
CREATE INDEX ix_licensed_structures_hierarchy ON licensing.licensed_structures USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- internal_licensed_features  <- Mongo: internallicensedfeatures
-- -----------------------------------------------------------------------------
CREATE TABLE licensing.internal_licensed_features (
    id                  public.oid PRIMARY KEY,
    name                TEXT        NOT NULL,
    feature_version     TEXT        NOT NULL,
    quota_count         INTEGER     NOT NULL,                          -- e.g. CREATE_DEVICE = 100
    type                TEXT        NOT NULL DEFAULT 'InternalLicensedFeature',
    hierarchy           TEXT[]      NOT NULL DEFAULT ARRAY['InternalLicensedFeature'],
    created_by          TEXT        NOT NULL DEFAULT '',
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX ux_internal_features_name      ON licensing.internal_licensed_features (name);
CREATE INDEX        ix_internal_features_hierarchy ON licensing.internal_licensed_features USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- licensed_features  <- Mongo: licensedfeatures   (currently empty)
-- -----------------------------------------------------------------------------
CREATE TABLE licensing.licensed_features (
    id              public.oid PRIMARY KEY,
    name            TEXT,
    feature_version TEXT,
    quantity        INTEGER,
    expires_at      TIMESTAMPTZ,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'LicensedFeature',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['LicensedFeature'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_licensed_features_name      ON licensing.licensed_features (name);
CREATE INDEX ix_licensed_features_hierarchy ON licensing.licensed_features USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- licensed_products  <- Mongo: licensedproducts  (currently empty)
-- -----------------------------------------------------------------------------
CREATE TABLE licensing.licensed_products (
    id              public.oid PRIMARY KEY,
    product_name    TEXT,
    activated       BOOLEAN     NOT NULL DEFAULT false,
    payload         JSONB       NOT NULL DEFAULT '{}'::jsonb,
    type            TEXT        NOT NULL DEFAULT 'LicensedProduct',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['LicensedProduct'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_licensed_products_name      ON licensing.licensed_products (product_name);
CREATE INDEX ix_licensed_products_hierarchy ON licensing.licensed_products USING gin (hierarchy);
