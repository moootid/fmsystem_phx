defmodule Fmsystem.Repo do
  use Ecto.Repo,
    otp_app: :fmsystem,
    adapter: Ecto.Adapters.Postgres
end
