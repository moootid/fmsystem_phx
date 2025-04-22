# lib/fmsystem_web/controllers/api_auth_controller.ex
defmodule FmsystemWeb.ApiAuthController do
  use FmsystemWeb, :controller
  alias Fmsystem.Credentials
  alias Fmsystem.Credentials.APIAuth
  alias FmsystemWeb.ErrorHelpers # Use helpers

  action_fallback FmsystemWeb.FallbackController

  # --- Plugs ---
  # Load resource for actions needing a specific ID
  plug :load_api_auth when action in [:show, :update, :delete]
  # Authorize actions after loading
  plug :authorize_api_auth_action when action in [:update, :delete]


  # --- Actions ---
  def index(conn, _params) do
    current_user = conn.assigns.current_user
    api_auths = Credentials.list_api_auths(current_user)
    render(conn, :index, data: api_auths)
  end

  def create(conn, api_auth_params) do
    current_user = conn.assigns.current_user
    with {:ok, %APIAuth{} = api_auth} <- Credentials.create_api_auth(current_user, api_auth_params) do
      conn
      |> put_status(:created)
      |> render(:show, data: api_auth)
    end
  end

  def show(conn, _params) do
    # Resource loaded by plug
    render(conn, :show, data: conn.assigns.api_auth)
  end

  def update(conn, api_auth_params) do
    # Resource loaded and authorized by plugs
    api_auth = conn.assigns.api_auth

    case Credentials.update_api_auth(api_auth, api_auth_params) do
      {:ok, %APIAuth{} = updated_api_auth} ->
        render(conn, :show, data: updated_api_auth)
      {:error, changeset} ->
         # Let FallbackController handle 422
         {:error, changeset}
    end
  end

  def delete(conn, _params) do
     # Resource loaded and authorized by plugs
     api_auth = conn.assigns.api_auth

     case Credentials.delete_api_auth(api_auth) do
       {:ok, _deleted_api_auth} ->
         send_resp(conn, :no_content, "") # 204 No Content
       {:error, %Ecto.Changeset{} = changeset} ->
          # This can happen if delete fails due to constraints (e.g., :restrict on IoT)
          conn
          |> put_status(:unprocessable_entity)
          |> put_view(json: FmsystemWeb.ChangesetJSON)
          |> render(:error, changeset: changeset)
       {:error, reason} ->
          ErrorHelpers.error_response(conn, :internal_server_error, "Could not delete API credential: #{inspect(reason)}")
     end
  end


  # --- Private Plug Functions ---
  defp load_api_auth(conn, _) do
      with %{"id" => id} <- conn.params,
           %APIAuth{} = api_auth <- Credentials.get_api_auth(id) do
        assign(conn, :api_auth, api_auth)
      else
        _ ->
          ErrorHelpers.error_response(conn, :not_found, "API credential not found")
          |> halt()
      end
  end

  defp authorize_api_auth_action(conn, _) do
      api_auth = conn.assigns.api_auth # Assumes load_api_auth ran
      current_user = conn.assigns.current_user # Assumes VerifyJWT ran

      # Check ownership or admin role
      if api_auth.created_by_id == current_user.id or current_user.role == :admin do
        conn # Authorized
      else
        ErrorHelpers.error_response(conn, :forbidden, "You are not authorized to perform this action on this API credential.")
        |> halt()
      end
  end

end
