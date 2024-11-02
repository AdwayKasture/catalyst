defmodule Catalyst.Analytics.BalanceHoldingsCache do
  use GenServer

  @balance_holdings_memo __MODULE__

  def start_link(_state) do
    GenServer.start_link(@balance_holdings_memo, :starting, name: @balance_holdings_memo)
  end

  @impl true
  def init(_init_arg) do
    :ets.new(:balance_holding_memo, [:set, :public, :named_table])
    {:ok, :initialized}
  end

  def put({_date, _user_id} = k, val) do
    GenServer.cast(@balance_holdings_memo, {:put, k, val})
  end

  def get({_date, _user_id} = k) do
    GenServer.call(@balance_holdings_memo, {:get, k})
  end

  def clear(user_id) do
    :ets.match_delete(:balance_holding_memo, {{:_, user_id}, :_})
    :ok
  end

  @impl true
  def handle_call({:get, k}, _from, state) do
    {:reply, :ets.lookup(:balance_holding_memo, k), state}
  end

  @impl true
  def handle_cast({:put, k, v}, state) do
    :ets.insert(:balance_holding_memo, {k, v})
    {:noreply, state}
  end
end
