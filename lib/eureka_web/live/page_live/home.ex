defmodule EurekaWeb.PageLive.Home do
  use EurekaWeb, :live_view

  def handle_event("join_room", %{"room_code" => _room_code}, socket) do
    {:noreply, socket}
  end

  def handle_event("new_room", _, socket) do
    socket
    |> noreply()
  end
end
