defmodule Electric.Client.AuthenticatorConformance do
  @moduledoc """
  Proves an authenticator (`Electric.Client.Authenticator`) keeps its contract: it marks each
  request authenticated, changes nothing about what the request reads (its endpoint, method,
  place in the log and the shape's parameters), gives a shape's headers as a map of text, and
  gives the same answer for the same request or shape every time.

  A host proves its own authenticator in its suite, with the configuration it is given:

      test "my authenticator keeps the authenticator's contract" do
        assert :ok =
                 Electric.Client.AuthenticatorConformance.prove(MyApp.Authenticator,
                   config: [secret: "a test secret"]
                 )
      end

  `prove/2` answers `:ok`, or `{:error, failures}` naming each part of the contract the
  authenticator breaks. Its options:

    * `config:` the authenticator's configuration, as `Electric.Client.new/1` is given it
      (`authenticator: {module, config}`). Default `[]`.
    * `shapes:` shapes to authenticate. Default: an `items` table, whole and narrowed by a
      where clause and columns.
    * `timeout:` how long one call may take, in milliseconds (default 5,000).

  What it proves:

    1. The module implements `Electric.Client.Authenticator`.
    2. `authenticate_request/2` returns the request marked authenticated, with the same
       endpoint, method, offset, shape handle, live, replica and cursor, and every one of the
       request's parameters kept as it was (it may add its own).
    3. `authenticate_shape/2` returns a map of header names to text (or lists of text).
    4. Authenticating the same request, or the same shape, twice gives the same answer.
  """

  alias Electric.Client.Authenticator
  alias Electric.Client.Conformance
  alias Electric.Client.Fetch
  alias Electric.Client.ShapeDefinition

  @default_timeout 5_000

  @doc "Proves `authenticator` keeps the contract with no configuration, on the default shapes."
  @spec prove(module()) :: :ok | {:error, [String.t()]}
  def prove(authenticator) when is_atom(authenticator), do: prove(authenticator, [])

  @doc """
  Proves `authenticator` keeps the `Electric.Client.Authenticator` contract, with the options
  above: `:ok`, or `{:error, failures}` naming each part of the contract it breaks.
  """
  @spec prove(module(), keyword()) :: :ok | {:error, [String.t()]}
  def prove(authenticator, opts) when is_atom(authenticator) and is_list(opts) do
    config = Keyword.get(opts, :config, [])
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    shapes = Keyword.get_lazy(opts, :shapes, &shapes/0)

    failures =
      if Conformance.implements?(authenticator, Authenticator) do
        Enum.flat_map(shapes, fn shape ->
          request(authenticator, config, shape, timeout) ++
            headers(authenticator, config, shape, timeout)
        end)
      else
        [
          "#{inspect(authenticator)} does not implement Electric.Client.Authenticator (authenticate_request/2 and authenticate_shape/2)"
        ]
      end

    Conformance.result(failures)
  end

  defp shapes do
    [
      ShapeDefinition.new!("items"),
      ShapeDefinition.new!("items", where: "done = false", columns: ["id", "title"])
    ]
  end

  @kept [:endpoint, :method, :offset, :shape_handle, :live, :replica, :next_cursor]

  defp request(authenticator, config, shape, timeout) do
    request = %Fetch.Request{
      endpoint: URI.parse("http://localhost:3000/v1/shape"),
      params: ShapeDefinition.params(shape),
      offset: "0_0",
      shape_handle: "items-1",
      next_cursor: 7
    }

    once =
      Conformance.call(fn -> authenticator.authenticate_request(request, config) end, timeout)

    again =
      Conformance.call(fn -> authenticator.authenticate_request(request, config) end, timeout)

    case {once, again} do
      {{:ok, %Fetch.Request{} = done}, {:ok, done}} ->
        marked(done) ++ unchanged(request, done)

      {{:ok, %Fetch.Request{} = done}, {:ok, other}} ->
        [
          "authenticating the same request twice gave #{Conformance.show(done)}, then #{Conformance.show(other)}"
        ]

      {{:ok, other}, _} ->
        ["authenticate_request/2 returned #{Conformance.show(other)}, not the request"]

      {{:crashed, how}, _} ->
        ["authenticate_request/2 of a request for #{shape.table} #{how}"]

      {_, {:crashed, how}} ->
        ["authenticate_request/2, asked again, #{how}"]
    end
  end

  defp marked(%Fetch.Request{authenticated: true}), do: []

  defp marked(_request),
    do: [
      "authenticate_request/2 did not mark the request authenticated (authenticated: true), so no fetcher is given it"
    ]

  defp unchanged(request, done) do
    fields =
      for field <- @kept,
          Map.fetch!(request, field) != Map.fetch!(done, field),
          do:
            "authenticate_request/2 changed the request's #{field} from #{Conformance.show(Map.fetch!(request, field))} to #{Conformance.show(Map.fetch!(done, field))}"

    params =
      for {key, value} <- request.params,
          Map.get(done.params || %{}, key) != value,
          do:
            "authenticate_request/2 changed the request's parameter #{key} from #{Conformance.show(value)} to #{Conformance.show(Map.get(done.params || %{}, key))}: it may add parameters, never change what the request reads"

    fields ++ params
  end

  defp headers(authenticator, config, shape, timeout) do
    once = Conformance.call(fn -> authenticator.authenticate_shape(shape, config) end, timeout)
    again = Conformance.call(fn -> authenticator.authenticate_shape(shape, config) end, timeout)

    case {once, again} do
      {{:ok, headers}, {:ok, headers}} when is_map(headers) ->
        if Enum.all?(headers, &header?/1),
          do: [],
          else: [
            "authenticate_shape/2 gave #{Conformance.show(headers)}: headers are names to text, or to lists of text"
          ]

      {{:ok, headers}, {:ok, other}} when is_map(headers) ->
        [
          "authenticating the same shape twice gave #{Conformance.show(headers)}, then #{Conformance.show(other)}"
        ]

      {{:ok, other}, _} ->
        ["authenticate_shape/2 returned #{Conformance.show(other)}, not a map of headers"]

      {{:crashed, how}, _} ->
        ["authenticate_shape/2 of #{shape.table} #{how}"]

      {_, {:crashed, how}} ->
        ["authenticate_shape/2, asked again, #{how}"]
    end
  end

  defp header?({name, value}) when is_binary(name) and is_binary(value), do: true

  defp header?({name, values}) when is_binary(name) and is_list(values),
    do: Enum.all?(values, &is_binary/1)

  defp header?(_header), do: false
end
