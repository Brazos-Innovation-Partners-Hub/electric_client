defmodule Electric.Client.FetchConformance do
  @moduledoc """
  Proves a fetcher (`Electric.Client.Fetch`) keeps its contract: it accepts its own options and
  refuses others, answers a read with the shape's rows, handle, offset and schema, answers a
  live read with a cursor, and answers a failure as a failure, never with a raise and never as
  a success.

  A fetcher reads from something the suite cannot start by itself (an Electric server, an
  embedded Electric, a test's mock), so a harness (`Electric.Client.FetchConformance.Harness`)
  gives the suite the fetcher's options and sets up each answer before it is asked for. A
  host proves its own fetcher in its suite:

      test "my fetcher keeps the fetch contract" do
        assert :ok =
                 Electric.Client.FetchConformance.prove(MyApp.Fetcher,
                   harness: MyApp.Test.FetcherHarness
                 )
      end

  `prove/2` answers `:ok`, or `{:error, failures}` naming each part of the contract the
  fetcher breaks. Its options:

    * `harness:` the harness module (required).
    * `timeout:` how long one call may take, in milliseconds (default 10,000).

  What it proves:

    1. The module implements `Electric.Client.Fetch`, and the harness implements
       `Electric.Client.FetchConformance.Harness`.
    2. `validate_opts/1` answers `{:ok, options}` (a keyword list) for the harness's options,
       and `{:error, reason}` for each of the options the harness says it must refuse.
    3. A read of rows (`:rows`) is answered `{:ok, response}`: a status from 200 to 299, the
       shape's handle and the offset reached as text, the schema as a map and the messages as
       a list of maps.
    4. A live read (`:live`) is answered `{:ok, response}` with a status from 200 to 299 and the
       server's cursor, an integer.
    5. A failure (`:failure`) is answered as one: `{:ok, response}` with a status outside 200
       to 299, or `{:error, response_or_reason}`.
    6. No call raises, exits or outlasts the timeout.
  """

  alias Electric.Client.Conformance
  alias Electric.Client.Fetch
  alias Electric.Client.FetchConformance.Harness

  @default_timeout 10_000

  @doc """
  Proves `fetcher` with no options: the suite needs a harness, so this answers what it is
  missing.
  """
  @spec prove(module()) :: :ok | {:error, [String.t()]}
  def prove(fetcher) when is_atom(fetcher), do: prove(fetcher, [])

  @doc """
  Proves `fetcher` keeps the `Electric.Client.Fetch` contract, driven by the harness given:
  `:ok`, or `{:error, failures}` naming each part of the contract it breaks.
  """
  @spec prove(module(), keyword()) :: :ok | {:error, [String.t()]}
  def prove(fetcher, opts) when is_atom(fetcher) and is_list(opts) do
    harness = Keyword.get(opts, :harness)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    failures =
      case implemented(fetcher, harness) do
        [] ->
          options(fetcher, harness, timeout) ++
            Enum.flat_map([:rows, :live, :failure], &answer(fetcher, harness, &1, timeout))

        problems ->
          problems
      end

    Conformance.result(failures)
  end

  defp implemented(fetcher, harness) do
    fetcher_problems =
      if Conformance.implements?(fetcher, Fetch) and function_exported?(fetcher, :fetch, 2) and
           function_exported?(fetcher, :validate_opts, 1),
         do: [],
         else: [
           "#{inspect(fetcher)} does not implement Electric.Client.Fetch (validate_opts/1 and fetch/2)"
         ]

    harness_problems =
      cond do
        is_nil(harness) ->
          [
            "harness: give a module implementing Electric.Client.FetchConformance.Harness, which sets up each answer the suite asks the fetcher for"
          ]

        not Conformance.implements?(harness, Harness) ->
          [
            "harness: #{inspect(harness)} does not implement Electric.Client.FetchConformance.Harness"
          ]

        true ->
          []
      end

    fetcher_problems ++ harness_problems
  end

  # -- Options ------------------------------------------------------------------------------

  defp options(fetcher, harness, timeout) do
    accepted =
      case Conformance.call(fn -> fetcher.validate_opts(harness.options()) end, timeout) do
        {:ok, {:ok, validated}} when is_list(validated) ->
          []

        {:ok, other} ->
          [
            "validate_opts/1 answered #{Conformance.show(other)} for the harness's options, not {:ok, options}"
          ]

        {:crashed, how} ->
          ["validate_opts/1 of the harness's options #{how}"]
      end

    refused =
      for options <- harness.refused(),
          failure = refusal(fetcher, options, timeout),
          failure != nil,
          do: failure

    accepted ++ refused
  end

  defp refusal(fetcher, options, timeout) do
    case Conformance.call(fn -> fetcher.validate_opts(options) end, timeout) do
      {:ok, {:error, _reason}} ->
        nil

      {:ok, other} ->
        "validate_opts/1 answered #{Conformance.show(other)} for #{Conformance.show(options)}, which it must refuse with {:error, reason}"

      {:crashed, how} ->
        "validate_opts/1 of #{Conformance.show(options)} #{how}: options it cannot work with are refused with {:error, reason}"
    end
  end

  # -- Answers ------------------------------------------------------------------------------

  defp answer(fetcher, harness, kind, timeout) do
    with {:ok, {%Fetch.Request{} = request, options}} <-
           Conformance.call(fn -> harness.arrange(kind) end, timeout),
         {:ok, {:ok, validated}} <-
           Conformance.call(fn -> fetcher.validate_opts(options) end, timeout) do
      request = %{request | authenticated: true, live: kind == :live}

      case Conformance.call(fn -> fetcher.fetch(request, validated) end, timeout) do
        {:ok, answered} -> judge(kind, answered)
        {:crashed, how} -> ["fetch/2 of a #{name(kind)} #{how}: a fetcher answers, never raises"]
      end
    else
      {:ok, {:error, reason}} ->
        [
          "validate_opts/1 refused the options the harness arranged a #{name(kind)} with: #{Conformance.show(reason)}"
        ]

      {:ok, other} ->
        [
          "the harness arranged a #{name(kind)} as #{Conformance.show(other)}, not {request, options}"
        ]

      {:crashed, how} ->
        ["the harness, arranging a #{name(kind)}, #{how}"]
    end
  end

  defp judge(:rows, {:ok, %Fetch.Response{status: status} = response})
       when status in 200..299 do
    checks = [
      {is_binary(response.shape_handle), "the shape's handle as text"},
      {is_binary(response.last_offset), "the offset reached as text"},
      {is_map(response.schema), "the schema as a map"},
      {is_list(response.body) and Enum.all?(response.body, &is_map/1),
       "the messages as a list of maps"}
    ]

    for {false, what} <- checks,
        do: "a read of rows was answered #{Conformance.show(response)}, without #{what}"
  end

  defp judge(:live, {:ok, %Fetch.Response{status: status} = response})
       when status in 200..299 do
    if is_integer(response.next_cursor),
      do: [],
      else: [
        "a live read was answered without the server's cursor (next_cursor: #{Conformance.show(response.next_cursor)}), which a live reader sends back"
      ]
  end

  defp judge(:failure, {:ok, %Fetch.Response{status: status}}) when status not in 200..299,
    do: []

  defp judge(:failure, {:error, _reason}), do: []

  defp judge(:failure, answered),
    do: [
      "a failure was answered #{Conformance.show(answered)}: a failure is a status outside 200 to 299, or {:error, reason}, never a success"
    ]

  defp judge(kind, answered),
    do: [
      "a #{name(kind)} was answered #{Conformance.show(answered)}, not {:ok, %Electric.Client.Fetch.Response{}} with a status from 200 to 299"
    ]

  defp name(:rows), do: "read of rows"
  defp name(:live), do: "live read"
  defp name(:failure), do: "failure"
end
