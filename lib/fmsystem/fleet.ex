defmodule Fmsystem.Fleet do
  @moduledoc "Context for managing Vehicles and IoT devices."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Fleet.{Vehicle, IoT}
  # For latest telemetry query
  alias Fmsystem.Tracking.Telemetry

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
    # Example: Preload latest telemetry for all vehicles
    # Repo.preload(vehicles)
  end

  def get_vehicle!(id),
    do:
      Repo.get!(Vehicle, id)
      |> Repo.preload([:iot_device])

  def get_vehicle(id),
    do:
      Repo.get(Vehicle, id)
      |> Repo.preload([:iot_device])

  def create_vehicle(current_user, attrs \\ %{}) do
    attrs = Map.put(attrs, "created_by_id", current_user.id)

    %Vehicle{}
    |> Vehicle.changeset(attrs)
    |> Repo.insert()
    # Preload associations after successful creation if needed immediately
    |> case do
      {:ok, vehicle} -> {:ok, Repo.preload(vehicle, [:iot_device])}
      error -> error
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
    from(t in Telemetry, order_by: [desc: t.time], limit: 1)
  end
end
