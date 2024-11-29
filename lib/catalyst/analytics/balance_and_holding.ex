defmodule Catalyst.Analytics.State do
  defstruct balance: %{},
            holdings: %{},
            buy_quantity: %{},
            avg_buy_price: %{},
            cash: Decimal.new(0)
end

# TODO optimize by ets caching / agent
# take into consideration create/update of a trade
defmodule Catalyst.Analytics.BalanceAndHolding do
  alias Catalyst.Repo
  alias Catalyst.Analytics.BalanceHoldingsCache
  alias Catalyst.PortfolioData.Cash
  alias Catalyst.DateTime.DateUtils
  alias Catalyst.Analytics.State
  alias Catalyst.PortfolioData.Trade

  defguardp valid_event(event) when is_struct(event, Cash) or is_struct(event, Trade)

  def fetch_from_cache(date) when is_struct(date, Date) do
    key = {date, Repo.get_user_id()}

    case BalanceHoldingsCache.get(key) do
      [{_key, val}] -> val
    end
  end

  def fetch_last_balance_holding(date \\ Timex.today()) do
    key = {date, Repo.get_user_id()}

    if(DateUtils.date_after_origin?(date)) do
      empty_state()
    else
      case BalanceHoldingsCache.get(key) do
        [{_key, val}] ->
          if(empty_state?(val)) do
            fetch_last_balance_holding(Timex.shift(date, days: -1))
          else
            val
          end

        [] ->
          fetch_last_balance_holding(Timex.shift(date, days: -1))
      end
    end
  end

  def clear() do
    BalanceHoldingsCache.clear(Repo.get_user_id())
  end

  def calculate(date, events) when is_struct(date, Date) do
    DateUtils.date_after_origin!(date)

    Date.range(DateUtils.origin_date(), date)
    |> Enum.each(fn date ->
      BalanceHoldingsCache.put({date, Repo.get_user_id()}, empty_state())
    end)

    events
    |> Enum.each(fn event -> update(:create, event, date) end)

    fetch_from_cache(date)
  end

  def calculate(date) when is_struct(date, Date) do
    DateUtils.date_after_origin!(date)
    cash = Cash.get_history() |> Enum.to_list()
    trades = Trade.get_history() |> Enum.to_list()
    calc_rec(date, empty_state(), trades ++ cash)
  end

  def update(:create, event, end_date)
      when valid_event(event) and is_struct(end_date, Date) do
    Date.range(event.transaction_date, end_date)
    |> Enum.map(fn date ->
      case BalanceHoldingsCache.get({date, event.user_id}) do
        [{key, val}] -> {key, merge(event, val)}
      end
    end)
    |> Enum.each(fn {key, state} -> BalanceHoldingsCache.put(key, state) end)
  end

  def update(:delete, event, end_date)
      when valid_event(event) and is_struct(end_date, Date) do
    reversed = reverse(event)

    Date.range(reversed.transaction_date, end_date)
    |> Enum.map(fn date ->
      case BalanceHoldingsCache.get({date, event.user_id}) do
        [{key, val}] -> {key, rev_merge(reversed, val)}
      end
    end)
    |> Enum.each(fn {key, state} -> BalanceHoldingsCache.put(key, state) end)
  end

  def update(:update, {new_txn, old_txn}, end_date)
      when valid_event(old_txn) and valid_event(new_txn) and is_struct(end_date, Date) do
    update(:delete, old_txn, end_date)
    update(:create, new_txn, end_date)
  end

  defp calc_rec(~D[2024-01-01], acc_state, events) when is_struct(acc_state, State) do
    key = {~D[2024-01-01], Repo.get_user_id()}

    case BalanceHoldingsCache.get(key) do
      [{_key, val}] ->
        val

      [] ->
        res = merge(acc_state, state_for(DateUtils.origin_date(), events))
        BalanceHoldingsCache.put(key, res)
        res
    end
  end

  defp calc_rec(date, acc_state, events)
       when is_struct(date, Date) and is_struct(acc_state, State) do
    key = {date, Repo.get_user_id()}

    updated_state =
      case BalanceHoldingsCache.get(key) do
        [{_key, val}] ->
          val

        [] ->
          res = merge(acc_state, state_for(date, events))
          BalanceHoldingsCache.put(key, res)
          res
      end

    calc_rec(Timex.shift(date, days: -1), updated_state, events)
  end

  defp state_for(date, events) when is_struct(date, Date) do
    events
    |> Enum.filter(&(&1.transaction_date == date))
    |> Enum.reduce(empty_state(), &merge(&1, &2))
  end

  defp merge(elem, acc) when is_struct(elem, Trade) and is_struct(acc, State) do
    new_avg_buy_price = update_avg_buy_price(elem, acc)
    new_bal = update_balance(elem, acc)
    new_holdings = update_holdings(elem, acc)
    new_buy_quantity = update_buy_quantity(elem, acc)

    %State{
      balance: new_bal,
      holdings: new_holdings,
      buy_quantity: new_buy_quantity,
      avg_buy_price: new_avg_buy_price,
      cash: acc.cash
    }
  end

  defp merge(elem, acc) when is_struct(elem, Cash) and is_struct(acc, State) do
    new_cash =
      case elem.type do
        :deposit -> Decimal.add(acc.cash, elem.amount)
        :withdraw -> Decimal.negate(elem.amount) |> Decimal.add(acc.cash)
      end

    %State{acc | cash: new_cash}
  end

  defp merge(l, r) when is_struct(l, State) and is_struct(r, State) do
    new_avg_buy_price = update_avg_buy_price(l, r)
    new_holding = Map.merge(l.holdings, r.holdings, fn _k, q1, q2 -> q1 + q2 end)
    new_balance = Map.merge(l.balance, r.balance, fn _k, v1, v2 -> Decimal.add(v1, v2) end)
    new_buy_quantity = Map.merge(l.buy_quantity, r.buy_quantity, fn _k, q1, q2 -> q1 + q2 end)
    new_cash = Decimal.add(l.cash, r.cash)

    %State{
      balance: new_balance,
      holdings: new_holding,
      avg_buy_price: new_avg_buy_price,
      buy_quantity: new_buy_quantity,
      cash: new_cash
    }
  end

  # dont update avg buy price/ quantity
  defp rev_merge(elem, acc) when is_struct(elem, Trade) and is_struct(acc, State) do
    %State{
      balance: update_balance(elem, acc),
      holdings: update_holdings(elem, acc),
      buy_quantity: acc.buy_quantity,
      avg_buy_price: acc.avg_buy_price,
      cash: acc.cash
    }
  end

  defp rev_merge(elem, acc) when is_struct(elem, Cash) and is_struct(acc, State) do
    merge(elem, acc)
  end

  defp update_balance(trade, state) when is_struct(trade, Trade) and is_struct(state, State) do
    Map.update(
      state.balance,
      trade.instrument_id,
      gross_value(trade),
      &Decimal.add(&1, gross_value(trade))
    )
  end

  defp update_avg_buy_price(trade, state)
       when is_struct(trade, Trade) and is_struct(state, State) do
    case trade.type do
      :sell ->
        state.avg_buy_price

      :buy ->
        Map.update(state.avg_buy_price, trade.instrument_id, avg_buy_price(trade), fn _v ->
          update_avg(trade, state)
        end)
    end
  end

  defp update_avg_buy_price(l, r) when is_struct(l, State) and is_struct(r, State) do
    Map.merge(l.avg_buy_price, r.avg_buy_price, fn k, avg1, avg2 ->
      weighted_avg(Map.get(l.buy_quantity, k), avg1, Map.get(r.buy_quantity, k), avg2)
    end)
  end

  defp weighted_avg(q1, avg1, q2, avg2) do
    tot = q1 + q2

    gross1 = Decimal.mult(q1, avg1)
    gross2 = Decimal.mult(q2, avg2)

    case tot do
      0 -> Decimal.new(0)
      total -> Decimal.add(gross1, gross2) |> Decimal.div(total)
    end
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

  defp update_buy_quantity(trade, state)
       when is_struct(trade, Trade) and is_struct(state, State) do
    case trade.type do
      :buy ->
        Map.update(
          state.buy_quantity,
          trade.instrument_id,
          trade.quantity,
          &(&1 + trade.quantity)
        )

      :sell ->
        state.buy_quantity
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

  defp avg_buy_price(trade) when is_struct(trade, Trade) do
    case trade.type do
      :buy -> trade.avg_trade_price
      :sell -> Decimal.new(0)
    end
  end

  defp update_avg(trade, state) when is_struct(trade, Trade) and is_struct(state, State) do
    holding_quantity = Map.get(state.buy_quantity, trade.instrument_id, 0)
    holding_buy_price = Map.get(state.avg_buy_price, trade.instrument_id, 0)

    case trade.type do
      :buy ->
        weighted_avg(trade.quantity, trade.avg_trade_price, holding_quantity, holding_buy_price)

      :sell ->
        holding_buy_price
    end
  end

  defp reverse(cash) when is_struct(cash, Cash) do
    case cash.type do
      :deposit -> %Cash{cash | type: :withdraw}
      :withdraw -> %Cash{cash | type: :deposit}
    end
  end

  defp reverse(trade) when is_struct(trade, Trade) do
    case trade.type do
      :buy -> %Trade{trade | type: :sell}
      :sell -> %Trade{trade | type: :buy}
    end
  end

  defp empty_state() do
    %State{balance: %{}, holdings: %{}, avg_buy_price: %{}, buy_quantity: %{}}
  end

  defp empty_state?(state) when is_struct(state, State) do
    map_empty?(state.avg_buy_price) &&
      map_empty?(state.buy_quantity) &&
      map_empty?(state.holdings) &&
      map_empty?(state.balance)
  end

  defp map_empty?(map) when is_map(map) do
    map_size(map) == 0
  end
end
