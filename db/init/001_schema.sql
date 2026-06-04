-- Shared schema for all three backends. Loaded automatically by the postgres
-- container on first boot (docker-entrypoint-initdb.d). Owned here so every
-- service reads/writes the exact same table — none of them run migrations.

CREATE TABLE IF NOT EXISTS vessels (
    id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       TEXT             NOT NULL,
    length_m   DOUBLE PRECISION NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ      NOT NULL DEFAULT now()
);

INSERT INTO vessels (name, length_m) VALUES
    ('Sloop John B', 8.5),
    ('Marie Celeste', 31.0);
