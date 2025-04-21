defmodule Fmsystem.Repo.Migrations.CreateIot do
  use Ecto.Migration

  def change do
    create table(:iot, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :model, :text
      add :hw_version, :text
      add :note, :text
      add :mac_address, :text, null: false
      add :status, :text
      add :sw_version, :text

      # Foreign Keys
      add :vehicle_id, references(:vehicles, type: :binary_id, on_delete: :nilify_all)
      add :api_auth_id, references(:api_auth, type: :binary_id, on_delete: :restrict) # Restrict delete if IoT uses it
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:iot, [:mac_address])
    create index(:iot, [:vehicle_id])
    create index(:iot, [:api_auth_id])
    create index(:iot, [:created_by_id])
  end
end
