defmodule Catalyst.PortfolioUtil do
  use Catalyst.DataCase

  def wait_for_tasks() do
    pids = Task.Supervisor.children(Catalyst.TaskSupervisor)

    case pids do
      [] ->
        wait_for_tasks()

      pids ->
        for pid <- pids do
          ref = Process.monitor(pid)
          assert_receive {:DOWN, ^ref, _, _, _reason}
        end
    end
  end

  defmacro wait(lambda) do
    quote do
      res = unquote(lambda)
      wait_for_tasks()
      res
    end
  end
end
