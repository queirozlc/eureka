defmodule Eureka.GameTest do
  use ExUnit.Case, async: true
  alias Eureka.{Game, Song}

  describe "next_song/1" do
    test "returns the first of queue when there is a song in the queue" do
      players = [1, 2, 3]
      game = Game.new_game("ABC123", players)

      assert %Game{} = game
      assert Enum.count(game.players) == 3
      assert game.current_song == nil

      song_queue = [
        %Song{
          artist: "Adele",
          track: "Easy On Me"
        },
        %Song{
          artist: "Beyoncé",
          track: "Halo"
        }
      ]

      [next_song | _] = song_queue

      song = Game.next_song(%Game{game | song_queue: song_queue})

      assert %Song{} = song
      assert song == next_song
    end

    test "returns nil when there is no song in the queue" do
      players = [1, 2, 3]
      game = Game.new_game("ABC123", players)

      assert %Game{} = game
      assert Enum.count(game.players) == 3
      assert game.current_song == nil

      song_queue = []

      game = %Game{game | song_queue: song_queue}

      song = Game.next_song(game)

      assert song == nil
      assert Enum.count(game.players) == 3
      assert game.song_queue == []
    end
  end

  test "update_song/2" do
    song_response = %Song.Response{
      artist: "Adele",
      cover: "cover.png",
      name: "Easy On Me",
      preview_url: "preview_url"
    }

    players = [1, 2, 3]

    game = Game.new_game("ABC123", players)

    song_queue = [
      %Song{
        artist: "Adele",
        track: "Easy On Me"
      },
      %Song{
        artist: "Beyoncé",
        track: "Halo"
      }
    ]

    game =
      %Game{game | song_queue: song_queue}
      |> Game.update_song(song_response)

    [_ | updated_song_queue] = song_queue

    assert game.current_song == song_response
    assert game.song_queue == updated_song_queue
    assert Enum.count(game.valid_answers) > 0
    assert game.song_timer == 30_000
    assert game.round == 1
  end

  test "get_score/2 returns the score for a specific player" do
    game = Game.new_game(123, [1, 2])
    score = Game.get_score(game, 1)

    assert %Game.Score{player: 1, score: 0} = score
  end

  test "get_score/2 returns nil when the player is not found" do
    game = Game.new_game(123, [1, 2])
    score = Game.get_score(game, 3)

    assert score == nil
  end

  test "countdown_timer/1 decreases the song timer by 1 second" do
    game = %Game{Game.new_game(123, [1]) | song_timer: 5000}
    updated_game = Game.countdown_timer(game)

    assert updated_game.song_timer == game.song_timer - 1000
  end

  describe "valid_guess?/2" do
    test "returns true for valid guesses" do
      song_response = %Song.Response{
        name: "Easy On Me",
        artist: "Adelê",
        preview_url: "http://example.com",
        cover: "image.png"
      }

      game = Game.new_game(123, [1]) |> Game.update_song(song_response)

      assert Game.valid_guess?(game, "Easy On Me")
      assert Game.valid_guess?(game, "easy on me")
      assert Game.valid_guess?(game, "EASY ON ME")
      assert Game.valid_guess?(game, "Adele - Easy On Me")
      assert Game.valid_guess?(game, "Easy On Me - Adele")
    end

    test "returns false for invalid guesses" do
      song_response = %Song.Response{
        name: "Easy On Me",
        artist: "Adele",
        preview_url: "http://example.com",
        cover: "cover.png"
      }

      game = Game.new_game(123, [1]) |> Game.update_song(song_response)

      refute Game.valid_guess?(game, "Wrong Song")
      refute Game.valid_guess?(game, "")
      refute Game.valid_guess?(game, "Easy")
    end
  end

  describe "guess_song/2" do
    setup do
      song_response = %Song.Response{
        name: "Easy On Me",
        artist: "Adele",
        preview_url: "http://example.com",
        cover: "cover.png"
      }

      game = Game.new_game(123, [1]) |> Game.update_song(song_response)
      {:ok, game: game}
    end

    test "returns {true, updated_game} for correct guess", %{game: game} do
      guess_info = %{guess: "Easy On Me", player: 1}
      {result, updated_game} = Game.guess_song(game, guess_info)

      assert result == true
      assert Game.get_score(updated_game, 1).score == 10
    end

    test "returns {false, game} for incorrect guess", %{game: game} do
      guess_info = %{guess: "Wrong Song", player: 1}
      {result, unchanged_game} = Game.guess_song(game, guess_info)

      assert result == false
      assert Game.get_score(unchanged_game, 1).score == 0
      assert unchanged_game == game
    end

    test "returns {true, updated_game} for similar guesses", %{game: game} do
      guess_info = %{guess: "ease on me", player: 1}
      {result, updated_game} = Game.guess_song(game, guess_info)

      assert result == true
      assert Game.get_score(updated_game, 1).score == 10
    end
  end
end
