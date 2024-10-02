defmodule Catalyst.DateTime.DateUtils do
  @origin_date ~D[2024-01-01]

  def origin_date() do
    @origin_date
  end

  def market_holiday?(date) when is_struct(date, Date) do
    false
  end

  def date_after_origin!(date) when is_struct(date, Date) do
    unless Timex.after?(date, origin_date()) do
      raise ArgumentError, "Date cannot be earlier than 2024-01-01"
    end
  end
end
