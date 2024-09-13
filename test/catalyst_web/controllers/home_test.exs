defmodule CatalystWeb.HomeTest do
  use CatalystWeb.ConnCase, async: true

  describe "public page" do
    test "home page has register and log in buttons", %{conn: conn} do
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ ~p"/users/log_in"
      assert response =~ ~p"/users/register"
    end
  end
end
