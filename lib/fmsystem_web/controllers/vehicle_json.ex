defmodule FmsystemWeb.VehicleJSON do
  alias Fmsystem.Fleet.Vehicle
  alias FmsystemWeb.{IotJSON, TelemetryJSON} # Reuse others

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
      # latest_telemetry: format_assoc(vehicle.latest_telemetry, TelemetryJSON)
    }
  end

  # Helper to handle nil or unloaded associations
  defp format_assoc(nil, _mod), do: nil
  defp format_assoc(%Ecto.Association.NotLoaded{}, _mod), do: nil # Or return %{loaded: false}
  defp format_assoc(assoc_data, json_module), do: json_module.data(assoc_data)

end
