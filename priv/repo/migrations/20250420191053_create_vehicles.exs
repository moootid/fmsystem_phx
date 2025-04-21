defmodule Fmsystem.Repo.Migrations.CreateVehicles do
  use Ecto.Migration

  def change do
    create table(:vehicles, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :text, null: false
      add :plate, :text
      add :vin, :text, null: false
      add :manufacturer, :text
      add :model, :text
      add :make_year, :integer
      add :status, :text
      add :type, :text
      add :color, :text
      add :description, :text

      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:vehicles, [:code])
    create unique_index(:vehicles, [:plate]) # Consider if plate must be unique globally
    create unique_index(:vehicles, [:vin])
    create index(:vehicles, [:created_by_id])
  end
end
