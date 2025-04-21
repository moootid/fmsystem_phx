defmodule FmsystemWeb.IotJSON do
  alias Fmsystem.Fleet.IoT
  # alias FmsystemWeb.VehicleJSON # Avoid circular refs if possible
  # alias FmsystemWeb.ApiAuthJSON

  def index(%{data: iots}), do: %{data: for(iot <- iots, do: data(iot))}
  def show(%{data: iot}), do: %{data: data(iot)}

  def data(%IoT{} = iot) do
     %{
       id: iot.id,
       model: iot.model,
       hw_version: iot.hw_version,
       note: iot.note,
       mac_address: iot.mac_address,
       status: iot.status,
       sw_version: iot.sw_version,
       vehicle_id: iot.vehicle_id,
       api_auth_id: iot.api_auth_id,
       created_by_id: iot.created_by_id,
       inserted_at: iot.inserted_at,
       updated_at: iot.updated_at
       # If preloaded, include basic info:
       # vehicle: format_assoc(iot.vehicle, VehicleJSON), # Be careful with depth
       # api_auth: format_assoc(iot.api_auth, ApiAuthJSON) # Be careful with depth
     }
   end
   defp format_assoc(nil, _mod), do: nil
   defp format_assoc(%Ecto.Association.NotLoaded{}, _mod), do: nil
   defp format_assoc(assoc_data, json_module), do: json_module.data(assoc_data)
end
