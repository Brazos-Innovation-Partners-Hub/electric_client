defmodule ElectricHost.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :title, :text, null: false
      add :done, :boolean, null: false, default: false
    end
  end
end
