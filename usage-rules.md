# electric_client usage rules

Written by hand: what the design cannot say. This package is a copy of Electric's own Elixir
client, kept current with its server; its README lists every way it differs from upstream.

- **A shape is a table, a where clause and columns.** Build it with `Electric.Client.shape/2`,
  or from an Ecto query (`Electric.Client.shape!/1`, `Electric.Client.EctoAdapter.shape!/2`
  with options); a query that cannot be one shape (a join, an aggregate, a limit) raises.
- **Use `replica: :full` with an Ecto shape:** updates otherwise carry only changed columns,
  so the schema's structs come back partial.
- **`poll/4` can answer `{:stale_retry, state}`**: a cache in front of the server served a
  shape known to be stale, and nothing was read. Poll again with the state given.
- **`:must_refetch` means drop what you kept of the shape** and read it again from the start.
- **Deleting a shape needs a server that allows it** (`allow_shape_deletion?`); the next reader
  starts the shape again.
- **In tests, give the client `Electric.Client.Mock`** and the responses it should see, rather
  than a server; prove a fetcher, mapper or authenticator of your own with its conformance
  suite.

<!-- vstack.usage_rules:begin -->

## electric_client: what its design declares

_Written by `mix vstack.usage_rules` from `Electric.Client.Design`, so it never drifts from the code: change the design and run it again. Rules written by hand go outside this part._

