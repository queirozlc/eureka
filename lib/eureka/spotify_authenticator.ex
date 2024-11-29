defmodule Eureka.SpotifyAuthenticator do
  @moduledoc """
  This module is responsible for authenticating with Spotify's API. This is a worker process
  that will be started by the application supervisor. It will first attempt to get a token from
  the "cache" (an ETS table) and if it doesn't exist, it will request a new token from Spotify.
  and store it in the cache.
  """
  alias Eureka.SpotifyAuthenticator.Credentials

  @auth_url "https://accounts.spotify.com/api/token"
  @cache_ttl :timer.hours(1)
  @app_cache :eureka_cache
  @cache_key :spotify_token

  @doc """
  Fetches the access token from the cache or requests a new one from Spotify.

  ## Examples
      iex> SpotifyAuthenticator.get_access_token()
      %Task{...}

      iex> SpotifyAuthenticator.get_access_token()
      {:ok, %Task{...}}

      iex> SpotifyAuthenticator.get_access_token()
      {:ok, "access_token"}
  """
  @spec get_access_token() :: Task.t() | String.t()
  def get_access_token do
    case Cachex.get(@app_cache, @cache_key) do
      {:ok, nil} ->
        request_token()

      {:ok,
       %Credentials{issued_at: issued_at, expires_in: expires_in, access_token: access_token}} ->
        get_or_refresh_token(issued_at, expires_in, access_token)
    end
  end

  defp request_token do
    client_id = Application.get_env(:eureka, :spotify_client_id)
    client_secret = Application.get_env(:eureka, :spotify_client_secret)

    headers = [
      {"Content-Type", "application/x-www-form-urlencoded"},
      {"Authorization",
       "Basic #{Base.encode64("#{client_id}:#{client_secret}") |> String.trim_trailing()}"}
    ]

    options =
      [
        url: @auth_url,
        headers: headers,
        method: :post,
        retry: :transient,
        form: [grant_type: "client_credentials"]
      ]
      |> Keyword.merge(Application.get_env(:eureka, :eureka_req_options, []))

    request = Req.new(options)

    Task.Supervisor.async(Eureka.TaskSupervisor, fn ->
      %Req.Response{body: body} = Req.post!(request)
      credentials = Credentials.from_map(body)
      Cachex.put(@app_cache, @cache_key, credentials, expire: @cache_ttl)
      credentials.access_token
    end)
  end

  defp get_or_refresh_token(issued_at, expires_in, token) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, issued_at, :second)

    if diff > expires_in - 60 do
      request_token()
    else
      token
    end
  end
end
