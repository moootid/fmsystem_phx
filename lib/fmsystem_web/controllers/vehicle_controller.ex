defmodule FmsystemWeb.VehicleController do
  use FmsystemWeb, :controller
  alias Fmsystem.Fleet
  alias Fmsystem.Fleet.Vehicle

  action_fallback FmsystemWeb.FallbackController

  # Example plug to load resource
  plug :load_vehicle when action in [:show]

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    vehicles = Fleet.list_vehicles(current_user)
    # Uses VehicleJSON
    render(conn, :index, data: vehicles)
  end

  def create(conn, vehicle_params) do
    current_user = conn.assigns.current_user

    with {:ok, %Vehicle{} = vehicle} <- Fleet.create_vehicle(current_user, vehicle_params) do
      conn
      |> put_status(:created)
      # Uses VehicleJSON
      |> render(:show, data: vehicle)
    end
  end

  def show(conn, _params) do
    # Vehicle is loaded by the plug and available in assigns
    render(conn, :show, data: conn.assigns.vehicle)
  end

  # --- Plugs ---
  defp load_vehicle(conn, _) do
    with %{"id" => id} <- conn.params,
         %Vehicle{} = vehicle <- Fleet.get_vehicle(id) do
      assign(conn, :vehicle, vehicle)
    else
      _ ->
        conn
        |> put_status(:not_found)
        |> json(%{error: %{detail: "Vehicle not found"}})
        |> halt()
    end
  end
end
