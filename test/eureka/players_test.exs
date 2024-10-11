defmodule Eureka.PlayersTest do
  use Eureka.DataCase

  alias Eureka.Players

  describe "rooms" do
    alias Eureka.Players.Room

    import Eureka.PlayersFixtures

    @invalid_attrs %{room_code: nil, capacity: nil, score: nil, genres: nil}

    test "list_rooms/0 returns all rooms" do
      room = room_fixture()
      assert Players.list_rooms() == [room]
    end

    test "get_room!/1 returns the room with given id" do
      room = room_fixture()
      assert Players.get_room!(room.id) == room
    end

    test "create_room/1 with valid data creates a room" do
      valid_attrs = %{room_code: "some room_code", capacity: 42, score: 42, genres: ["option1", "option2"]}

      assert {:ok, %Room{} = room} = Players.create_room(valid_attrs)
      assert room.room_code == "some room_code"
      assert room.capacity == 42
      assert room.score == 42
      assert room.genres == ["option1", "option2"]
    end

    test "create_room/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Players.create_room(@invalid_attrs)
    end

    test "update_room/2 with valid data updates the room" do
      room = room_fixture()
      update_attrs = %{room_code: "some updated room_code", capacity: 43, score: 43, genres: ["option1"]}

      assert {:ok, %Room{} = room} = Players.update_room(room, update_attrs)
      assert room.room_code == "some updated room_code"
      assert room.capacity == 43
      assert room.score == 43
      assert room.genres == ["option1"]
    end

    test "update_room/2 with invalid data returns error changeset" do
      room = room_fixture()
      assert {:error, %Ecto.Changeset{}} = Players.update_room(room, @invalid_attrs)
      assert room == Players.get_room!(room.id)
    end

    test "delete_room/1 deletes the room" do
      room = room_fixture()
      assert {:ok, %Room{}} = Players.delete_room(room)
      assert_raise Ecto.NoResultsError, fn -> Players.get_room!(room.id) end
    end

    test "change_room/1 returns a room changeset" do
      room = room_fixture()
      assert %Ecto.Changeset{} = Players.change_room(room)
    end
  end
end
