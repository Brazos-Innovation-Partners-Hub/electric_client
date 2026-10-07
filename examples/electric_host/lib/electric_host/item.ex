defmodule ElectricHost.Item do
  @moduledoc "An item of a list: what it says, and whether it is done."
  use Ecto.Schema

  schema "items" do
    field :title, :string
    field :done, :boolean, default: false
  end
end
