defmodule Catalyst.Repo.Migrations.CreateDailySnapshotsTable do
  use Ecto.Migration

  def change do
    create table(:daily_snapshots) do
      add :snapshot_date, :date

      add :assets_value, :decimal
      add :cash, :decimal
      add :total_portfolio_value, :decimal
      add :book_pl, :decimal
      add :notional_pl, :decimal
      add :net_pl, :decimal

      add :user_id, references(:users), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:daily_snapshots, [:snapshot_date])
  end
end
