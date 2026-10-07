defmodule ElectricHost.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([ElectricHost.Repo],
      strategy: :one_for_one,
      name: ElectricHost.Supervisor
    )
  end
end
