defmodule Fmsystem.Auth do
  @moduledoc "Handles JWT generation and verification."
  alias Fmsystem.Accounts.User
  use Joken.Config
  # --- JWT Handling ---
  # defp get_secret(), do: System.get_env("JWT_SECRET_KEY" || "your_jwt_secret_key")
  # defp get_signer(), do: Joken.Signer.create("HS256", get_secret())

  @doc "Generates a JWT for a given user."

  # Function to generate a token for a user
  def generate_user_token(%User{} = user) do
    jwt_secret = Application.fetch_env!(:fmsystem, :jwt_secret)
    # Set claims: subject (user ID), role, and expiration (e.g., 1 day)
    claims = %{
      sub: user.id,
      role: user.role,
      # Issuer claim
      iss: "fmsystem",
      exp: expiration_time(1)
      # Add other claims as needed
    }

    # Expires in 1 day
    generate_and_sign(claims, Joken.Signer.create("HS256", jwt_secret))
  end

  @doc """
  Verifies a JWT string using the application's secret key.
  Returns {:ok, claims} or {:error, reason}.
  """
  def verify_token(token) when is_binary(token) do
    # Fetch the secret from the application environment at runtime
    jwt_secret = Application.fetch_env!(:fmsystem, :jwt_secret)
    # Verify using the same algorithm and secret
    verify(token, Joken.Signer.create("HS256", jwt_secret))
  end

  # Helper for expiration time (in days)
  defp expiration_time(days) do
    DateTime.utc_now()
    # Add days in seconds
    |> DateTime.add(days * 24 * 60 * 60, :second)
    |> DateTime.to_unix()
  end
end
