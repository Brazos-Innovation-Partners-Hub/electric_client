defmodule Electric.Client.ValueMapperConformance do
  @moduledoc """
  Proves a value mapper (`Electric.Client.ValueMapper`) keeps its contract: given a shape's
  schema it returns one function, which maps each row (a map of column to the text Electric
  sent) without raising, the same way every time, keeps a missing value missing and, when it
  answers a map, keeps every column.

  A host proves its own mapper in its suite, with the schema and rows of a shape it reads:

      test "my mapper keeps the value mapper's contract" do
        assert :ok = Electric.Client.ValueMapperConformance.prove(MyApp.Mapper)
      end

  `prove/2` answers `:ok`, or `{:error, failures}` naming each part of the contract the mapper
  breaks. Its options:

    * `options:` what the mapper is given beside the schema (`for_schema/2`'s second
      argument; for `Electric.Client.EctoAdapter`, the Ecto schema module). Default `[]`.
    * `schema:` the shape's schema, as the server sends it. Default: an `items` table of
      `id` (`int8`, the primary key), `title` (`text`) and `done` (`bool`).
    * `rows:` rows of that shape, as the server sends them. Default: rows of the default
      schema.
    * `timeout:` how long one call may take, in milliseconds (default 5,000).

  What it proves:

    1. The module implements `Electric.Client.ValueMapper`.
    2. `for_schema/2` returns a function of one argument.
    3. Each row maps without raising, and mapping it again gives the same value.
    4. A row whose every value is missing (`nil`) maps without raising, and each column the
       mapped value has (a map's key, or a struct's field of the column's name) stays missing.
    5. A row mapped to a map keeps every column of the row as a key, and no other.
  """

  alias Electric.Client.Conformance
  alias Electric.Client.ValueMapper

  @default_timeout 5_000

  @schema %{
    id: %{type: "int8", pk_index: 0, not_null: true},
    title: %{type: "text"},
    done: %{type: "bool"}
  }

  @rows [
    %{"id" => "1", "title" => "Buy milk", "done" => "f"},
    %{"id" => "2", "title" => "Pay rent", "done" => "t"}
  ]

  @doc "Proves `mapper` keeps the contract on the default schema and rows, with no options."
  @spec prove(module()) :: :ok | {:error, [String.t()]}
  def prove(mapper) when is_atom(mapper), do: prove(mapper, [])

  @doc """
  Proves `mapper` keeps the `Electric.Client.ValueMapper` contract, with the options above:
  `:ok`, or `{:error, failures}` naming each part of the contract it breaks.
  """
  @spec prove(module(), keyword()) :: :ok | {:error, [String.t()]}
  def prove(mapper, opts) when is_atom(mapper) and is_list(opts) do
    schema = Keyword.get(opts, :schema, @schema)
    rows = Keyword.get(opts, :rows, @rows)
    options = Keyword.get(opts, :options, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    failures =
      if Conformance.implements?(mapper, ValueMapper) and
           function_exported?(mapper, :for_schema, 2) do
        case Conformance.call(fn -> mapper.for_schema(schema, options) end, timeout) do
          {:ok, fun} when is_function(fun, 1) ->
            Enum.flat_map(rows, &row(fun, &1, timeout)) ++ missing(fun, rows, timeout)

          {:ok, other} ->
            ["for_schema/2 returned #{Conformance.show(other)}, not a function of one argument"]

          {:crashed, how} ->
            ["for_schema/2 of #{Conformance.show(schema)} #{how}"]
        end
      else
        ["#{inspect(mapper)} does not implement Electric.Client.ValueMapper (for_schema/2)"]
      end

    Conformance.result(failures)
  end

  defp row(fun, row, timeout) do
    case {Conformance.call(fn -> fun.(row) end, timeout),
          Conformance.call(fn -> fun.(row) end, timeout)} do
      {{:ok, value}, {:ok, value}} ->
        columns(row, value)

      {{:ok, first}, {:ok, again}} ->
        [
          "the row #{Conformance.show(row)} mapped to #{Conformance.show(first)}, then to #{Conformance.show(again)}: the same row maps the same way every time"
        ]

      {{:crashed, how}, _} ->
        ["mapping the row #{Conformance.show(row)} #{how}"]

      {_, {:crashed, how}} ->
        ["mapping the row #{Conformance.show(row)} a second time #{how}"]
    end
  end

  defp columns(row, value) when is_map(value) and not is_struct(value) do
    if Enum.sort(Map.keys(value)) == Enum.sort(Map.keys(row)),
      do: [],
      else: [
        "the row #{Conformance.show(row)} mapped to #{Conformance.show(value)}: a mapped map keeps every column of the row as its key, and no other"
      ]
  end

  defp columns(_row, _value), do: []

  defp missing(fun, rows, timeout) do
    empty =
      rows
      |> Enum.flat_map(&Map.keys/1)
      |> Enum.uniq()
      |> Map.new(&{&1, nil})

    case Conformance.call(fn -> fun.(empty) end, timeout) do
      {:ok, value} ->
        kept =
          for column <- Map.keys(empty),
              {:ok, held} <- [held(value, column)],
              held != nil,
              do: column

        if kept == [],
          do: [],
          else: [
            "a row with every value missing mapped to #{Conformance.show(value)}: #{Enum.join(kept, ", ")} took a value, where a missing value stays missing"
          ]

      {:crashed, how} ->
        ["mapping a row with every value missing #{how}"]
    end
  end

  # The value a mapped row holds for a column: a map's key, or a struct's field of its name.
  defp held(value, column) when is_struct(value) do
    field = String.to_existing_atom(column)
    if Map.has_key?(value, field), do: {:ok, Map.get(value, field)}, else: :none
  rescue
    ArgumentError -> :none
  end

  defp held(value, column) when is_map(value) do
    if Map.has_key?(value, column), do: {:ok, Map.get(value, column)}, else: :none
  end

  defp held(_value, _column), do: :none
end
