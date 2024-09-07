defmodule Catalyst.TradesTest do
  alias Catalyst.Portfolio.Trade
  alias Phoenix.PubSub
  alias Catalyst.AccountsFixtures
  use Catalyst.DataCase
  import Catalyst.CashFixtures

  describe "CRUD tests for cash " do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.insert(get_instrument())
      Repo.put_user_id(user.id)
      PubSub.subscribe(Catalyst.PubSub, "trades")
      {:ok, user_logged_in: true}
    end

    test "create transaction" do
      assert Repo.all(Trade) |> Enum.count() == 0
      txn_data = trade_data()
      Trade.create_trade(txn_data)
      assert Repo.all(Trade) |> Enum.count() == 1
      assert_receive {:create,_}
    end

    test "update transaction" do
      assert Repo.all(Trade) |> Enum.count() == 0
      txn_data = trade_data()
      Trade.create_trade(txn_data)
      %{type: type} = txn = Repo.all(Trade) |> Enum.at(0)
      assert ^type = :buy
      Trade.update_trade(txn, %{type: :sell})
      %{type: updated_type} = updated_txn = Repo.all(Trade) |> Enum.at(0)
      assert ^updated_type = :sell
      assert_receive {:update,_txn,_txn2}
    end

    test "delete transaction" do
      txn_data = trade_data()
      Trade.create_trade(txn_data)
      assert Repo.all(Trade) |> Enum.count() == 1
      Trade.delete_trade(Repo.all(Trade) |> Enum.at(0))
      assert Repo.all(Trade) |> Enum.count() == 0
      assert_receive {:delete,_any}
    end
  end

  describe "validations" do
  end
end
