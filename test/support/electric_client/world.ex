defmodule Electric.Client.Test.World do
  @moduledoc """
  The world `electric_client`'s worked examples (`Electric.Client.Examples`) run in: the
  client's own application, the stand-in Electric server and the Electric the suite embeds,
  and these words. Ours, not upstream's.
  """
  use VStack.Examples.LibraryWorld

  alias Electric.Client.ShapeDefinition

  @impl VStack.Examples.World
  def examples, do: [Electric.Client.Examples]

  @impl VStack.Examples.LibraryWorld
  def words do
    [
      shape:
        "The act made one shape (a `ShapeDefinition`, or `{:ok, shape}`) whose fields are the ones given: `table:`, `where:`, `columns:`, `replica:`.",
      proved: "The conformance suite answered this: `:ok` when it proved the implementation."
    ]
  end

  @impl VStack.Examples.LibraryWorld
  def judge(:shape, [], fields, %{result: result}) do
    case shape(result) do
      %ShapeDefinition{} = shape ->
        wrong =
          for {field, want} <- fields,
              Map.get(shape, field) != want,
              do: "#{field} is #{inspect(Map.get(shape, field))}, not #{inspect(want)}"

        if wrong == [], do: :ok, else: {:error, Enum.join(wrong, "; ")}

      other ->
        {:error, "the act answered #{inspect(other)}, not a shape"}
    end
  end

  def judge(:proved, [expected], [], %{result: result}) do
    if result == expected,
      do: :ok,
      else: {:error, "the suite answered #{inspect(result)}, not #{inspect(expected)}"}
  end

  defp shape({:ok, %ShapeDefinition{} = shape}), do: shape
  defp shape(other), do: other
end
