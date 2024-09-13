defmodule CatalystWeb.TradesLive do
  alias Catalyst.Portfolio
  alias Catalyst.PortfolioData.Trade
  alias Catalyst.Market
  use CatalystWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id="create-trade-modal" show on_cancel={JS.push("closed")}>
        <%= if instr_not_selected?(@selected_instrument)  do %>
          <.search_input
            value={@query}
            phx-target={@myself}
            phx-keyup="do-search"
            phx-debounce="200"
            id="search"
          />
          <.result_list instruments={@instruments} target={@myself} />
        <% else %>
          <.trade_form
            form={@form}
            selected_instrument={@selected_instrument}
            myself={@myself}
            action={@action}
          />
        <% end %>
      </.modal>
    </div>
    """
  end

  attr :rest, :global
  attr :value, :string

  def search_input(assigns) do
    ~H"""
    <div class="relative">
      <input
        id="search-instrument"
        {@rest}
        type="text"
        class="mt-2 block w-full rounded-lg bg-gray-700  sm:text-sm sm:leading-6"
        placeholder="Type to search..."
        aria-expanded="false"
        aria-controls="options"
        autocomplete="off"
      />
    </div>
    """
  end

  attr :instruments, :list
  attr :target, :string

  def result_list(assigns) do
    ~H"""
    <ul class="py-2 flex space-y-2 flex-col" id="options" role="listbox">
      <%= for instrument <- @instruments do %>
        <.result_item instrument={instrument} target={@target} />
      <% end %>

      <%= if Enum.empty?(@instruments) do %>
        <li>
          <div class="py-2 text-m text-white">
            No results
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  attr :instrument, :map
  attr :target, :string

  def result_item(assigns) do
    ~H"""
    <li
      class="hover:font-semibold hover:border-gray-200 hover:bg-gray-700 cursor-pointer p-2 border-2 rounded-md"
      id={"option-#{@instrument.instrument_id}"}
      role="option"
      phx-click="select-instrument"
      phx-value-selected_instrument={@instrument.instrument_id}
      phx-target={@target}
    >
      <div class="text-white">
        <%= @instrument.ticker %>
      </div>

      <div class="text-xs text-gray-400">
        <%= "(" <> @instrument.instrument_name <> ")" %>
      </div>
    </li>
    """
  end

  attr :form, :map, required: true
  attr :selected_instrument, :map, required: true
  attr :myself, :any, required: true
  attr :trade, :map
  attr :action, :atom, required: true

  def trade_form(assigns) do
    ~H"""
    <.simple_form
      for={@form}
      id="trade-form"
      phx-change="validate"
      phx-submit="save"
      phx-target={@myself}
    >
      <.input field={@form[:type]} type="select" label="Type" options={[:buy, :sell]} />
      <.input field={@form[:transaction_date]} type="date" label="Transaction Date" />
      <.input
        field={@form[:instrument_name]}
        type="text"
        label="Instrument"
        disabled
        value={@selected_instrument.instrument_name}
      />
      <.input field={@form[:quantity]} type="number" label="Quantity" />
      <.input
        field={@form[:avg_trade_price]}
        type="number"
        label="Average Trade Price (INR)"
        step="0.01"
      />
      <.input field={@form[:fees]} type="number" label="Fees (%)" step="0.001" />
      <:actions>
        <.button type="button" phx-click="reset" phx-target={@myself}>Reset</.button>
        <.button phx-disable-with="Saving...">Save Trade</.button>
      </:actions>
    </.simple_form>
    """
  end

  @impl true
  def update(assigns, socket) do
    {trade, instr} =
      case assigns.action do
        :new -> {%Trade{}, nil}
        :edit -> {assigns.trade, assigns.trade.instrument}
      end

    changeset = Portfolio.create_changeset(trade)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(selected_instrument: instr)
     |> assign(instruments: [])
     |> assign(:query, "")
     |> assign(:org_trade, trade)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("do-search", %{"value" => value}, socket) do
    {:noreply, assign(socket, instruments: Market.autocomplete_list(value))}
  end

  @impl true
  def handle_event("select-instrument", %{"selected_instrument" => instrument_id}, socket) do
    instrument = Market.instrument(instrument_id)
    {:noreply, assign(socket, selected_instrument: instrument)}
  end

  @impl true
  def handle_event("validate", %{"trade" => attrs}, socket) do
    changeset = Portfolio.update_changeset(socket.assigns.org_trade, attrs)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("reset", _assigns, socket) do
    instr =
      case socket.assigns.action do
        :new -> nil
        :edit -> socket.assigns.selected_instrument
      end

    {:noreply,
     assign(socket,
       selected_instrument: instr,
       instruments: [],
       form: to_form(Portfolio.create_changeset(socket.assigns.org_trade))
     )}
  end

  @impl true
  def handle_event("save", %{"trade" => trade}, socket) do
    trade =
      Map.put(
        trade,
        "instrument_id",
        to_string(socket.assigns.selected_instrument.instrument_id)
      )

    res =
      case socket.assigns.action do
        :new -> Portfolio.save_trade(trade)
        :edit -> Portfolio.update_trade(socket.assigns.trade, trade)
      end

    case res do
      {:ok, msg} ->
        {:noreply,
         socket
         |> put_flash(:info, msg)
         |> push_navigate(to: socket.assigns.navigate_back)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp instr_not_selected?(selected_instrument) do
    selected_instrument == nil
  end
end
