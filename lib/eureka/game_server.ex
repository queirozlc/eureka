defmodule Eureka.GameServer do
  alias Eureka.{Accounts, Game, Song}
  alias Phoenix.PubSub
  use GenServer
  require Logger

  @pubsub Eureka.PubSub

  # Initialization
  def start_link(room_code: room_code, players: players) do
    GenServer.start_link(__MODULE__, room_code: room_code, players: players)
  end

  @impl true
  def init(room_code: room_code, players: players) do
    new_game = Game.new_game(room_code, players)
    {:ok, new_game, {:continue, :fetch_song}}
  end

  # Client API
  @doc """
  Returns the current game state
  """
  @spec game(pid()) :: Game.t()
  def game(game_server) do
    GenServer.call(game_server, :get_game)
  end

  @doc """
  Get the players in the game
  """
  @spec get_players(pid()) :: [Accounts.User.t()]
  def get_players(game_server) do
    GenServer.call(game_server, :get_players)
  end

  @doc """
  Get the scores of the players in the game
  """
  @spec get_scores(pid()) :: %{String.t() => Game.Score.t()}
  def get_scores(game_server) do
    GenServer.call(game_server, :get_scores)
  end

  @doc """
  Check if the calling process is the owner of the game

  ## Examples
    iex> GameServer.owner?(game_server_pid, self())
    true
  """
  @spec owner?(pid(), pid()) :: boolean()
  def owner?(game_server, pid) do
    GenServer.call(game_server, {:owner?, pid})
  end

  @spec set_owner(pid(), pid()) :: :ok
  def set_owner(game_server, owner_pid) do
    GenServer.cast(game_server, {:set_owner, owner_pid})
  end

  @doc """
  Guess the current song
  """
  @spec guess_song(pid(), %{guess: String.t(), player: String.t()}) :: Game.t()
  def guess_song(game_server, %{guess: guess, player: player}) do
    GenServer.cast(game_server, {:guess_song, %{guess: guess, player: player}})
  end

  @doc """
  Subscribe to the game's topic
  """
  @spec subscribe_game(pid()) :: :ok
  def subscribe_game(game_server) do
    game = game(game_server)
    PubSub.subscribe(@pubsub, topic(game.id))
  end

  def leave_game(game_server, user_id) do
    GenServer.cast(game_server, {:leave_game, user_id})
  end

  # Server API

  @impl true
  def handle_continue(:fetch_song, %Game{timer_ref: timer_ref} = game) do
    if current_song = Game.next_song(game) do
      Song.search(current_song)
      {:noreply, game}
    else
      Process.cancel_timer(timer_ref)
      broadcast_update!(game, :game_over)
      {:noreply, game}
    end
  end

  @impl true
  def handle_cast(:timer, game) do
    Process.send_after(self(), :countdown, 1_000)
    {:noreply, game}
  end

  def handle_cast({:set_owner, owner_pid}, %Game{} = game) do
    {:noreply, %Game{game | owner: owner_pid}}
  end

  def handle_cast({:guess_song, %{guess: guess, player: player}}, %Game{} = game) do
    {valid?, game} = Game.guess_song(game, %{guess: guess, player: player})
    score = Game.get_score(game, player)
    broadcast_update!(game, {:guess_result, %{score: score, valid?: valid?}})
    {:noreply, game}
  end

  def handle_cast({:leave_game, user_id}, %Game{} = game) do
    game = Game.leave(game, user_id)
    broadcast_update!(game, {:player_left, game})
    {:noreply, game}
  end

  @impl true
  def handle_call(:get_game, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:owner?, pid}, _from, %Game{owner: owner} = game) do
    {:reply, pid == owner, game}
  end

  def handle_call(:get_players, _from, %Game{} = game) do
    players = Accounts.get_users_map(game.players)
    {:reply, players, game}
  end

  def handle_call(:get_scores, _from, %Game{} = game) do
    {:reply, game.score, game}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  def handle_info({_ref, %Song.Response{} = fetched_song}, %Game{} = game) do
    Logger.info("Fetched song: #{inspect(fetched_song)}")

    game =
      game
      |> Game.update_song(fetched_song)
      |> broadcast_update!({:current_song, fetched_song})

    if game.timer_ref, do: Process.cancel_timer(game.timer_ref)

    new_timer_ref = Process.send_after(self(), :countdown, 1_000)

    {:noreply, %Game{game | timer_ref: new_timer_ref}}
  end

  def handle_info(:countdown, %Game{} = game) do
    %Game{song_timer: current_timer} = game = Game.countdown_timer(game)

    cond do
      current_timer == 0 ->
        {:noreply, game, {:continue, :fetch_song}}

      true ->
        Logger.debug("Countdown: #{current_timer}")

        countdown = div(current_timer, 1000)
        duration = div(Song.duration(game.current_song), 1000)
        broadcast_update!(game, {:countdown, %{duration: duration, countdown: countdown}})

        new_timer_ref = Process.send_after(self(), :countdown, 1000)

        {:noreply, %Game{game | timer_ref: new_timer_ref}}
    end
  end

  defp broadcast_update!(%Game{id: game_id} = game, message) do
    PubSub.broadcast!(@pubsub, topic(game_id), message)
    game
  end

  defp topic(game_id) do
    "game:" <> game_id
  end
end
