defmodule Catalyst.PortfolioData.PortfolioSnapshot do
  alias Catalyst.PortfolioData.Cash
  alias Catalyst.PortfolioData.PortfolioSnapshot
  alias Catalyst.MarketData.BhavCopy
  alias Catalyst.Analytics.State
  alias Catalyst.Analytics.BalanceAndHolding
  alias Catalyst.DateTime.DateUtils
  alias Catalyst.Repo
  use Ecto.Schema
  import Ecto.Query

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

  def calculate_snapshot(date) when is_struct(date, Date) do
    case query_by_date(date) do
      [] ->
        result = %{evaluate_snapshot(date) | user_id: Repo.get_user_id()}
        {:ok, rec} = Repo.insert(result)
        rec

      [rec] ->
        rec
    end
  end

  def calculate_snapshot_all() do
    Date.range(DateUtils.origin_date(), Timex.today())
    |> Enum.each(&calculate_snapshot/1)

    :ok
  end

  defp evaluate_snapshot(date) when is_struct(date, Date) do
    BalanceAndHolding.calculate(date)
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

    cash = Cash.for(date)

    total_portfolio_value =
      notional_asset_value
      |> Decimal.add(cash)
      |> Decimal.add(pl_balance)

    notional_pl = notional_pl(state, date)

    net_pl = Decimal.add(notional_pl, pl_balance)

    %PortfolioSnapshot{
      snapshot_date: date,
      assets_value: notional_asset_value,
      cash: cash,
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
          delta = Decimal.sub(BhavCopy.cp_for(instr, date), Map.get(state.avg_buy_price, instr))
          Map.put(acc, instr, Decimal.mult(delta, quantity))
      end

    Map.to_list(notional_pl)
    |> Enum.reduce(Decimal.new(0), fn {_k, v}, acc -> Decimal.add(v, acc) end)
  end

  def query_by_date(date) when is_struct(date, Date) do
    query = from rec in PortfolioSnapshot, where: [snapshot_date: ^date]
    Repo.all(query)
  end
end
