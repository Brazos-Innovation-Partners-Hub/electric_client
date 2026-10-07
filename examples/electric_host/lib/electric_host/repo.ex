defmodule ElectricHost.Repo do
  @moduledoc "The application's database, which Electric reads too."
  use Ecto.Repo, otp_app: :electric_host, adapter: Ecto.Adapters.Postgres
end
