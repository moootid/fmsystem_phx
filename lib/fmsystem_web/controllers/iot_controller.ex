defmodule FmsystemWeb.IotController do
  use FmsystemWeb, :controller
  alias Fmsystem.Fleet
  alias Fmsystem.Fleet.IoT

  action_fallback FmsystemWeb.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    iot_devices = Fleet.list_iot_devices(current_user)
    # Uses IotJSON
    render(conn, :index, data: iot_devices)
  end

  def create(conn, iot_params) do
    current_user = conn.assigns.current_user

    with {:ok, %IoT{} = iot} <- Fleet.create_iot_device(current_user, iot_params) do
      conn
      |> put_status(:created)
      # Uses IotJSON
      |> render(:show, data: iot)
    end
  end
end
