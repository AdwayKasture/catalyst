defmodule Catalyst.PortfolioData.PortfolioListener do
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
    state_loop()
  end

  def state_loop() do
    receive do
      data -> process_event(data)
    end

    state_loop()
  end

  defp process_event({:create, _txn}) do
    IO.puts("create observed")
    :ok
  end

  defp process_event({:update, _txn, _org_txn}) do
    IO.puts("update observed")
    :ok
  end

  defp process_event({:delete, _txn}) do
    IO.puts("delete observed")
    :ok
  end
end
