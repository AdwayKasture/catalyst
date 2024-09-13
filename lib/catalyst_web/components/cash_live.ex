defmodule CatalystWeb.CashLive do
  alias Catalyst.Portfolio
  alias Catalyst.PortfolioData.Cash
  use CatalystWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.modal id="create-cash-modal" show on_cancel={JS.push("closed")}>
        <.cash_form form={@form} myself={@myself} action={@action} />
      </.modal>
    </div>
    """
  end

  attr :form, :map, required: true
  attr :myself, :any, required: true
  attr :cash, :map
  attr :action, :atom, required: true

  def cash_form(assigns) do
    ~H"""
    <.simple_form
      for={@form}
      id="cash-form"
      phx-change="validate"
      phx-submit="save"
      phx-target={@myself}
    >
      <.input field={@form[:type]} type="select" label="Type" options={[:deposit, :withdraw]} />
      <.input field={@form[:transaction_date]} type="date" label="Transaction Date" />
      <.input field={@form[:amount]} type="number" label="Amount (INR)" step="0.01" />
      <.input field={@form[:fees]} type="number" label="Fees (%)" step="0.001" />
      <:actions>
        <.button type="button" phx-click="reset" phx-target={@myself}>Reset</.button>
        <.button phx-disable-with="Saving...">Save Transaction</.button>
      </:actions>
    </.simple_form>
    """
  end

  @impl true
  def update(assigns, socket) do
    cash =
      case assigns.action do
        :new -> %Cash{}
        :edit -> assigns.cash
      end

    changeset = Portfolio.create_changeset(cash)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:org_cash, cash)
     |> assign(:form, to_form(changeset))}
  end

  @impl true
  def handle_event("validate", %{"cash" => attrs}, socket) do
    changeset = Portfolio.update_changeset(socket.assigns.org_cash, attrs)
    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("reset", _assigns, socket) do
    {:noreply, assign(socket, form: to_form(Portfolio.create_changeset(socket.assigns.org_cash)))}
  end

  @impl true
  def handle_event("save", %{"cash" => cash}, socket) do
    res =
      case socket.assigns.action do
        :new -> Portfolio.save_txn(cash)
        :edit -> Portfolio.update_txn(socket.assigns.org_cash, cash)
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
end
