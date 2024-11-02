defmodule Catalyst.PortfolioData.PortfolioSnapshot do
  alias Catalyst.Portfolio
  alias Catalyst.PortfolioData.PortfolioSnapshot
  alias Catalyst.MarketData.BhavCopy
  alias Catalyst.Analytics.State
  alias Catalyst.Analytics.BalanceAndHolding
  alias Catalyst.DateTime.DateUtils
  alias Catalyst.Repo
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  schema "daily_snapshots" do
    field :snapshot_date, :date

    # notional value of holdings for the day
    field :assets_value, :decimal

    # cash present for the day
    field :cash, :decimal

    # notional value of holdings  + cash + balance for day
    field :total_portfolio_value, :decimal

    # all sell - buy till the day / balance_pl
    field :book_pl, :decimal

    # notional value of holdings - buy price
    field :notional_pl, :decimal

    # book + notional
    field :net_pl, :decimal

    belongs_to :user, Catalyst.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def calculate_snapshot_all() do
    trades = Portfolio.get_history(:trade) |> Enum.to_list()
    cash = Portfolio.get_history(:cash) |> Enum.to_list()

    calculate_snapshot(DateUtils.origin_date(), Timex.today(), trades ++ cash)
  end

  def update_snapshot_for(type, data, end_date) when is_struct(end_date, Date) do
    txn_date =
      case {type, data} do
        {:create, txn} -> txn.transaction_date
        {:delete, txn} -> txn.transaction_date
        {:update, {old, _new}} -> old.transaction_date
      end

    BalanceAndHolding.update(type, data, end_date)

    Date.range(txn_date, end_date)
    |> Enum.map(&get_pair/1)
    |> Enum.each(&handle_update/1)

    :ok
  end

  defp calculate_snapshot_for_day(date, events) when is_struct(date, Date) do
    result = %{evaluate_snapshot(date, events) | user_id: Repo.get_user_id()}
    {:ok, rec} = Repo.insert(result)
    rec
  end

  defp calculate_snapshot(start_date, end_date, events)
       when is_struct(start_date, Date) and is_struct(end_date, Date) do
    Date.range(start_date, end_date)
    |> Enum.reverse()
    |> Enum.each(&calculate_snapshot_for_day(&1, events))
  end

  defp evaluate_snapshot(date, events) when is_struct(date, Date) do
    BalanceAndHolding.calculate(date, events)
    |> reduce(date)
  end

  defp reduce(state, date) when is_struct(state, State) and is_struct(date, Date) do
    notional_asset_value =
      state.holdings
      |> enrich_asset_value(date)
      |> Map.to_list()
      |> Enum.reduce(Decimal.new(0), fn {_k, v}, acc -> Decimal.add(v, acc) end)

    pl_balance =
      state.balance
      |> Map.to_list()
      |> Enum.reduce(Decimal.new(0), fn {_k, v}, acc -> Decimal.add(v, acc) end)

    total_portfolio_value =
      notional_asset_value
      |> Decimal.add(state.cash)
      |> Decimal.add(pl_balance)

    notional_pl = notional_pl(state, date)

    net_pl = Decimal.add(notional_pl, pl_balance)

    %PortfolioSnapshot{
      snapshot_date: date,
      assets_value: notional_asset_value,
      cash: state.cash,
      total_portfolio_value: total_portfolio_value,
      book_pl: pl_balance,
      notional_pl: notional_pl,
      net_pl: net_pl
    }
  end

  def enrich_asset_value(holdings, date)
      when is_non_struct_map(holdings) and is_struct(date, Date) do
    for {instr, quantity} <- holdings, reduce: %{} do
      acc ->
        Map.put(acc, instr, Decimal.new(quantity) |> Decimal.mult(BhavCopy.cp_for(instr, date)))
    end
  end

  def notional_pl(state, date) when is_struct(state, State) and is_struct(date, Date) do
    notional_pl =
      for {instr, quantity} <- state.holdings, reduce: %{} do
        acc ->
          delta =
            Decimal.sub(
              BhavCopy.cp_for(instr, date),
              Map.get(state.avg_buy_price, instr, Decimal.new(0))
            )

          Map.put(acc, instr, Decimal.mult(delta, quantity))
      end

    Map.to_list(notional_pl)
    |> Enum.reduce(Decimal.new(0), fn {_k, v}, acc -> Decimal.add(v, acc) end)
  end

  def query_by_date(date) when is_struct(date, Date) do
    query = from rec in PortfolioSnapshot, where: [snapshot_date: ^date]
    Repo.all(query)
  end

  defp get_pair(date) when is_struct(date, Date) do
    case query_by_date(date) do
      [] ->
        {:insert, BalanceAndHolding.fetch_from_cache(date) |> reduce(date)}

      [old] when is_struct(old, PortfolioSnapshot) ->
        {:update, old, BalanceAndHolding.fetch_from_cache(date) |> reduce(date)}

      [h | _t] when is_struct(h, PortfolioSnapshot) ->
        raise "multiple snapshots for a #{h.snapshot_date} and #{h.user_id} found please check"
    end
  end

  defp handle_update(data) do
    case data do
      {:insert, val} -> Repo.insert!(%{val | user_id: Repo.get_user_id()})
      {:update, old, new} -> update_snapshot(old, to_map(new))
    end
  end

  defp update_snapshot(old, new)
       when is_struct(old, PortfolioSnapshot) and is_non_struct_map(new) do
    old
    |> cast(new, [
      :snapshot_date,
      :assets_value,
      :cash,
      :total_portfolio_value,
      :book_pl,
      :notional_pl,
      :net_pl
    ])
    |> Repo.update()
  end

  defp to_map(snapshot) when is_struct(snapshot, PortfolioSnapshot) do
    %{
      snapshot_date: snapshot.snapshot_date,
      assets_value: snapshot.assets_value,
      cash: snapshot.assets_value,
      total_portfolio_value: snapshot.total_portfolio_value,
      book_pl: snapshot.book_pl,
      notional_pl: snapshot.notional_pl,
      net_pl: snapshot.net_pl
    }
  end
end
