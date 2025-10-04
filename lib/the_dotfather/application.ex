defmodule TheDotfather.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    start_repo? = Application.get_env(:the_dotfather, :start_repo?, true)

    base_children = [
      TheDotfatherWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:the_dotfather, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: TheDotfather.PubSub},
      {Registry, keys: :unique, name: TheDotfather.GameRegistry},
      {DynamicSupervisor, name: TheDotfather.GameSupervisor, strategy: :one_for_one},
      TheDotfather.Matchmaker,
      TheDotfatherWeb.Endpoint
    ]

    children =
      if start_repo? do
        [TheDotfather.Repo | base_children]
      else
        base_children
      end

    opts = [strategy: :one_for_one, name: TheDotfather.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    TheDotfatherWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
