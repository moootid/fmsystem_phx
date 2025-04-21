# lib/fmsystem_web/controllers/api_auth_json.ex
defmodule FmsystemWeb.ApiAuthJSON do
  alias Fmsystem.Credentials.APIAuth
  alias FmsystemWeb.IotJSON # Assuming you have IotJSON for nested rendering

  @doc """
  Renders a list of api_auth records.
  """
  def index(%{data: api_auths}) do
    %{data: for(aa <- api_auths, do: data(aa))}
  end

  @doc """
  Renders a single api_auth record.
  This is used by the `render(conn, :show, data: api_auth)` call.
  """
  def show(%{data: api_auth}) do
    %{data: data(api_auth)} # Delegate to the main data rendering function
  end

  # --- Private Helper Functions ---

  @doc """
  Transforms a single APIAuth struct into a map suitable for JSON encoding.
  """
  defp data(%APIAuth{} = api_auth) do
    %{
      id: api_auth.id,
      title: api_auth.title,
      description: api_auth.description,
      # IMPORTANT: Decide if you want to return the token in the response after creation.
      # Usually, this is desired. For a generic :show or :index, maybe not.
      token: api_auth.token,
      last_access: api_auth.last_access,
      inserted_at: api_auth.inserted_at,
      updated_at: api_auth.updated_at,
      created_by_id: api_auth.created_by_id,
      # Render associated devices if they were preloaded (handle safely)
      iot_devices: format_assoc_list(api_auth.iot_devices, IotJSON)
    }
  end

  # Helper to handle associated data lists (nil or unloaded)
  defp format_assoc_list(nil, _mod), do: []
  defp format_assoc_list(%Ecto.Association.NotLoaded{}, _mod), do: [] # Or return info like %{loaded: false}
  defp format_assoc_list(associated_list, json_module) do
     Enum.map(associated_list, &json_module.data/1)
  end
end
