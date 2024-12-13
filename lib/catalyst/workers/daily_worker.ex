defmodule Catalyst.Workers.DailyWorker do
  alias Catalyst.Market
  @max_attempts 1

  use Oban.Worker, queue: :default, max_attempts: @max_attempts
  

  @impl true
  def perform(_job) do
    Market.fetch_market_data(Timex.today())
  end
end
