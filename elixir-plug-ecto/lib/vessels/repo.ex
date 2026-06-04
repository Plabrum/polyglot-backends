defmodule Vessels.Repo do
  @moduledoc """
  Ecto repo for the shared `app` database. The schema is owned by the database
  (db/init/001_schema.sql) — this service never migrates, so it must not be
  started with `ecto.create`/`ecto.migrate`. All connection config is passed in
  at runtime by `Vessels.Application`.
  """
  use Ecto.Repo, otp_app: :vessels, adapter: Ecto.Adapters.Postgres
end
