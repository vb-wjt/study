-- =============================================================================
-- FILE / GRIDFS
-- Two separate concerns:
--   1) `file.file_metadata` is the application-level catalog (path, MIME, ...).
--   2) `file.fs_files` + `file.fs_chunks` mirror the Mongo GridFS layout for a
--      drop-in migration. RECOMMENDED: in production, store binary in S3/MinIO
--      and let `file_metadata.location` point at the object key instead.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- file_metadata  <- Mongo: filemanager
-- `location.address` originally references fs.files._id; here we keep the
-- address as TEXT so it can also hold an S3 key after the binary migration.
-- -----------------------------------------------------------------------------
CREATE TABLE file.file_metadata (
    id              public.oid PRIMARY KEY,
    name            TEXT        NOT NULL,
    file_path       TEXT        NOT NULL,
    full_name       TEXT        NOT NULL,                              -- file_path + '/' + name
    file_type       TEXT        NOT NULL,                              -- 'file' | 'directory'
    content_type    TEXT,                                              -- MIME
    size_bytes      BIGINT      NOT NULL,
    location_type   TEXT        NOT NULL,                              -- 'db' | 's3' | 'fs'
    location_address TEXT       NOT NULL,                              -- fs_files.id | s3 key | fs path
    type            TEXT        NOT NULL DEFAULT 'FileMetadata',
    hierarchy       TEXT[]      NOT NULL DEFAULT ARRAY['FileMetadata'],
    created_by      TEXT        NOT NULL DEFAULT '',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    modified_by     TEXT,
    modified_at     TIMESTAMPTZ
);
CREATE UNIQUE INDEX ux_file_metadata_full_name ON file.file_metadata (full_name);
CREATE INDEX        ix_file_metadata_path      ON file.file_metadata (file_path);
CREATE INDEX        ix_file_metadata_hierarchy ON file.file_metadata USING gin (hierarchy);

-- -----------------------------------------------------------------------------
-- fs_files / fs_chunks  <- Mongo: fs.files / fs.chunks
-- Direct port of the GridFS layout. Use only if you are NOT migrating the
-- binary blobs to object storage.
-- -----------------------------------------------------------------------------
CREATE TABLE file.fs_files (
    id              public.oid PRIMARY KEY,
    filename        TEXT        NOT NULL,
    length          BIGINT      NOT NULL,
    chunk_size      INTEGER     NOT NULL,
    upload_date     TIMESTAMPTZ NOT NULL DEFAULT now(),
    metadata        JSONB       NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX ix_fs_files_filename_uploaded ON file.fs_files (filename, upload_date);

CREATE TABLE file.fs_chunks (
    id              public.oid PRIMARY KEY,
    files_id        public.oid NOT NULL REFERENCES file.fs_files(id) ON DELETE CASCADE,
    n               INTEGER     NOT NULL,
    data            BYTEA       NOT NULL
);
CREATE UNIQUE INDEX ux_fs_chunks_files_n ON file.fs_chunks (files_id, n);
