defmodule Fmsystem.Fleet do
  @moduledoc "Context for managing Vehicles and IoT devices."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Fleet.{Vehicle, IoT}
  # For latest telemetry query
  alias Fmsystem.Tracking.Telemetry
  alias FmsystemWeb.VehicleChannel
  # --- Vehicle Functions ---
  def list_vehicles(current_user) do
    # Preload IoT device
    query = from(v in Vehicle, preload: [:iot_device])

    query =
      if current_user.role == :admin do
        query
      else
        from(v in query, where: v.created_by_id == ^current_user.id)
      end

    # Optionally preload latest telemetry here or let the JSON view handle it
    vehicles = Repo.all(query)
    vehicle_ids = Enum.map(vehicles, & &1.id)
    # Ensure preloads needed by VehicleJSON.data are here
    Repo.preload(vehicles, [
      :iot_device,
      latest_telemetry: latest_telemetry_preload_query(vehicle_ids)
    ])
  end

  def get_vehicle!(id) do
    # Fetch vehicle first
    vehicle = Repo.get!(Vehicle, id)
    # --- UPDATED Preload using a function ---
    # Preload using the helper function (passing a list with single ID)
    Repo.preload(vehicle, [
      :iot_device,
      latest_telemetry: latest_telemetry_preload_query([vehicle.id])
    ])
  end

  def get_vehicle(id) do
    case Repo.get(Vehicle, id) do
      nil ->
        nil

      vehicle ->
        # --- UPDATED Preload using a function ---
        Repo.preload(vehicle, [
          :iot_device,
          latest_telemetry: latest_telemetry_preload_query([vehicle.id])
        ])
    end
  end

  def create_vehicle(current_user, attrs \\ %{}) do
    attrs = Map.put(attrs, "created_by_id", current_user.id)

    %Vehicle{}
    |> Vehicle.changeset(attrs)
    |> Repo.insert()
    # Preload associations after successful creation if needed immediately
    # Tap into the result
    |> tap(&maybe_broadcast_vehicle_created/1)
    |> case do
      {:ok, vehicle} -> {:ok, get_vehicle!(vehicle.id)}
      error -> error
    end
  end

  # Example: Add update_vehicle function
  def update_vehicle(%Vehicle{} = vehicle, attrs) do
    vehicle
    |> Vehicle.changeset(attrs)
    |> Repo.update()
    |> tap(&maybe_broadcast_vehicle_updated/1)
    |> case do
      {:ok, updated_vehicle} ->
        {:ok, get_vehicle!(updated_vehicle.id)}

      error ->
        error
    end
  end

  # Example: Add delete_vehicle function
  def delete_vehicle(%Vehicle{} = vehicle) do
    # Capture ID before deletion
    original_id = vehicle.id

    case Repo.delete(vehicle) do
      {:ok, _deleted_struct} ->
        # Broadcast deletion
        VehicleChannel.broadcast_vehicle_deleted(original_id)
        {:ok, original_id}

      error ->
        error
    end
  end

  # --- IoT Functions ---
  def list_iot_devices(current_user) do
    # Preload associations
    query = from(i in IoT, preload: [:vehicle, :api_auth])

    query =
      if current_user.role == :admin do
        query
      else
        from(i in query, where: i.created_by_id == ^current_user.id)
      end

    Repo.all(query)
  end

  @doc """
  Updates an IoT device.
  Authorization should be checked before calling.
  """
  def update_iot_device(%IoT{} = iot_device, attrs) do
    iot_device
    # Use existing changeset for validation
    |> IoT.changeset(attrs)
    |> Repo.update()
    |> case do
      # Re-fetch with preloads for consistent response data
      {:ok, updated_iot} -> {:ok, get_iot_device!(updated_iot.id)}
      error -> error
    end

    # Note: No broadcast typically needed for IoT device config changes unless a live dashboard depends on it.
  end

  @doc """
  Deletes an IoT device.
  Authorization should be checked before calling.
  Handles telemetry cascade delete via DB constraint.
  """
  def delete_iot_device(%IoT{} = iot_device) do
    # The ON DELETE CASCADE on telemetry_iot_id_fkey should handle telemetry cleanup.
    # The ON DELETE RESTRICT on iot_api_auth_id_fkey might prevent deletion
    # if the API key is still linked - Repo.delete handles this constraint check.
    Repo.delete(iot_device)
    # Returns {:ok, deleted_iot} or {:error, changeset/reason}
    # Note: No broadcast typically needed
  end

  def get_iot_device!(id), do: Repo.get!(IoT, id) |> Repo.preload([:vehicle, :api_auth])
  def get_iot_device(id), do: Repo.get(IoT, id) |> Repo.preload([:vehicle, :api_auth])

  @doc "Fetches an IoT device specifically for telemetry ingestion, preloading needed associations."
  def get_iot_device_for_telemetry(iot_id) do
    # Preload api_auth for token check and vehicle for vehicle_id
    Repo.get(IoT, iot_id) |> Repo.preload([:api_auth, :vehicle])
  end

  def create_iot_device(current_user, attrs \\ %{}) do
    attrs = Map.put(attrs, "created_by_id", current_user.id)

    %IoT{}
    |> IoT.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, iot} -> {:ok, Repo.preload(iot, [:vehicle, :api_auth])}
      error -> error
    end
  end

  # --- Helper Queries ---
  defp latest_telemetry_query() do
    from(t in Telemetry, order_by: [desc: t.inserted_at], limit: 1)
  end

  defp latest_telemetry_preload_query(vehicle_ids) do
    from(t in Telemetry,
      where: t.vehicle_id in ^vehicle_ids,
      # DISTINCT ON (vehicle_id) grabs the first row for each vehicle_id...
      distinct: :vehicle_id,
      # ...based on this ordering (latest inserted_at first within each vehicle group)
      order_by: [:vehicle_id, desc: t.inserted_at]
    )
  end

  # --- Private Broadcasting Helpers ---
  defp maybe_broadcast_vehicle_created({:ok, vehicle}) do
    # Preload data needed for the broadcast payload *before* broadcasting
    # Ensure the data matches what VehicleJSON expects
    preloaded_vehicle =
      get_vehicle!(vehicle.id)

    VehicleChannel.broadcast_vehicle_created(preloaded_vehicle)
  end

  # Don't broadcast on error
  defp maybe_broadcast_vehicle_created({:error, _changeset}), do: :ok

  defp maybe_broadcast_vehicle_updated({:ok, vehicle}) do
    preloaded_vehicle =
      get_vehicle!(vehicle.id)

    VehicleChannel.broadcast_vehicle_updated(preloaded_vehicle)
  end

  defp maybe_broadcast_vehicle_updated({:error, _changeset}), do: :ok
end
