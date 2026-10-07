# electric_host

`electric_client`'s reference: a real host, independent of anything else, that proves the
client against an Electric server running over the application's own PostgreSQL.

The application runs Electric (its HTTP API on port 3418, `ELECTRIC_HOST_PORT`) over its
`items` table, and its suite reads shapes from it: a table from its start over HTTP, an Ecto
query as the schema's structs, a poll that waits for the next change, the same shape in
process from the Electric it runs, and a shape deleted on the server and read again.

    mix test        # makes the database and its table first

It needs a PostgreSQL with logical replication on localhost (postgres/postgres, or `PGHOST`
and `PGPORT`).
