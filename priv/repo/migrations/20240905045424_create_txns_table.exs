defmodule Catalyst.Repo.Migrations.CreateTxnsTable do
  use Ecto.Migration

  def change do
    create table(:transactions) do
      add :type, :string
      add :transaction_date, :date
      add :amount, :decimal
      add :currency, :string
      add :fees, :decimal

      add :user_id, references(:users), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:transaction_date])
  end
end
