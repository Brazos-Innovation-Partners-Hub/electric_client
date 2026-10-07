defmodule ElectricHost.MixProject do
  use Mix.Project

  def project do
    [
      app: :electric_host,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: [test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]]
    ]
  end

  def application do
    [extra_applications: [:logger], mod: {ElectricHost.Application, []}]
  end

  defp deps do
    [
      {:electric_client, path: "../.."},
      # The Electric server this application runs over its own database, with its HTTP API on.
      {:electric, "~> 1.8"},
      # Electric's generated protobuf code must match the protox runtime; the version Hex
      # resolves for Electric alone does not.
      {:protox, "~> 2.0.10"},
      {:ecto_sql, "~> 3.12"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.4"}
    ]
  end
end
