defmodule EurekaWeb.RoomLive.FormComponent do
  alias Eureka.Game
  use EurekaWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        phx-target={@myself}
        phx-submit="start_game"
        phx-change="validate"
        id="room-settings"
      >
        <div class="grid grid-cols-3 divide-x-4 divide-black min-h-60">
          <div class="space-y-6 pt-1">
            <h2 class="font-semibold font-mono text-2xl">
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
                  type="select"
                  options={[5, 10, 15, 20]}
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
                  options={[10, 20, 30, 40, 50, 60, 70, 80, 90, 100]}
                  value={@form[:score].value || 10}
                />
              </li>
            </ul>
          </div>
          <div class="col-span-1">
            <h2 class="font-semibold font-mono text-xl text-center">
              Genres
            </h2>
          </div>
          <div class="pt-1">
            <h2 class="font-semibold font-mono text-xl text-center">
              Online Players
            </h2>
          </div>
        </div>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(%{room: room} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Game.change_room_settings(room))
     end)}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Game.change_room_settings(socket.assigns.room, room_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("start_game", %{"room" => _room_params}, socket) do
    {:noreply, socket}
  end
end
