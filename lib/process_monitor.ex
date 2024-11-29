defmodule ProcessMonitor do
  use GenServer

  def start_link([]) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init([]) do
    {:ok, %{monitored: %{}}}
  end

  def monitor(exit_callback) when is_function(exit_callback, 1) do
    GenServer.call(__MODULE__, {:monitor, exit_callback})
  end

  @impl true
  def handle_call({:monitor, exit_callback}, {caller_pid, _}, %{monitored: monitored} = state)
      when not is_map_key(monitored, caller_pid) do
    monitor_ref = Process.monitor(caller_pid)

    {:reply, :ok,
     %{state | monitored: Map.put(monitored, caller_pid, {exit_callback, monitor_ref})}}
  end

  @impl true
  def handle_call({:monitor, _exit_callback}, _from, state) do
    {:reply, {:error, :already_monitored}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{monitored: monitored} = state) do
    {{exit_callback, _monitor_ref}, new_monitored} = Map.pop(monitored, pid)

    # should wrap in isolated task or rescue from exception
    exit_callback.(reason)
    {:noreply, %{state | monitored: new_monitored}}
  end
end
