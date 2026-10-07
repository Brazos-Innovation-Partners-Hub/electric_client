# electric_client's worked examples (`Electric.Client.Examples`), run in its world
# (`Electric.Client.Test.World`), and the world proven to keep its contract. Ours, not upstream's.
defmodule Electric.Client.ExamplesTest do
  use VStack.Examples.Case, world: Electric.Client.Test.World, otp_app: :electric_client
end

defmodule Electric.Client.WorldTest do
  use ExUnit.Case, async: false

  @moduletag capture_log: true

  @tag timeout: 300_000
  test "the world keeps its contract" do
    assert :ok = VStack.Examples.WorldConformance.prove(Electric.Client.Test.World)
  end
end
