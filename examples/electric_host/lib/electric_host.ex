defmodule ElectricHost do
  @moduledoc """
  `electric_client`'s reference: an application that runs an Electric server over its own
  database and reads shapes from it with the client, over HTTP as any reader would, and in
  process from the Electric it runs.
  """

  @doc "A client reading the application's Electric over HTTP."
  @spec client() :: Electric.Client.t()
  def client do
    port = Application.fetch_env!(:electric, :service_port)

    Electric.Client.new!(
      base_url: "http://127.0.0.1:#{port}",
      fetch: {Electric.Client.Fetch.HTTP, timeout: 30}
    )
  end

  @doc "A client reading the Electric the application runs, in process."
  @spec embedded_client() :: Electric.Client.t()
  def embedded_client, do: Electric.Client.embedded!()

  @doc "Writes down an item."
  @spec add(String.t(), boolean()) :: ElectricHost.Item.t()
  def add(title, done \\ false),
    do: ElectricHost.Repo.insert!(%ElectricHost.Item{title: title, done: done})
end
