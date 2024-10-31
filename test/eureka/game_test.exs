defmodule Eureka.GameTest do
  use Eureka.DataCase
  import Eureka.AccountsFixtures

  alias Eureka.Game

  setup do
    {:ok, user: user_fixture()}
  end

  describe "rooms" do
    alias Eureka.Game.Room

    import Eureka.GameFixtures

    @invalid_attrs %{capacity: nil, score: nil, genres: nil}

    test "list_rooms/0 returns all rooms" do
      room = room_fixture()
      assert Game.list_rooms() == [room]
    end

    test "get_room!/1 returns the room with given id" do
      room = room_fixture()
      assert Game.get_room!(room.id) == room
    end

    test "get_room/1 raises Ecto.NoResultsError when no room found" do
      assert_raise Ecto.NoResultsError, fn -> Game.get_room!(0) end
    end

    test "get_room_by_code/1 returns the room with given code" do
      room = room_fixture()
      assert Game.get_room_by_code(room.code) == room
    end

    test "get_room_by_code/1 returns nil when no room found" do
      assert nil == Game.get_room_by_code("invalid")
    end

    test "create_room/1 with valid data creates a room", %{user: user} do
      valid_attrs = %{user_id: user.id}

      assert {:ok, %Room{} = room} = Game.create_room(valid_attrs)
      assert room.code =~ ~r/^[A-Z0-9]{4}$/
      assert room.capacity == 2
      assert room.score == 0
      assert room.genres == []
    end

    test "create_room/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Game.create_room(@invalid_attrs)
    end

    test "update_room/2 with valid data updates the room" do
      room = room_fixture()
      last_played = DateTime.utc_now()
      update_attrs = %{capacity: 43, score: 43, genres: ["option1"], last_played_at: last_played}

      assert {:ok, %Room{} = room} = Game.update_room(room, update_attrs)
      # cannot compare DateTime directly, so we use DateTime.diff
      assert DateTime.diff(room.last_played_at, last_played) < 1
      assert room.capacity == 43
      assert room.score == 43
      assert room.genres == ["option1"]
    end

    test "update_room/2 with invalid data returns error changeset" do
      room = room_fixture()
      assert {:error, %Ecto.Changeset{}} = Game.update_room(room, @invalid_attrs)
      assert room == Game.get_room!(room.id)
    end

    test "delete_room/1 deletes the room" do
      room = room_fixture()
      assert {:ok, %Room{}} = Game.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Game.get_room!(room.id) end
    end

    test "can_join_room/2 when room is available" do
      room = room_fixture()
      num_players = 1
      assert Game.can_join_room?(room, num_players)
    end

    test "can_join_room/2 when room is full of capacity" do
      room = room_fixture()
      num_players = room.capacity
      refute Game.can_join_room?(room, num_players)
    end

    test "change_room/1 returns a room changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Game.change_room(room)
    end

    test "change_room_settings/1 returns a room changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Game.change_room_settings(room)
    end
  end
end
