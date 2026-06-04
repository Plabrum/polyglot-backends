defmodule Vessels.Vessel do
  @moduledoc """
  Ecto schema mapped onto the existing `vessels` table plus the two queries the
  API needs. Like the other backends, `length_m` is optional and defaults to 0.

  `created_at` is rendered with a `::text` cast in SQL (mirroring the OCaml
  example) so we never decode a Postgres timestamp on the way out — Jason then
  ships it as the plain string Postgres produced.
  """
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias Vessels.Repo

  @primary_key {:id, :id, autogenerate: true}
  schema "vessels" do
    field :name, :string
    field :length_m, :float, default: 0.0
    # DB owns the default; we only ever read it back via the ::text cast below.
    field :created_at, :string
  end

  @doc "Validates a create payload — only `name` is required (length_m defaults to 0)."
  def changeset(vessel, attrs) do
    vessel
    |> cast(attrs, [:name, :length_m])
    |> validate_required([:name])
  end

  @doc "All vessels, oldest first, as JSON-ready maps."
  def all do
    Repo.all(
      from v in __MODULE__,
        order_by: [asc: v.id],
        select: %{
          id: v.id,
          name: v.name,
          length_m: v.length_m,
          created_at: fragment("?::text", v.created_at)
        }
    )
  end

  @doc "Insert a vessel and return its JSON-ready map, or `{:error, changeset}`."
  def create(attrs) do
    case %__MODULE__{} |> changeset(attrs) |> Repo.insert() do
      {:ok, vessel} -> {:ok, fetch(vessel.id)}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp fetch(id) do
    Repo.one(
      from v in __MODULE__,
        where: v.id == ^id,
        select: %{
          id: v.id,
          name: v.name,
          length_m: v.length_m,
          created_at: fragment("?::text", v.created_at)
        }
    )
  end
end
