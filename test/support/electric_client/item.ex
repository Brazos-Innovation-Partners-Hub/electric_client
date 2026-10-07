defmodule Electric.Client.Test.Item do
  @moduledoc """
  The schema the client's worked examples and conformance proofs read: an `items` table of
  `id`, `title` and `done`. Ours, not upstream's.
  """
  use Ecto.Schema

  schema "items" do
    field :title, :string
    field :done, :boolean
  end
end
