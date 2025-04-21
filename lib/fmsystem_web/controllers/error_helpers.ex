defmodule FmsystemWeb.ErrorHelpers do
  import Phoenix.Controller
  import Plug.Conn, only: [put_resp_content_type: 2, put_status: 2]

 @doc "Generates a JSON error response."
 def error_response(conn, status, detail) do
   code = Plug.Conn.Status.code(status)
   conn
   |> put_status(status)
   |> put_resp_content_type("application/json")
   |> json(%{error: %{status: code, detail: detail}})
 end

  @doc """
  Translates changeset errors into a map of messages.
  """
  def translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
