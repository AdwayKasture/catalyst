defmodule Catalyst.MarketData.InstrumentsCache do
  use GenServer
  alias Catalyst.Repo
  alias Catalyst.MarketData.Instrument

  @instruments_cache __MODULE__

  def start_link(_any) do
    GenServer.start_link(@instruments_cache, :starting, name: @instruments_cache)
  end

  def insert(instrument) when is_struct(instrument, Instrument) do
    GenServer.cast(@instruments_cache, {:insert, instrument})
  end

  def instrument?(instrument_id) do
    GenServer.call(@instruments_cache, {:instrument?, instrument_id})
  end

  def clear_all() do
    GenServer.cast(@instruments_cache, {:reset})
  end

  @impl true
  def init(_state) do
    :ets.new(:instruments, [:set, :public, :named_table])

    Repo.all(Instrument, skip_user_id: true)
    |> Enum.each(fn instr -> :ets.insert(:instruments, {instr.instrument_id, instr}) end)

    {:ok, :initailzed}
  end

  @impl true
  def handle_cast({:insert, instrument}, _state) do
    :ets.insert(:instruments, {instrument.instrument_id, instrument})
    {:noreply, :inserted}
  end

  @impl true
  def handle_cast({:reset}, _state) do
    :ets.delete_all_objects(:instruments)
    {:noreply, :reset}
  end

  @impl true
  def handle_call({:instrument?, instrument_id}, _from, state) do
    {:reply, :ets.member(:instruments, instrument_id), state}
  end

  def fetch_all() do
    :ets.match(:instruments, :"$1")
    |> Stream.map(fn [{_id, instrument}] -> instrument end)
  end

  def autocomplete_list(query) do
    if String.length(query) >= 3 do
      regex_query = ~r/#{query}/i

      fetch_all()
      |> Stream.filter(fn x ->
        Regex.match?(regex_query, x.instrument_name) || Regex.match?(regex_query, x.ticker) ||
          Regex.match?(regex_query, x.isin)
      end)
      |> Enum.take(5)
    else
      []
    end
  end

  def get_instrument(instrument_id) do
    hd(:ets.lookup(:instruments, instrument_id))
    |> elem(1)
  end
end
