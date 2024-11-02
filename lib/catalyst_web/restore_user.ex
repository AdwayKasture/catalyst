defmodule CatalystWeb.RestoreUser do
  alias Catalyst.Analytics.BalanceAndHolding
  # alias Catalyst.PortfolioData.PortfolioSnapshot
  alias Catalyst.Repo

  def on_mount(:default, _params, %{"user_id" => user_id}, socket) do
    Repo.put_user_id(user_id)
    BalanceAndHolding.calculate(Timex.today())
    {:cont, socket}
  end

  def on_mount(:default, _params, _session, socket) do
    {:cont, socket}
  end
end
