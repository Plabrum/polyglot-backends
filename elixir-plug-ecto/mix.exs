defmodule Vessels.MixProject do
  use Mix.Project

  def project do
    [
      app: :vessels,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # OTP application — Vessels.Application boots the Ecto repo + Bandit server.
  def application do
    [
      extra_applications: [:logger],
      mod: {Vessels.Application, []}
    ]
  end

  defp deps do
    [
      {:bandit, "~> 1.0"},
      {:plug, "~> 1.15"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
