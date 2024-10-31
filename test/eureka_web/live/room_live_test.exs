defmodule EurekaWeb.RoomLiveTest do
  use EurekaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Eureka.AccountsFixtures
  import Eureka.PlayersFixtures

  setup :register_and_log_in_user

  @valid_attrs %{"capacity" => 5, "score" => 10}

  describe "Show" do
    setup :create_room

    test "renders the room settings", %{conn: conn, room: room, user: user} do
      {:ok, _lv, html} = live(conn, ~p"/rooms/#{room.code}/settings")
      html =~ "Let's setup your room"
      html =~ "Your room code is: #{room.code}"
      html =~ user.email
    end

    test "validates room changes", %{conn: conn, room: room} do
      {:ok, show_live, _html} = live conn, ~p"/rooms/#{room.code}/settings"

      # It never reaches the error case because of the
      # minimal accepted values of capacity and score selects
      assert show_live
             |> form("#room-settings", room: @valid_attrs)
             |> render_change()
    end

    test "renders the room settings when user have nickname", %{
      conn: conn,
      room: room,
      user: user
    } do
      user = Map.put(user, :nickname, "John")
      {:ok, _lv, html} = live(conn, ~p"/rooms/#{room.code}/settings")
      html =~ "Let's setup your room"
      html =~ "Your room code is: #{room.code}"
      html =~ user.nickname
    end

    test "two users joins the room, show them in the list", %{conn: conn, room: room, user: user} do
      {:ok, view, html} = live(conn, ~p"/rooms/#{room.code}/settings")

      user2 = user_fixture()
      conn2 = log_in_user(build_conn(), user2)
      {:ok, view2, _html} = live(conn2, ~p"/rooms/#{room.code}/settings")

      assert html =~ "Online Players"
      assert Enum.count(EurekaWeb.Presence.list_online_users(room)) == 2
      assert has_element?(view, "#user-#{user.id}")
      assert has_element?(view2, "#user-#{user2.id}")
    end

    test "two users joined and one of them leaves", %{conn: conn, room: room, user: user} do
      {:ok, view, _html} = live(conn, ~p"/rooms/#{room.code}/settings")
      user_2 = user_fixture()

      conn_2 = log_in_user(build_conn(), user_2)

      {:ok, view_2, _html} = live(conn_2, ~p"/rooms/#{room.code}/settings")

      assert Enum.count(EurekaWeb.Presence.list_online_users(room)) == 2
      assert has_element?(view_2, "#user-#{user_2.id}")
      assert has_element?(view_2, "#user-#{user.id}")

      {_user_id, data} = EurekaWeb.Presence.list_online_users(room) |> Enum.at(0)

      data = %{data | metas: []}

      send(view.pid, {EurekaWeb.Presence, %{user_left: data}})

      refute render(view) =~ "#user-#{user.id}"
      refute has_element?(view, "#user-#{user.id}")
      assert has_element?(view_2, "#user-#{user_2.id}")
    end
  end

  defp create_room(_) do
    %{room: room_fixture()}
  end
end
