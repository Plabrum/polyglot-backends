defmodule Vessels.Router do
  @moduledoc "The whole HTTP surface: GET /health, GET /vessels, POST /vessels."
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:json], pass: ["application/json"], json_decoder: Jason
  plug :dispatch

  get "/health" do
    json(conn, 200, %{status: "ok", service: "elixir-plug-ecto"})
  end

  get "/vessels" do
    json(conn, 200, Vessels.Vessel.all())
  end

  post "/vessels" do
    case Vessels.Vessel.create(conn.body_params) do
      {:ok, vessel} -> json(conn, 201, vessel)
      {:error, changeset} -> json(conn, 422, %{errors: errors(changeset)})
    end
  end

  match _ do
    json(conn, 404, %{error: "not found"})
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end

  # Render changeset errors as a field => [messages] map, interpolating opts.
  defp errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {k, v}, acc ->
        String.replace(acc, "%{#{k}}", to_string(v))
      end)
    end)
  end
end
