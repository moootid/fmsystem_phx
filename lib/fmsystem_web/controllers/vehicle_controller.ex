defmodule FmsystemWeb.VehicleController do
  use FmsystemWeb, :controller
  alias Fmsystem.Fleet
  alias Fmsystem.Fleet.Vehicle
  alias FmsystemWeb.ErrorHelpers
  action_fallback FmsystemWeb.FallbackController

  # Apply plug to load vehicle for actions that need it
  plug :load_vehicle when action in [:show, :update, :delete]
  # Apply authorization plug after loading vehicle
  plug :authorize_vehicle_action when action in [:update, :delete]

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

  def update(conn, vehicle_params) do
    # Vehicle and authorization handled by plugs
    vehicle = conn.assigns.vehicle
    # Needed if update_vehicle required it, but not strictly needed here
    current_user = conn.assigns.current_user

    # Pass only the params to update, vehicle is already loaded
    case Fleet.update_vehicle(vehicle, vehicle_params) do
      {:ok, %Vehicle{} = updated_vehicle} ->
        # Render updated vehicle
        render(conn, :show, data: updated_vehicle)

      {:error, changeset} ->
        # Let FallbackController handle changeset errors (422)
        {:error, changeset}

      # Handle potential authorization error from context (though plug should catch it)
      {:error, :unauthorized} ->
        ErrorHelpers.error_response(
          conn,
          :forbidden,
          "You are not authorized to update this vehicle."
        )
    end
  end

  def delete(conn, _params) do
    # Vehicle and authorization handled by plugs
    vehicle = conn.assigns.vehicle

    case Fleet.delete_vehicle(vehicle) do
      {:ok, _vehicle_id} ->
        # 204 No Content on successful delete
        send_resp(conn, :no_content, "")

      {:error, :unauthorized} ->
        # Should be caught by plug, but belt-and-suspenders
        ErrorHelpers.error_response(
          conn,
          :forbidden,
          "You are not authorized to delete this vehicle."
        )

      {:error, reason} ->
        # Handle other potential delete errors (e.g., DB constraint)
        ErrorHelpers.error_response(
          conn,
          :internal_server_error,
          "Could not delete vehicle: #{inspect(reason)}"
        )
    end
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

  # Authorization Plug - checks if current user owns the loaded vehicle or is admin
  defp authorize_vehicle_action(conn, _) do
    # Assumes load_vehicle ran first
    vehicle = conn.assigns.vehicle
    # Assumes VerifyJWT ran first
    current_user = conn.assigns.current_user

    if vehicle.created_by_id == current_user.id or current_user.role == :admin do
      # Authorized, continue
      conn
    else
      ErrorHelpers.error_response(
        conn,
        :forbidden,
        "You are not authorized to perform this action on this vehicle."
      )
      |> halt()
    end
  end
end
