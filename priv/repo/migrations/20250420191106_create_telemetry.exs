defmodule Fmsystem.Repo.Migrations.CreateTelemetryTable do
  use Ecto.Migration

  def change do
    create table(:telemetry, primary_key: false) do
      # Use a serial id; note: not declared as primary key here
      add :id, :serial
      add :rpm, :integer
      add :speed, :integer
      add :fuel, :decimal
      add :engine_load, :decimal
      add :coolant_temp, :decimal
      add :lat, :decimal
      add :long, :decimal
      add :ip, :text
      add :sw_version, :text
      add :hw_version, :text
      add :status, :text
      add :iot_id, references(:iot, type: :uuid)
      add :vehicle_id, references(:vehicles, type: :uuid)
      add :created_at, :timestamptz, default: fragment("NOW()"), null: false
      # Explicitly add the inserted_at column for partitioning
      add :inserted_at, :timestamptz, null: false, default: fragment("NOW()")
    end

    # Add a composite primary key that includes the partitioning column
    execute("ALTER TABLE telemetry ADD PRIMARY KEY (id, inserted_at);")

    # Now create the hypertable on the inserted_at column
    execute("SELECT create_hypertable('telemetry', 'inserted_at');")
  end
end
