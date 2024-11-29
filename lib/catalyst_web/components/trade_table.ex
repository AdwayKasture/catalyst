defmodule CatalystWeb.TradeTable do
  use Phoenix.Component
  import CatalystWeb.CoreComponents
  alias Phoenix.LiveView.JS

  attr :data, :list, required: true

  def trade_grid(assigns) do
    ~H"""
    <.table id="trade_grid" rows={@data} row_click={&JS.push("edit_trade", value: %{trade_id: &1.id})}>
      <:col :let={trade} label="Transaction Date">
        <%= Date.to_iso8601(trade.transaction_date) %>
      </:col>

      <:col :let={trade} label="Type"><%= trade.type %></:col>

      <:col :let={trade} label="Instrument">
        <%= trade.instrument.ticker %>
      </:col>

      <:col :let={trade} label="Quantity"><%= trade.quantity %></:col>

      <:col :let={trade} label="Average Trade Price"><%= trade.avg_trade_price %></:col>

      <%!-- <:col :let={trade} label="Fees"><%= trade.fees %></:col> --%>
      <:action :let={trade}>
        <.button
          :if={trade.type == :buy}
          phx-click="sell"
          phx-value-type="trade"
          phx-value-id={trade.id}
          class="text-gray-300 bg-green-600 hover:bg-green-400 "
        >
          Sell
        </.button>
        <.button
          phx-click="delete"
          phx-value-type="trade"
          phx-value-id={trade.id}
          class="text-gray-300 bg-red-600 hover:bg-red-400"
        >
          delete
        </.button>
      </:action>
    </.table>
    """
  end

  attr :data, :list, required: true

  def cash_grid(assigns) do
    ~H"""
    <.table id="cash_grid" rows={@data} row_click={&JS.push("edit_cash", value: %{cash_id: &1.id})}>
      <:col :let={cash} label="Type"><%= cash.type %></:col>

      <:col :let={cash} label="Transaction Date">
        <%= Date.to_iso8601(cash.transaction_date) %>
      </:col>

      <:col :let={cash} label="Amount"><%= cash.amount %></:col>

      <:col :let={cash} label="Fees"><%= cash.fees %></:col>

      <:action :let={trade}>
        <.button
          phx-click="delete"
          phx-value-type="cash"
          phx-value-id={trade.id}
          class="text-gray-300 bg-red-600 hover:bg-red-400"
        >
          delete
        </.button>
      </:action>
    </.table>
    """
  end
end
