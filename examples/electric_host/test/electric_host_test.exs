defmodule ElectricHostTest do
  @moduledoc """
  electric_client proved against a real host: an Electric server run over the application's
  own PostgreSQL, read over HTTP and in process.
  """
  use ExUnit.Case, async: false

  import Ecto.Query

  alias Electric.Client
  alias Electric.Client.Message.{ChangeMessage, ControlMessage, ResumeMessage}
  alias Electric.Client.{ShapeDefinition, ShapeState}
  alias ElectricHost.Item

  @moduletag timeout: 120_000

  test "a table is read over HTTP from its start: its rows, then that it is up to date" do
    list = list()
    ElectricHost.add("#{list} Buy milk")
    ElectricHost.add("#{list} Pay rent", true)

    messages = Client.stream(ElectricHost.client(), shape(list), live: false) |> Enum.to_list()

    assert titles(messages) == ["#{list} Buy milk", "#{list} Pay rent"]
    assert Enum.any?(messages, &match?(%ControlMessage{control: :up_to_date}, &1))
    # A stream that ends before it is live says where to carry on from.
    assert %ResumeMessage{} = List.last(messages)
  end

  test "an Ecto query is one shape, and its rows come back as the schema's structs" do
    list = list()
    ElectricHost.add("#{list} Buy milk")
    ElectricHost.add("#{list} Pay rent", true)

    query = from(i in Item, where: like(i.title, ^"#{list}%") and i.done == false)

    values =
      ElectricHost.client()
      |> Client.stream(query, live: false, replica: :full)
      |> Enum.flat_map(fn
        %ChangeMessage{value: value} -> [value]
        _other -> []
      end)

    assert [%Item{title: title, done: false}] = values
    assert title == "#{list} Buy milk"
  end

  test "a poll reads the shape from its start, then waits for the next change" do
    list = list()
    ElectricHost.add("#{list} Buy milk")
    client = ElectricHost.client()

    # Polls until the shape is up to date: the rows may come before the server says so.
    {first, state} = poll_until_up_to_date(client, shape(list), ShapeState.new(), [])
    assert titles(first) == ["#{list} Buy milk"]

    waiting = Task.async(fn -> Client.poll(client, shape(list), state) end)
    Process.sleep(500)
    ElectricHost.add("#{list} Write report")

    assert {:ok, next, _state} = Task.await(waiting, 60_000)
    assert titles(next) == ["#{list} Write report"]
  end

  test "the client reads the Electric the application runs, in process, as over HTTP" do
    list = list()
    ElectricHost.add("#{list} Buy milk")

    messages =
      Client.stream(ElectricHost.embedded_client(), shape(list), live: false) |> Enum.to_list()

    assert titles(messages) == ["#{list} Buy milk"]
  end

  test "a shape deleted on the server is read again from its start" do
    list = list()
    ElectricHost.add("#{list} Buy milk")
    client = ElectricHost.client()

    assert titles(Client.stream(client, shape(list), live: false) |> Enum.to_list()) == [
             "#{list} Buy milk"
           ]

    assert %Client.Fetch.Response{status: status} = Client.delete_shape(client, shape(list))
    assert status in 200..299

    assert titles(Client.stream(client, shape(list), live: false) |> Enum.to_list()) == [
             "#{list} Buy milk"
           ]
  end

  defp poll_until_up_to_date(client, shape, state, seen) do
    {:ok, messages, state} = Client.poll(client, shape, state)

    if state.up_to_date?,
      do: {seen ++ messages, state},
      else: poll_until_up_to_date(client, shape, state, seen ++ messages)
  end

  # Each test reads a list of its own, so tests never see another's items.
  defp list, do: "list-#{System.unique_integer([:positive])}"

  defp shape(list), do: ShapeDefinition.new!("items", where: "title LIKE '#{list}%'")

  defp titles(messages) do
    for %ChangeMessage{value: %{"title" => title}} <- messages, do: title
  end
end
