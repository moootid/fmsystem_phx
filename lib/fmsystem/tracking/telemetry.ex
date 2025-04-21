defmodule Fmsystem.Tracking.Telemetry do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fmsystem.Fleet.{IoT, Vehicle}

  # No single primary key for hypertable usually
  @primary_key false
  @foreign_key_type :binary_id
  # No @derive needed if never sending individual records directly as JSON
  # If needed, derive carefully:
  # @derive {Jason.Encoder, only: [:time, :iot_id, :vehicle_id, :rpm, :speed, ...]}

  schema "telemetry" do
    # Timestamp is essential for TimescaleDB
    # Use native Elixir type, maps to timestamptz via Postgrex
    field :time, :utc_datetime_usec

    # Foreign keys
    belongs_to :iot, IoT, foreign_key: :iot_id, type: :binary_id
    belongs_to :vehicle, Vehicle, foreign_key: :vehicle_id, type: :binary_id

    # Data fields
    field :rpm, :integer
    field :speed, :integer
    field :fuel, :decimal
    field :engine_load, :decimal
    field :coolant_temp, :decimal
    field :lat, :decimal
    field :long, :decimal
    field :ip, :string
    field :sw_version, :string
    field :hw_version, :string
    field :status, :string

    # No Ecto timestamps, :time field serves this purpose
  end

  # Changeset for creating new telemetry entries
  def changeset(telemetry, attrs) do
    telemetry
    |> cast(attrs, [
      # Allow setting time explicitly, otherwise default in DB works
      :time,
      # Required foreign keys
      :iot_id,
      :vehicle_id,
      :rpm,
      :speed,
      :fuel,
      :engine_load,
      :coolant_temp,
      :lat,
      :long,
      :ip,
      :sw_version,
      :hw_version,
      :status
    ])
    # Vehicle ID can be derived from IoT if needed/redundant
    |> validate_required([:iot_id])
    # Add validations for numerical ranges, lengths etc. as in the original
    |> validate_number(:rpm, greater_than_or_equal_to: 0)
    |> validate_number(:speed, greater_than_or_equal_to: 0)
    # ... other validations ...
    |> foreign_key_constraint(:iot_id)
    # If vehicle_id is required
    |> foreign_key_constraint(:vehicle_id)
  end
end
