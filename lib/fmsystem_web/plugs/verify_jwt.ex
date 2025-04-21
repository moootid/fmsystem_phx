defmodule FmsystemWeb.Plugs.VerifyJWT do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2, put_status: 2, halt: 1]

  # Use contexts
  alias Fmsystem.{Accounts, Auth}
  alias Fmsystem.Accounts.User

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, claims} <- Auth.verify_token(token),
         %{"sub" => user_id} <- claims,
         %User{} = user <- Accounts.get_user(user_id) do
      # Token valid, user found - assign to conn and continue
      assign(conn, :current_user, user)
    else
      # Any step fails -> Unauthorized
      _error -> send_unauthorized(conn)
    end
  end

  defp send_unauthorized(conn) do
    conn
    # 401
    |> put_status(:unauthorized)
    |> json(%{error: %{status: 401, detail: "Unauthorized"}})
    |> halt()
  end
end
