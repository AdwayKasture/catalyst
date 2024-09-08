defmodule Catalyst.Portfolio.Trade do
  alias Catalyst.Repo
  alias Catalyst.Portfolio.Trade
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

  def create_trade(attrs) do
    %Trade{}
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
    |> validate()
    |> put_change(:user_id, Repo.get_user_id())
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

  defp notify_creation(event) do
    case event do
      {:ok, txn} -> broadcast({:create, txn})
      {:error, changeset} -> changeset
    end
  end

  defp notify_deletion(event) do
    case event do
      {:ok, txn} -> broadcast({:delete, txn})
      {:error, changeset} -> changeset
    end
  end

  defp notify_update(event, original_txn) do
    case event do
      {:ok, txn} -> broadcast({:update, original_txn, txn})
      {:error, changeset} -> changeset
    end
  end

  defp broadcast(data) do
    Phoenix.PubSub.broadcast(Catalyst.PubSub, "trades", data)
  end
end
