defmodule Catalyst.DateTime.MarketHoliday do
  alias Catalyst.Repo
  alias Catalyst.DateTime.MarketHoliday
  use Ecto.Schema
  use GenServer
  require Logger

  @market_holidays __MODULE__

  schema "market_holidays" do
    field :holiday_date, :date
    field :description, :string
  end

  def start_link(_any) do
    GenServer.start_link(@market_holidays, :starting, name: @market_holidays)
  end

  @impl true
  def init(_any) do
    :ets.new(:market_holidays, [:set, :public, :named_table])

    Repo.all(MarketHoliday, skip_user_id: true)
    |> Enum.map(&holiday_tuple/1)
    |> Enum.each(&insert_in_ets/1)

    {:ok, :initialized}
  end

  def is_holiday?(date) when is_struct(date, Date) do
    :ets.member(:market_holidays, date)
  end

  def mark_weekends_as_holidays(year) do
    Timex.Interval.new(
      from: Timex.beginning_of_year(year),
      until: Timex.end_of_year(year),
      step: [days: 1]
    )
    |> Enum.to_list()
    |> Enum.map(&Timex.to_date/1)
    |> Enum.filter(fn day -> Timex.weekday(day) in [6, 7] end)
    |> Enum.map(fn day -> %MarketHoliday{holiday_date: day, description: "weekend"} end)
    |> Enum.each(&handle_insert/1)
  end

  def ingest_holidays(file) do
    file
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&parse_line/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.each(&handle_insert/1)

    {:ok, :holidays_loaded}
  end

  defp parse_line(line) do
    with [date, description] <- String.split(line, ",", parts: 2),
         {:ok, datetime} <- Timex.parse(String.trim(date), "{D}-{0M}-{YYYY}"),
         date <- Timex.to_date(datetime) do
      %MarketHoliday{holiday_date: date, description: String.trim(description)}
    else
      {:error, reason} ->
        Logger.error(reason)
        raise reason

      error ->
        Logger.error(error)
        raise "unexpected error"
    end
  end

  defp handle_insert(holiday) when is_struct(holiday, MarketHoliday) do
    case(Repo.insert(holiday, skip_user_id: true)) do
      {:ok, holiday} ->
        holiday |> holiday_tuple() |> insert_in_ets()

      {:error, error} ->
        Logger.error(error)
        :error
    end
  end

  defp holiday_tuple(holiday) when is_struct(holiday, MarketHoliday) do
    {holiday.holiday_date, holiday.description}
  end

  defp insert_in_ets(tuple) do
    :ets.insert(:market_holidays, tuple)
  end
end
