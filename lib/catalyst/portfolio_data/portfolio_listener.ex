defmodule Catalyst.PortfolioData.PortfolioListener do
  alias Catalyst.Repo
  alias Catalyst.PortfolioData.PortfolioSnapshot
  alias Phoenix.PubSub

  @listener_name __MODULE__

  def start_link(_opts) do
    pid = spawn_link(@listener_name, :init, [])
    {:ok, pid}
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  def init() do
    PubSub.subscribe(Catalyst.PubSub, "transactions")
    PubSub.subscribe(Catalyst.PubSub, "trades")
    state_loop()
  end

  def state_loop() do
    receive do
      data -> process_event(data)
    end

    state_loop()
  end

  defp process_event({_event_type, :create, txn}) do
    # todo handle after today
    portfolio_task(:create, txn, txn.user_id)
    :ok
  end

  defp process_event({_event_type, :update, txn, old_txn}) do
    # handle after today
    portfolio_task(:update, {old_txn, txn}, old_txn.user_id)
    :ok
  end

  defp process_event({_event_type, :delete, txn}) do
    portfolio_task(:delete, txn, txn.user_id)
    :ok
  end

  defp portfolio_task(type, event, user_id) do
    task =
      Task.Supervisor.async(Catalyst.TaskSupervisor, fn ->
        Repo.put_user_id(user_id)

        PortfolioSnapshot.update_snapshot_for(type, event, Timex.today())
      end)

    Task.await(task)
  end
end
