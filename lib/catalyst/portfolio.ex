defmodule Catalyst.Portfolio do
  alias Catalyst.PortfolioData.Trade
  alias Catalyst.PortfolioData.Cash

  def create_changeset(trade) when is_struct(trade, Trade) do
    Trade.create_changeset(trade, %{})
  end

  def create_changeset(cash) when is_struct(cash, Cash) do
    Cash.create_changeset(cash, %{})
  end

  def update_changeset(trade, attrs) when is_struct(trade, Trade) do
    Trade.create_changeset(trade, attrs)
    |> Map.put(:action, :validate)
  end

  def update_changeset(cash, attrs) when is_struct(cash, Cash) do
    Cash.create_changeset(cash, attrs)
    |> Map.put(:action, :validate)
  end

  def save_trade(attrs) do
    Trade.create_trade(attrs)
  end

  def update_trade(org_trade, attrs) when is_struct(org_trade, Trade) do
    Trade.update_trade(org_trade, attrs)
  end

  def save_txn(attrs) do
    Cash.create_txn(attrs)
  end

  def update_txn(org_cash, attrs) when is_struct(org_cash, Cash) do
    Cash.update_txn(org_cash, attrs)
  end

  def get_history(type) do
    case type do
      "trade" -> Trade.get_history()
      "cash" -> Cash.get_history()
    end
  end

  def delete(type, id) do
    data = get(type, id)

    case type do
      "trade" -> Trade.delete_trade(data)
      "cash" -> Cash.delete_txn(data)
    end
  end

  def get(type, id) do
    case type do
      :trade -> Trade.get(id)
      "trade" -> Trade.get(id)
      :cash -> Cash.get(id)
      "cash" -> Cash.get(id)
    end
  end
end
