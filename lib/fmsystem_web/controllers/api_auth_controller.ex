defmodule FmsystemWeb.ApiAuthController do
  use FmsystemWeb, :controller
  alias Fmsystem.Credentials
  alias Fmsystem.Credentials.APIAuth

  action_fallback FmsystemWeb.FallbackController

  def index(conn, _params) do
    current_user = conn.assigns.current_user
    api_auths = Credentials.list_api_auths(current_user)
    # Uses ApiAuthJSON
    render(conn, :index, data: api_auths)
  end

  def create(conn, api_auth_params) do
    current_user = conn.assigns.current_user

    with {:ok, %APIAuth{} = api_auth} <-
           Credentials.create_api_auth(current_user, api_auth_params) do
      conn
      |> put_status(:created)
      # Uses ApiAuthJSON
      |> render(:show, data: api_auth)
    end
  end
end
