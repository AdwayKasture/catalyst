defmodule Catalyst.DateTime.MarketHoliday do
  alias Catalyst.Repo
  alias Catalyst.DateTime.MarketHoliday
  use Ecto.Schema

  schema "market_holidays" do
    field :holiday_date, :date
    field :description, :string
  end

  def ingest_holidays(file) do
    IO.inspect(file)

    file
    |> File.stream!()
    |> Stream.map(&String.trim/1)
    |> Stream.reject(&(&1 == ""))
    |> Stream.map(&parse_line/1)
    |> Stream.reject(&is_nil/1)
    |> Enum.each(fn holiday -> Repo.insert(holiday, skip_user_id: true) end)

    {:ok, :holidays_loaded}
  end

  defp parse_line(line) do
    with [date, description] <- String.split(line, ",", parts: 2),
         {:ok, datetime} <- Timex.parse(String.trim(date), "{D}-{0M}-{YYYY}"),
         date <- Timex.to_date(datetime) do
      %MarketHoliday{holiday_date: date, description: String.trim(description)}
    else
      {:error, reason} ->
        # TODO log error
        IO.inspect(reason)
        raise reason

      error ->
        # TODO log error
        IO.inspect(error)
        raise "unexpected error"
    end
  end
end
