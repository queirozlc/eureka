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
  def get_scores(game_server) do
    GenServer.call(game_server, :get_scores)
  end

  @doc """
  Starts the countdown for the current song
  """
  @spec song_countdown(pid()) :: :ok
  def song_countdown(game_server) do
    GenServer.cast(game_server, :timer)
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

  # Server API

  @impl true
  def handle_continue(:fetch_song, %Game{} = game) do
    Song.search(Game.next_song(game))
    {:noreply, game}
  end

  @impl true
  def handle_cast(:timer, game) do
    Process.send(self(), :countdown, [])
    {:noreply, game}
  end

  def handle_cast({:guess_song, %{guess: guess, player: player}}, %Game{} = game) do
    {valid?, game} = Game.guess_song(game, %{guess: guess, player: player})
    score = Game.get_score(game, player)
    broadcast_update!(game, {:guess_result, %{score: score, valid?: valid?}})
    {:noreply, game}
  end

  @impl true
  def handle_call(:get_game, _from, state) do
    {:reply, state, state}
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
    # After fetch and broadcast song, now i need to start the timer for the song
    # and then broadcast the timer, the timer will be the countdown for the song
    # and then when the timer is done, i need to fetch the next song

    Logger.info("Fetched song: #{inspect(fetched_song)}")

    {:noreply,
     Game.update_song(game, fetched_song)
     |> broadcast_update!({:current_song, fetched_song})}
  end

  def handle_info(:countdown, %Game{} = game) do
    %Game{song_timer: current_timer} = game = Game.countdown_timer(game)

    if current_timer <= 0 do
      {:noreply, game}
    else
      Logger.debug("Countdown: #{current_timer}")
      Process.send_after(self(), :countdown, :timer.seconds(1))
      {:noreply, game}
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
