defmodule Eureka.Song do
  alias Eureka.SpotifyAuthenticator
  alias __MODULE__.Response

  defstruct [:artist, :track]

  @type t :: %__MODULE__{
          artist: String.t(),
          track: String.t()
        }

  @task_supervisor Eureka.TaskSupervisor

  @spotify_url "https://api.spotify.com/v1/search/"

  def search(%__MODULE__{artist: artist, track: track}) do
    access_token = get_access_token()

    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{access_token}"}
    ]

    query = "track:#{track} artist:#{artist}"

    options =
      [
        url: @spotify_url,
        headers: headers,
        method: :get,
        params: [q: query, type: "track", limit: 1, market: "BR"]
      ]
      |> Keyword.merge(Application.get_env(:eureka, :eureka_req_options, []))

    request = Req.new(options)

    Task.Supervisor.async_nolink(
      @task_supervisor,
      fn ->
        Req.get!(request).body
        |> parse_song
      end
    )
  end

  @spec duration(Song.Response.t()) :: integer()
  def duration(song) do
    case song.preview_url do
      nil -> 0
      _ -> :timer.seconds(30)
    end
  end

  defp parse_song(%{"tracks" => tracks}) do
    items =
      Map.get(tracks, "items")
      |> Enum.at(0)

    name = Map.get(items, "name")
    artist = Map.get(items, "artists") |> Enum.at(0) |> Map.get("name")
    cover = Map.get(items, "album") |> Map.get("images") |> Enum.at(0) |> Map.get("url")
    preview_url = Map.get(items, "preview_url")

    Response.new(name, artist, cover, preview_url)
  end

  defp get_access_token do
    SpotifyAuthenticator.start()

    case SpotifyAuthenticator.get_access_token() do
      %Task{} = task ->
        Task.await(task)

      token ->
        token
    end
  end
end

defmodule Eureka.Song.Response do
  @enforce_keys [:name, :artist, :cover, :preview_url]
  defstruct [:name, :artist, :cover, :preview_url]

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
end
