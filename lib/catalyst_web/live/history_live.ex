defmodule CatalystWeb.HistoryLive do
  alias Catalyst.Portfolio
  alias CatalystWeb.TradeTable
  use CatalystWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex justify-center flex-col ">
      <div class="text-gray-300 text-4xl">
        Trade history
      </div>
      <div class="p-5 flex justify-end gap-4">
        <.button phx-click="open_trade">Log trade</.button>
        <.button phx-click="open_cash">Log transaction</.button>
      </div>
      <div class="border border-gray-600  rounded-md p-5 flex justify-evenly">
        <.link
          class="bg-gray-600 hover:text-white hover:border hover:border-gray-300 px-5 py-3 rounded-md"
          phx-click="change_tab"
          phx-value-tab="trade"
        >
          trades
        </.link>
        <.link
          class="bg-gray-600 hover:text-white hover:border  hover:border-gray-300 px-5 py-3 rounded-md"
          phx-click="change_tab"
          phx-value-tab="cash"
        >
          transactions
        </.link>
      </div>
      <div>
        <TradeTable.trade_grid :if={@tab == "trade"} data={@data} />
        <TradeTable.cash_grid :if={@tab == "cash"} data={@data} />
      </div>
    </div>
    <.live_component
      :if={@active_modal == :cash}
      module={CatalystWeb.CashLive}
      id="cash_editor"
      navigate_back={~p"/history/#{"cash"}"}
      action={@modal_action}
      cash={@modal_data}
    />
    <.live_component
      :if={@active_modal == :trade}
      module={CatalystWeb.TradesLive}
      id="trade_editor"
      navigate_back={~p"/history/#{"trade"}"}
      action={@modal_action}
      trade={@modal_data}
    />
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(modal_action: :new)
     |> assign(modal_data: nil)
     |> assign(active_modal: nil)}
  end

  @impl true
  def handle_params(%{"tab" => tab}, _uri, socket) do
    data = Portfolio.get_history(tab)
    {:noreply, assign(socket, tab: tab, data: data)}
  end

  @impl true
  def handle_params(%{}, _uri, socket) do
    tab = "trade"
    data = Portfolio.get_history(tab)
    {:noreply, assign(socket, tab: tab, data: data)}
  end

  @impl true
  def handle_event("edit_trade", %{"trade_id" => id}, socket) do
    trade = Portfolio.get(:trade, id)
    {:noreply, socket |> assign(modal_action: :edit, modal_data: trade, active_modal: :trade)}
  end

  @impl true
  def handle_event("edit_cash", %{"cash_id" => id}, socket) do
    cash = Portfolio.get(:cash, id)
    {:noreply, socket |> assign(modal_action: :edit, modal_data: cash, active_modal: :cash)}
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
  def handle_event("change_tab", %{"tab" => tab}, socket) do
    {:noreply, push_patch(socket, to: ~p"/history/#{tab}")}
  end

  @impl true
  def handle_event("closed", _unsigned_params, socket) do
    {:noreply, socket |> assign(modal_action: :new, modal_data: nil, active_modal: nil)}
  end

  @impl true
  def handle_event("delete", %{"type" => type, "id" => id}, socket) do
    res = Portfolio.delete(type, id)

    case res do
      {:ok, msg} ->
        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> push_navigate(to: ~p"/history/#{type}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :info, "failed to delete")}
    end
  end

  @impl true
  def handle_event("sell", %{"id" => id}, socket) do
    trade = %{Portfolio.get(:trade, id) | type: :sell}
    {:noreply, socket |> assign(modal_action: :sell, modal_data: trade, active_modal: :trade)}
  end
end
