defmodule Fmsystem.Repo.Migrations.CreateApiAuth do
  use Ecto.Migration

  def change do
    create table(:api_auth, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :text
      add :description, :text
      add :token, :text, null: false
      add :last_access, :utc_datetime_usec # Match timestamp type

      # Foreign key referencing users table (using binary_id)
      add :created_by_id, references(:users, type: :binary_id, on_delete: :nilify_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:api_auth, [:token])
    create index(:api_auth, [:created_by_id])
  end
end
