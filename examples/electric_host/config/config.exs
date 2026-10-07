import Config

config :electric_host, ecto_repos: [ElectricHost.Repo]

config :electric_host, ElectricHost.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("PGHOST", "localhost"),
  port: String.to_integer(System.get_env("PGPORT", "5432")),
  database: "electric_host_client_#{config_env()}",
  pool_size: 5

config :logger, level: :warning
