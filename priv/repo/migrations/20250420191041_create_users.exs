defmodule Fmsystem.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do # Use binary_id from generator
      add :id, :binary_id, primary_key: true
      add :email, :text, null: false
      add :password_hash, :text, null: false
      add :role, :text, null: false, default: "user"

      timestamps(type: :utc_datetime_usec) # Consistent timestamp type
    end

    create unique_index(:users, [:email])
  end
end
