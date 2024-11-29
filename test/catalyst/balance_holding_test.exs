defmodule Catalyst.BalanceHoldingTest do
  alias Catalyst.Portfolio
  alias Catalyst.PortfolioUtil
  alias Catalyst.PortfolioData.Cash
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.PortfolioData.Trade
  alias Catalyst.Analytics.State
  alias Catalyst.Analytics.BalanceAndHolding
  alias Catalyst.AccountsFixtures
  use Catalyst.DataCase
  import Catalyst.CashFixtures
  import PortfolioUtil

  describe "Balance and holding calculations are correct" do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.put_user_id(user.id)
      Repo.insert(get_instrumentA())
      Repo.insert(get_instrumentB())
      InstrumentsCache.insert(get_instrumentA())
      InstrumentsCache.insert(get_instrumentB())
      Portfolio.recompute_snapshots()
      :ok
    end

    test "exception on date before origin" do
      assert_raise(ArgumentError, fn -> BalanceAndHolding.calculate(~D[2023-01-01]) end)
    end

    test "no trades result in empty state" do
      ans = %State{} = BalanceAndHolding.calculate(~D[2024-01-05])
      assert ans.holdings == %{}
      assert ans.balance == %{}
      assert ans.cash == Decimal.new(0)
    end

    test "buy only for a single instrument" do
      trade_A = trade_data()
      trade_B = %{trade_A | avg_trade_price: Decimal.new(1200)}
      wait(Trade.create_trade(trade_A))
      wait(Trade.create_trade(trade_B))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.holdings == %{"1000" => 2000}
      assert ans.balance == %{"1000" => Decimal.new(-2_200_000)}
    end

    test "only sell for single instrument" do
      trade_A = %{trade_data() | type: :sell}
      wait(Trade.create_trade(trade_A))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.holdings == %{"1000" => -1000}
      assert ans.balance == %{"1000" => Decimal.new(1_000_000)}
    end

    test "buy and sell for single instrument" do
      trade_A = trade_data()

      trade_B =
        trade_data()
        |> Map.put(:type, :sell)
        |> Map.put(:quantity, 500)
        |> Map.put(:avg_trade_price, Decimal.new(1200))

      wait(Trade.create_trade(trade_A))
      wait(Trade.create_trade(trade_B))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.holdings == %{"1000" => 500}
      assert ans.balance == %{"1000" => Decimal.new(-400_000)}
    end

    test "net zero case " do
      trade_A = trade_data()
      trade_B = trade_A |> Map.put(:avg_trade_price, Decimal.new(1200)) |> Map.put(:type, :sell)

      wait(Trade.create_trade(trade_A))
      wait(Trade.create_trade(trade_B))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.holdings == %{"1000" => 0}
      assert ans.balance == %{"1000" => Decimal.new(200_000)}
    end

    test "buy and sell of multiple instruments" do
      trade_A = trade_data()
      trade_B = %{trade_data() | instrument_id: get_instrumentB().instrument_id}

      trade_C =
        trade_data()
        |> Map.put(:type, :sell)
        |> Map.put(:quantity, 500)
        |> Map.put(:avg_trade_price, Decimal.new(1200))

      wait(Trade.create_trade(trade_A))
      wait(Trade.create_trade(trade_B))
      wait(Trade.create_trade(trade_C))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.holdings == %{"1000" => 500, "1001" => 1000}
      assert ans.balance == %{"1000" => Decimal.new(-400_000), "1001" => Decimal.new(-1_000_000)}
    end
  end

  describe "cash aggregation for days" do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.put_user_id(user.id)
      BalanceAndHolding.calculate(Timex.today())
      :ok
    end

    test "no cash transactions" do
      ans = %State{} = BalanceAndHolding.calculate(test_date())
      assert ans.cash == Decimal.new(0)
    end

    test "only deposit transactions" do
      deposit_A = deposit_cash(1000)
      wait(Cash.create_txn(deposit_A))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(1000)
      deposit_B = deposit_cash(1500)
      wait(Cash.create_txn(deposit_B))
      updated = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert updated.cash == Decimal.new(2500)
    end

    test "only withdraw transactions" do
      withdraw_A = withdraw_cash(1000)
      wait(Cash.create_txn(withdraw_A))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(-1000)
      deposit_B = withdraw_cash(1500)
      wait(Cash.create_txn(deposit_B))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(-2500)
    end

    test "net zero transactions" do
      deposit = deposit_cash(1000)
      withdraw = withdraw_cash(1000)
      wait(Cash.create_txn(deposit))
      wait(Cash.create_txn(withdraw))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(0)
    end

    test "net greater than zero" do
      deposit = deposit_cash(1500)
      withdraw = withdraw_cash(1000)
      wait(Cash.create_txn(deposit))
      wait(Cash.create_txn(withdraw))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(500)
    end

    test "net lesser than zero" do
      deposit = deposit_cash(1000)
      withdraw = withdraw_cash(1500)
      wait(Cash.create_txn(deposit))
      wait(Cash.create_txn(withdraw))
      ans = %State{} = BalanceAndHolding.fetch_from_cache(test_date())
      assert ans.cash == Decimal.new(-500)
    end
  end

  defp test_date() do
    ~D[2024-09-05]
  end
end
