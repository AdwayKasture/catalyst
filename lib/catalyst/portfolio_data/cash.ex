defmodule Catalyst.PortfolioData.Cash do
  alias Catalyst.Repo
  alias Catalyst.PortfolioData.Cash
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
    |> validate(:transaction_date)
  end

  defp validate(changeset, :transaction_date = field) do
    txn_date = get_field(changeset, field)

    if is_nil(txn_date) do
      changeset
    else
      case !Timex.after?(txn_date, Timex.today()) do
        true -> changeset
        false -> add_error(changeset, field, "transaction date must  be on/before today")
      end
    end
  end

  def create_changeset(txn \\ %Cash{}, attrs) do
    txn
    |> cast(attrs, [:type, :transaction_date, :amount, :currency, :fees])
    |> put_change(:currency, "INR")
    |> validate()
    |> put_change(:user_id, Repo.get_user_id())
  end

  def create_txn(attrs) do
    create_changeset(attrs)
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

  def get_history() do
    Repo.all(Cash)
  end

  def get(id) do
    Repo.get(Cash, id)
  end

  def clear_history() do
    Repo.delete_all(Cash)
  end

  defp notify_creation(event) do
    case event do
      {:ok, txn} -> {broadcast({:cash, :create, txn}), "Transaction created successfully"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp notify_deletion(event) do
    case event do
      {:ok, txn} -> {broadcast({:cash, :delete, txn}), "Transaction deleted successfully"}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp notify_update(event, original_txn) do
    case event do
      {:ok, txn} ->
        {broadcast({:cash, :update, original_txn, txn}), "Transaction updated successfully"}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  defp broadcast(data) do
    Phoenix.PubSub.broadcast!(Catalyst.PubSub, "transactions", data)
  end
end
