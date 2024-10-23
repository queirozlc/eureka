defmodule EurekaWeb.RoomLive.Show do
  alias Eureka.Game
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
        <button
          class="flex items-center p-1"
          phx-click={JS.dispatch("clipboard:copy", to: "#room_code")}
        >
          <.icon name="hero-clipboard" />
        </button>
      </div>
    </div>

    <div class="w-full bg-white border-2 px-8 border-black shadow-brutalism mt-10 py-10 flex flex-col gap-8">
      <h1 class="text-2xl md:text-3xl font-bold font-mono text-contrast-yellow text-center font-outline-05 select-none drop-shadow-text md:font-outline-05">
        Let's setup your room
      </h1>

      <div>
        <.live_component module={EurekaWeb.RoomLive.FormComponent} room={@room} id={@room.id} />
      </div>
      <.button
        type="submit"
        class="self-center rounded-none w-[10%] !bg-brand border-black border-2 hover:shadow-brutalism-sm"
        form="room-settings"
      >
        Start
      </.button>
    </div>
    """
  end

  @impl true
  def mount(%{"code" => code}, _session, socket) do
    room = Game.get_room_by_code(code)
    {:ok, assign(socket, room: room)}
  end
end
