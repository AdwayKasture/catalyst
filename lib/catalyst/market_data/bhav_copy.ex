defmodule Catalyst.MarketData.BhavCopy do
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.MarketData.Instrument
  alias Catalyst.Repo
  alias Catalyst.MarketData.BhavCopy
  import Ecto.Query
  use Ecto.Schema

  @api_template "https://www.bseindia.com/download/BhavCopy/Equity/BhavCopy_BSE_CM_0_0_0_<%=date%>_F_0000.CSV"

  @headers "User-Agent":
             "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/83.0.4103.97 Safari/537.36 Edg/83.0.478.45"

  schema "market_history" do
    # session data

    field :session_id, :string
    field :src, :string
    field :trade_date, :date
    field :business_date, :date

    # instrument data
    field :isin, :string
    field :instrument_id, :string
    field :instrument_type, :string
    field :instrument_name, :string
    field :ticker, :string
    field :segment, :string
    field :scrip_group, :string

    # price data
    field :open_price, :decimal
    field :high_price, :decimal
    field :low_price, :decimal
    field :close_price, :decimal
    field :last_price, :decimal
    field :previous_close_price, :decimal
    field :settlement_price, :decimal

    # volume data
    field :total_traded_volume, :integer
    field :total_traded_value, :decimal
    field :total_number_of_trades_executed, :integer

    timestamps()
  end

  def store_market_history_for_date(date) when is_struct(date, Date) do
    date
    |> Calendar.strftime("%Y%m%d")
    |> fetch_data_for_date
    |> String.split("\n", trim: true)
    |> parse_rows_to_bhavcopy
    |> handle_insert

    {:ok, :data_loaded}
  end

  def load_data_from_csv(path) do
    trade_date =
      File.stream!(path)
      |> Stream.drop(1)
      |> Enum.at(1)
      |> map_to_record()
      |> Map.get(:trade_date)

    unless data_fetched(trade_date) do
      path
      |> File.stream!()
      |> parse_rows_to_bhavcopy
      |> handle_insert()

      {:ok, :data_loaded}
    end

    {:ok, :already_fetched}
  end

  defp fetch_data_for_date(date) do
    EEx.eval_string(@api_template, date: date)
    |> HTTPoison.get!(@headers)
    |> validate_response!
  end

  defp validate_response!(%HTTPoison.Response{status_code: 200, body: body}) do
    body
  end

  defp parse_rows_to_bhavcopy(lines) do
    lines
    |> Enum.drop(1)
    |> Enum.map(&map_to_record(&1))
  end

  defp map_to_record(row) do
    row
    |> String.split(",")
    |> map_to_bhav_struct()
  end

  defp map_to_bhav_struct(fields) do
    [
      trade_date,
      business_date,
      segment,
      src,
      instrument_type,
      instrument_id,
      isin,
      ticker,
      scrip_group,
      _xpiry_date,
      _fin_instrm_actl_xpry_dt,
      _strike_price,
      _option_price,
      instrument_name,
      open_price,
      high_price,
      low_price,
      close_price,
      last_price,
      previous_close_price,
      _underlying_price,
      settlement_price,
      _opn_instr,
      _chg_in_opn_instr,
      ttl_trade_vol,
      ttl_trade_value,
      ttl_trade_numbers,
      session_id,
      _new_brd_lot_qty,
      _rmks,
      _rsvd_1,
      _rsvd_2,
      _rsvd_3,
      _rsvd_4
    ] = fields

    %BhavCopy{
      session_id: session_id,
      trade_date: Date.from_iso8601!(trade_date),
      business_date: Date.from_iso8601!(business_date),
      segment: segment,
      src: src,
      instrument_type: instrument_type,
      instrument_id: instrument_id,
      isin: isin,
      ticker: ticker,
      scrip_group: scrip_group,
      instrument_name: instrument_name,
      open_price: Decimal.new(open_price),
      high_price: Decimal.new(high_price),
      low_price: Decimal.new(low_price),
      close_price: Decimal.new(close_price),
      last_price: Decimal.new(last_price),
      previous_close_price: Decimal.new(previous_close_price),
      settlement_price: Decimal.new(settlement_price),
      total_traded_volume: String.to_integer(ttl_trade_vol),
      total_traded_value: Decimal.new(ttl_trade_value),
      total_number_of_trades_executed: String.to_integer(ttl_trade_numbers)
    }
  end

  defp handle_insert(bhav_copy) do
    bhav_copy
    |> Enum.map(&update_instruments_if_absent(&1))
    |> Enum.map(&Repo.insert(&1))
  end

  defp update_instruments_if_absent(bhavCopy) do
    unless InstrumentsCache.instrument?(bhavCopy.instrument_id) do
      instrument = %Instrument{
        instrument_id: bhavCopy.instrument_id,
        instrument_name: bhavCopy.instrument_name,
        instrument_type: bhavCopy.instrument_type,
        isin: bhavCopy.isin,
        ticker: bhavCopy.ticker,
        segment: bhavCopy.segment,
        scrip_group: bhavCopy.scrip_group
      }

      # TODO: log error
      case Repo.insert(instrument) do
        {:ok, instrument} -> InstrumentsCache.insert(instrument)
        {:error, changeset} -> {:error, changeset}
      end
    end

    bhavCopy
  end

  def cp_for(instrument_id, date) when is_struct(date, Date) do
    filters = [instrument_id: instrument_id, trade_date: date]
    query = from rec in BhavCopy, where: ^filters

    ret =
      case(Repo.all(query, skip_user_id: true)) do
        [] -> 0
        [val] when is_struct(val, BhavCopy) -> val.close_price
      end

    ret
  end

  defp data_fetched(date) when is_struct(date, Date) do
    [{count}] = Repo.all(from rec in BhavCopy, where: [trade_date: ^date], select: {count(rec)})

    if count > 0 do
      true
    else
      false
    end
  end
end
