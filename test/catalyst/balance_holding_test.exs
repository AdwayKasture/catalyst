defmodule Catalyst.BalanceHoldingTest do
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.PortfolioData.Trade
  alias Catalyst.Analytics.State
  alias Catalyst.Analytics.BalanceAndHolding
  alias Catalyst.AccountsFixtures
  use Catalyst.DataCase
  import Catalyst.CashFixtures

  describe "Balance and holding calculations are correct" do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.put_user_id(user.id)
      Repo.insert(get_instrumentA())
      Repo.insert(get_instrumentB())
      InstrumentsCache.insert(get_instrumentA())
      InstrumentsCache.insert(get_instrumentB())
      :ok
    end

    test "exception on date before origin" do
      assert_raise(ArgumentError, fn -> BalanceAndHolding.calculate(~D[2023-01-01]) end)
    end

    test "no trades result in empty state" do
      ans = %State{} = BalanceAndHolding.calculate(~D[2024-01-05])
      assert ans.holdings == %{}
      assert ans.balance == %{}
    end

    test "buy only for a single instrument" do
      trade_A = trade_data()
      trade_B = %{trade_A | avg_trade_price: Decimal.new(1200)}
      Trade.create_trade(trade_A)
      Trade.create_trade(trade_B)
      ans = %State{} = BalanceAndHolding.calculate(test_date())
      assert ans.holdings == %{"1000" => 2000}
      assert ans.balance == %{"1000" => Decimal.new(-2_200_000)}
    end

    test "only sell for single instrument" do
      trade_A = %{trade_data() | type: :sell}
      Trade.create_trade(trade_A)
      ans = %State{} = BalanceAndHolding.calculate(test_date())
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

      Trade.create_trade(trade_A)
      Trade.create_trade(trade_B)
      ans = %State{} = BalanceAndHolding.calculate(test_date())
      assert ans.holdings == %{"1000" => 500}
      assert ans.balance == %{"1000" => Decimal.new(-400_000)}
    end

    test "net zero case " do
      trade_A = trade_data()
      trade_B = trade_A |> Map.put(:avg_trade_price, Decimal.new(1200)) |> Map.put(:type, :sell)

      Trade.create_trade(trade_A)
      Trade.create_trade(trade_B)
      ans = %State{} = BalanceAndHolding.calculate(test_date())
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

      Trade.create_trade(trade_A)
      Trade.create_trade(trade_B)
      Trade.create_trade(trade_C)
      ans = %State{} = BalanceAndHolding.calculate(test_date())
      assert ans.holdings == %{"1000" => 500, "1001" => 1000}
      assert ans.balance == %{"1000" => Decimal.new(-400_000), "1001" => Decimal.new(-1_000_000)}
    end
  end

  defp test_date() do
    ~D[2024-09-05]
  end
end
