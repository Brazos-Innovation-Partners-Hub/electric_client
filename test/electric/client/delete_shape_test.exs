# Deleting a shape tells the server which shape: its definition goes with the request. Upstream
# sent none, so the server refused every deletion. Ours, not upstream's.
defmodule Electric.Client.DeleteShapeTest do
  use ExUnit.Case, async: true

  alias Electric.Client
  alias Electric.Client.{Mock, ShapeDefinition}

  test "a deletion carries the shape's table and where clause" do
    {:ok, client} = Mock.new()
    shape = ShapeDefinition.new!("items", where: "done = true")
    ref = Mock.async_response(client, status: 202, body: [])

    assert %Client.Fetch.Response{status: 202} = Client.delete_shape(client, shape)

    request = Mock.async_await(ref)
    assert request.method == :delete
    assert request.params["table"] == "items"
    assert request.params["where"] == "done = true"
  end
end
