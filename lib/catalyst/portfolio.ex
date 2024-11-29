defmodule Catalyst.Portfolio do
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.Analytics.BalanceAndHolding
  alias Catalyst.Repo
  alias Catalyst.DateTime.DateUtils
  alias Catalyst.PortfolioData.PortfolioSnapshot
  alias Catalyst.PortfolioData.Trade
  alias Catalyst.PortfolioData.Cash

  def create_changeset(trade) when is_struct(trade, Trade) do
    Trade.create_changeset(trade, %{})
  end

  def create_changeset(cash) when is_struct(cash, Cash) do
    Cash.create_changeset(cash, %{})
  end

  def update_changeset(trade, attrs) when is_struct(trade, Trade) do
    Trade.create_changeset(trade, attrs)
    |> Map.put(:action, :validate)
  end

  def update_changeset(cash, attrs) when is_struct(cash, Cash) do
    Cash.create_changeset(cash, attrs)
    |> Map.put(:action, :validate)
  end

  def save_trade(attrs) do
    Trade.create_trade(attrs)
  end

  def update_trade(org_trade, attrs) when is_struct(org_trade, Trade) do
    Trade.update_trade(org_trade, attrs)
  end

  def save_txn(attrs) do
    Cash.create_txn(attrs)
  end

  def update_txn(org_cash, attrs) when is_struct(org_cash, Cash) do
    Cash.update_txn(org_cash, attrs)
  end

  def get_history(type) do
    case type do
      "trade" -> Trade.get_history()
      :trade -> Trade.get_history()
      "cash" -> Cash.get_history()
      :cash -> Cash.get_history()
    end
  end

  def delete(type, id) do
    data = get(type, id)

    case type do
      "trade" -> Trade.delete_trade(data)
      "cash" -> Cash.delete_txn(data)
    end
  end

  def get(type, id) do
    case type do
      :trade -> Trade.get(id)
      "trade" -> Trade.get(id)
      :cash -> Cash.get(id)
      "cash" -> Cash.get(id)
    end
  end

  def get_snapshot(range \\ "1w") do
    PortfolioSnapshot.snapshot(range)
    |> Stream.map(fn snp -> {snp.snapshot_date, snp} end)
    |> Stream.reject(fn {date, _val} -> DateUtils.market_holiday?(date) end)
    |> Enum.reduce({[], [], [], []}, fn {date, snapshot},
                                        {date_acc, tot_val_acc, book_pl, notional_pl} ->
      {[date | date_acc], [snapshot.total_portfolio_value | tot_val_acc],
       [snapshot.book_pl | book_pl], [snapshot.notional_pl | notional_pl]}
    end)
  end

  def get_holdings() do
    %{holdings: holdings, avg_buy_price: buy_price} =
      BalanceAndHolding.fetch_last_balance_holding()
      |> Map.from_struct()

    holdings
    |> Map.keys()
    |> Enum.filter(fn key -> holdings[key] !== 0 end)
    |> Enum.map(fn key ->
      %{
        instrument: InstrumentsCache.get_instrument(key),
        quantity: holdings[key],
        avg_buy_price: buy_price[key]
      }
    end)
    |> Enum.reduce([], fn key, acc -> [key | acc] end)
  end

  def reset_portfolio_data() do
    Trade.clear_history()
    Cash.clear_history()
    PortfolioSnapshot.clear_history()
    PortfolioSnapshot.calculate_snapshot_all()
  end

  def recompute_snapshots() do
    PortfolioSnapshot.clear_history()
    PortfolioSnapshot.calculate_snapshot_all()
  end

  def logout_cleanup(user_id) do
    cleanup =
      Task.async(fn ->
        Repo.put_user_id(user_id)
        BalanceAndHolding.clear()
      end)

    Task.await(cleanup)
  end
end
