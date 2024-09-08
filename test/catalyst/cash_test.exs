defmodule Catalyst.CashTest do
  alias Phoenix.PubSub
  alias Catalyst.AccountsFixtures
  use Catalyst.DataCase
  import Catalyst.CashFixtures
  alias Catalyst.Portfolio.Cash

  describe "CRUD tests for cash " do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.put_user_id(user.id)
      PubSub.subscribe(Catalyst.PubSub, "transactions")
      {:ok, user_logged_in: true}
    end

    test "create transaction" do
      assert Repo.all(Cash) |> Enum.count() == 0
      txn_data = txn_data()
      Cash.create_txn(txn_data)
      assert Repo.all(Cash) |> Enum.count() == 1
      assert_receive {:create, _}
    end

    test "update transaction" do
      assert Repo.all(Cash) |> Enum.count() == 0
      txn_data = txn_data()
      Cash.create_txn(txn_data)
      %{type: type} = txn = Repo.all(Cash) |> Enum.at(0)
      assert ^type = :deposit
      Cash.update_txn(txn, %{type: :withdraw})
      %{type: updated_type} = updated_txn = Repo.all(Cash) |> Enum.at(0)
      assert ^updated_type = :withdraw
      assert_receive {:update, _txn, _txn2}
    end

    test "delete transaction" do
      txn_data = txn_data()
      Cash.create_txn(txn_data)
      assert Repo.all(Cash) |> Enum.count() == 1
      Cash.delete_txn(Repo.all(Cash) |> Enum.at(0))
      assert Repo.all(Cash) |> Enum.count() == 0
      assert_receive {:delete, _any}
    end
  end

  describe "validations" do
  end
end
