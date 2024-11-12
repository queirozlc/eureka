defmodule Eureka.GameSupervisor do
  use DynamicSupervisor
  alias Eureka.GameServer

  @impl true
  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_game(room_code, players) do
    case DynamicSupervisor.start_child(__MODULE__, %{
           id: :ignore,
           start: {GameServer, :start_link, [[room_code: room_code, players: players]]}
         }) do
      :ignore ->
        {:error, "GameServer ignored start request"}

      {:error, error} ->
        {:error, error}

      {:ok, child_pid} ->
        broadcast_game_started(room_code, child_pid)
        {:ok, child_pid}
    end
  end

  def subscribe_game_started(room_code) do
    Phoenix.PubSub.subscribe(Eureka.PubSub, "game_started:#{room_code}")
  end

  def broadcast_game_started(room_code, game_server_pid) do
    Phoenix.PubSub.broadcast!(
      Eureka.PubSub,
      "game_started:#{room_code}",
      {:game_started, game_server_pid}
    )
  end

  def games do
    DynamicSupervisor.which_children(__MODULE__)
    |> Stream.filter(&match?({_, _pid, :worker, [GameServer]}, &1))
    |> Stream.map(fn {_, pid, _, _} -> pid end)
    |> Stream.map(&Task.async(fn -> {&1, GameServer.game(&1)} end))
    |> Enum.map(&Task.await/1)
  end

  def get_game(game_id) do
    case Enum.find(games(), fn {_pid, %Eureka.Game{id: id}} -> id == game_id end) do
      nil -> {:error, :game_not_found}
      {game_pid, game} -> {:ok, game_pid, game}
    end
  end
end
