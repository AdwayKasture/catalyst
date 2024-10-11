defmodule Catalyst.Repo.Migrations.CreateMarketHolidays do
  use Ecto.Migration

  def change do
    create table(:market_holidays) do
      add :holiday_date, :date
      add :description, :string
    end
  end
end
