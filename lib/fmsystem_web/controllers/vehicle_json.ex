defmodule FmsystemWeb.VehicleJSON do
  alias Fmsystem.Fleet.Vehicle
  alias FmsystemWeb.{IotJSON, TelemetryJSON} # Reuse others
  alias Fmsystem.Tracking.Telemetry # Needed for Telemetry struct type

  def index(%{data: vehicles}), do: %{data: for(v <- vehicles, do: data(v))}
  def show(%{data: vehicle}), do: %{data: data(vehicle)}

  def data(%Vehicle{} = vehicle) do
    %{
      id: vehicle.id,
      code: vehicle.code,
      plate: vehicle.plate,
      vin: vehicle.vin,
      manufacturer: vehicle.manufacturer,
      model: vehicle.model,
      make_year: vehicle.make_year,
      status: vehicle.status,
      type: vehicle.type,
      color: vehicle.color,
      description: vehicle.description,
      inserted_at: vehicle.inserted_at,
      updated_at: vehicle.updated_at,
      created_by_id: vehicle.created_by_id,
      # Handle preloaded associations safely
      iot_device: format_assoc(vehicle.iot_device, IotJSON),
      latest_telemetry: format_latest_telemetry(vehicle.latest_telemetry)
    }
  end

  # Helper to handle nil or unloaded associations
  defp format_assoc(nil, _mod), do: nil
  defp format_assoc(%Ecto.Association.NotLoaded{}, _mod), do: nil
  defp format_assoc(assoc_data, json_module), do: json_module.data(assoc_data)

  # Helper specifically for latest_telemetry (handles nil/not loaded)
  # And formats only the desired fields
  defp format_latest_telemetry(nil), do: nil
  defp format_latest_telemetry(%Ecto.Association.NotLoaded{}), do: nil
  defp format_latest_telemetry(%Telemetry{} = telemetry) do
    # Select only the fields needed for the vehicle overview
    %{
      inserted_at: telemetry.inserted_at, # Or :time if using that column name
      lat: telemetry.lat,
      long: telemetry.long,
      speed: telemetry.speed,
      status: telemetry.status,
      rpm: telemetry.rpm,
      fuel: telemetry.fuel,
      engine_load: telemetry.engine_load,
      coolant_temp: telemetry.coolant_temp,
      ip: telemetry.ip
      # Add other relevant fields like rpm, fuel, etc. if desired
    }
  end

end
