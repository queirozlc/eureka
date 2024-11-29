defmodule EurekaWeb.GameLive.Show do
  alias Eureka.Accounts
  use EurekaWeb, :live_view
  alias Eureka.{Game, GameServer, GameSupervisor, Players, Song}
  alias EurekaWeb.Presence

  @impl true
  def render(assigns) do
    ~H"""
    <audio :if={@loading == false} id="audio" src={@song.preview_url} phx-hook="AudioPlayer" autoplay />

    <section class="flex h-[calc(100vh-14rem)] gap-10">
      <aside class="bg-white space-y-4 shadow-brutalism flex-1 max-w-xs border-2 border-black px-6 py-4">
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
      <div class="relative mx-auto max-w-md flex-1">
        <%= if @loading == false do %>
          <img src={@song.cover} class="w-full h-[56%] rounded-xl" alt="song cover" />
          <div
            id="cover-backdrop"
            class="min-w-full bg-brown-700 bg-clip-padding backdrop-filter backdrop-blur-lg bg-opacity-40 border border-gray-100 rounded-xl absolute inset-0 h-[56%]"
          />

          <div class="flex flex-col items-center pt-4 text-center space-y-3">
            <h3 class="text-lg font-mono font-medium">
              Which song is this?
            </h3>

            <div class="flex space-x-4 items-center w-full">
              <%= for option <- @game.guess_options  do %>
                <button
                  id={"guess-#{option}"}
                  disabled={@valid}
                  phx-hook="GuessButton"
                  class="font-mono font-medium rounded-sm bg-brand-yellow border-2 border-black flex items-center justify-center hover:bg-brand-yellow text-black w-full transition-shadow duration-200 hover:shadow-brutalism text-sm p-4 disabled:transition-none disabled:bg-gray-100 disabled:shadow-none"
                >
                  <%= option %>
                </button>
              <% end %>
            </div>

            <div class="w-full h-4 self-end bg-zinc-300 shadow-brutalism-sm relative mt-10 rounded-full">
              <div
                class="absolute h-full bg-brand z-10 rounded-full"
                id="countdown_bar"
                style={"width: #{@bar_width}%"}
              />
            </div>
          </div>
        <% end %>
      </div>
    </section>

    <.modal :if={@show_modal} show on_cancel={JS.navigate(~p"/", replace: true)} id="winner-modal">
      <h2 class="text-2xl font-bold mb-4 text-center">Game Over!</h2>
      <div class="text-center flex flex-col items-center space-y-3">
        <%= if @winner do %>
          <div class="size-12 rounded-full">
            <%= @winner.avatar |> raw() %>
          </div>
          <%= if @winner.nickname do %>
            <p class="text-xl mb-4 font-medium font-mono">
              <%= "#{@winner.nickname} wins!" %>
            </p>
          <% else %>
            <p class="text-xl mb-4 font-medium font-mono">
              <%= "Player #{@winner.id} wins!" %>
            </p>
          <% end %>
        <% else %>
          <p class="text-xl mb-4 font-medium font-mono">
            It's a tie!
          </p>
        <% end %>
        <.button phx-click={JS.navigate(~p"/", replace: true)}>
          Back to home
        </.button>
      </div>
    </.modal>
    """
  end

  @impl true
  def mount(%{"game_id" => game_id}, _session, socket) do
    case GameSupervisor.get_game(game_id) do
      {:ok, game_server_pid, game} ->
        room = Players.get_room_by_code(game.room_code)

        if connected?(socket) do
          GameServer.subscribe_game(game_server_pid)
          Presence.track_players(room, socket.assigns.current_user.id)

          ProcessMonitor.monitor(fn _reason ->
            GameServer.leave_game(game_server_pid, socket.assigns.current_user.id, self())
          end)
        end

        scores =
          GameServer.get_scores(game_server_pid)
          |> Enum.map(&{&1.player, &1.score})

        {:ok,
         assign(socket,
           game: game,
           game_server_pid: game_server_pid,
           players: GameServer.get_players(game_server_pid),
           scores: scores,
           song: game.current_song,
           countdown: 0,
           duration: 0,
           winner: game.winner,
           show_modal: false,
           round: game.round,
           loading: game.current_song == nil,
           bar_width: 100,
           valid: false
         )}

      {:error, :game_not_found} ->
        {:ok, put_flash(socket, :error, "Game not found")}
    end
  end

  @impl true
  def handle_event("guess_song", %{"guess" => guess}, socket) do
    player_guessing = %{
      guess: guess,
      player: socket.assigns.current_user.id
    }

    GameServer.guess_song(socket.assigns.game_server_pid, player_guessing)
    {:noreply, assign(socket, valid: true)}
  end

  @impl true
  def handle_info({:current_song, %{song: %Song.Response{} = song, game: game}}, socket) do
    {:noreply, assign(socket, song: song, loading: false, game: game, valid: false)}
  end

  def handle_info({:countdown, %{countdown: countdown, duration: duration}}, socket) do
    bar_width = countdown / duration * 100
    {:noreply, assign(socket, countdown: countdown, duration: duration, bar_width: bar_width)}
  end

  def handle_info({:game_over, winner}, socket) when is_nil(winner) do
    dbg("reached here")
    current_user = socket.assigns.current_user
    owner? = GameServer.owner?(socket.assigns.game_server_pid, current_user.id)

    socket = assign(socket, show_modal: true)

    if owner?, do: GameSupervisor.remove_game(socket.assigns.game.id)

    {:noreply, socket}
  end

  def handle_info({:game_over, winner}, socket) when is_list(winner) do
    current_user = socket.assigns.current_user
    owner? = GameServer.owner?(socket.assigns.game_server_pid, current_user.id)
    socket = assign(socket, winners: winner, show_modal: true)

    if owner?, do: GameSupervisor.remove_game(socket.assigns.game.id)

    {:noreply, socket}
  end

  def handle_info({:game_over, winner}, socket) do
    current_user = socket.assigns.current_user
    owner? = GameServer.owner?(socket.assigns.game_server_pid, current_user.id)

    user_winner = Accounts.get_user!(winner)

    socket = assign(socket, winner: user_winner, show_modal: true, bar_width: 0)

    if owner?, do: GameSupervisor.remove_game(socket.assigns.game.id)

    {:noreply, socket}
  end

  def handle_info(:game_ended, socket) do
    dbg({socket.assigns.winner, socket.assigns.show_modal})
    {:noreply, push_event(socket, "game_ended", %{})}
  end

  def handle_info({:guess_result, %{score: %Game.Score{player: player, score: score}}}, socket) do
    socket =
      assign(socket,
        scores:
          Enum.map(socket.assigns.scores, fn
            {player_id, _} when player_id == player -> {player_id, score}
            {player_id, score} -> {player_id, score}
          end)
      )

    {:noreply, socket}
  end

  def handle_info({:player_left, %Game{} = game, _player_pid}, socket) do
    players = Eureka.Accounts.get_users_map(game.players)

    {:noreply, assign(socket, players: players, game: game)}
  end
end