Reads shapes (a table's rows, narrowed by a where clause and a list of columns) from an Electric sync server, over HTTP or from one embedded in the application, as a stream of changes or one long poll at a time.

- Design version 1, at the `:core` layer: it depends only on libraries at its layer or below.
- Its design is owned by the `telic-supply-chains` lane, and `examples/electric_host` proves it against a real host.

### What applications call

- `Electric.Client`: Makes a client for an Electric server (at a URL, or embedded in the application) and reads a shape through it: a stream of its rows and then its changes, a single long poll, or deleting the shape on the server.
- `Electric.Client.Error`: The error a read ends in: what went wrong and, when the server answered, its response.
- `Electric.Client.ShapeDefinition`: A shape: the table and its schema, the rows a where clause keeps (with its parameters), the columns, and whether an update carries the whole row.
- `Electric.Client.ShapeState`: Where a polled shape has got to (its handle, offset, schema and the rows it tracks), carried from one poll to the next.
- `Electric.Client.Offset`: A position in a shape's log, as the server writes it.
- `Electric.Client.Message.ChangeMessage`: A row of the shape inserted, updated or deleted: its key, its values (and, for an update, the values it had) and its headers.
- `Electric.Client.Message.Headers`: What a change says about its row: the operation, the table, the transaction and log position, and the tags that place the row in a shape with a subquery.
- `Electric.Client.Message.ControlMessage`: A change in the shape's state rather than in its rows: it is up to date, or it must be read again from the start.
- `Electric.Client.Message.ResumeMessage`: Where a stream ended early, given back to `Electric.Client.stream/3` to carry on from there.
- `Electric.Client.EctoAdapter`: Turns an Ecto query, schema, changeset or changeset function into a shape (its table, where clause and columns), and maps the shape's rows back into the schema's structs.
- `Electric.Client.Fetch.HTTP`: The fetcher a client uses unless told otherwise: reads a shape from an Electric server over HTTP, retrying a transient failure with growing waits until its timeout.
- `Electric.Client.Fetch.Request`: A request for a shape's log, as a fetcher is given it: the endpoint, the shape's parameters, the offset and handle to read from, and whether to wait for changes.
- `Electric.Client.Fetch.Response`: A fetcher's answer: the status, the rows, and what the server's headers say (the shape's handle, the offset reached, the schema and the cursor).
- `Electric.Client.Mock`: A fetcher for tests: a test gives the client the responses it should see, with no server, and reads back the requests the client made.
- `Electric.Client.FetchConformance`: Proves a fetcher keeps its contract: it accepts its own options and refuses others, answers a read with the rows and the shape's handle, offset and schema, and returns a failure as an error rather than raising.
- `Electric.Client.ValueMapperConformance`: Proves a value mapper keeps its contract: given a shape's schema it returns one function that maps a row's values, keeps every column, leaves a missing value missing, and maps the same row the same way twice.
- `Electric.Client.AuthenticatorConformance`: Proves an authenticator keeps its contract: it marks the request authenticated, changes nothing else about what the request reads, and gives the same headers for the same shape every time.

### What a host implements

- `Electric.Client.Fetch`, which `Electric.Client.FetchConformance` proves an implementation keeps: How a client reaches a shape's log: over HTTP from an Electric server, in process from an Electric embedded in the application, or from a test's mock; a host may give its own (`fetch:` in `Electric.Client.new/1`).
  - `fetch/2`: Reads the request's part of the shape's log, with the options `validate_opts/1` returned. Answers `{:ok, response}` with the server's status, the shape's messages and its handle, offset, schema (on a read that is not live) and cursor (on a live one); a failure is `{:ok, response}` with its status, or `{:error, response_or_reason}`, never a raise. The request is authenticated.
  - `validate_opts/1`: Checks the fetcher's options when a client is made: `{:ok, options}`, the options it will be given, defaults filled in; or `{:error, reason}` for options it cannot work with.
- `Electric.Client.ValueMapper`, which `Electric.Client.ValueMapperConformance` proves an implementation keeps: Turns the values of a shape's rows, which Electric sends as text, into Elixir terms, from the schema the server sends with the shape (`parser:` in `Electric.Client.new/1` and `stream/3`).
  - `for_schema/2`: Given the schema information passed from the electric server should return a 1-arity function that takes a values map, which is a map of column names to string values, and returns a version with the values cast to some appropriate Elixir type.
- `Electric.Client.Authenticator`, which `Electric.Client.AuthenticatorConformance` proves an implementation keeps: Adds to each request what lets it through whatever guards the shape's endpoint, such as a signed token for its shape (`authenticator:` in `Electric.Client.new/1`).
  - `authenticate_request/2`: Update the given `Request` struct with authentication headers.
  - `authenticate_shape/2`: Get authentication headers for the given ShapeDefinition

### Worked examples

Examples run in a world, each pinning down what it covers:

- `:a_table_is_one_shape`, covering `Electric.Client.ShapeDefinition`: A table, a where clause and whole rows on update make one shape, as the server is asked for it.
- `:an_ecto_schema_is_one_shape`, covering `Electric.Client.EctoAdapter`: An Ecto schema is read as its table with every column it maps, and its rows come back as its structs.
- `:the_http_fetcher_keeps_its_contract`, covering `Electric.Client.Fetch.HTTP`: The fetcher a client uses unless told otherwise keeps the fetch contract against an Electric server over HTTP: rows with the shape's handle, offset and schema, a live read with a cursor, and a refused table as a failure.
- `:the_embedded_fetcher_keeps_its_contract`, covering `Electric.Client.Embedded`: The fetcher for an Electric embedded in the application keeps the fetch contract, in process, against a real table.
- `:the_mock_fetcher_keeps_its_contract`, covering `Electric.Client.Mock`: The fetcher a test gives a client keeps the fetch contract, so what a test sees is what a real fetcher would give it.
- `:the_default_value_mapper_keeps_its_contract`, covering `Electric.Client.ValueMapper`: The mapper a client uses unless told otherwise keeps the value mapper's contract: integers and floats become numbers, every other column stays the text Electric sent.
- `:the_ecto_value_mapper_keeps_its_contract`, covering `Electric.Client.EctoAdapter`: The mapper an Ecto shape uses keeps the value mapper's contract for its schema, each row becoming one of the schema's structs.
- `:the_unauthenticated_authenticator_keeps_its_contract`, covering `Electric.Client.Authenticator.Unauthenticated`: The authenticator a client uses unless told otherwise adds nothing, and still marks each request authenticated.
- `:the_mock_authenticator_keeps_its_contract`, covering `Electric.Client.Authenticator.MockAuthenticator`: The authenticator a test uses adds a header that depends only on the shape and its salt, and marks each request authenticated.

### What it reaches outside the application

- `Electric.Client.Fetch.HTTP` reaches `:electric` (read): Reads a shape's log from an Electric server over HTTP: its rows from an offset, then, when live, each change as it happens, one long poll at a time.
- `Electric.Client.Fetch.HTTP` reaches `:electric` (actuate): Deletes a shape on an Electric server (`Electric.Client.delete_shape/2`), where the server allows it: the server forgets the shape's log, and the next reader of the shape starts it again. A repeat with the same `[:shape]` is the same effect; an unknown outcome is handled by `:report`.

<!-- vstack.usage_rules:end -->
