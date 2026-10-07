> **Brazos Innovation Partners copy** of `packages/elixir-client` from electric-sql/electric
> at tag `@core/sync-service@1.8.1` (upstream commit `0f404200402f918a4b1596bc5c8a53479a435349`),
> the code Hex publishes as `electric_client` 0.10.3. Upstream's client stopped following its
> server at Electric 1.6 (May 2026); this copy follows it. Used by `electric_plug` and by
> `syndikos_test`. Not published to Hex.

## How this copy differs from upstream

Every change to upstream's files is listed here, so that the next update from upstream knows
what to carry across. Keep upstream's code as it is wherever we can: add around it, and change
its behaviour only to mend a real defect.

Upstream files changed:

- `mix.exs`: the Electric requirement also allows `~> 1.7` and `~> 1.8`, written over two lines
  so it passes the formatter; and `vstack_shared` (the vocabulary the design is written in) and,
  for development and tests, `vstack_dev` (the library standard's tools) are dependencies,
  taken by path while the standard is brought in.
- `package.json`: version `0.10.3-bip.1`, so this copy is told apart from Hex's 0.10.3.
- `lib/electric/client/ecto_adapter/postgres.ex`: a bound value given its type explicitly
  (`type(^value, type)`, which Ash writes for every comparison in a policy) is rendered: an
  enum's atom by its name, and cast as its type is stored (`varchar`). Upstream raised
  "unsupported expression".
- `lib/electric/client.ex`: `delete_shape/2` sends the shape's definition with the request.
  Upstream passed it as `shape:`, which a request has no field for, so the server was never
  told which shape and refused every deletion ("handle can't be blank when shape definition
  is missing"); upstream's tests only deleted in `on_exit`, logs captured, against a server
  that allows no deletion. Proven by `test/electric/client/delete_shape_test.exs` and the
  reference application.
- Documentation and typespecs only, no behaviour changed, so that every module applications
  call says what it is for and every function it offers is documented and specified:
  - `lib/electric/client.ex`: a moduledoc for `Electric.Client.Error`; a doc for `embedded!/1`;
    a spec for `delete_shape/2`; and `poll/4`'s doc and spec name the answer it could already
    give, `{:stale_retry, state}` (a cache answered with a shape known to be stale; poll again).
  - `lib/electric/client/poll.ex`: the same answer in `poll_result` and in `request/3`'s doc.
  - `lib/electric/client/ecto_adapter.ex`: a moduledoc (it was hidden, and applications call
    `shape!/2`), and docs and specs for `shape!/2` and `shape_from_changeset!/2`.
  - `lib/electric/client/message.ex`: moduledocs for `Headers`, `ControlMessage` and
    `ChangeMessage`; docs and specs for `Headers.insert/1`, `update/1` and `delete/1` and
    `ControlMessage.up_to_date/0` and `must_refetch/0`; and the parsers each message is read
    with (`from_message`) hidden from the docs, as `Headers.from_message/2` already was.
  - `lib/electric/client/mock.ex`: docs for `response/2`, `async_response/2`,
    `async_await/2`, `up_to_date/1`, `change/1` and `headers/1`; `async_response/2`'s spec,
    which was written under `response/2`'s name; and `up_to_date/1`'s spec, written for an
    arity it does not have.
  - `lib/electric/client/shape_definition.ex`: docs for `new/1`, `new!/1`, `new!/2`,
    `public_keys/0`, `url_table_name/2` and `params/2` (hidden upstream; `electric_plug` gives
    an embedded Electric its shape through it), and specs for `new!/1`, `public_keys/0` and
    `url_table_name/2`.
  - `lib/electric/client/fetch.ex`: a moduledoc, and docs for its two callbacks.
  - `lib/electric/client/fetch/http.ex`: a spec for `transient_status_codes/0`.
  - `lib/electric/client/fetch/request.ex`: a moduledoc, and `url/2`'s and `uri/2`'s specs
    for the arity they have.
  - `lib/electric/client/fetch/response.ex`: a moduledoc.
- `test/test_helper.exs`: starts the stand-in Electric server the HTTP fetcher is proven
  against.
- `.formatter.exs`: the design and the worked examples are formatted as the DSLs they are
  written in (Spark's formatter, and the words vstack_shared exports).
- `config/config.exs`: Spark's formatter is told those DSLs.
- `README.md`: this header and this list.

Files that are ours alone:

- `lib/electric/client/design.ex` (`Electric.Client.Design`): the library's design, declared
  with `VStack.Library`: the modules applications call, the behaviours a host may implement
  (fetching, mapping values, authenticating) with the suite that proves each, and what the
  code reaches outside the application.
- `lib/electric/client/examples.ex` (`Electric.Client.Examples`): its worked examples.
- `lib/electric/client/fetch_conformance.ex`, `fetch_conformance/harness.ex`,
  `value_mapper_conformance.ex`, `authenticator_conformance.ex` and `conformance.ex`: the suites
  that prove an implementation of each of the three behaviours a host may implement (fetching,
  mapping values, authenticating; `Electric.Client.Authenticator` is upstream's, its option
  hidden in upstream's docs, declared here as a port because the client accepts it), and what
  they share.
- `examples/electric_host`: the reference application, which runs an Electric server over
  its own database and reads shapes from it, over HTTP and in process.
- `test/electric/client/delete_shape_test.exs`: a deletion carries its shape.
- `test/electric/client/examples_test.exs` and `conformance_test.exs`, and
  `test/support/electric_client/`: the worked examples run in their world, the world proven,
  each suite shown catching broken implementations, and the harnesses that drive the client's
  own three fetchers.

# ElectricSQL Elixir client

An Elixir client for [ElectricSQL](https://electric-sql.com).

Electric is a sync engine that allows you to sync
[little subsets](https://electric-sql.com/docs/guides/shapes)
of data from Postgres into local apps and services. This client
allows you to sync data from Electric into Elixir applications.

## Installation

```elixir
def deps do
  [
    {:electric_client, "~> 0.1.0"}
  ]
end
```

## Usage

See the [Documentation](https://hexdocs.pm/electric_client).

## Testing

[Run Electric and Postgres](https://electric-sql.com/docs/guides/installation).

Define `DATABASE_URL` and `ELECTRIC_URL` as env vars. Or see the defaults in `config/runtime.exs`.

Then run:

```sh
mix test
```
