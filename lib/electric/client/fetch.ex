defmodule Electric.Client.Fetch do
  @moduledoc """
  How a client reaches a shape's log: the behaviour a fetcher implements, given to
  `Electric.Client.new/1` as `fetch: {module, options}`.

  The client ships three: `Electric.Client.Fetch.HTTP` (an Electric server over HTTP, the
  default), `Electric.Client.Embedded` (an Electric embedded in the application, in process)
  and `Electric.Client.Mock` (a test's responses). `Electric.Client.FetchConformance` proves an
  implementation keeps the contract.
  """
  alias Electric.Client.Fetch.{Request, Response}
  alias Electric.Client

  @doc """
  Checks the fetcher's options when a client is made: `{:ok, options}`, the options it will
  be given, defaults filled in; or `{:error, reason}` for options it cannot work with.
  """
  @callback validate_opts(keyword()) :: {:ok, keyword()} | {:error, term()}

  @doc """
  Reads the request's part of the shape's log, with the options `validate_opts/1` returned.
  Answers `{:ok, response}` with the server's status, the shape's messages and its handle,
  offset, schema (on a read that is not live) and cursor (on a live one); a failure is
  `{:ok, response}` with its status, or `{:error, response_or_reason}`, never a raise. The
  request is authenticated.
  """
  @callback fetch(Request.t(), keyword()) :: {:ok, Response.t()} | {:error, Response.t() | term()}

  @behaviour Electric.Client.Fetch.Pool

  def request(client, request, opts \\ [])

  @impl Electric.Client.Fetch.Pool
  def request(%Client{} = client, %Request{} = request, _opts) do
    %{pool: {module, opts}} = client
    apply(module, :request, [client, request, opts])
  end
end
