defmodule Catalyst.Workers.DailyWorker do
  alias Catalyst.Market
  use Oban.Worker, queue: :default

  @impl true
  def perform(_job) do
    Market.fetch_market_data(Timex.today())
  end
end
