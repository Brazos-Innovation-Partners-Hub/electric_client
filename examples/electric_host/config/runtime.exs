import Config

# The Electric server this application runs, reading its own database, with its HTTP API on the
# port the client reads from: a temporary slot, and storage of its own for each run.
database = "electric_host_client_#{config_env()}"
host = System.get_env("PGHOST", "localhost")
port = System.get_env("PGPORT", "5432")

config :electric,
  start_in_library_mode: false,
  replication_connection_opts:
    Electric.Config.parse_postgresql_uri!(
      "postgresql://postgres:postgres@#{host}:#{port}/#{database}?sslmode=disable"
    ),
  enable_http_api: true,
  service_port: String.to_integer(System.get_env("ELECTRIC_HOST_PORT", "3418")),
  allow_shape_deletion?: true,
  replication_stream_id: "electric_host_client",
  replication_slot_temporary?: true,
  storage_dir:
    Path.join(System.tmp_dir!(), "electric-host-client-#{System.unique_integer([:positive])}")
