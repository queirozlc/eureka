defmodule Eureka.PlayersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Eureka.Players` context.
  """

  @doc """
  Generate a unique room code.
  """
  def unique_room_code, do: Eureka.Players.Room.generate_code()

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    user = Eureka.AccountsFixtures.user_fixture()

    {:ok, room} =
      attrs
      |> Enum.into(%{
        code: unique_room_code(),
        user_id: user.id
      })
      |> Eureka.Players.create_room()

    room
  end
end
