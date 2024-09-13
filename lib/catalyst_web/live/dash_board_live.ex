defmodule CatalystWeb.DashBoardLive do
  use CatalystWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex justify-center flex-col">
      <div class="text-gray-300 text-4xl">
        Current user's portfolio
      </div>
      <div class="border border-white p-5 flex justify-end gap-4">
        <.button phx-click="open_trade">Log trade</.button>
        <.button phx-click="open_cash">Log transaction</.button>
      </div>
      <div class="border border-white p-5 flex justify-evenly">
        <.link>1d</.link>
        <.link>1w</.link>
        <.link>1m</.link>
        <.link>ytd</.link>
      </div>
      <div class="border p-5 flex justify-center ">
        <canvas class="border" id="my-chart" phx-hook="ChartJS"></canvas>
      </div>
      <div class="p-5 border">
        table name
      </div>
      <div class="p-5 border">
        table
      </div>
    </div>
    <.live_component
      :if={@active_modal == :trade}
      module={CatalystWeb.TradesLive}
      id="trade-editor"
      action={:new}
      navigate_back="/dashboard"
    />
    <.live_component
      :if={@active_modal == :cash}
      module={CatalystWeb.CashLive}
      id="cash-editor"
      action={:new}
      navigate_back="/dashboard"
    />
    """
  end

  # TODO: extract to the buttons and callbacks

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, active_modal: nil)}
  end

  @impl true
  def handle_event("open_trade", _unsigned_params, socket) do
    {:noreply, assign(socket, active_modal: :trade)}
  end

  @impl true
  def handle_event("open_cash", _unsigned_params, socket) do
    {:noreply, assign(socket, active_modal: :cash)}
  end

  @impl true
  def handle_event("closed", _unsigned_params, socket) do
    {:noreply, socket |> assign(trade_action: :new, cash_action: :new, active_modal: nil)}
  end
end
