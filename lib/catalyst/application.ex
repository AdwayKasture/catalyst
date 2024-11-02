defmodule Catalyst.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      CatalystWeb.Telemetry,
      Catalyst.Repo,
      {DNSCluster, query: Application.get_env(:catalyst, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Catalyst.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Catalyst.Finch},
      {Catalyst.MarketData.InstrumentsCache, name: Catalyst.MarketData.InstrumentsCache},
      {Catalyst.Analytics.BalanceHoldingsCache, name: Catalyst.Analytics.BalanceHoldingsCache},
      {Catalyst.PortfolioData.PortfolioListener, name: Catalyst.PortfolioData.PortfolioListener},
      {Catalyst.DateTime.MarketHoliday, name: Catalyst.DateTime.MarketHoliday},
      # Start a worker by calling: Catalyst.Worker.start_link(arg)
      # {Catalyst.Worker, arg},
      # Start to serve requests, typically the last entry
      CatalystWeb.Endpoint,
      {Oban, oban_config()},
      {Task.Supervisor, name: Catalyst.TaskSupervisor}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Catalyst.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CatalystWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp oban_config() do
    opts = Application.fetch_env!(:catalyst, Oban)

    # if(Code.ensure_loaded?(IEx) and IEx.started?()) do
    #   opts
    #   |> Keyword.put(:crontab, false)
    #   |> Keyword.put(:queues, false)
    # else
    opts
    # end
  end
end
