defmodule EurekaWeb.RoomLive.Show do
  alias Eureka.{GameServer, Players, Song}
  alias EurekaWeb.Presence
  use EurekaWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-1 max-w-md mx-auto">
      <h1 class="text-lg font-mono text-nowrap font-semibold leading-8 text-zinc-800">
        Your room code is:
      </h1>

      <div class="border divide-x divide-black border-black flex items-center rounded-sm bg-white shadow-brutalism pl-4 grow">
        <p class="font-mono font-medium text-xl grow select-none" id="room_code">
          <%= @room.code %>
        </p>
        <button class="flex items-center p-1" phx-click={add_to_clipboard()}>
          <.icon name="hero-clipboard" />
        </button>
      </div>
    </div>

    <div class="w-full bg-white border-2 px-8 border-black shadow-brutalism mt-10 py-10 flex flex-col gap-8">
      <h1
        :if={@live_action == :edit}
        class="text-2xl md:text-3xl font-bold font-mono text-contrast-yellow text-center font-outline-05 select-none drop-shadow-text md:font-outline-05"
      >
        Let's setup your room
      </h1>
      <div>
        <.simple_form for={@form} phx-submit="start_game" phx-change="validate" id="room-settings">
          <div class="grid grid-cols-3 divide-x-4 divide-black min-h-60">
            <div class="space-y-6 pt-1">
              <h2 class="font-semibold font-mono text-xl">
                Settings
              </h2>

              <ul class="space-y-6 pr-4">
                <li class="flex items-center justify-between">
                  <div class="gap-1 flex items-center">
                    <.icon name="hero-user" class="size-6" />
                    <p class="font-mono md:text-lg font-medium text-center">Players</p>
                  </div>

                  <.input
                    field={@form[:capacity]}
                    disabled={@live_action == :show}
                    type="select"
                    options={5..20//5}
                    value={@form[:capacity].value || 5}
                  />
                </li>

                <li class="flex items-center justify-between">
                  <div class="gap-1 flex items-center">
                    <.icon name="hero-trophy" class="size-6" />
                    <p class="font-mono md:text-lg font-medium text-center">Points</p>
                  </div>

                  <.input
                    type="select"
                    field={@form[:score]}
                    disabled={@live_action == :show}
                    options={10..120//10}
                    value={@form[:score].value || 10}
                  />
                </li>
              </ul>
            </div>
            <div class="col-span-1">
              <h2 class="font-semibold font-mono text-xl text-center">
                Genres
              </h2>

              <.async_result :let={genres} assign={@genres}>
                <:loading>
                  <div class="flex items-center justify-center h-full">
                    <.spinner />
                  </div>
                </:loading>

                <:failed>
                  <div class="h-full items-center flex flex-col pt-5 space-y-4">
                    <div class="w-full flex flex-col items-center">
                      <svg
                        class="size-12 text-red-500"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                        xmlns="http://www.w3.org/2000/svg"
                      >
                        <path
                          stroke-linecap="round"
                          stroke-linejoin="round"
                          stroke-width="2"
                          d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
                        >
                        </path>
                      </svg>

                      <div class="text-gray-700 text-base font-medium font-mono">
                        Oops! Something went wrong
                      </div>
                    </div>

                    <div class="w-full px-20">
                      <button
                        class="font-mono font-medium rounded-sm !bg-brand-yellow border-2 border-black h-10 flex items-center justify-center hover:bg-brand-yellow !text-black active:!text-black w-full transition-shadow duration-200 hover:shadow-brutalism"
                        phx-click={JS.push("retry_genres") |> JS.add_class("phx-loading")}
                      >
                        <svg
                          class="mr-2 -ml-1 size-4"
                          xmlns="http://www.w3.org/2000/svg"
                          fill="none"
                          viewBox="0 0 24 24"
                          stroke="currentColor"
                        >
                          <path
                            stroke-linecap="round"
                            stroke-linejoin="round"
                            stroke-width="2"
                            d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"
                          />
                        </svg>
                        Retry
                      </button>
                    </div>
                  </div>
                </:failed>

                <div class="grid grid-cols-2 gap-2 pt-4 px-3">
                  <%= for genre <- genres do %>
                    <div class="font-mono font-medium rounded-sm bg-brand-yellow border-2 border-black h-10 flex items-center justify-center hover:shadow-brutalism-sm text-black w-full text-sm transition-shadow duration-200 cursor-default px-3 py-2">
                      <%= genre %>
                    </div>
                  <% end %>
                </div>
              </.async_result>
            </div>
            <div class="pt-1 space-y-3">
              <h2 class="font-semibold font-mono text-xl text-center">
                Online Players
              </h2>

              <ul class="w-full px-4 space-y-2 divide-y-4 divide-black">
                <li
                  :for={{user_id, user} <- sorted_presences(@presences, @room.user_id)}
                  id={"user-#{user_id}"}
                  class="pt-2"
                >
                  <div class="flex items-center gap-2">
                    <div class="size-12 rounded-full"><%= user.avatar |> raw() %></div>
                    <%= if user.id == @current_user.id do %>
                      <p class="font-mono font-medium text-lg text-center">
                        You
                      </p>
                    <% else %>
                      <p class="font-mono font-medium text-lg text-center">
                        <%= user.nickname || user.email %>
                      </p>
                    <% end %>
                  </div>
                </li>
              </ul>
            </div>
          </div>
        </.simple_form>
      </div>
      <.button
        :if={@room.user_id == @current_user.id}
        type="submit"
        class="self-center rounded-none w-[10%] !bg-brand border-black border-2 hover:shadow-brutalism-sm"
        form="room-settings"
        phx-disable-with="Starting..."
      >
        Start
      </.button>
    </div>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    room = Players.get_room_by_code(code)

    if connected?(socket) do
      Presence.subscribe(room)
      Presence.track_players(room, socket.assigns.current_user.id)
      Eureka.GameSupervisor.subscribe_game_start(room.code)
    end

    socket =
      socket
      |> assign(room: room)
      |> assign_presences()
      |> assign_async(:genres, fn -> get_genres(room) end, supervisor: Eureka.TaskSupervisor)
      |> assign_new(:form, fn ->
        to_form(Players.change_room_settings(room))
      end)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Players.change_room_settings(socket.assigns.room, room_params)

    if changeset.valid? do
      Players.update_room(socket.assigns.room, room_params)
    end

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event(
        "start_game",
        _params,
        %{assigns: %{room: room, current_user: current_user}} = socket
      ) do
    players_id = Presence.get_online_users_id(room)

    songs = Song.get_game_songs(room)

    case Eureka.GameSupervisor.start_game(room.code, players_id, songs) do
      {:ok, game_pid} ->
        GameServer.set_owner(game_pid, current_user.id)
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start the game: #{reason}")}
    end
  end

  @impl true
  def handle_info({Presence, %{user_joined: presence}}, socket) do
    {:noreply, assign_presence(socket, presence)}
  end

  def handle_info({Presence, %{user_left: presence}}, socket) do
    %{user: user} = presence

    if presence.metas == [] do
      {:noreply, remove_presence(socket, user)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:game_started, game_server_pid}, socket) do
    game = Eureka.GameServer.game(game_server_pid)
    {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
  end

  defp assign_presences(socket) do
    %{room: room} = socket.assigns
    socket = assign(socket, presences: %{})

    room
    |> Presence.list_online_users()
    |> Enum.reduce(socket, fn {_, presence}, acc -> assign_presence(acc, presence) end)
  end

  defp assign_presence(socket, presence) do
    %{user: user} = presence

    socket
    |> update(:presences, &Map.put(&1, user.id, user))
  end

  defp remove_presence(socket, user) do
    socket
    |> update(:presences, &Map.delete(&1, user.id))
  end

  defp sorted_presences(presences, admin_id) do
    Enum.sort_by(presences, fn {_, user} -> {user.id == admin_id, user.id} end)
  end

  defp get_genres(room) do
    genres = Song.get_genres_suggestion!(room.code)

    if genres != room.genres, do: Players.update_room(room, %{genres: genres})

    {:ok, %{genres: genres}}
  end

  defp add_to_clipboard do
    JS.dispatch("clipboard:copy", to: "#room_code")
  end
end
