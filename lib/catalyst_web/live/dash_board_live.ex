defmodule CatalystWeb.DashBoardLive do
  alias Catalyst.Portfolio
  use CatalystWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex justify-center flex-col">
      <div class=" p-5 flex justify-end gap-4">
        <.button phx-click="open_trade">Log trade</.button>
        <.button phx-click="open_cash">Log transaction</.button>
      </div>
      <div class=" p-5 flex justify-evenly">
        <.link navigate={~p"/dashboard/1w"}>1w</.link>
        <.link navigate={~p"/dashboard/1m"}>1m</.link>
        <.link navigate={~p"/dashboard/3m"}>3m</.link>
        <.link navigate={~p"/dashboard/ytd"}>ytd</.link>
      </div>
      <div class="p-5 flex justify-center ">
        <canvas
          id="my-chart"
          phx-hook="ChartJS"
          phx-update="stream"
          data-dates={Jason.encode!(@dates)}
          data-valuations={Jason.encode!(@valuations)}
          data-book_pl={Jason.encode!(@book_pl)}
          data-notional_pl={Jason.encode!(@notional_pl)}
        >
        </canvas>
      </div>
      <div class="p-5">
        Holdings
      </div>
      <div>
        <.holdings_table data={@holdings} />
      </div>
    </div>
    <.live_component
      :if={@active_modal == :trade}
      module={CatalystWeb.TradesLive}
      id="trade-editor"
      action={:new}
      navigate_back={~p"/dashboard"}
    />
    <.live_component
      :if={@active_modal == :cash}
      module={CatalystWeb.CashLive}
      id="cash-editor"
      action={:new}
      navigate_back={~p"/"}
    />
    """
  end

  @impl true
  def handle_params(%{"range" => date_range}, _uri, socket) do
    {dates, tot_val, book_pl, notional_pl} = Portfolio.get_snapshot(date_range)
    holdings = Portfolio.get_holdings()

    {:noreply,
     socket
     |> assign(active_modal: nil)
     |> assign(dates: dates)
     |> assign(valuations: tot_val)
     |> assign(book_pl: book_pl)
     |> assign(notional_pl: notional_pl)
     |> assign(holdings: holdings)}
  end

  @impl true
  def handle_params(%{}, _uri, socket) do
    {dates, tot_val, book_pl, notional_pl} = Portfolio.get_snapshot("1w")
    holdings = Portfolio.get_holdings()

    {:noreply,
     socket
     |> assign(active_modal: nil)
     |> assign(dates: dates)
     |> assign(valuations: tot_val)
     |> assign(book_pl: book_pl)
     |> assign(notional_pl: notional_pl)
     |> assign(holdings: holdings)}
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
    {:noreply, socket |> assign(active_modal: nil)}
  end

  def holdings_table(assigns) do
    ~H"""
    <.table id="holdings_table" rows={@data}>
      <:col :let={elem} label="Name"><%= elem.instrument.instrument_name %></:col>
      <:col :let={elem} label="Quantity"><%= elem.quantity %></:col>
      <:col :let={elem} label="Avg buy price"><%= elem.avg_buy_price %></:col>
      <:action></:action>
    </.table>
    """
  end
end
