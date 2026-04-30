-- =============================================================================
-- PostgreSQL extensions required by the refactored PI schema.
-- Target: PostgreSQL 16+ (works on 14+).
-- Run order: first.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;        -- gen_random_uuid(), digest()
CREATE EXTENSION IF NOT EXISTS btree_gin;       -- composite GIN over scalar+jsonb
CREATE EXTENSION IF NOT EXISTS pg_trgm;         -- fuzzy search on names/keys
CREATE EXTENSION IF NOT EXISTS citext;          -- case-insensitive text (e-mails, usernames)

-- Optional: enable when the operator wants in-DB JSON Schema validation.
-- Requires the pg_jsonschema extension (https://github.com/supabase/pg_jsonschema).
-- CREATE EXTENSION IF NOT EXISTS pg_jsonschema;

-- Optional: enable when telemetry volume justifies a TS-engine.
-- CREATE EXTENSION IF NOT EXISTS timescaledb;
