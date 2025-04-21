defmodule Fmsystem.Credentials.APIAuth do
  use Ecto.Schema
  import Ecto.Changeset
  # Updated reference
  alias Fmsystem.Accounts.User
  # Updated reference
  alias Fmsystem.Fleet.IoT

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Jason.Encoder,
   only: [
     :id,
     :title,
     :description,
     :token,
     :last_access,
     :inserted_at,
     :updated_at,
     :created_by_id,
     # Only include if preloaded and desired
     :iot_devices
   ]}

  schema "api_auth" do
    field :title, :string
    field :description, :string
    field :token, :string
    field :last_access, :utc_datetime_usec

    # type: :binary_id inferred
    belongs_to :created_by, User, foreign_key: :created_by_id
    has_many :iot_devices, IoT, foreign_key: :api_auth_id

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(api_auth, attrs) do
    api_auth
    # Token is generated
    |> cast(attrs, [:title, :description, :created_by_id])
    # Description is optional
    |> validate_required([:title, :created_by_id])
    |> validate_length(:title, max: 255)
    |> validate_length(:description, max: 1000, allow_nil: true)
    |> generate_token()
    |> unique_constraint(:token)
    |> foreign_key_constraint(:created_by_id)
  end

  defp generate_token(changeset) do
    # Only generate token on insert (when token is nil or not changed)
    if get_field(changeset, :token) == nil do
      token =
        :crypto.strong_rand_bytes(32)
        # No padding needed
        |> Base.url_encode64(padding: false)

      put_change(changeset, :token, token)
    else
      changeset
    end
  end
end
