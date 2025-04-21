defmodule FmsystemWeb.UserSocket do
  use Phoenix.Socket

  # A Socket handler
  #
  # It's possible to control the websocket connection and
  # assign values that can be accessed by your channel topics.

  alias Fmsystem.{Accounts, Auth} # Use our contexts/modules
  alias Fmsystem.Accounts.User
  ## Channels
  # Uncomment the following line to define a "room:*" topic
  # pointing to the `FmsystemWeb.RoomChannel`:
  #
  # channel "room:*", FmsystemWeb.RoomChannel
  #
  # To create a channel file, use the mix task:
  #
  #     mix phx.gen.channel Room
  #
  # See the [`Channels guide`](https://hexdocs.pm/phoenix/channels.html)
  # for further details.
  # Channels listed here are accessible through this socket handler.
  # We will add our VehicleChannel here.
  channel "vehicles:*", FmsystemWeb.VehicleChannel # Topic structure example

  @max_age 24 * 60 * 60 # e.g., 1 day max age for token check

  # Socket params are passed from the client connect request, e.g:
  # let socket = new Socket("/socket", {params: {token: userToken}})
  # See "Bringing Authentication to Channels" section: https://hexdocs.pm/phoenix/channels.html

  @impl true
  def connect(%{"token" => token}, socket, _connect_info) do
    # Verify the token passed in the connection params
    case Auth.verify_token(token) do
      {:ok, claims} ->
        # Check claims like expiration ('exp') if needed
        # Expiration check example:
        # if claims["exp"] <= DateTime.to_unix(DateTime.utc_now()) do
        #   :error
        # else
           handle_valid_connection(claims, socket)
        # end

      {:error, _reason} ->
        :error # Token invalid or expired
    end
  end

  # Reject connections without a token
  @impl true
  def connect(_params, _socket, _connect_info), do: :error

  # Assign user_id if connection is valid
  defp handle_valid_connection(%{"sub" => user_id}, socket) do
     # Optional: Fetch user to ensure they still exist, or just trust the token claim
     # case Accounts.get_user(user_id) do
     #   %User{} -> {:ok, assign(socket, :user_id, user_id)}
     #   _ -> :error # User deleted since token was issued
     # end
     {:ok, assign(socket, :user_id, user_id)} # Assign user_id for use in Channels
  end
  defp handle_valid_connection(_claims_without_sub, _socket), do: :error # Token missing user ID


  # Socket id's are topics that allow you to identify all sockets for a given user:
  # See documentation for Multiple Topic Handling for more details.
  @impl true
  def id(socket), do: "user_socket:#{socket.assigns.user_id}" # Use the authenticated user ID
end
