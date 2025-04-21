# lib/fmsystem_web/controllers/user_json.ex
defmodule FmsystemWeb.UserJSON do
  alias Fmsystem.Accounts.User

  def show(%{data: user}) do
    %{data: data(user)}
  end

  def data(%User{} = user) do
    %{
      id: user.id,
      email: user.email,
      role: user.role,
      inserted_at: user.inserted_at
    }
  end
end




# Create IotJSON, ApiAuthJSON, TelemetryJSON similarly, reusing where possible
# lib/fmsystem_web/controllers/iot_json.ex (Example)

# Define ApiAuthJSON and TelemetryJSON ...
