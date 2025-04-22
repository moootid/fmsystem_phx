# lib/fmsystem/tracking.ex
defmodule Fmsystem.Tracking do
  @moduledoc "Context for handling Telemetry data."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Tracking.Telemetry
  alias FmsystemWeb.VehicleChannel # <-- Alias the channel for broadcasting
  require Logger

  @doc "Creates a telemetry record asynchronously and broadcasts update."
  def create_telemetry_async(attrs) do
    Task.start(fn ->
      case insert_telemetry(attrs) do
        {:ok, telemetry_record} ->
          # Broadcast *after* successful insertion
          VehicleChannel.broadcast_telemetry_updated(telemetry_record) # <-- Call broadcast
          :ok
        {:error, _reason} ->
          # Error already logged in insert_telemetry
          :error
      end
    end)
    :ok # Respond immediately
  end

  # This function now returns the record on success for broadcasting
  defp insert_telemetry(attrs) do
    # attrs = Map.put_new(attrs, :inserted_at, DateTime.utc_now()) # Use inserted_at
    case Telemetry.changeset(%Telemetry{}, attrs) |> Repo.insert() do
      {:ok, telemetry_record} ->
        Logger.debug("Telemetry record inserted.")
        {:ok, telemetry_record} # <--- Return the record on success
      {:error, changeset} ->
        errors = FmsystemWeb.ErrorHelpers.translate_errors(changeset)
        Logger.error("Failed to insert telemetry: #{inspect(errors)}")
        {:error, errors}
    end
  end
end
