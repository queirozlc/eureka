defmodule EurekaWeb.PageLive.Home do
  use EurekaWeb, :live_view
  alias Eureka.Avatar
  alias Eureka.Game

  embed_templates "components/*"

  attr :avatar, :string, required: true
  attr :action, :atom, required: true
  def join_room_modal(assigns)

  @impl true
  def mount(_params, _session, socket) do
    socket
    |> assign_async(:avatar, &Avatar.random/0)
    |> ok()
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

  defp apply_action(socket, nil) do
    socket
    |> put_flash(:error, "You must be logged in to create a room")
    |> push_patch(to: ~p"/users/guest/log_in")
  end

  defp apply_action(socket, user) do
    case Game.create_room(%{user_id: user.id}) do
      {:ok, room} ->
        socket
        |> assign(room: room)
        |> push_navigate(to: ~p"/rooms/#{room.code}/settings")

      {:error, changeset} ->
        socket |> put_flash(:error, "Error creating room") |> assign(changeset: changeset)
    end
  end
end
