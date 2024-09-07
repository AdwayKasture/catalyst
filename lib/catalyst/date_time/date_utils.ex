defmodule Catalyst.DateTime.DateUtils do
  def market_holiday?(date) when is_struct(date, Date) do
    false
  end
end
