defmodule Eureka.GameServer do
  alias Eureka.{Accounts, Game, Players, Song}
  alias Phoenix.PubSub
  use GenServer
  require Logger

  @pubsub Eureka.PubSub

  # Initialization
  def start_link(room_code: room_code, players: players, songs: songs) do
    GenServer.start_link(__MODULE__, room_code: room_code, players: players, songs: songs)
  end

  @impl true
  def init(room_code: room_code, players: players, songs: songs) do
    %Players.Room{code: code, score: score} = Players.get_room_by_code(room_code)
    rounds = div(score, 10)
    {:ok, Game.new_game(code, players, songs, rounds), {:continue, :fetch_song}}
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
  Check if the user is the owner of the game

  ## Examples

      iex> GameServer.owner?(game_server_pid, user_id)
      true
  """
  @spec owner?(pid(), user_id :: non_neg_integer()) :: boolean()
  def owner?(game_server, user_id) do
    GenServer.call(game_server, {:owner?, user_id})
  end

  @spec set_owner(pid(), user_id :: non_neg_integer()) :: :ok
  def set_owner(game_server, user_id) do
    GenServer.cast(game_server, {:set_owner, user_id})
  end

  @doc """
  Guess the current song
  """
  @spec guess_song(pid(), %{guess: String.t(), player: String.t()}) :: Game.t()
  def guess_song(game_server, %{guess: guess, player: player}) do
    guess = %{guess: guess, player: player}
    GenServer.cast(game_server, {:guess_song, guess})
  end

  @doc """
  Subscribe to the game's topic
  """
  @spec subscribe_game(pid()) :: :ok
  def subscribe_game(game_server) do
    game = game(game_server)
    PubSub.subscribe(@pubsub, topic(game.id))
  end

  def leave_game(game_server, user_id, player_pid) do
    GenServer.cast(game_server, {:leave_game, user_id, player_pid})
  end

  # Server API

  @impl true
  def handle_continue(:fetch_song, %Game{timer_ref: timer_ref} = game) do
    if current_song = Game.next_song(game) do
      Song.search(current_song)
      {:noreply, game}
    else
      Process.cancel_timer(timer_ref)
      {:stop, :normal, game}
    end
  end

  @impl true
  def handle_cast({:set_owner, owner_id}, %Game{} = game) do
    {:noreply, %Game{game | owner: owner_id}}
  end

  def handle_cast({:guess_song, %{guess: guess, player: player}}, %Game{} = game) do
    {valid?, game} = Game.guess_song(game, %{guess: guess, player: player})

    if game.round == game.rounds do
      %Game{winner: winner} = game = Game.result(game)
      broadcast_update!(game, {:game_over, winner})
    end

    score = Game.get_score(game, player)
    broadcast_update!(game, {:guess_result, %{score: score, valid?: valid?}})
    {:noreply, game}
  end

  def handle_cast({:leave_game, user_id, player_pid}, %Game{} = game) do
    game = Game.leave(game, user_id)
    broadcast_update!(game, {:player_left, game, player_pid})
    {:stop, :normal, game}
  end

  @impl true
  def handle_call(:get_game, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:owner?, id}, _from, %Game{owner: owner_id} = game) do
    {:reply, id == owner_id, game}
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

    game = Game.update_song(game, fetched_song)
    broadcast_update!(game, {:current_song, %{song: fetched_song, game: game}})

    if game.timer_ref, do: Process.cancel_timer(game.timer_ref)

    new_timer_ref = Process.send_after(self(), :countdown, 1_000)

    {:noreply, %Game{game | timer_ref: new_timer_ref}}
  end

  def handle_info({_ref, %{}}, %Game{} = game) do
    game = Game.dequeue_song(game)
    {:noreply, game, {:continue, :fetch_song}}
  end

  def handle_info(:countdown, %Game{} = game) do
    %Game{song_timer: current_timer} = game = Game.countdown_timer(game)

    if current_timer <= 0 do
      if game.round == game.rounds do
        game = Game.result(game)
        broadcast_update!(game, {:game_over, game.winner})
        {:noreply, game}
      else
        {:noreply, game, {:continue, :fetch_song}}
      end
    else
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
