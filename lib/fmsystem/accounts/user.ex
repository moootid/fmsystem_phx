defmodule Fmsystem.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset
  alias Bcrypt

  @primary_key {:id, :binary_id, autogenerate: true}
  # Important for associations
  @foreign_key_type :binary_id
  # Exclude password_hash
  @derive {Jason.Encoder, only: [:id, :email, :role, :inserted_at]}

  @roles ~w(user admin)a

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :role, Ecto.Enum, values: @roles, default: :user
    # Redact virtual password
    field :password, :string, virtual: true, redact: true

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for user registration.
  """
  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :role])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:password, min: 8, message: "should be at least 8 characters")
    |> validate_inclusion(:role, @roles, message: "is invalid")
    |> unique_constraint(:email)
    |> put_password_hash()
  end

  defp put_password_hash(changeset) do
    case fetch_change(changeset, :password) do
      {:ok, password} ->
        # Hash the password if present and valid
        put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))

      :error ->
        # If password hasn't changed or changeset invalid, do nothing
        changeset
    end
  end

  @doc "Verifies the user's password."
  def verify_password(%__MODULE__{password_hash: hash}, password) when not is_nil(hash) do
    Bcrypt.verify_pass(password, hash)
  end

  def verify_password(_, _), do: false
end
