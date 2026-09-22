> **Brazos Innovation Partners copy** of `packages/elixir-client` from electric-sql/electric
> at tag `@core/sync-service@1.8.1` (upstream commit `0f404200402f918a4b1596bc5c8a53479a435349`), with the Electric
> requirement widened to include 1.7 and 1.8. Upstream's client stopped tracking its
> server at 1.6 (May 2026). Consumed by our phoenix_sync fork; proven by eidetic_ui's
> suite. Not published to Hex.

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
