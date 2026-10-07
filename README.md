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
