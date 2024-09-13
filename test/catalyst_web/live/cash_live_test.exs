defmodule CatalystWeb.CashLiveTest do
  alias CatalystWeb.CashLive
  use CatalystWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "create new cash txn" do
    component = render_component(CashLive, id: "create-txn", action: :new, navigate_back: "/")
    IO.inspect(component)
    assert 1 == 2
  end
end
