defmodule Electric.Client.Test.FakeElectric do
  @moduledoc """
  A stand-in for an Electric server, served over HTTP for the HTTP fetcher's proof
  (`Electric.Client.Test.HTTPHarness`). It answers a read of any table with one row and an
  up-to-date message, with Electric's headers, and refuses the table `missing` with 400, as
  Electric refuses a table it does not have. Ours, not upstream's.
  """
  @behaviour Plug

  import Plug.Conn

  @schema %{id: %{type: "int8", pk_index: 0, not_null: true}, title: %{type: "text"}}

  @doc "Starts the server on a free loopback port, once, and keeps its port for the harness."
  @spec start!() :: :ok
  def start! do
    {:ok, server} =
      Bandit.start_link(plug: __MODULE__, port: 0, ip: :loopback, startup_log: false)

    {:ok, {_address, port}} = ThousandIsland.listener_info(server)
    :persistent_term.put({__MODULE__, :port}, port)
    :ok
  end

  @doc "The shape endpoint the server answers on."
  @spec endpoint() :: URI.t()
  def endpoint,
    do: URI.parse("http://127.0.0.1:#{:persistent_term.get({__MODULE__, :port})}/v1/shape")

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    conn = fetch_query_params(conn)

    case conn.query_params["table"] do
      "missing" ->
        json(conn, 400, %{message: "Invalid request", errors: %{table: ["does not exist"]}})

      table ->
        conn
        |> put_resp_header("electric-handle", "#{table}-1")
        |> put_resp_header("electric-offset", "0_0")
        |> put_resp_header("electric-schema", Jason.encode!(@schema))
        |> put_resp_header("electric-cursor", "1")
        |> json(200, [
          %{
            key: ~s("public"."#{table}"/"1"),
            value: %{id: "1", title: "Buy milk"},
            headers: %{operation: "insert"}
          },
          %{headers: %{control: "up-to-date"}}
        ])
    end
  end

  defp json(conn, status, body) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(body))
  end
end
