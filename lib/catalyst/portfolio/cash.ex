defmodule Catalyst.Portfolio.Cash do
  alias Catalyst.Repo
  alias Catalyst.Portfolio.Cash
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :type, Ecto.Enum, values: [:deposit, :withdraw]
    field :transaction_date, :date
    field :amount, :decimal
    field :currency, :string
    field :fees, :decimal
    belongs_to :user, Catalyst.Accounts.User

    timestamps(type: :utc_datetime)
  end

  defp validate(changeset) do
    changeset
    |> validate_required([:type, :transaction_date, :amount, :currency])
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:fees, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
  end

  def create_txn(attrs) do
    %Cash{}
    |> cast(attrs, [:type, :transaction_date, :amount, :currency, :fees])
    |> put_change(:currency, "INR")
    |> validate()
    |> put_change(:user_id, Repo.get_user_id())
    |> Repo.insert()
    |> notify_creation()
  end

  def update_txn(org_txn, attrs) do
    org_txn
    |> cast(attrs, [:type, :transaction_date, :amount, :currency, :fees])
    |> validate()
    |> Repo.update()
    |> notify_update(org_txn)
  end

  def delete_txn(txn) do
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
    Phoenix.PubSub.broadcast(Catalyst.PubSub, "transactions", data)
  end
end
