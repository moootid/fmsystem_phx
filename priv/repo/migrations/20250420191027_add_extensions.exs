# priv/repo/migrations/*_add_extensions.exs
defmodule Fmsystem.Repo.Migrations.AddExtensions do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;", # For Telemetry
            "DROP EXTENSION IF EXISTS timescaledb;") # Drop on down

    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";", # For binary_id generation
            "DROP EXTENSION IF EXISTS \"uuid-ossp\";")
  end
end
