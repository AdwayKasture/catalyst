defmodule Catalyst.Repo.Migrations.CreateMarketData do
  use Ecto.Migration

  def change do
    create table(:instruments, primary_key: false) do
      add :instrument_id, :string, primary_key: true
      add :instrument_type, :string
      add :instrument_name, :string

      add :ticker, :string
      add :isin, :string
      add :segment, :string
      add :scrip_group, :string

      timestamps(type: :utc_datetime)
    end

    create table(:market_history) do
      add :session_id, :string
      add :src, :string
      add :trade_date, :date
      add :business_date, :date
      add :isin, :string
      add :instrument_id, :string
      add :instrument_type, :string
      add :instrument_name, :string
      add :ticker, :string
      add :segment, :string
      add :scrip_group, :string
      add :open_price, :decimal
      add :high_price, :decimal
      add :low_price, :decimal
      add :close_price, :decimal
      add :last_price, :decimal
      add :previous_close_price, :decimal
      add :settlement_price, :decimal
      add :total_traded_volume, :integer
      add :total_traded_value, :decimal
      add :total_number_of_trades_executed, :integer

      timestamps()
    end

    create index(:market_history, [:session_id])
    create index(:market_history, [:trade_date])
    create index(:market_history, [:instrument_id])
  end
end
