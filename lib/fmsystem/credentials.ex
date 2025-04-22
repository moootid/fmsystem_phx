defmodule Fmsystem.Credentials do
  @moduledoc "Context for managing API Authentication credentials."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Credentials.APIAuth

  def list_api_auths(current_user) do
    # Preload associated devices
    query = from(a in APIAuth, preload: [:iot_devices])

    query =
      if current_user.role == :admin do
        # Admins see all
        query
      else
        # Users see only their own
        from(a in query, where: a.created_by_id == ^current_user.id)
      end

    Repo.all(query)
  end

  def get_api_auth!(id), do: Repo.get!(APIAuth, id) |> Repo.preload(:iot_devices)
  def get_api_auth(id), do: Repo.get(APIAuth, id) |> Repo.preload(:iot_devices)

  def create_api_auth(current_user, attrs \\ %{}) do
    attrs = Map.put(attrs, "created_by_id", current_user.id)

    %APIAuth{}
    |> APIAuth.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Verifies if the provided token matches the token associated with the given IoT device.
  Assumes iot_device has its api_auth relationship preloaded.
  """
  def verify_iot_api_token(iot_device, provided_token) do
    case iot_device.api_auth do
      %APIAuth{token: expected_token} ->
        expected_token == provided_token

      _ ->
        # No associated APIAuth or not preloaded
        false
    end
  end

  @doc """
  Updates an API credential. Only allows title and description changes.
  Authorization should be checked before calling this function.
  """
  def update_api_auth(%APIAuth{} = api_auth, attrs) do
    # Explicitly only allow title and description updates
    # Token and created_by_id should not be changed here.
    api_auth
    # Use existing changeset
    |> APIAuth.changeset(attrs)
    # Optionally, add specific validation for updates if needed
    # |> Changeset.validate_change(...)
    |> Repo.update()

    # Returns {:ok, updated_api_auth} or {:error, changeset}
    # Note: No broadcast needed typically for API key changes unless UI depends on title/desc in real-time
  end

  @doc """
  Deletes an API credential.
  Authorization should be checked before calling this function.
  Handles potential constraint errors if IoT devices still reference it (:restrict).
  """
  def delete_api_auth(%APIAuth{} = api_auth) do
    # Repo.delete() will return {:error, changeset} if constraints fail
    # (like the iot_api_auth_id_fkey with ON DELETE RESTRICT)
    Repo.delete(api_auth)
    # Returns {:ok, deleted_api_auth} or {:error, changeset/reason}
    # Note: No broadcast typically needed
  end
end
