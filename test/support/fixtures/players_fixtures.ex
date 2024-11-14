defmodule Eureka.PlayersFixtures do
  alias Eureka.{AccountsFixtures, Players}

  @moduledoc """
  This module defines test helpers for creating
  entities via the `Eureka.Players` context.
  """

  @doc """
  Generate a unique room code.
  """
  def unique_room_code, do: Players.Room.generate_code()

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    user = AccountsFixtures.user_fixture()
    

    {:ok, room} =
      attrs
      |> Enum.into(%{
        code: unique_room_code(),
        user_id: user.id
      })
      |> Players.create_room()

    room
  end
end
