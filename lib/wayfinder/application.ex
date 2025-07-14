defmodule Wayfinder.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl Application
  def start(_type, _args) do
    children = [
      WayfinderWeb.Telemetry,
      Wayfinder.Repo,
      {DNSCluster, query: Application.get_env(:wayfinder, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Wayfinder.PubSub},
      # Start a worker by calling: Wayfinder.Worker.start_link(arg)
      # {Wayfinder.Worker, arg},
      # Start to serve requests, typically the last entry
      WayfinderWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Wayfinder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl Application
  def config_change(changed, _new, removed) do
    WayfinderWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
