# Polyglot backends — Python (Litestar), Go (huma+ent), OCaml (Dream+Caqti)
# Postgres runs in Docker; each backend runs locally against it.

# Local connection strings (each driver wants a slightly different shape).
export PG_PY   := "postgresql+asyncpg://app:app@localhost:5434/app"
export PG_GO   := "postgres://app:app@localhost:5434/app?sslmode=disable"
export PG_ML   := "postgresql://app:app@localhost:5434/app"
export PG_EX   := "ecto://app:app@localhost:5434/app"
export PG_RS   := "postgres://app:app@localhost:5434/app"

default:
    @just --list

# --- database ---

# Start Postgres and wait until it is accepting connections.
db:
    docker compose up -d db
    @echo "waiting for postgres..."
    @until docker compose exec -T db pg_isready -U app -d app >/dev/null 2>&1; do sleep 1; done
    @echo "postgres ready on localhost:5432"

db-stop:
    docker compose stop db

# Drop the database volume (wipes all data, re-seeds schema on next `just db`).
db-reset:
    docker compose down -v

psql:
    docker compose exec db psql -U app -d app

# --- python (litestar + advanced-alchemy), port 8001 ---

py-install:
    cd python-litestar && uv sync

py-dev: db
    cd python-litestar && DATABASE_URL="$PG_PY" uv run litestar --app app.main:app run --host 0.0.0.0 --port 8001

# --- go (huma + ent), port 8002 ---

# Regenerate ent's typed client from the schema in go-huma-ent/ent/schema.
go-gen:
    cd go-huma-ent && go generate ./...

go-dev: db go-gen
    cd go-huma-ent && DATABASE_URL="$PG_GO" go run .

# --- ocaml (dream + caqti), port 8003 ---

ml-build:
    cd ocaml-dream && opam exec -- dune build

ml-dev: db ml-build
    cd ocaml-dream && DATABASE_URL="$PG_ML" opam exec -- dune exec ./bin/main.exe

# --- elixir (plug + bandit + ecto), port 8004 ---

ex-install:
    cd elixir-plug-ecto && mix deps.get

ex-dev: db
    cd elixir-plug-ecto && DATABASE_URL="$PG_EX" mix run --no-halt

# --- rust (axum + sea-orm + utoipa), port 8005 ---

rs-dev: db
    cd rust-axum-seaorm && DATABASE_URL="$PG_RS" cargo run

# --- smoke test (run the five `*-dev` recipes in separate terminals first) ---

smoke:
    @echo "== python (8001) ==" && curl -s localhost:8001/health && echo
    @echo "== go     (8002) ==" && curl -s localhost:8002/health && echo
    @echo "== ocaml  (8003) ==" && curl -s localhost:8003/health && echo
    @echo "== elixir (8004) ==" && curl -s localhost:8004/health && echo
    @echo "== rust   (8005) ==" && curl -s localhost:8005/health && echo
    @echo "== create via go, list via python ==" \
        && curl -s -X POST localhost:8002/vessels -H 'content-type: application/json' \
             -d '{"name":"Black Pearl","length_m":40.5}' && echo \
        && curl -s localhost:8001/vessels && echo
