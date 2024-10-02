defmodule Catalyst.Analytics.State do
  defstruct balance: %{}, holdings: %{}
end

defmodule Catalyst.Analytics.BalanceAndHolding do
  alias Catalyst.DateTime.DateUtils
  alias Catalyst.Analytics.State
  alias Catalyst.PortfolioData.Trade

  def calculate(date) when is_struct(date, Date) do
    DateUtils.date_after_origin!(date)
    trades = Trade.get_history() |> Enum.to_list()
    calc_rec(date, empty_state(), trades)
  end

  defp calc_rec(~D[2024-01-01], acc_state, trades) when is_struct(acc_state, State) do
    merge(acc_state, state_for(DateUtils.origin_date(), trades))
  end

  defp calc_rec(date, acc_state, trades)
       when is_struct(date, Date) and is_struct(acc_state, State) do
    updated_state = merge(acc_state, state_for(date, trades))
    calc_rec(Timex.shift(date, days: -1), updated_state, trades)
  end

  defp state_for(date, trades) when is_list(trades) and is_struct(date, Date) do
    trades
    |> Enum.filter(&(&1.transaction_date == date))
    |> Enum.reduce(empty_state(), &merge(&1, &2))
  end

  defp merge(elem, acc) when is_struct(elem, Trade) and is_struct(acc, State) do
    new_bal = update_balance(elem, acc)
    new_holdings = update_holdings(elem, acc)
    %State{balance: new_bal, holdings: new_holdings}
  end

  defp merge(l, r) when is_struct(l, State) and is_struct(r, State) do
    new_holding = Map.merge(l.holdings, r.holdings, fn _k, q1, q2 -> q1 + q2 end)
    new_balance = Map.merge(l.balance, r.balance, fn _k, v1, v2 -> Decimal.add(v1, v2) end)
    %State{balance: new_balance, holdings: new_holding}
  end

  defp update_balance(trade, state) when is_struct(trade, Trade) and is_struct(state, State) do
    Map.update(
      state.balance,
      trade.instrument_id,
      gross_value(trade),
      &Decimal.add(&1, gross_value(trade))
    )
  end

  defp update_holdings(trade, state) when is_struct(trade, Trade) and is_struct(state, State) do
    case trade.type do
      :buy ->
        Map.update(state.holdings, trade.instrument_id, trade.quantity, &(&1 + trade.quantity))

      :sell ->
        Map.update(
          state.holdings,
          trade.instrument_id,
          -1 * trade.quantity,
          &(&1 - trade.quantity)
        )
    end
  end

  defp gross_value(trade) when is_struct(trade, Trade) do
    case trade.type do
      :buy ->
        Decimal.new(trade.quantity) |> Decimal.mult(trade.avg_trade_price) |> Decimal.negate()

      :sell ->
        Decimal.new(trade.quantity) |> Decimal.mult(trade.avg_trade_price)
    end
  end

  defp empty_state() do
    %State{balance: %{}, holdings: %{}}
  end
end
