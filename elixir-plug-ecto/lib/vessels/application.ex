defmodule Vessels.Application do
  @moduledoc """
  Boots the two long-running children: the Ecto repo (connection pool to the
  shared Postgres) and the Bandit HTTP server fronting `Vessels.Router`.

  Both the database URL and the port come from the environment so the justfile
  wires them up the same way the other backends are wired (see the `ex-dev`
  recipe). The database owns the schema, so the repo never migrates.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    url = System.get_env("DATABASE_URL") || "ecto://app:app@localhost:5434/app"
    port = String.to_integer(System.get_env("PORT") || "8004")

    children = [
      {Vessels.Repo, url: url, pool_size: 10},
      {Bandit, plug: Vessels.Router, scheme: :http, port: port}
    ]

    Logger.info("elixir (plug+ecto) listening on http://localhost:#{port}")
    Supervisor.start_link(children, strategy: :one_for_one, name: Vessels.Supervisor)
  end
end
