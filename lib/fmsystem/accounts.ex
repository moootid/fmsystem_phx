defmodule Fmsystem.Accounts do
  @moduledoc "The Accounts context, handling Users."
  import Ecto.Query, warn: false
  alias Fmsystem.Repo
  alias Fmsystem.Accounts.User

  def get_user!(id), do: Repo.get!(User, id)
  def get_user(id), do: Repo.get(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def register_user(attrs \\ %{}) do
    %User{}
    |> User.registration_changeset(attrs)
    # Returns {:ok, user} or {:error, changeset}
    |> Repo.insert()
  end

  def list_users do
    # Add filtering/pagination as needed
    Repo.all(User)
  end

  # Delegate password verification
  def verify_password(user, password), do: User.verify_password(user, password)
end
