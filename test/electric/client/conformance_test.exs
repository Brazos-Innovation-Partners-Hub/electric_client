# The client's conformance suites catch each kind of broken implementation, and never pass on
# nothing. Ours, not upstream's.
defmodule Electric.Client.ConformanceTest do
  use ExUnit.Case, async: true

  alias Electric.Client.{
    AuthenticatorConformance,
    Fetch,
    FetchConformance,
    ValueMapperConformance
  }

  alias Electric.Client.Test.MockHarness

  # -- fetchers ------------------------------------------------------------------------------

  defmodule Answering do
    @moduledoc false
    # A fetcher answering whatever `answer/2` says, accepting what `accept?/1` says.
    defmacro __using__(_opts) do
      quote do
        @behaviour Electric.Client.Fetch

        @impl true
        def validate_opts(opts),
          do: if(Keyword.has_key?(opts, :endpoint), do: {:ok, opts}, else: {:error, :refused})

        @impl true
        def fetch(request, _opts), do: answer(request.params["table"], request.live)

        def rows(fields \\ []) do
          struct(
            %Fetch.Response{
              status: 200,
              shape_handle: "items-1",
              last_offset: "0_0",
              schema: %{id: %{type: "int8"}},
              next_cursor: 1,
              body: [%{"headers" => %{"control" => "up-to-date"}}]
            },
            fields
          )
        end

        defoverridable validate_opts: 1
      end
    end
  end

  defmodule Sound do
    @moduledoc false
    use Answering
    def answer("missing", _live), do: {:ok, %Fetch.Response{status: 400}}
    def answer(_table, _live), do: {:ok, rows()}
  end

  defmodule AcceptsAnything do
    @moduledoc false
    use Answering
    @impl true
    def validate_opts(opts), do: {:ok, opts}
    def answer("missing", _live), do: {:error, :refused}
    def answer(_table, _live), do: {:ok, rows()}
  end

  defmodule NoHandle do
    @moduledoc false
    use Answering
    def answer("missing", _live), do: {:error, :refused}
    def answer(_table, _live), do: {:ok, rows(shape_handle: nil)}
  end

  defmodule RaisesOnFailure do
    @moduledoc false
    use Answering
    def answer("missing", _live), do: raise("no such table")
    def answer(_table, _live), do: {:ok, rows()}
  end

  defmodule FailsAsSuccess do
    @moduledoc false
    use Answering
    def answer(_table, _live), do: {:ok, rows()}
  end

  defmodule LiveWithoutCursor do
    @moduledoc false
    use Answering
    def answer("missing", _live), do: {:error, :refused}
    def answer(_table, true), do: {:ok, rows(next_cursor: nil)}
    def answer(_table, false), do: {:ok, rows()}
  end

  test "a sound fetcher is proved, driven by its harness" do
    assert :ok = FetchConformance.prove(Sound, harness: MockHarness)
  end

  test "the fetch suite needs a harness and a fetcher" do
    assert {:error, [failure]} = FetchConformance.prove(Sound)
    assert failure =~ "harness:"
    assert {:error, [failure]} = FetchConformance.prove(String, harness: MockHarness)
    assert failure =~ "does not implement Electric.Client.Fetch"
  end

  test "a fetcher that accepts the options it must refuse is caught" do
    assert {:error, failures} = FetchConformance.prove(AcceptsAnything, harness: MockHarness)
    assert Enum.any?(failures, &(&1 =~ "which it must refuse"))
  end

  test "a read answered without the shape's handle is caught" do
    assert {:error, failures} = FetchConformance.prove(NoHandle, harness: MockHarness)
    assert Enum.any?(failures, &(&1 =~ "without the shape's handle"))
  end

  test "a fetcher that raises on a failure is caught" do
    assert {:error, failures} = FetchConformance.prove(RaisesOnFailure, harness: MockHarness)
    assert Enum.any?(failures, &(&1 =~ "never raises"))
  end

  test "a failure answered as a success is caught" do
    assert {:error, failures} = FetchConformance.prove(FailsAsSuccess, harness: MockHarness)
    assert Enum.any?(failures, &(&1 =~ "never a success"))
  end

  test "a live read answered without a cursor is caught" do
    assert {:error, failures} = FetchConformance.prove(LiveWithoutCursor, harness: MockHarness)
    assert Enum.any?(failures, &(&1 =~ "without the server's cursor"))
  end

  # -- value mappers -------------------------------------------------------------------------

  defmodule NotAFunction do
    @moduledoc false
    @behaviour Electric.Client.ValueMapper
    @impl true
    def for_schema(_schema, _opts), do: :not_a_function
  end

  defmodule RaisesOnMissing do
    @moduledoc false
    @behaviour Electric.Client.ValueMapper
    @impl true
    def for_schema(_schema, _opts), do: &Map.new(&1, fn {k, v} -> {k, String.upcase(v)} end)
  end

  defmodule Restless do
    @moduledoc false
    @behaviour Electric.Client.ValueMapper
    @impl true
    def for_schema(_schema, _opts), do: &Map.put(&1, "at", make_ref())
  end

  defmodule DropsAColumn do
    @moduledoc false
    @behaviour Electric.Client.ValueMapper
    @impl true
    def for_schema(_schema, _opts), do: &Map.delete(&1, "title")
  end

  defmodule InventsAValue do
    @moduledoc false
    @behaviour Electric.Client.ValueMapper
    @impl true
    def for_schema(_schema, _opts), do: &Map.new(&1, fn {k, v} -> {k, v || "default"} end)
  end

  test "the value mapper suite proves the client's own mappers" do
    assert :ok = ValueMapperConformance.prove(Electric.Client.ValueMapper)

    assert :ok =
             ValueMapperConformance.prove(Electric.Client.EctoAdapter,
               options: Electric.Client.Test.Item
             )
  end

  test "a mapper that is not one is caught" do
    assert {:error, [failure]} = ValueMapperConformance.prove(String)
    assert failure =~ "does not implement Electric.Client.ValueMapper"
    assert {:error, [failure]} = ValueMapperConformance.prove(NotAFunction)
    assert failure =~ "not a function of one argument"
  end

  test "a mapper that raises on a missing value is caught" do
    assert {:error, failures} = ValueMapperConformance.prove(RaisesOnMissing)
    assert Enum.any?(failures, &(&1 =~ "every value missing"))
  end

  test "a mapper that maps one row two ways is caught" do
    assert {:error, failures} = ValueMapperConformance.prove(Restless)
    assert Enum.any?(failures, &(&1 =~ "maps the same way every time"))
  end

  test "a mapper that drops a column is caught" do
    assert {:error, failures} = ValueMapperConformance.prove(DropsAColumn)
    assert Enum.any?(failures, &(&1 =~ "keeps every column"))
  end

  test "a mapper that invents a value for a missing one is caught" do
    assert {:error, failures} = ValueMapperConformance.prove(InventsAValue)
    assert Enum.any?(failures, &(&1 =~ "stays missing"))
  end

  # -- authenticators ------------------------------------------------------------------------

  defmodule Unmarked do
    @moduledoc false
    @behaviour Electric.Client.Authenticator
    @impl true
    def authenticate_request(request, _config), do: request
    @impl true
    def authenticate_shape(_shape, _config), do: %{}
  end

  defmodule Widens do
    @moduledoc false
    @behaviour Electric.Client.Authenticator
    @impl true
    def authenticate_request(request, _config),
      do: %{request | authenticated: true, params: Map.put(request.params, "where", "true")}

    @impl true
    def authenticate_shape(_shape, _config), do: %{}
  end

  defmodule Moves do
    @moduledoc false
    @behaviour Electric.Client.Authenticator
    @impl true
    def authenticate_request(request, _config),
      do: %{request | authenticated: true, endpoint: URI.parse("http://elsewhere/v1/shape")}

    @impl true
    def authenticate_shape(_shape, _config), do: %{}
  end

  defmodule BadHeaders do
    @moduledoc false
    @behaviour Electric.Client.Authenticator
    @impl true
    def authenticate_request(request, _config), do: %{request | authenticated: true}
    @impl true
    def authenticate_shape(_shape, _config), do: %{"authorization" => :token}
  end

  defmodule Fickle do
    @moduledoc false
    @behaviour Electric.Client.Authenticator
    @impl true
    def authenticate_request(request, _config), do: %{request | authenticated: true}
    @impl true
    def authenticate_shape(_shape, _config),
      do: %{"x-nonce" => Integer.to_string(System.unique_integer())}
  end

  test "an authenticator that does not mark the request is caught" do
    assert {:error, failures} = AuthenticatorConformance.prove(Unmarked)
    assert Enum.any?(failures, &(&1 =~ "did not mark the request authenticated"))
  end

  test "an authenticator that changes what the request reads is caught" do
    assert {:error, failures} = AuthenticatorConformance.prove(Widens)
    assert Enum.any?(failures, &(&1 =~ "parameter where"))
    assert {:error, failures} = AuthenticatorConformance.prove(Moves)
    assert Enum.any?(failures, &(&1 =~ "changed the request's endpoint"))
  end

  test "an authenticator whose headers are not text is caught" do
    assert {:error, failures} = AuthenticatorConformance.prove(BadHeaders)
    assert Enum.any?(failures, &(&1 =~ "headers are names to text"))
  end

  test "an authenticator that answers one shape two ways is caught" do
    assert {:error, failures} = AuthenticatorConformance.prove(Fickle)
    assert Enum.any?(failures, &(&1 =~ "same shape twice"))
  end

  test "an authenticator that is not one is caught" do
    assert {:error, [failure]} = AuthenticatorConformance.prove(String)
    assert failure =~ "does not implement Electric.Client.Authenticator"
  end
end
