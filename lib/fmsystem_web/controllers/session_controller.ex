defmodule FmsystemWeb.SessionController do
  use FmsystemWeb, :controller
  alias Fmsystem.{Accounts, Auth}
  alias Fmsystem.Accounts.User

  action_fallback FmsystemWeb.FallbackController

  def login(conn, %{"email" => email, "password" => password}) do
    with %User{} = user <- Accounts.get_user_by_email(email),
         true <- Accounts.verify_password(user, password),
         {:ok, token, _claims} <- Auth.generate_user_token(user) do
      # Successful login
      # Pass data to SessionJSON
      render(conn, :show, token: token, user: user)
    else
      # Handle failures explicitly for better error messages
      # User not found
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{detail: "Invalid email or password"}})

      # Password verification failed
      false ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{detail: "Invalid email or password"}})

      # Token generation failed
      {:error, reason} ->
        Logger.error("JWT generation failed: #{inspect(reason)}")
        conn |> put_status(:internal_server_error) |> json(%{error: %{detail: "Login failed"}})
    end
  end

  def login(conn, _params), do: bad_request(conn, "Missing email or password")

  # Get current user info (requires :api_auth pipeline)
  def show(conn, _params) do
    # Already loaded by VerifyJWT
    current_user = conn.assigns.current_user
    # Use UserJSON view
    render(conn, :show_user, data: current_user)
  end

  defp bad_request(conn, message) do
    conn |> put_status(:bad_request) |> json(%{error: %{detail: message}})
  end
end
