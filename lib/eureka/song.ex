defmodule Eureka.Song do
  require Logger
  alias Eureka.{ExGroq, Players.Room}
  alias __MODULE__

  defstruct [:artist, :track]

  @type t :: %__MODULE__{
          artist: String.t(),
          track: String.t()
        }

  @task_supervisor Eureka.TaskSupervisor

  @api_url "https://itunes.apple.com/search"

  @genres_prompt ~s(Generates 10 random popular song genres. Be sure to answer in a json format with the following structure: "{genres: []}". IMPORTANT: try to return popular genres in Brazil and USA and avoid genres like classical and jazz.)

  @cache_ttl :timer.minutes(5)

  @cache_key :eureka_cache

  @doc """
  Gets the duration of a song. If the song has no preview URL, the duration is 0.

  ## Parameters
    * `song` - A song response struct. `%Song.Response{preview_url: "https://example.com"}`

  ## Examples
    iex> Song.duration(%Song.Response{preview_url: "https://example.com"})
    30
  """
  @spec duration(Song.Response.t()) :: non_neg_integer()
  defdelegate duration(song), to: Song.Response

  @doc """
  Searches for a song on Spotify's API.

  ## Parameters
    * `song` - A song struct with the artist and track name.

  ## Examples

      iex> Song.search(%Song{artist: "Adele", track: "Easy On Me"})
      %Task{...}

  """
  @spec search(Song.t()) :: Task.t()
  def search(%Song{artist: artist, track: track}) do
    query = "#{track} #{artist}"

    options =
      [
        url: @api_url,
        method: :get,
        params: [
          term: query,
          media: "music",
          entity: "song",
          limit: 1
        ]
      ]
      |> Keyword.merge(Application.get_env(:eureka, :eureka_req_options, []))

    request = Req.new(options)

    Task.Supervisor.async_nolink(@task_supervisor, fn ->
      Req.get!(request).body
      |> Jason.decode()
      |> parse_song
    end)
  end

  @doc """
  Retrieves a list of suggested genres using Groq AI API.

  Returns a list of genres based on a predefined prompt.

  > Note: The function is marked with ! as it may raise an error if the API call fails.

  ## Examples

      iex> get_genres_suggestion!("AB20")
      ["rock", "indie", "alternative"]
  """
  @spec get_genres_suggestion!(room_code :: String.t()) :: list()
  def get_genres_suggestion!(room_code) do
    case Cachex.get(@cache_key, room_code) do
      {:ok, nil} ->
        %ExGroq.Response{content: content} = ExGroq.ask!(@genres_prompt)
        genres = Map.get(content, "genres")
        Cachex.put(@cache_key, room_code, genres, expire: @cache_ttl)
        genres

      {:ok, genres} ->
        genres
    end
  end

  @spec get_game_songs(room :: Room.t()) :: [Song.t()]
  def get_game_songs(%Room{genres: genres, score: score}) do
    genres_str = Enum.join(genres, ", ")
    rounds = div(score, 10)

    songs_prompt =
      ~s(Generate #{rounds * 3} songs with the following json format: "{"songs": [{"artist": "artist_name", "track": "track_name"}]} based on the following genres: #{genres_str}. The songs must be popular and most random as possible. is important to have a good mix of genres and songs.)

    %ExGroq.Response{content: content} = ExGroq.ask!(songs_prompt)

    Map.get(content, "songs")
    |> Enum.map(&from_map(&1))
  end

  # in this case, no song was found
  defp parse_song({:ok, %{"results" => []}}) do
    Logger.info("No song was found.")
    %{}
  end

  defp parse_song({:ok, %{"results" => results}}) do
    [track] = results

    name = Map.get(track, "trackName") |> sanitize_name()
    artist = Map.get(track, "artistName")
    cover = Map.get(track, "artworkUrl100")
    preview_url = Map.get(track, "previewUrl")

    Song.Response.new(name, artist, cover, preview_url)
  end

  defp parse_song({:error, decode_error}) do
    Logger.error("Error decoding the response: #{inspect(decode_error)}")
    %{}
  end

  defp from_map(%{"artist" => artist, "track" => track}) do
    %Song{artist: artist, track: track}
  end

  defp from_map(_), do: []

  # remove special characters from the song name such as " - " and " (feat. )"
  defp sanitize_name(name) do
    name
    |> String.replace(~r/ - /, " ")
    |> String.replace(~r/ \(feat. .*\)/, "")
    |> String.replace(~r/ \(.*\)/, "")
    |> String.replace(~r/ \[.*\]/, "")
    |> String.replace(~r/ \{.*\}/, "")
    |> String.trim()
    |> String.split(",")
    |> List.first()
  end
end

defmodule Eureka.Song.Response do
  @enforce_keys [:name, :artist, :cover, :preview_url]
  defstruct [:name, :artist, :cover, :preview_url]
  alias __MODULE__

  @type t :: %__MODULE__{
          name: String.t(),
          artist: String.t(),
          cover: String.t(),
          preview_url: String.t()
        }

  def new(name, artist, cover, preview_url) do
    %__MODULE__{
      name: name,
      artist: artist,
      cover: cover,
      preview_url: preview_url
    }
  end

  def duration(%Response{preview_url: preview_url}) do
    case preview_url do
      nil -> 0
      _ -> :timer.seconds(30)
    end
  end
end
