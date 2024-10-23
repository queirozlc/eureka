defmodule EurekaWeb.PageLive.Home do
  use EurekaWeb, :live_view
  alias Eureka.Avatar

  embed_templates "components/*"

  attr :avatar, :string, required: true
  attr :action, :atom, required: true
  def join_room_modal(assigns)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Avatar.random(self())

    {:ok, assign(socket, :avatar, "")}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:avatar, svg}, socket) do
    socket
    |> assign(:avatar, svg)
    |> noreply()
  end

  def handle_info(_msg, socket) do
    # message that come here unhandled are:
    # 1. {:DOWN, _ref, :process, _pid, :normal}
    # 2. {_ref, {:ok, response = %Req.Response{}}}

    {:noreply, socket}
  end
end
