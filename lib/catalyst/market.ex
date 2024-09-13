defmodule Catalyst.Market do
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.MarketData.BhavCopy
  alias Catalyst.DateTime.DateUtils

  def fetch_market_data(today) when is_struct(today, Date) do
    if DateUtils.market_holiday?(today) do
      {:ok, :market_holiday}
    else
      BhavCopy.store_market_history_for_date(today)
    end
  end

  def list_instruments() do
    InstrumentsCache.fetch_all()
  end

  def autocomplete_list(query) do
    InstrumentsCache.autocomplete_list(query)
  end

  def instrument(instrument_id) do
    InstrumentsCache.get_instrument(instrument_id)
  end
end
