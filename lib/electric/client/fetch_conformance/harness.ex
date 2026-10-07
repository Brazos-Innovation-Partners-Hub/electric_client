defmodule Electric.Client.FetchConformance.Harness do
  @moduledoc """
  What `Electric.Client.FetchConformance` needs to drive a fetcher: the fetcher's options, the
  options it must refuse, and a way to set up each answer before the suite asks for it.

  A harness lives in the suite of whoever proves the fetcher (a host's tests for its own, this
  package's tests for the three it ships), since only it knows how to make the fetcher's source
  answer: an Electric server it starts, a table it fills, a mock it primes.
  """

  @doc "Options the fetcher accepts, as `Electric.Client.new/1` would be given them."
  @callback options() :: keyword()

  @doc "Option lists the fetcher must refuse (`validate_opts/1` answering `{:error, reason}`)."
  @callback refused() :: [keyword()]

  @doc """
  Sets the fetcher's source up so that the next read answers as asked, and returns the
  request to read with and the fetcher's options for it:

    * `:rows`: a shape with at least one row, read from its start;
    * `:live`: a shape that is up to date, read live, with a change arriving soon;
    * `:failure`: a read the source refuses, such as one of a table it does not have.
  """
  @callback arrange(answer :: :rows | :live | :failure) ::
              {Electric.Client.Fetch.Request.t(), keyword()}
end
