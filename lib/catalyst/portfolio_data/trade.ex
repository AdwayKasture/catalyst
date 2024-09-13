defmodule Catalyst.PortfolioData.Trade do
  alias Catalyst.MarketData.InstrumentsCache
  alias Catalyst.Repo
  alias Catalyst.PortfolioData.Trade
  use Ecto.Schema
  import Ecto.Changeset

  schema "trades" do
    field :type, Ecto.Enum, values: [:buy, :sell]
    field :transaction_date, :date
    field :avg_trade_price, :decimal
    field :currency, :string
    field :fees, :decimal
    field :quantity, :integer

    belongs_to :instrument, Catalyst.MarketData.Instrument,
      type: :string,
      references: :instrument_id

    belongs_to :user, Catalyst.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def validate(changeset) do
    changeset
    |> validate_required([
      :type,
      :transaction_date,
      :avg_trade_price,
      :currency,
      :quantity,
      :instrument_id
    ])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:avg_trade_price, greater_than: 0)
    |> validate_number(:fees, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  def create_changeset(trade \\ %Trade{}, attrs) when is_struct(trade, Trade) do
    trade
    |> cast(attrs, [
      :type,
      :transaction_date,
      :avg_trade_price,
      :currency,
      :fees,
      :quantity,
      :instrument_id
    ])
    |> put_change(:currency, "INR")
    |> put_change(:user_id, Repo.get_user_id())
    |> validate()
  end

  def create_trade(attrs) do
    create_changeset(attrs)
    |> Repo.insert()
    |> notify_creation()
  end

  def update_trade(org_txn, attrs) do
    org_txn
    |> cast(attrs, [
      :type,
      :transaction_date,
      :avg_trade_price,
      :currency,
      :fees,
      :quantity,
      :instrument_id
    ])
    |> validate()
    |> Repo.update()
    |> notify_update(org_txn)
  end

  def delete_trade(txn) do
    txn
    |> Repo.delete()
    |> notify_deletion()
  end

  def get_history() do
    Repo.all(Trade)
    |> Stream.map(&enrich_instrument/1)
  end

  def get(id) do
    Repo.get!(Trade, id)
    |> enrich_instrument()
  end

  defp notify_creation(event) do
    case event do
      {:ok, txn} -> {broadcast({:create, txn}), "Trade created successfully"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp notify_deletion(event) do
    case event do
      {:ok, txn} -> {broadcast({:delete, txn}), "Trade deleted successfully"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp notify_update(event, original_txn) do
    case event do
      {:ok, txn} -> {broadcast({:update, original_txn, txn}), "Trade updated successfully"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp broadcast(data) do
    Phoenix.PubSub.broadcast!(Catalyst.PubSub, "trades", data)
  end

  defp enrich_instrument(trade) do
    %{trade | instrument: InstrumentsCache.get_instrument(trade.instrument_id)}
  end
end
