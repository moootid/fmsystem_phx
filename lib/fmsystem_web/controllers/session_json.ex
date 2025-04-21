# lib/fmsystem_web/controllers/session_json.ex
defmodule FmsystemWeb.SessionJSON do
  alias FmsystemWeb.UserJSON # Reuse UserJSON

  def show(%{token: token, user: user}) do
    %{
      token: token,
      user: UserJSON.data(user) # Embed user data
    }
  end
end
