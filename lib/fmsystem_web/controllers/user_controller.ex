defmodule FmsystemWeb.UserController do
  use FmsystemWeb, :controller
  alias Fmsystem.Accounts
  # Needed for the struct type
  alias Fmsystem.Accounts.User

  action_fallback FmsystemWeb.FallbackController

  def register(conn, user_params) do
    with {:ok, %User{} = user} <- Accounts.register_user(user_params) do
      conn
      |> put_status(:created)
      # Use UserJSON view
      |> render(:show, data: user)
    end
  end
end
