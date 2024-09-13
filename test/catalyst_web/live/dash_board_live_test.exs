defmodule CatalystWeb.DashBoardLiveTest do
  alias Catalyst.PortfolioData.Cash
  alias Catalyst.Repo
  use CatalystWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Catalyst.AccountsFixtures

  describe "dashboard screen features" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user) |> get(~p"/dashboard"), user: user}
    end

    test "test all nav bar buttons present", %{conn: conn} do
      html = html_response(conn, 200)
      assert html =~ ~p"/users/log_out"
      assert html =~ ~p"/users/settings"
      assert html =~ ~p"/history"
      assert html =~ ~p"/"
    end

    test "test buttons for creating transactions are present ", %{conn: conn, user: user} do
      html = html_response(conn, 200)
      assert html =~ "Log trade\n</button>"
      assert html =~ "Log transaction\n</button>"
    end

    test "test create transaction", %{conn: conn} do
      assert Repo.all(Cash) |> Enum.count() == 0
      {:ok, lv, _html} = live(conn, ~p"/dashboard")

      assert {:ok, _lv, _html} =
               lv
               |> form("#cash-form",
                 cash: %{type: :deposit, transaction_date: ~D[2024-09-12], amount: 1000, fees: 1}
               )
               |> render_submit()
               |> follow_redirect(conn, ~p"/dashboard")

      assert Repo.all(Cash) |> Enum.count() == 1
    end

    test "test create transaction fails with missing amount", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/dashboard")

      html =
        lv
        |> form("#cash-form", cash: %{transaction_date: ~D[2024-09-12]})
        |> render_submit()
        |> Floki.parse_document!()
        |> Floki.text()

      assert html =~ "can't be blank"
    end

    test "test create transaction fails with missing date", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/dashboard")

      html =
        lv
        |> form("#cash-form", cash: %{amount: 1000})
        |> render_submit()
        |> Floki.parse_document!()
        |> Floki.text()

      assert html =~ "can't be blank"
    end
  end
end
