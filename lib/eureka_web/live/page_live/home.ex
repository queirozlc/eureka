defmodule EurekaWeb.PageLive.Home do
  use EurekaWeb, :live_view
  alias Eureka.Avatar
  alias Eureka.Players

  embed_templates "components/*"

  @impl true
  def mount(_params, _session, socket) do
    room_changeset = Players.change_room(%Players.Room{})

    socket =
      socket
      |> assign_async(:avatar, &Avatar.random/0)
      |> assign_form(room_changeset)
      |> assign(:check_errors, false)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("create_room", _params, socket) do
    user = socket.assigns.current_user
    {:noreply, apply_action(socket, user)}
  end

  @impl true
  def handle_event("validate", %{"room" => room_params}, socket) do
    changeset = Players.change_room(%Players.Room{}, room_params)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("join_room", %{"room" => %{"code" => code}}, socket) do
    if room = Players.get_room_by_code(code) do
      num_players = Enum.count(EurekaWeb.Presence.list_online_users(room))
      {:noreply, check_room_capacity(socket, room, num_players)}
    else
      {:noreply, put_flash(socket, :error, "Invalid room code")}
    end
  end

  defp apply_action(socket, nil) do
    socket
    |> put_flash(:error, "You must be logged in to create a room")
    |> push_patch(to: ~p"/users/guest/log_in")
  end

  defp apply_action(socket, user) do
    {:ok, room} = Players.create_room(%{user_id: user.id})

    socket
    |> assign(room: room)
    |> push_navigate(to: ~p"/rooms/#{room.code}/settings")
  end

  defp assign_form(socket, changeset) do
    form = to_form(changeset, as: "room")

    if changeset.valid? do
      assign(socket, form: form, check_errors: false)
    else
      assign(socket, form: form)
    end
  end

  defp check_room_capacity(socket, room, num_players) do
    if Players.can_join_room?(room, num_players) do
      navigate_to_room(socket, room)
    else
      put_flash(socket, :error, "Room is full of capacity")
    end
  end

  defp navigate_to_room(socket, room) do
    case socket.assigns.current_user do
      nil ->
        push_patch(socket, to: ~p"/users/guest/log_in")

      user ->
        if Players.owner?(room.code, user.id) do
          push_navigate(socket, to: ~p"/rooms/#{room.code}/settings")
        else
          push_navigate(socket, to: ~p"/rooms/#{room.code}")
        end
    end
  end
end
