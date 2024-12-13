defmodule Catalyst.MarketData.BhavCopy do
  require Logger
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
    fetched_data = date
    |> Calendar.strftime("%Y%m%d")
    |> fetch_data_for_date

    case fetched_data do
      :error -> {:ok,"job failed and error has been logged"}
      body ->
        body
        |> String.split("\n", trim: true)
        |> parse_rows_to_bhavcopy
        |> update_instruments()
        |> Enum.map(&to_map/1)
        |> Enum.chunk_every(100)
        |> Enum.each(fn chunk -> Repo.insert_all(BhavCopy, chunk) end)
    end


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
      |> update_instruments()
      |> Enum.map(&to_map/1)
      |> Enum.chunk_every(100)
      |> Enum.each(fn chunk -> Repo.insert_all(BhavCopy, chunk) end)

      {:ok, :data_loaded}
    end

    {:ok, :already_fetched}
  end

  def load_data_from_zip(path) do
    upload_folder = Path.join([:code.priv_dir(:catalyst), "static", "uploads"])
    {:ok, file_list} = :zip.unzip(to_charlist(path), [{:cwd, to_charlist(upload_folder)}])

    file_list
    |> Stream.map(&to_string/1)
    |> Enum.each(fn file_name -> load_data_from_csv(file_name) end)

    {:ok, :finished_processing}
  end

  def fetch_data_from_file(path, file_extension) do
    case file_extension do
      ".zip" -> load_data_from_zip(path)
      ".csv" -> load_data_from_csv(path)
    end

    {:ok, :market_data_loaded}
  end

  defp fetch_data_for_date(date) do
    EEx.eval_string(@api_template, date: date)
    |> HTTPoison.get!(@headers)
    |> validate_response
  end

  defp validate_response(%HTTPoison.Response{status_code: 200, body: body}) do
    body
  end

  defp validate_response(%HTTPoison.Response{status_code: error_code, body: body}) do
    Logger.error("failed to fetch data",[error_code: error_code,response: body])
    :error
  end

  defp parse_rows_to_bhavcopy(lines) do
    lines
    |> Enum.drop(1)
    |> Enum.map(&map_to_record/1)
    |> Enum.filter(&valid_instrument?/1)
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

    sp =
      case settlement_price do
        "" -> 0
        val -> val
      end

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
      settlement_price: Decimal.new(sp),
      total_traded_volume: String.to_integer(ttl_trade_vol),
      total_traded_value: Decimal.new(ttl_trade_value),
      total_number_of_trades_executed: String.to_integer(ttl_trade_numbers)
    }
  end

  defp update_instruments(bhav_copy) do
    bhav_copy
    |> Enum.map(&update_instruments_if_absent(&1))
  end

  defp update_instruments_if_absent(bhavCopy) when is_struct(bhavCopy, BhavCopy) do
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

      case Repo.insert(instrument) do
        {:ok, instrument} ->
          InstrumentsCache.insert(instrument)

        {:error, changeset} ->
          Logger.error("error inserting instrument",
            instrument_id: instrument.instrument_id,
            inserted_at: instrument.inserted_at
          )

          {:error, changeset}
      end
    end

    bhavCopy
  end

  defp to_map(bhav_copy) when is_struct(bhav_copy, BhavCopy) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    bhav_copy
    |> Map.take(BhavCopy.__schema__(:fields))
    |> Map.delete(:id)
    |> Map.put(:inserted_at, now)
    |> Map.put(:updated_at, now)
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
    query = from rec in BhavCopy, where: [trade_date: ^date], select: {count(rec)}
    [{count}] = Repo.all(query, skip_user_id: true)

    if count > 0 do
      true
    else
      false
    end
  end

  defp valid_instrument?(bhav_copy) when is_struct(bhav_copy, BhavCopy) do
    case {bhav_copy.ticker, Application.get_env(:catalyst, :instruments)} do
      {_, :all} -> true
      {_, nil} -> true
      {_, []} -> true
      {ticker, instruments} when is_list(instruments) -> ticker in instruments
    end
  end
end
