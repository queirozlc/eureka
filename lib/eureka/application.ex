defmodule Eureka.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EurekaWeb.Telemetry,
      Eureka.Repo,
      {DNSCluster, query: Application.get_env(:eureka, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Eureka.PubSub},
      EurekaWeb.Presence,
      # Start the Finch HTTP client for sending emails
      {Finch, name: Eureka.Finch},
      # Start a worker by calling: Eureka.Worker.start_link(arg)
      # {Eureka.Worker, arg},
      # Start to serve requests, typically the last entry
      EurekaWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Eureka.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EurekaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
