defmodule EurekaWeb.Presence do
  @moduledoc """
  Provides presence tracking to channels and processes.

  See the [`Phoenix.Presence`](https://hexdocs.pm/phoenix/Phoenix.Presence.html)
  docs for more details.
  """
  use Phoenix.Presence,
    otp_app: :eureka,
    pubsub_server: Eureka.PubSub

  alias Eureka.Accounts
  alias Eureka.Game.Room

  @pubsub Eureka.PubSub
  @topic "rooms:"

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def fetch(_topic, presences) do
    users =
      presences
      |> Map.keys()
      |> Accounts.get_users_map()
      |> Enum.into(%{})

    for {key, %{metas: metas}} <- presences, into: %{} do
      {key, %{metas: metas, user: users[String.to_integer(key)]}}
    end
  end

  @impl true
  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    for {user_id, presence} <- joins do
      user_data = %{user: presence.user, metas: Map.fetch!(presences, user_id)}
      local_broadcast(topic, {__MODULE__, %{user_joined: user_data}})
    end

    for {user_id, presence} <- leaves do
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      user_data = %{user: presence.user, metas: metas}

      local_broadcast(topic, {__MODULE__, %{user_left: user_data}})
    end

    {:ok, state}
  end

  def track_players(%Room{code: code}, current_user_id) do
    track(self(), "proxy:" <> topic(code), current_user_id, %{})
  end

  def list_online_users(%Room{code: code}) do
    list("proxy:" <> topic(code))
  end

  def subscribe(%Room{code: code}) do
    Phoenix.PubSub.subscribe(@pubsub, topic(code))
  end

  defp topic(room_code) do
    @topic <> room_code
  end

  defp local_broadcast("proxy:" <> topic, payload) do
    Phoenix.PubSub.local_broadcast(@pubsub, topic, payload)
  end
end
