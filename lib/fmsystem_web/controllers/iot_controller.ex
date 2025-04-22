# lib/fmsystem_web/controllers/iot_controller.ex
defmodule FmsystemWeb.IotController do
  use FmsystemWeb, :controller
  alias Fmsystem.Fleet
  alias Fmsystem.Fleet.IoT
  alias FmsystemWeb.ErrorHelpers

  action_fallback FmsystemWeb.FallbackController

  # --- Plugs ---
  plug :load_iot_device when action in [:show, :update, :delete]
  plug :authorize_iot_action when action in [:update, :delete]

  # --- Actions ---
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    iot_devices = Fleet.list_iot_devices(current_user)
    render(conn, :index, data: iot_devices)
  end

  def create(conn, iot_params) do
    current_user = conn.assigns.current_user

    with {:ok, %IoT{} = iot} <- Fleet.create_iot_device(current_user, iot_params) do
      conn
      |> put_status(:created)
      |> render(:show, data: iot)
    end
  end

  def show(conn, _params) do
    # Loaded by plug
    render(conn, :show, data: conn.assigns.iot_device)
  end

  def update(conn, iot_params) do
    # Loaded and authorized by plugs
    iot_device = conn.assigns.iot_device

    case Fleet.update_iot_device(iot_device, iot_params) do
      {:ok, %IoT{} = updated_iot} ->
        render(conn, :show, data: updated_iot)

      {:error, changeset} ->
        # Let fallback handle
        {:error, changeset}
    end
  end

  def delete(conn, _params) do
    # Loaded and authorized by plugs
    iot_device = conn.assigns.iot_device

    case Fleet.delete_iot_device(iot_device) do
      {:ok, _deleted_iot} ->
        # 204
        send_resp(conn, :no_content, "")

      {:error, %Ecto.Changeset{} = changeset} ->
        # Should not happen for IoT delete unless there's a new constraint
        conn
        |> put_status(:unprocessable_entity)
        |> put_view(json: FmsystemWeb.ChangesetJSON)
        |> render(:error, changeset: changeset)

      {:error, reason} ->
        ErrorHelpers.error_response(
          conn,
          :internal_server_error,
          "Could not delete IoT device: #{inspect(reason)}"
        )
    end
  end

  # --- Private Plug Functions ---
  defp load_iot_device(conn, _) do
    with %{"id" => id} <- conn.params,
         %IoT{} = iot_device <- Fleet.get_iot_device(id) do
      assign(conn, :iot_device, iot_device)
    else
      _ ->
        ErrorHelpers.error_response(conn, :not_found, "IoT device not found")
        |> halt()
    end
  end

  defp authorize_iot_action(conn, _) do
    # Assumes load ran
    iot_device = conn.assigns.iot_device
    # Assumes VerifyJWT ran
    current_user = conn.assigns.current_user

    # Check ownership or admin role
    if iot_device.created_by_id == current_user.id or current_user.role == :admin do
      # Authorized
      conn
    else
      ErrorHelpers.error_response(
        conn,
        :forbidden,
        "You are not authorized to perform this action on this IoT device."
      )
      |> halt()
    end
  end
end
