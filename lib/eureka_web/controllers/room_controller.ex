defmodule EurekaWeb.RoomController do
  use EurekaWeb, :controller

  def join(conn, %{"room" => %{"code" => code}}) do
    conn
    |> put_flash(:info, "Joining room")
    |> redirect(to: ~p"/rooms/#{code}")
  end
end
