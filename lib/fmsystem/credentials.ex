defmodule Fmsystem.Credentials do
  @moduledoc "Context for managing API Authentication credentials."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Credentials.APIAuth

  def list_api_auths(current_user) do
    query = from(a in APIAuth, preload: [:iot_devices]) # Preload associated devices

    query =
      if current_user.role == :admin do
        query # Admins see all
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
        false # No associated APIAuth or not preloaded
    end
  end

  # Add update/delete functions as needed
end
