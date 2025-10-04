defmodule TheDotfather.Matchmaker do
  @moduledoc """
  Pairs players into duels and starts a game server for each match.
  """

  use GenServer

  alias TheDotfather.GameServer

  @name __MODULE__

  ## Public API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: @name)
  end

  @doc """
  Request to find a match for the given player metadata.
  """
  def find_game(ch_pid, player) do
    GenServer.call(@name, {:find_game, ch_pid, player})
  end

  def cancel(ch_pid) do
    GenServer.cast(@name, {:cancel, ch_pid})
  end

  ## GenServer callbacks

  @impl true
  def init(:ok) do
    {:ok, %{queue: :queue.new()}}
  end

  @impl true
  def handle_call({:find_game, ch_pid, player}, _from, %{queue: queue} = state) do
    Process.monitor(ch_pid)

    case :queue.out(queue) do
      {{:value, {other_pid, other_player}}, remaining_queue} ->
        {:ok, match_id} = start_match(other_player, player)

        send(other_pid, {:match_found, match_id, :p1})
        send(ch_pid, {:match_found, match_id, :p2})

        {:reply, {:paired, match_id}, %{state | queue: remaining_queue}}

      {:empty, _} ->
        updated_queue = :queue.in({ch_pid, player}, queue)
        {:reply, :queued, %{state | queue: updated_queue}}
    end
  end

  @impl true
  def handle_cast({:cancel, ch_pid}, state) do
    {:noreply, %{state | queue: drop_pid(state.queue, ch_pid)}}
  end

  @impl true
  def handle_info({:DOWN, _mref, :process, ch_pid, _reason}, state) do
    {:noreply, %{state | queue: drop_pid(state.queue, ch_pid)}}
  end

  ## Helpers

  defp start_match(p1, p2) do
    match_id = generate_match_id()
    spec = {GameServer, %{match_id: match_id, p1: p1, p2: p2}}

    {:ok, _pid} = DynamicSupervisor.start_child(TheDotfather.GameSupervisor, spec)

    {:ok, match_id}
  end

  defp drop_pid(queue, ch_pid) do
    queue
    |> :queue.to_list()
    |> Enum.reject(fn {pid, _player} -> pid == ch_pid end)
    |> :queue.from_list()
  end

  defp generate_match_id do
    8
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
  end
end
