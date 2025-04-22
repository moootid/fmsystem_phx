defmodule FmsystemWeb.VehicleChannel do
  use FmsystemWeb, :channel
  # To potentially fetch user info if needed for authZ
  # <-- Add Fleet context
  alias Fmsystem.{Accounts, Fleet}
  alias Fmsystem.Tracking.Telemetry
  # <-- Need the JSON renderer
  alias FmsystemWeb.VehicleJSON
  require Logger

  # The topic clients will join
  @vehicle_topic "vehicles:live"

  @impl true
  def join(@vehicle_topic, _payload, socket) do
    # Authorize the user joining this specific topic
    # Here, we assume any authenticated user can join the live vehicle feed.
    # You could add role checks or other logic using socket.assigns.user_id
    if authorized?(socket) do
      Logger.info("User #{socket.assigns.user_id} joined topic #{@vehicle_topic}")
      # <-- Call new function
      # <--- Send message to self
      send(self(), :after_join)
      {:ok, socket}
    else
      Logger.warning(
        "Unauthorized attempt to join topic #{@vehicle_topic} by user #{socket.assigns.user_id}"
      )

      {:error, %{reason: "unauthorized"}}
    end
  end

  # --- Handle Internal Message ---
  @impl true
  def handle_info(:after_join, socket) do
    # This runs *after* the client is successfully joined
    Logger.info(
      "User #{socket.assigns.user_id} successfully joined topic #{@vehicle_topic}. Sending initial list."
    )

    # Now it's safe to push the initial list
    send_initial_vehicle_list(socket)

    # <--- Standard reply for handle_info
    {:noreply, socket}
  end

  # --- Broadcasting Helpers (Internal Use) ---

  @doc """
  Broadcasts that a new vehicle was created.
  Called from the Fleet context after successful creation.
  """
  def broadcast_vehicle_created(vehicle) do
    # Format the payload using the JSON view for consistency
    payload = %{data: FmsystemWeb.VehicleJSON.data(vehicle)}
    FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "vehicle_created", payload)
  end

  @doc """
  Broadcasts that a vehicle was updated.
  """
  def broadcast_vehicle_updated(vehicle) do
    payload = %{data: FmsystemWeb.VehicleJSON.data(vehicle)}
    FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "vehicle_updated", payload)
  end

  @doc """
  Broadcasts that a vehicle was deleted.
  """
  def broadcast_vehicle_deleted(vehicle_id) do
    # Send only the ID for deletion events
    payload = %{id: vehicle_id}
    FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "vehicle_deleted", payload)
  end

  @doc """
  Broadcasts that a new telemetry record was added for a vehicle.
  """
  def broadcast_telemetry_updated(%Telemetry{} = telemetry_record) do
    # We need to inform clients which vehicle this telemetry belongs to.
    # The payload should ideally represent the *updated state* of the vehicle's
    # latest telemetry, not just the raw new telemetry record.

    # Option 1: Send only the relevant telemetry bits + vehicle_id
    # payload = %{
    #   vehicle_id: telemetry_record.vehicle_id, # Essential to identify the vehicle
    #   telemetry: %{ # Send only necessary fields
    #     inserted_at: telemetry_record.inserted_at,
    #     lat: telemetry_record.lat,
    #     long: telemetry_record.long,
    #     speed: telemetry_record.speed,
    #     status: telemetry_record.status
    #     # Add other fields clients need
    #   }
    # }
    # FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "telemetry_updated", payload)

    # Option 2 (More robust): Re-fetch the vehicle with its *new* latest_telemetry
    # This ensures the client receives the same structure as initial load/vehicle updates.
    # Requires fetching the vehicle after telemetry insert.
    # Note: This adds a DB read after each telemetry insert, consider performance.
    case Fleet.get_vehicle(telemetry_record.vehicle_id) do
      nil ->
        Logger.warning(
          "Cannot broadcast telemetry update: Vehicle #{telemetry_record.vehicle_id} not found."
        )

      %Fmsystem.Fleet.Vehicle{} = vehicle ->
        # Vehicle fetched will now have the new telemetry record as latest_telemetry
        # due to the order_by clause in latest_telemetry_query.
        # We broadcast the *entire updated vehicle* data structure.
        payload = %{data: VehicleJSON.data(vehicle)}
        FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "vehicle_updated", payload)

      # Note: We reuse "vehicle_updated" event here. Clients update the whole vehicle.
      # Alternatively, define a new event like "latest_telemetry_changed"
      # FmsystemWeb.Endpoint.broadcast(@vehicle_topic, "latest_telemetry_changed", payload)
      _ ->
        Logger.error(
          "Unexpected result fetching vehicle #{telemetry_record.vehicle_id} for telemetry broadcast."
        )
    end
  end

  # Add clause for nil if telemetry_record could be nil (unlikely from Tracking context)
  def broadcast_telemetry_updated(nil), do: :ok

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  @impl true
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (vehicle:lobby).
  @impl true
  def handle_in("shout", payload, socket) do
    broadcast(socket, "shout", payload)
    {:noreply, socket}
  end

  # --- Private Authorization Helper ---
  defp authorized?(socket) do
    # Check if user_id exists (meaning they authenticated successfully in UserSocket)
    Map.has_key?(socket.assigns, :user_id)
    # Add more checks here if needed, e.g., fetch user and check role:
    # user = Accounts.get_user!(socket.assigns.user_id)
    # user && user.role in [:admin, :user]
  end

  @doc """
  Fetches the initial list of vehicles for the user and pushes it to their socket.
  """
  # Function to fetch and push data - now called from handle_info
  defp send_initial_vehicle_list(socket) do
    current_user_id = socket.assigns.user_id

    case Accounts.get_user(current_user_id) do
      nil ->
        Logger.error("Cannot send initial vehicle list: User #{current_user_id} not found.")

      current_user ->
        vehicles = Fleet.list_vehicles(current_user)
        payload = FmsystemWeb.VehicleJSON.index(%{data: vehicles})

        # Now push is safe because we are in handle_info after join completed
        # <--- Push is safe here
        push(socket, "initial_vehicles", payload)
        Logger.info("Sent initial vehicle list to user #{current_user_id}")
    end
  end
end
