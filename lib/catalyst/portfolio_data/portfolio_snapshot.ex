# defmodule Catalyst.PortfolioData.PortfolioSnapshot do
#   alias Catalyst.PortfolioData.Cash
#   alias Catalyst.PortfolioData.PortfolioSnapshot
#   alias Catalyst.MarketData.BhavCopy
#   alias Catalyst.Analytics.State
#   alias Catalyst.Analytics.BalanceAndHolding
#   alias Catalyst.DateTime.DateUtils
#   alias Catalyst.Repo
#   use Ecto.Schema

#   schema "daily_snapshots" do
#     field :snapshot_date, :date

#     # notional value of holdings for the day
#     field :assets_value, :decimal

#     # cash present for the day
#     field :cash, :decimal

#     # notional value of holdings  + cash + balance for day
#     field :total_portfolio_value, :decimal

#     # all sell - buy till the day
#     field :book_pl, :decimal

#     # notional value of holdings - buy price
#     field :notional_pl, :decimal

#     # book + notional
#     field :net_pl, :decimal

#     belongs_to :user, Catalyst.Accounts.User

#     timestamps(type: :utc_datetime)
#   end

#   def calculate_snapshot(date) when is_struct(date,Date) do

#     case Repo.get(date) do
#       nil -> evaluate_snapshot(date)
#       rec -> rec
#     end
#   end

#   def calculate_snapshot_all() do
#     Date.range(DateUtils.origin_date(),Timex.today())
#     |>Enum.each(&calculate_snapshot/1)

#     :ok
#   end

#   defp evaluate_snapshot(date) when is_struct(date,Date) do
#     BalanceAndHolding.calculate(date)
#   end

#   # defp reduce(state,date) when is_struct(state,State) and is_struct(date,Date) do
#   #   notional_asset_value = state.holdings
#   #   |> enrich_asset_value(date)
#   #   |> Map.to_list()
#   #   |>Enum.reduce(Decimal.new(0),fn {_k,v}, acc -> Decimal.add(v,acc) end)

#   #   %PortfolioSnapshot{snapshot_date: date,assets_value: notional_asset_value,cash: Cash.for()}

#   # end

#   def enrich_asset_value(holdings,date) when is_non_struct_map(holdings) and is_struct(date,Date) do
#     for {instr,quantity} <- holdings, reduce: %{} do
#       acc -> Map.put(acc,instr,Decimal.new(quantity)|>Decimal.mult(BhavCopy.cp_for(instr,date)))
#     end
#   end

# end
