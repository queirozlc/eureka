defmodule EurekaWeb.PageLive.Home do
  use EurekaWeb, :live_view
  alias Eureka.Avatar

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
    socket
  end


  end
end
