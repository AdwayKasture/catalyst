defmodule Catalyst.Repo.Migrations.CreateTradesTable do
  use Ecto.Migration

  def change do
    create table(:trades) do
      add :type, :string
      add :transaction_date, :date
      add :avg_trade_price, :decimal
      add :currency, :string
      add :fees, :decimal

      add :instrument_id,
          references(:instruments, on_delete: :nothing, column: :instrument_id, type: :string)

      add :quantity, :integer

      add :user_id, references(:users), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:trades, [:instrument_id])
    create index(:trades, [:transaction_date])
  end
end
