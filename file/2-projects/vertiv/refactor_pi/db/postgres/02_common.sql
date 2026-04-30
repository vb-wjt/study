-- =============================================================================
-- Common types, domains and reusable functions.
-- ID convention:
--   * Mongo ObjectId is 24 hex chars (12 bytes). We keep it as CHAR(24) so that
--     migration is a 1:1 string copy and existing cross-collection string
--     references (e.g. baseobjects._id referenced by monitoredobjects.objectId)
--     remain comparable. New rows generated in PG MUST follow the same shape.
--   * `gen_oid()` produces a 24-char lowercase hex value: 8 hex from epoch
--     seconds + 16 hex random — collision-resistant and sortable.
-- =============================================================================

-- 24-char lowercase hex domain mirroring Mongo ObjectId surface.
CREATE DOMAIN public.oid AS CHAR(24)
    CHECK (VALUE ~ '^[0-9a-f]{24}$');

COMMENT ON DOMAIN public.oid IS 'Mongo-compatible ObjectId stored as 24-char lowercase hex.';

-- Generate a new ObjectId-shaped value.
CREATE OR REPLACE FUNCTION public.gen_oid() RETURNS public.oid
    LANGUAGE sql VOLATILE AS $$
    SELECT (
        lpad(to_hex(extract(epoch FROM now())::bigint), 8, '0')
        || encode(gen_random_bytes(8), 'hex')
    )::public.oid;
$$;

-- Audit trigger: keeps modified_at fresh and forbids tampering with created_at.
CREATE OR REPLACE FUNCTION public.tg_touch_modified() RETURNS TRIGGER
    LANGUAGE plpgsql AS $$
BEGIN
    NEW.modified_at := now();
    NEW.created_at  := OLD.created_at;
    NEW.created_by  := OLD.created_by;
    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.tg_touch_modified IS
    'Attach to BEFORE UPDATE on any table that follows the standard audit columns.';

-- Helper: convert epoch milliseconds (Mongo tsd.datapoints style) to timestamptz.
CREATE OR REPLACE FUNCTION public.epoch_ms_to_ts(ms BIGINT)
    RETURNS TIMESTAMPTZ LANGUAGE sql IMMUTABLE AS $$
    SELECT to_timestamp(ms::double precision / 1000.0)
$$;

-- Helper: extract the leaf type from a `_hierarchy` array (Mongo convention).
CREATE OR REPLACE FUNCTION public.hierarchy_leaf(h TEXT[])
    RETURNS TEXT LANGUAGE sql IMMUTABLE AS $$
    SELECT h[array_length(h, 1)]
$$;
