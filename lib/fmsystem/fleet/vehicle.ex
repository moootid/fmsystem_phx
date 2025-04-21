defmodule Fmsystem.Fleet.Vehicle do
  use Ecto.Schema
  import Ecto.Changeset
  # Updated reference
  alias Fmsystem.Accounts.User
  # Updated reference
  alias Fmsystem.Fleet.IoT
  # Updated reference
  alias Fmsystem.Tracking.Telemetry

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
   only: [
     :id,
     :code,
     :plate,
     :vin,
     :manufacturer,
     :model,
     :make_year,
     :status,
     :type,
     :color,
     :description,
     :inserted_at,
     :updated_at,
     :created_by_id,
     # Include only if preloaded
     :iot_device,
    #  :latest_telemetry
   ]}

  schema "vehicles" do
    field :code, :string
    field :plate, :string
    field :vin, :string
    field :manufacturer, :string
    field :model, :string
    field :make_year, :integer
    field :status, :string
    field :type, :string
    field :color, :string
    field :description, :string

    belongs_to :created_by, User, foreign_key: :created_by_id
    has_one :iot_device, IoT, foreign_key: :vehicle_id
    # Note: We can define latest_telemetry relationship here or query it in context
    # has_many :telemetry_entries, Telemetry, foreign_key: :vehicle_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(vehicle, attrs) do
    vehicle
    |> cast(attrs, [
      :code,
      :plate,
      :vin,
      :manufacturer,
      :model,
      :make_year,
      :status,
      :type,
      :color,
      :description,
      :created_by_id
    ])
    |> validate_required([:code, :vin, :created_by_id])
    # Standard VIN length
    |> validate_length(:vin, is: 17)
    |> unique_constraint(:code)
    |> unique_constraint(:vin)
    # Plate uniqueness might be handled differently (e.g., unique per region/user)
    # If globally unique: |> unique_constraint(:plate)
    |> validate_number(:make_year,
      # Allow next year's models
      less_than_or_equal_to: Date.utc_today().year + 1,
      greater_than_or_equal_to: 1900
    )
    |> foreign_key_constraint(:created_by_id)
  end
end
