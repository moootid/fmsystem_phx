defmodule FmsystemWeb.TelemetryController do
  use FmsystemWeb, :controller
  alias Fmsystem.{Fleet, Credentials, Tracking}
  require Logger

  # No action_fallback needed if we handle all cases explicitly

  def create(conn, params) do
    iot_id_str = params["iot_id"] || params["iot"]
    provided_token = params["token"]

    # Validate input presence
    cond do
      is_nil(iot_id_str) ->
        bad_request(conn, "Missing 'iot_id'")

      is_nil(provided_token) ->
        unauthorized(conn, "Missing 'token'")

      true ->
        process_telemetry(conn, iot_id_str, provided_token, params)
    end
  end

  defp process_telemetry(conn, iot_id_str, provided_token, params) do
    case Ecto.UUID.cast(iot_id_str) do
      :error ->
        bad_request(conn, "Invalid 'iot_id' format (must be UUID)")

      {:ok, iot_id} ->
        case Fleet.get_iot_device_for_telemetry(iot_id) do
          nil ->
            not_found(conn, "IoT device not found")

          iot_device ->
            if Credentials.verify_iot_api_token(iot_device, provided_token) do
              # Prepare attributes for insertion
              telemetry_attrs =
                params
                |> Map.put("iot_id", iot_device.id)
                # Add vehicle_id if the IoT device has one associated
                |> Map.put_new("vehicle_id", iot_device.vehicle_id)
                # Remove redundant/sensitive fields
                |> Map.drop(["iot", "token"])

              # Create telemetry asynchronously
              Tracking.create_telemetry_async(telemetry_attrs)

              conn
              # 202 Accepted
              |> put_status(:accepted)
              |> json(%{status: "Telemetry data accepted"})
            else
              unauthorized(conn, "Invalid token for this IoT device")
            end
        end
    end
  end

  # --- Helper functions for responses ---
  defp bad_request(conn, detail), do: error_response(conn, :bad_request, detail)
  defp unauthorized(conn, detail), do: error_response(conn, :unauthorized, detail)
  defp not_found(conn, detail), do: error_response(conn, :not_found, detail)

  defp error_response(conn, status, detail) do
    code = Plug.Conn.Status.code(status)

    conn
    |> put_status(status)
    |> json(%{error: %{status: code, detail: detail}})

    # |> halt() # Halt might be needed depending on flow, but usually json ends it
  end
end
