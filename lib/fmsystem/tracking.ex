defmodule Fmsystem.Tracking do
  @moduledoc "Context for handling Telemetry data."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Tracking.Telemetry
  require Logger

  @doc "Creates a telemetry record asynchronously."
  def create_telemetry_async(attrs) do
    # Use Task.Supervisor recommended for production supervision
    # For simplicity here, just Task.start
    Task.start(fn -> insert_telemetry(attrs) end)
    # Respond immediately
    :ok
  end

  defp insert_telemetry(attrs) do
    # Add current time if not provided, using UTC is best practice
    # attrs = Map.put_new(attrs, :time, DateTime.utc_now())

    case Telemetry.changeset(%Telemetry{}, attrs) |> Repo.insert() do
      {:ok, _telemetry} ->
        # Logger.debug("Telemetry record inserted.")
        :ok

      {:error, changeset} ->
        # Use helper
        errors = FmsystemWeb.ErrorHelpers.translate_errors(changeset)
        Logger.error("Failed to insert telemetry: #{inspect(errors)}")
        {:error, errors}
    end
  end

  # Add functions to query telemetry data (e.g., get_telemetry_for_vehicle)
end
