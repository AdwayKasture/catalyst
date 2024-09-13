defmodule Catalyst.MarketData.Instrument do
  use Ecto.Schema
  alias Catalyst.Repo
  alias Catalyst.Instrument
  import Ecto.Changeset

  @primary_key {:instrument_id, :string, []}
  @derive {Phoenix.Param, key: :instrument_id}
  schema "instruments" do
    field :ticker, :string
    field :isin, :string
    field :instrument_type, :string
    field :instrument_name, :string
    field :segment, :string
    field :scrip_group, :string

    has_many :trades, Catalyst.PortfolioData.Trade

    timestamps(type: :utc_datetime)
  end

  def list_instruments() do
    Repo.all(Instrument)
    |> Enum.map(& &1.instrument_name)
  end

  def changeset(instrument, attrs) do
    instrument
    |> cast(attrs, [
      :ticker,
      :isin,
      :instrument_type,
      :instrument_name,
      :segment,
      :scrip_group,
      :instrument_id
    ])
    |> validate_required([
      :ticker,
      :isin,
      :instrument_type,
      :instrument_name,
      :segment,
      :scrip_group
    ])
    |> unique_constraint(:instrument_id)
  end
end
