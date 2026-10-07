# Examples are written in vstack_shared's vocabulary, which needs Spark: a host without it has
# no use for them, and the client itself runs without either.
if Code.ensure_loaded?(VStack.Examples) do
  defmodule Electric.Client.Examples do
    @moduledoc """
    `electric_client`'s worked examples, run in its world (`Electric.Client.Test.World`): the
    shape a table or an Ecto schema is read as, and each implementation of a port this package
    ships proven by the port's conformance suite.

    The client declares no vocabulary and ships no rules, so it has no `declares`, `breaks` or
    `refuses` examples. Its schema is the world's `Electric.Client.Test.Item`, an `items` table
    of `id`, `title` and `done`.
    """
    use VStack.Examples

    # ── shapes ──────────────────────────────────────────────────────────────────

    example :a_table_is_one_shape do
      description "A table, a where clause and whole rows on update make one shape, as the server is asked for it."
      covers Electric.Client.ShapeDefinition
      act Electric.Client.shape("items", where: "done = false", replica: :full)

      expect do
        shape table: "items", where: "done = false", replica: :full
      end
    end

    example :an_ecto_schema_is_one_shape do
      description "An Ecto schema is read as its table with every column it maps, and its rows come back as its structs."
      covers Electric.Client.EctoAdapter
      act Electric.Client.shape!(Electric.Client.Test.Item)

      expect do
        shape table: "items", columns: ["id", "title", "done"]
      end
    end

    # ── the ports' implementations, each proven ─────────────────────────────────

    example :the_mock_fetcher_keeps_its_contract do
      description "The fetcher a test gives a client keeps the fetch contract, so what a test sees is what a real fetcher would give it."
      covers Electric.Client.Mock
      act Electric.Client.FetchConformance.prove(Electric.Client.Mock)

      expect do
        proved :ok
      end
    end

    example :the_default_value_mapper_keeps_its_contract do
      description "The mapper a client uses unless told otherwise keeps the value mapper's contract: integers and floats become numbers, every other column stays the text Electric sent."
      covers Electric.Client.ValueMapper
      act Electric.Client.ValueMapperConformance.prove(Electric.Client.ValueMapper)

      expect do
        proved :ok
      end
    end

    example :the_ecto_value_mapper_keeps_its_contract do
      description "The mapper an Ecto shape uses keeps the value mapper's contract for its schema, each row becoming one of the schema's structs."
      covers Electric.Client.EctoAdapter

      act Electric.Client.ValueMapperConformance.prove(
            Electric.Client.EctoAdapter,
            Electric.Client.Test.Item
          )

      expect do
        proved :ok
      end
    end

    example :the_unauthenticated_authenticator_keeps_its_contract do
      description "The authenticator a client uses unless told otherwise adds nothing, and still marks each request authenticated."
      covers Electric.Client.Authenticator.Unauthenticated

      act Electric.Client.AuthenticatorConformance.prove(
            Electric.Client.Authenticator.Unauthenticated
          )

      expect do
        proved :ok
      end
    end

    example :the_mock_authenticator_keeps_its_contract do
      description "The authenticator a test uses adds a header that depends only on the shape and its salt, and marks each request authenticated."
      covers Electric.Client.Authenticator.MockAuthenticator

      act Electric.Client.AuthenticatorConformance.prove(
            Electric.Client.Authenticator.MockAuthenticator,
            salt: "a salt"
          )

      expect do
        proved :ok
      end
    end
  end
end
