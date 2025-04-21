# lib/fmsystem_web/controllers/fallback_controller.ex
defmodule FmsystemWeb.FallbackController do
  use FmsystemWeb, :controller
  alias FmsystemWeb.ErrorHelpers # Use the helper module

  # Handle Ecto Changeset errors
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity) # 422
    |> put_view(json: FmsystemWeb.ChangesetJSON)
    |> render(:error, changeset: changeset)
  end

  # Handle generic {:error, :reason} tuples
  def call(conn, {:error, reason}) when is_atom(reason) do
    status = Map.get(%{not_found: :not_found, unauthorized: :unauthorized}, reason, :bad_request)
    detail = Macro.to_string(reason) |> String.replace("_", " ") |> String.capitalize()
    ErrorHelpers.error_response(conn, status, detail)
  end

  # Handle {:error, "message"}
  def call(conn, {:error, detail}) when is_binary(detail) do
     ErrorHelpers.error_response(conn, :bad_request, detail)
  end
end
