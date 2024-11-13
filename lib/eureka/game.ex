defmodule Eureka.Game do
  @moduledoc """
  This module defines the struct who will store the game state.
  """
  alias __MODULE__
  alias Eureka.Song

  @type t :: %{
          id: String.t(),
          room_code: String.t(),
          song_queue: [Song.t()],
          current_song: Song.Response.t(),
          score: [Game.Score.t()],
          round: integer(),
          winner: integer(),
          valid_answers: [String.t()],
          players: [integer()],
          song_timer: non_neg_integer()
        }

  @enforce_keys [
    :id,
    :room_code,
    :song_queue,
    :current_song,
    :score,
    :round,
    :winner,
    :valid_answers,
    :players,
    :song_timer
  ]
  defstruct [
    :id,
    :room_code,
    :song_queue,
    :current_song,
    :score,
    :round,
    :winner,
    :valid_answers,
    :players,
    :song_timer
  ]

  @spec new_game(integer(), [integer()]) :: Game.t()
  def new_game(room_code, players) do
    queue = [
      # This will be mocked for now but will come through AI in the future
      %Song{
        artist: "Matuê",
        track: "333"
      },
      %Song{
        artist: "Adele",
        track: "Easy On Me"
      },
      %Song{
        artist: "Rihanna",
        track: "Umbrella"
      }
    ]

    score = Enum.map(players, fn player_id -> %Game.Score{score: 0, player: player_id} end)

    %Eureka.Game{
      id: generate_game_id(),
      room_code: room_code,
      song_queue: queue,
      current_song: nil,
      score: score,
      round: 0,
      winner: nil,
      valid_answers: [],
      players: players,
      song_timer: 0
    }
  end

  @doc """
  Returns the next song in the queue
  """
  @spec next_song(game :: Game.t()) :: Song.t()
  def next_song(%__MODULE__{song_queue: song_queue}) do
    hd(song_queue)
  end

  @doc """
  Updates the song queue removing the first element and setting the current fetched song
  """
  @spec update_song(game :: Game.t(), song :: Song.Response.t()) :: Game.t()
  def update_song(%__MODULE__{} = game, %Song.Response{} = current_song) do
    song_queue = tl(game.song_queue)

    %Game{
      game
      | song_queue: song_queue,
        current_song: current_song,
        song_timer: Song.duration(current_song),
        round: game.round + 1,
        valid_answers:
          get_valid_answers(%Song{track: current_song.name, artist: current_song.artist})
    }
  end

  @doc """
  Returns the score of a player
  """
  @spec get_score(Game.t(), player_id :: non_neg_integer()) :: Game.Score.t()
  def get_score(%Game{score: score}, player_id) do
    Enum.find(score, fn %Game.Score{player: player} -> player == player_id end)
  end

  @doc """
  Decreases the song timer by 1 second
  """
  @spec countdown_timer(Game.t()) :: Game.t()
  def countdown_timer(%__MODULE__{} = game) do
    %Game{game | song_timer: game.song_timer - :timer.seconds(1)}
  end

  @doc """
  Checks if the user input is a valid answer
  """
  @spec valid_guess?(Game.t(), String.t()) :: boolean()
  def valid_guess?(%Game{valid_answers: valid_answers}, guess) do
    guess = String.normalize(guess, :nfd) |> String.trim() |> String.downcase()
    Enum.member?(valid_answers, guess)
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
  @spec guess_song(Game.t(), Map.t()) :: {boolean(), Game.t()}
  def guess_song(%Game{} = game, %{guess: guess, player: player}) do
    if valid_guess?(game, guess) do
      {true, update_score(game, player)}
    else
      {false, game}
    end
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

  defp generate_game_id do
    Ecto.UUID.generate()
  end

  # This function will return the valid answers for the current song
  # The main idea is to handle the possible cases of the user input
  # Take the song "Easy on Me" by Adele as an example
  # The valid answers will be ["Easy on Me", "easy on me", "Adele - Easy on Me", "adele - easy on me", "EASY ON ME", "ADELE - EASY ON ME", "easy on me - adele", "EASY ON ME - ADELE"]
  defp get_valid_answers(%Song{track: track, artist: artist}) do
    artist = String.normalize(artist, :nfd)

    [
      track,
      String.downcase(track),
      String.capitalize(track),
      String.upcase(track),
      "#{artist} - #{track}",
      "#{String.downcase(artist)} - #{String.downcase(track)}",
      "#{String.capitalize(artist)} - #{String.capitalize(track)}",
      "#{String.upcase(artist)} - #{String.upcase(track)}",
      "#{track} - #{artist}",
      "#{String.downcase(track)} - #{String.downcase(artist)}",
      "#{String.capitalize(track)} - #{String.capitalize(artist)}",
      "#{String.upcase(track)} - #{String.upcase(artist)}"
    ]
    |> Enum.map(&String.trim/1)
  end
end
