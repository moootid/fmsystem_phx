defmodule Fmsystem.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      FmsystemWeb.Telemetry,
      Fmsystem.Repo,
      {DNSCluster, query: Application.get_env(:fmsystem, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Fmsystem.PubSub},
      # Start a worker by calling: Fmsystem.Worker.start_link(arg)
      # {Fmsystem.Worker, arg},
      # Start to serve requests, typically the last entry
      FmsystemWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fmsystem.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FmsystemWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
