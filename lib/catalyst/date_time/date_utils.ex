defmodule Catalyst.DateTime.DateUtils do
  alias Catalyst.DateTime.MarketHoliday
  @origin_date ~D[2024-01-01]

  def origin_date() do
    @origin_date
  end

  def market_holiday?(date) when is_struct(date, Date) do
    MarketHoliday.is_holiday?(date)
  end

  def date_after_origin!(date) when is_struct(date, Date) do
    if Timex.before?(date, origin_date()) do
      raise ArgumentError, "Date cannot be earlier than 2024-01-01"
    end
  end
end
