defmodule Catalyst.CashFixtures do
  alias Catalyst.MarketData.Instrument

  def txn_data() do
    %{
      type: :deposit,
      transaction_date: ~D[2024-09-05],
      amount: Decimal.new(1000),
      fees: Decimal.new(0)
    }
  end

  def deposit_cash(amt) do
    %{
      type: :deposit,
      transaction_date: ~D[2024-09-05],
      amount: Decimal.new(amt),
      fees: Decimal.new(0)
    }
  end

  def withdraw_cash(amt) do
    %{
      type: :withdraw,
      transaction_date: ~D[2024-09-05],
      amount: Decimal.new(amt),
      fees: Decimal.new(0)
    }
  end

  def trade_data() do
    %{
      type: :buy,
      transaction_date: ~D[2024-09-05],
      quantity: 1000,
      avg_trade_price: Decimal.new(1000),
      fees: Decimal.new(0),
      instrument_id: "1000"
    }
  end

  def get_instrumentA() do
    %Instrument{
      ticker: "1000",
      isin: "1000",
      instrument_type: "something",
      instrument_name: "unicorp",
      segment: "A",
      scrip_group: "A",
      instrument_id: "1000"
    }
  end

  def get_instrumentB() do
    %Instrument{
      ticker: "1001",
      isin: "1001",
      instrument_type: "something",
      instrument_name: "anton",
      segment: "A",
      scrip_group: "A",
      instrument_id: "1001"
    }
  end
end
