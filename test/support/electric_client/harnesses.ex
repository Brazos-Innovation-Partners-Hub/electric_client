defmodule Electric.Client.Test.MockHarness do
  @moduledoc """
  Drives `Electric.Client.Mock` for `Electric.Client.FetchConformance`: each answer is primed
  on a new mock's endpoint before the suite reads. Ours, not upstream's.
  """
  @behaviour Electric.Client.FetchConformance.Harness

  alias Electric.Client.Fetch
  alias Electric.Client.Mock

  @impl true
  def options, do: [endpoint: self()]

  @impl true
  def refused, do: [[]]

  @impl true
  def arrange(answer) do
    {:ok, client} = Mock.new()
    {Mock, options} = client.fetch
    Mock.async_response(client, response(answer))

    request = %Fetch.Request{
      endpoint: URI.parse("http://mock.electric/v1/shape"),
      params: %{"table" => table(answer)}
    }

    {request, options}
  end

  defp table(:failure), do: "missing"
  defp table(_answer), do: "items"

  defp response(:failure), do: [status: 400, body: [%{"message" => "no table missing"}]]

  defp response(_answer) do
    [
      status: 200,
      shape_handle: "items-1",
      last_offset: "0_0",
      schema: %{id: %{type: "int8", pk_index: 0}, title: %{type: "text"}},
      body: Mock.transaction([%{id: "1", title: "Buy milk"}])
    ]
  end
end

defmodule Electric.Client.Test.HTTPHarness do
  @moduledoc """
  Drives `Electric.Client.Fetch.HTTP` for `Electric.Client.FetchConformance`, against the
  stand-in Electric server the suite starts (`Electric.Client.Test.FakeElectric`). Ours, not
  upstream's.
  """
  @behaviour Electric.Client.FetchConformance.Harness

  alias Electric.Client.Fetch
  alias Electric.Client.Test.FakeElectric

  @impl true
  def options, do: [timeout: 5]

  @impl true
  def refused, do: [[timeout: 0], [headers: 3]]

  @impl true
  def arrange(answer) do
    table = if answer == :failure, do: "missing", else: "items"
    {%Fetch.Request{endpoint: FakeElectric.endpoint(), params: %{"table" => table}}, options()}
  end
end

defmodule Electric.Client.Test.EmbeddedHarness do
  @moduledoc """
  Drives `Electric.Client.Embedded` for `Electric.Client.FetchConformance`, against the
  Electric the suite embeds and its database: a table of its own is made and filled for a
  read, a change is written while a live read waits, and a table the database does not have is
  read for a failure. Ours, not upstream's.
  """
  @behaviour Electric.Client.FetchConformance.Harness

  alias Electric.Client.Embedded
  alias Electric.Client.Fetch

  @table "conformance_items"

  @impl true
  def options,
    do: [api: Electric.Application.api(encoder: Electric.Shapes.Api.Encoder.Term)]

  @impl true
  def refused, do: [[]]

  @impl true
  def arrange(:failure),
    do: {request(%{"table" => "no_such_table_for_conformance"}), options()}

  def arrange(:rows) do
    query!(
      "CREATE TABLE IF NOT EXISTS #{@table} (id uuid PRIMARY KEY, title text)",
      []
    )

    query!("INSERT INTO #{@table} (id, title) VALUES (gen_random_uuid(), $1)", ["Buy milk"])
    {request(%{"table" => @table}), options()}
  end

  # A live read waits for a change: read the shape up to date first, then write a row once
  # the live read is waiting.
  def arrange(:live) do
    {request, options} = arrange(:rows)
    {:ok, validated} = Embedded.validate_opts(options)
    {:ok, read} = Embedded.fetch(%{request | authenticated: true}, validated)

    Task.start(fn ->
      Process.sleep(300)
      query!("INSERT INTO #{@table} (id, title) VALUES (gen_random_uuid(), $1)", ["Pay rent"])
    end)

    {%{request | shape_handle: read.shape_handle, offset: read.last_offset}, options}
  end

  defp request(params),
    do: %Fetch.Request{
      endpoint: URI.parse("elixir://Electric.Client.Embedded"),
      params: params,
      live: false
    }

  defp query!(sql, params) do
    config =
      :electric_client
      |> Application.fetch_env!(:database_config)
      |> Electric.Utils.deobfuscate_password()

    {:ok, conn} = Postgrex.start_link(config ++ [backoff_type: :stop])

    try do
      Postgrex.query!(conn, sql, params)
    after
      GenServer.stop(conn)
    end
  end
end
