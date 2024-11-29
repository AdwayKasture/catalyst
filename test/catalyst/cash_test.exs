defmodule Catalyst.CashTest do
  import Catalyst.PortfolioUtil
  alias Catalyst.Portfolio
  alias Phoenix.PubSub
  alias Catalyst.AccountsFixtures
  use Catalyst.DataCase
  import Catalyst.CashFixtures
  alias Catalyst.PortfolioData.Cash

  describe "CRUD tests for cash " do
    setup do
      user = AccountsFixtures.user_fixture()
      Repo.put_user_id(user.id)
      PubSub.subscribe(Catalyst.PubSub, "transactions")
      Portfolio.recompute_snapshots()
      {:ok, user_logged_in: true}
    end

    test "create transaction" do
      assert Repo.all(Cash) |> Enum.count() == 0
      txn_data = txn_data()
      wait(Cash.create_txn(txn_data))
      assert Repo.all(Cash) |> Enum.count() == 1
      assert_receive {:cash, :create, _}
    end

    test "update transaction" do
      assert Repo.all(Cash) |> Enum.count() == 0
      txn_data = txn_data()
      wait(Cash.create_txn(txn_data))
      %{type: type} = txn = Repo.all(Cash) |> Enum.at(0)
      assert ^type = :deposit
      wait(Cash.update_txn(txn, %{type: :withdraw}))
      %{type: updated_type} = Repo.all(Cash) |> Enum.at(0)
      assert ^updated_type = :withdraw
      assert_receive {:cash, :update, _txn, _txn2}
    end

    test "delete transaction" do
      txn_data = txn_data()
      wait(Cash.create_txn(txn_data))
      assert Repo.all(Cash) |> Enum.count() == 1
      wait(Cash.delete_txn(Repo.all(Cash) |> Enum.at(0)))
      assert Repo.all(Cash) |> Enum.count() == 0
      assert_receive {:cash, :delete, _any}
    end
  end
end
