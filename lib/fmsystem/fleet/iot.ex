defmodule Fmsystem.Fleet.IoT do
  use Ecto.Schema
  import Ecto.Changeset
  alias Fmsystem.Fleet.Vehicle
  alias Fmsystem.Credentials.APIAuth
  alias Fmsystem.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
   only: [
     :id,
     :model,
     :hw_version,
     :note,
     :mac_address,
     :status,
     :sw_version,
     :vehicle_id,
     :api_auth_id,
     :inserted_at,
     :updated_at,
     :created_by_id
     # :vehicle, :api_auth # Include only if preloaded
   ]}

  schema "iot" do
    field :model, :string
    field :hw_version, :string
    field :note, :string
    field :mac_address, :string
    field :status, :string
    field :sw_version, :string

    belongs_to :vehicle, Vehicle, foreign_key: :vehicle_id
    belongs_to :api_auth, APIAuth, foreign_key: :api_auth_id
    belongs_to :created_by, User, foreign_key: :created_by_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(iot, attrs) do
    iot
    |> cast(attrs, [
      :model,
      :hw_version,
      :note,
      :mac_address,
      :status,
      :sw_version,
      :vehicle_id,
      :api_auth_id,
      :created_by_id
    ])
    # Require association IDs and mac_address
    |> validate_required([:mac_address, :api_auth_id, :created_by_id])
    |> unique_constraint(:mac_address)
    # Checks if UUID exists if provided
    |> foreign_key_constraint(:vehicle_id)
    # Checks if required UUID exists
    |> foreign_key_constraint(:api_auth_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
