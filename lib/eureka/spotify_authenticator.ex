defmodule Eureka.SpotifyAuthenticator do
  @moduledoc """
  This module is responsible for authenticating with Spotify's API. This is a worker process
  that will be started by the application supervisor. It will first attempt to get a token from
  the "cache" (an ETS table) and if it doesn't exist, it will request a new token from Spotify.
  and store it in the cache.
  """
  alias Eureka.SpotifyAuthenticator.Credentials

  @auth_url "https://accounts.spotify.com/api/token"
  @table :spotify_token

  def start do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [
        :named_table,
        :set,
        :public,
        read_concurrency: true,
        write_concurrency: true
      ])
    end

    :already_started
  end

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
  def get_access_token() do
    case :ets.lookup(@table, __MODULE__) do
      [] ->
        request_token()

      [
        {_key,
         %Credentials{issued_at: issued_at, expires_in: expires_in, access_token: access_token}}
      ] ->
        get_or_refresh_token(issued_at, expires_in, access_token)
    end
  end

  def request_token do
    start()

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

    Task.async(fn ->
      %Req.Response{body: body} = Req.post!(request)
      credentials = Credentials.from_map(body)
      :ets.insert(@table, {__MODULE__, credentials})
      credentials.access_token
    end)
  end

  def table do
    @table
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
