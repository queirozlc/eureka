defmodule Eureka.Game do
  @moduledoc """
  This module defines the struct who will store the game state.
  """
  alias __MODULE__
  alias Eureka.Song

  @guess_threshold 0.85

  @type t :: %{
          id: String.t(),
          owner: non_neg_integer() | nil,
          room_code: String.t(),
          song_queue: [Song.t()],
          current_song: Song.Response.t() | nil,
          score: [Game.Score.t()],
          round: non_neg_integer(),
          rounds: non_neg_integer(),
          winner: integer(),
          players: [integer()],
          guess_options: [String.t()],
          song_timer: non_neg_integer(),
          timer_ref: reference()
        }

  @enforce_keys [
    :id,
    :owner,
    :room_code,
    :song_queue,
    :current_song,
    :score,
    :round,
    :rounds,
    :winner,
    :players,
    :guess_options,
    :song_timer,
    :timer_ref
  ]
  defstruct [
    :id,
    :owner,
    :room_code,
    :song_queue,
    :current_song,
    :score,
    :round,
    :rounds,
    :winner,
    :players,
    :guess_options,
    :song_timer,
    :timer_ref
  ]

  @spec new_game(
          room_code :: non_neg_integer(),
          players :: [non_neg_integer()],
          songs :: [Song.t()],
          rounds :: non_neg_integer()
        ) :: t()
  def new_game(room_code, players, songs, rounds) do
    score = Enum.map(players, &%Game.Score{score: 0, player: &1})

    %Eureka.Game{
      id: generate_game_id(),
      owner: nil,
      room_code: room_code,
      song_queue: songs,
      current_song: nil,
      score: score,
      round: 0,
      rounds: rounds,
      winner: nil,
      players: players,
      guess_options: [],
      song_timer: 0,
      timer_ref: nil
    }
  end

  @doc """
  Returns the next song in the queue
  """
  @spec next_song(game :: t()) :: Song.t() | nil
  def next_song(%__MODULE__{song_queue: song_queue}) do
    [_ | song_queue] = song_queue
    if Enum.empty?(song_queue), do: nil, else: Enum.at(song_queue, 0)
  end

  @doc """
  Updates the song queue removing the first element and setting the current fetched song
  """
  @spec update_song(game :: t(), song :: Song.Response.t()) :: t()
  def update_song(%__MODULE__{} = game, %Song.Response{} = current_song) do
    [_ | song_queue] = game.song_queue

    %Game{
      game
      | song_queue: song_queue,
        current_song: current_song,
        song_timer: Song.duration(current_song),
        round: game.round + 1,
        guess_options:
          guess_options(%Song{track: current_song.name, artist: current_song.artist}, game)
    }
  end

  @doc """
  Updates the song queue removing the first element, useful when the song is not found and need to skip it

  ## Parameters

    * game - A %Game{} struct representing the current game state

  ## Returns

    * %Game{} - The updated game state with the song queue updated

  ## Examples

      iex> game = %Game{song_queue: [%Song{}, %Song{}]}
      iex> update_song_queue(game)
      %Game{song_queue: [%Song{}]}
  """
  @spec dequeue_song(game :: t()) :: t()
  def dequeue_song(%__MODULE__{} = game) do
    %Game{game | song_queue: Enum.drop(game.song_queue, 0)}
  end

  @doc """
  Returns the score of a player
  """
  @spec get_score(t(), player_id :: non_neg_integer()) :: Game.Score.t()
  def get_score(%Game{score: score}, player_id) do
    Enum.find(score, fn %Game.Score{player: player} -> player == player_id end)
  end

  @doc """
  Decreases the song timer by 1 second
  """
  @spec countdown_timer(t()) :: t()
  def countdown_timer(%__MODULE__{} = game) do
    %Game{game | song_timer: game.song_timer - :timer.seconds(1)}
  end

  @doc """
  Checks if the user input is a valid answer
  """
  @spec valid_guess?(t(), String.t()) :: boolean()
  def valid_guess?(%Game{} = game, guess) do
    guess = guess |> String.normalize(:nfd) |> String.trim() |> String.downcase()
    %Song.Response{name: name, artist: artist} = game.current_song

    answer =
      "#{artist} - #{name}" |> String.normalize(:nfd) |> String.trim() |> String.downcase()

    String.jaro_distance(guess, answer) > @guess_threshold
  end

  def result(%Game{} = game) do
    # Get list of players with their scores, sorted by score (highest first)
    players_by_score = Enum.sort_by(game.score, & &1.score, &>=/2)

    winners =
      case players_by_score do
        [] ->
          nil

        [%Game.Score{player: player, score: score}] ->
          if score == 0 do
            nil
          else
            player
          end

        [player1 | rest] ->
          # if is an array of %Score{score: 0} then it's a draw
          if player1.score == 0 && Enum.all?(rest, &(&1.score == 0)) do
            nil
          else
            # Check for draws by comparing scores with the highest score
            highest_score = player1.score

            winners =
              [player1 | rest]
              |> Stream.take_while(&(&1.score == highest_score))
              |> Stream.map(& &1.player)
              |> Enum.to_list()

            case winners do
              [single_winner] -> single_winner
              multiple_winners -> multiple_winners
            end
          end
      end

    %Game{game | winner: winners}
  end

  @doc """
  Processes a player's song guess and updates the game state accordingly.

  Takes a game state and a map containing the player's guess information. Returns a tuple
  containing a boolean indicating if the guess was correct and the updated game state.

  ## Parameters

    * game - A %Game{} struct representing the current game state
    * guess_info - A map containing:
      * :guess - The player's song guess
      * :player - The id of player making the guess

  ## Returns

    * {true, updated_game} - If the guess was correct, returns true and the game with updated score
    * {false, game} - If the guess was incorrect, returns false and the unchanged game

  ## Examples

      iex> game = %Game{current_song: "Yesterday", scores: %{}}
      iex> guess_info = %{guess: "Yesterday", player: 1}
      iex> guess_song(game, guess_info)
      {true, %Game{current_song: "Yesterday", scores: %{"Player1" => 1}}}

      iex> game = %Game{current_song: "Hey Jude", scores: %{}}
      iex> guess_info = %{guess: "Yesterday", player: 2}
      iex> guess_song(game, guess_info)
      {false, %Game{current_song: "Hey Jude", scores: %{}}}
  """
  @spec guess_song(t(), %{:guess => String.t(), :player => non_neg_integer()}) :: {boolean(), t()}
  def guess_song(%Game{} = game, %{guess: guess, player: player}) do
    if valid_guess?(game, guess) do
      {true, update_score(game, player)}
    else
      {false, game}
    end
  end

  def leave(%Game{} = game, user_id) do
    players = Enum.reject(game.players, &(&1 == user_id))
    %Game{game | players: players}
  end

  defp update_score(%Game{} = game, player) do
    score =
      Enum.map(game.score, fn %Game.Score{player: player_id, score: score} ->
        if player_id == player do
          %Game.Score{player: player_id, score: score + 10}
        else
          %Game.Score{player: player_id, score: score}
        end
      end)

    %Game{game | score: score}
  end

  defp guess_options(%Song{} = song, game) do
    [random_song] = Enum.take_random(game.song_queue, 1)

    valid = "#{song.artist} - #{song.track}"
    # ensures that the random song is different from the valid one
    invalid_random = "#{random_song.artist} - #{random_song.track}"

    if String.jaro_distance(song.track, random_song.track) > 0.85 do
      guess_options(song, game)
    else
      Enum.shuffle([valid, invalid_random])
    end
  end

  defp generate_game_id do
    Ecto.UUID.generate()
  end
end
