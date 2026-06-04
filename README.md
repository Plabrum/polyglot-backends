# polyglot-backends

Five implementations of the same tiny web backend — **Python (Litestar)**,
**Go (huma + ent)**, **OCaml (Dream + Caqti)**, **Elixir (Plug + Ecto)**, and
**Rust (Axum + SeaORM)** — all talking to one shared Postgres database. Built to
compare the stacks side by side.

Every service exposes the same API over a shared `vessels` table:

| Method | Path        | Description                              |
| ------ | ----------- | ---------------------------------------- |
| GET    | `/health`   | liveness + which service answered        |
| GET    | `/vessels`  | list all vessels                         |
| POST   | `/vessels`  | create a vessel `{name, length_m}`       |

| Service | Stack                              | Port |
| ------- | ---------------------------------- | ---- |
| Python  | Litestar + Advanced Alchemy + asyncpg | 8001 |
| Go      | huma + ent + pgx                   | 8002 |
| OCaml   | Dream + Caqti + caqti-driver-postgresql | 8003 |
| Elixir  | Plug + Bandit + Ecto + Postgrex    | 8004 |
| Rust    | Axum + SeaORM + utoipa             | 8005 |

Postgres runs in Docker; the five backends run locally against it. The schema
lives in `db/init/001_schema.sql` and is owned by the database — no service runs
migrations, so all five see identical data.

## Prerequisites

- Docker (for Postgres)
- [`just`](https://github.com/casey/just)
- Python toolchain: [`uv`](https://docs.astral.sh/uv/)
- Go toolchain: `go` 1.23+
- OCaml toolchain: `opam` with `dune dream caqti-driver-postgresql caqti-lwt yojson lwt_ppx`
  - `caqti-driver-postgresql` needs libpq. On macOS: `brew install libpq` and
    `export PKG_CONFIG_PATH="/opt/homebrew/opt/libpq/lib/pkgconfig"` before `opam install`.
- Elixir toolchain: `elixir` 1.15+ / OTP 25+ (`mix` ships with it). On macOS:
  `brew install elixir`. Deps install with `just ex-install` (`mix deps.get`).
- Rust toolchain: `cargo` / `rustc` 1.75+ (via [rustup](https://rustup.rs)).
  `just rs-dev` fetches crates and compiles on first run.

Postgres is published on host port **5434** (to avoid colliding with other local
Postgres instances); the connection strings in the justfile already use it.

## Quick start

```sh
just db            # start Postgres (seeds the schema on first boot)

# each backend runs in the foreground — use separate terminals
just py-dev        # http://localhost:8001
just go-dev        # http://localhost:8002  (also serves OpenAPI docs at /docs)
just ml-dev        # http://localhost:8003
just ex-dev        # http://localhost:8004
just rs-dev        # http://localhost:8005  (also serves OpenAPI docs at /docs)

just smoke         # curl /health on all five + a cross-service write/read
```

Try it:

```sh
curl localhost:8002/vessels
curl -X POST localhost:8001/vessels \
  -H 'content-type: application/json' \
  -d '{"name":"Black Pearl","length_m":40.5}'
```

## Layout

```
db/init/001_schema.sql   shared schema (auto-loaded by the postgres container)
python-litestar/         uv project; app/main.py is the whole service
go-huma-ent/             ent schema in ent/schema/, `just go-gen` regenerates the client
ocaml-dream/             dune project; bin/main.ml is the whole service
elixir-plug-ecto/        mix project; lib/vessels/ holds the repo, schema, and router
rust-axum-seaorm/        cargo project; src/main.rs is the service, src/entity/ the SeaORM model
justfile                 db + per-service dev recipes
docker-compose.yml       Postgres only
```

## Notes per stack

- **Python** — Advanced Alchemy is Litestar's first-party SQLAlchemy layer. The
  `Vessel` model maps onto the existing table; `SQLAlchemyPlugin` injects an
  `AsyncSession` (`db_session`) into handlers. `uv sync` installs deps.
- **Go** — `ent` generates a typed client from `ent/schema/vessel.go`. The
  generated `ent/` package is git-ignored-friendly but committed-safe; run
  `just go-gen` after editing the schema. `huma` gives typed handlers and a free
  OpenAPI spec + docs UI. ent connects through the `pgx` stdlib driver.
- **OCaml** — Dream's `sql_pool` middleware wraps a Caqti connection pool;
  handlers use `Dream.sql` to borrow a connection. Queries are typed with
  `Caqti_request`/`Caqti_type`. `created_at` is cast to text in SQL to skip a
  `ptime` decoder.
- **Elixir** — `Vessels.Application` supervises an Ecto repo (the Postgres
  connection pool) and a Bandit HTTP server fronting a `Plug.Router`. The
  `Vessels.Vessel` Ecto schema maps the existing table; both queries `select`
  straight into JSON-shaped maps and cast `created_at` to text in SQL (same
  trick as OCaml) so no timestamp decoder is needed. `mix deps.get` installs
  deps; `mix run --no-halt` boots the supervision tree. The DB owns the schema,
  so the repo never runs `ecto.create`/`ecto.migrate`.
- **Rust** — Axum routes share a SeaORM `DatabaseConnection` pool via `State`.
  The `vessel` entity in `src/entity/` is the hand-written SeaORM model mapping
  the existing table (no migrations); `utoipa` derives the OpenAPI spec from the
  `VesselIn`/`VesselOut` wire structs and `utoipa-swagger-ui` serves it at
  `/docs`. SeaORM has no lazy loading or dirty-tracking, so reads and writes are
  explicit (`find()` / `ActiveModel::insert`); `id` and `created_at` are left
  `NotSet` so Postgres fills them via `RETURNING`. Cargo fetches and compiles on
  first `just rs-dev`.
