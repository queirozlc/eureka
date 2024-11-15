defmodule EurekaWeb.GameLive.Show do
  use EurekaWeb, :live_view
  alias Eureka.{Game, GameServer, GameSupervisor, Players, Song}
  alias EurekaWeb.Presence

  @impl true
  def render(assigns) do
    ~H"""
    <audio :if={@loading == false} id="audio" src={@song.preview_url} autoplay />

    <%= if @loading == false && @countdown > 0 do %>
      <h3>
        <%= @countdown %> / <%= @duration %>
      </h3>
    <% end %>

    <section class="grid grid-cols-3 h-[calc(100vh-14rem)] gap-20">
      <aside class="bg-white space-y-4 shadow-brutalism min-w-20 border-2 border-black px-6 py-4">
        <h3 class="font-mono text-xl text-center font-semibold">Leaderboard</h3>
        <ul class="w-full space-y-2 divide-y-4 divide-black">
          <li
            :for={{player_id, player} <- @players}
            id={"user-#{player_id}"}
            class="pt-2 flex items-center justify-between"
          >
            <div class="flex items-center gap-2">
              <div class="size-12 rounded-full"><%= player.avatar |> raw() %></div>
              <%= if player_id == @current_user.id do %>
                <p class="font-mono font-medium text-lg text-center">
                  You
                </p>
              <% else %>
                <p class="font-mono font-medium text-lg text-center">
                  <%= player.nickname || player.email %>
                </p>
              <% end %>
            </div>

            <span class="font-mono font-medium text-lg text-center">
              Points: <%= Enum.find(@scores, fn {id, _} -> id == player_id end) |> elem(1) %>
            </span>
          </li>
        </ul>
      </aside>
      <div class="relative w-full col-span-1">
        <%= if @loading == false do %>
          <img src={@song.cover} class="w-full h-[56%] rounded-xl" alt="song cover" />
          <div class="min-w-full bg-brown-700 bg-clip-padding backdrop-filter backdrop-blur-lg bg-opacity-40 border border-gray-100 rounded-xl absolute inset-0 h-[56%]" />
        <% end %>
      </div>
      <div class="border-l-4 border-black px-4 flex">
        <.simple_form for={@form} class="self-end w-full" id="guess-song-form" phx-submit="guess_song">
          <.input
            type="text"
            id="guessing"
            field={@form[:guess]}
            disabled={player_scored?(@current_user.id, @scores) || @loading}
            name="guessing"
            label="What song?"
            placeholder="Your guess"
            class="!rounded-full bg-white !outline-none !border-2 !border-black shadow-brutalism font-mono font-medium h-12 focus:ring-offset-0 focus:ring-0 focus:border-current"
            required
          />
        </.simple_form>
      </div>
    </section>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    case GameSupervisor.get_game(game_id) do
      {:ok, game_server_pid, game} ->
        GameServer.set_owner(game_server_pid, self())
        room = Players.get_room_by_code(game.room_code)

        if connected?(socket) do
          GameServer.subscribe_game(game_server_pid)
          Presence.track_players(room, socket.assigns.current_user.id)
        end

        scores =
          GameServer.get_scores(game_server_pid)
          |> Enum.map(&{&1.player, &1.score})

        players = GameServer.get_players(game_server_pid)

        {:ok,
         assign(socket,
           game: game,
           game_server_pid: game_server_pid,
           players: players,
           scores: scores,
           song: game.current_song,
           valid_answers: [],
           countdown: 0,
           duration: 0,
           loading: game.current_song == nil,
           song: game.current_song
         )
         |> assign_new(:form, fn ->
           to_form(%{"guess" => ""})
         end)}

      {:error, :game_not_found} ->
        {:ok, put_flash(socket, :error, "Game not found")}
    end
  end

  @impl true
  def handle_event("guess_song", %{"guessing" => guess}, socket) do
    GameServer.guess_song(socket.assigns.game_server_pid, %{
      guess: guess,
      player: socket.assigns.current_user.id
    })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:current_song, %Song.Response{} = song}, socket) do
    {:noreply, assign(socket, song: song, loading: false)}
  end

  def handle_info({:countdown, %{countdown: countdown, duration: duration}}, socket) do
    {:noreply, assign(socket, countdown: countdown, duration: duration)}
  end

  def handle_info(:game_over, socket) do
    owner? = GameServer.owner?(socket.assigns.game_server_pid, self())

    if owner?, do: GameSupervisor.remove_game(socket.assigns.game.id)

    {:noreply, socket}
  end

  def handle_info(:game_ended, socket) do
    room_code = socket.assigns.game.room_code
    current_user_id = socket.assigns.current_user.id

    if Players.owner?(room_code, current_user_id) do
      {:noreply, push_navigate(socket, to: ~p"/rooms/#{room_code}/settings")}
    else
      {:noreply, push_navigate(socket, to: ~p"/rooms/#{room_code}")}
    end
  end

  def handle_info(
        {:guess_result, %{score: %Game.Score{player: player, score: score}}},
        socket
      ) do
    socket =
      socket
      |> assign(
        scores:
          Enum.map(socket.assigns.scores, fn
            {player_id, _} when player_id == player -> {player_id, score}
            {player_id, score} -> {player_id, score}
          end)
      )

    {:noreply, socket}
  end

  def handle_info({:player_left, %Game{} = game}, socket) do
    players = Eureka.Accounts.get_users_map(game.players)
    {:noreply, assign(socket, players: players)}
  end

  @impl true
  def terminate({:shutdown, :left}, socket) do
    game_pid = socket.assigns.game_server_pid
    GameServer.leave_game(game_pid, socket.assigns.current_user.id)
  end

  defp player_scored?(player_id, scores) do
    Enum.find(scores, fn {id, _} -> id == player_id end) |> elem(1) != 0
  end
end
