# The design is written in vstack_shared's vocabulary, which needs Spark: a host without it has
# no use for the declaration, and the client itself runs without either.
if Code.ensure_loaded?(VStack.Library) do
  defmodule Electric.Client.Design do
    @moduledoc """
    `electric_client`'s design (`VStack.Library`): Electric's Elixir client, which reads
    shapes (a table's rows, narrowed by a where clause and a list of columns) from an Electric
    sync server and keeps them current.

    This package is a copy of `packages/elixir-client` from electric-sql/electric, kept by us
    because the upstream client stopped following its server; the README lists every way it
    differs from upstream. Its design is declared around the upstream code rather than in it:
    the modules applications call, the behaviours a host may implement with the suites that
    prove an implementation, and what the code reaches outside the application. The effects are
    declared here, each naming the module that has it (`by:`), so the upstream modules stay as
    they are.

    It declares no vocabulary and ships no rules: an application tells it what to read through
    function calls (`Electric.Client.new/1`, `stream/3`, `poll/4`), and what it reads is data.
    It stands with Ash and Ecto (`:core`): a client of a data service, below the systems that
    use it. Its reference is `examples/electric_host`, an application that reads shapes from a
    real Electric over HTTP and from one embedded in it.
    """
    use VStack.Library, extensions: [VStack.Effects]

    library do
      name :electric_client

      description "Reads shapes (a table's rows, narrowed by a where clause and a list of columns) from an Electric sync server, over HTTP or from one embedded in the application, as a stream of changes or one long poll at a time."

      version 1
      layer :core
      owner "telic-supply-chains"
      reference "examples/electric_host"

      api Electric.Client,
        description:
          "Makes a client for an Electric server (at a URL, or embedded in the application) and reads a shape through it: a stream of its rows and then its changes, a single long poll, or deleting the shape on the server."

      api Electric.Client.Error,
        description:
          "The error a read ends in: what went wrong and, when the server answered, its response."

      api Electric.Client.ShapeDefinition,
        description:
          "A shape: the table and its schema, the rows a where clause keeps (with its parameters), the columns, and whether an update carries the whole row."

      api Electric.Client.ShapeState,
        description:
          "Where a polled shape has got to (its handle, offset, schema and the rows it tracks), carried from one poll to the next."

      api Electric.Client.Offset,
        description: "A position in a shape's log, as the server writes it."

      api Electric.Client.Message.ChangeMessage,
        description:
          "A row of the shape inserted, updated or deleted: its key, its values (and, for an update, the values it had) and its headers."

      api Electric.Client.Message.Headers,
        description:
          "What a change says about its row: the operation, the table, the transaction and log position, and the tags that place the row in a shape with a subquery."

      api Electric.Client.Message.ControlMessage,
        description:
          "A change in the shape's state rather than in its rows: it is up to date, or it must be read again from the start."

      api Electric.Client.Message.ResumeMessage,
        description:
          "Where a stream ended early, given back to `Electric.Client.stream/3` to carry on from there."

      api Electric.Client.EctoAdapter,
        description:
          "Turns an Ecto query, schema, changeset or changeset function into a shape (its table, where clause and columns), and maps the shape's rows back into the schema's structs."

      api Electric.Client.Fetch.HTTP,
        description:
          "The fetcher a client uses unless told otherwise: reads a shape from an Electric server over HTTP, retrying a transient failure with growing waits until its timeout."

      api Electric.Client.Fetch.Request,
        description:
          "A request for a shape's log, as a fetcher is given it: the endpoint, the shape's parameters, the offset and handle to read from, and whether to wait for changes."

      api Electric.Client.Fetch.Response,
        description:
          "A fetcher's answer: the status, the rows, and what the server's headers say (the shape's handle, the offset reached, the schema and the cursor)."

      api Electric.Client.Mock,
        description:
          "A fetcher for tests: a test gives the client the responses it should see, with no server, and reads back the requests the client made."

      api Electric.Client.FetchConformance,
        description:
          "Proves a fetcher keeps its contract: it accepts its own options and refuses others, answers a read with the rows and the shape's handle, offset and schema, and returns a failure as an error rather than raising."

      api Electric.Client.ValueMapperConformance,
        description:
          "Proves a value mapper keeps its contract: given a shape's schema it returns one function that maps a row's values, keeps every column, leaves a missing value missing, and maps the same row the same way twice."

      api Electric.Client.AuthenticatorConformance,
        description:
          "Proves an authenticator keeps its contract: it marks the request authenticated, changes nothing else about what the request reads, and gives the same headers for the same shape every time."

      port Electric.Client.Fetch,
        conformance: Electric.Client.FetchConformance,
        description:
          "How a client reaches a shape's log: over HTTP from an Electric server, in process from an Electric embedded in the application, or from a test's mock; a host may give its own (`fetch:` in `Electric.Client.new/1`)."

      port Electric.Client.ValueMapper,
        conformance: Electric.Client.ValueMapperConformance,
        description:
          "Turns the values of a shape's rows, which Electric sends as text, into Elixir terms, from the schema the server sends with the shape (`parser:` in `Electric.Client.new/1` and `stream/3`)."

      port Electric.Client.Authenticator,
        conformance: Electric.Client.AuthenticatorConformance,
        description:
          "Adds to each request what lets it through whatever guards the shape's endpoint, such as a signed token for its shape (`authenticator:` in `Electric.Client.new/1`)."
    end

    effects do
      # Electric's reads are safe to repeat: the fetcher retries a timeout, a refused connection
      # or a transient status with growing waits until its timeout (`Fetch.HTTP`, `timeout:`).
      reaches :electric,
        class: :read,
        by: Electric.Client.Fetch.HTTP,
        doc:
          "Reads a shape's log from an Electric server over HTTP: its rows from an offset, then, when live, each change as it happens, one long poll at a time."

      # A deletion is repeated by the same retries as a read: deleting a shape twice deletes it
      # once, so a repeat is the same effect. When the retries run out the error is returned to
      # the caller of `Electric.Client.delete_shape/2`, who decides.
      reaches :electric do
        class :actuate
        by Electric.Client.Fetch.HTTP

        doc "Deletes a shape on an Electric server (`Electric.Client.delete_shape/2`), where the server allows it: the server forgets the shape's log, and the next reader of the shape starts it again."

        promise idempotent_by: [:shape], on_unknown: :report
      end
    end
  end
end
