defmodule Eureka.PlayersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Eureka.Players` context.
  """

  @doc """
  Generate a room.
  """
  def room_fixture(attrs \\ %{}) do
    {:ok, room} =
      attrs
      |> Enum.into(%{
        capacity: 42,
        genres: ["option1", "option2"],
        room_code: "some room_code",
        score: 42
      })
      |> Eureka.Players.create_room()

    room
  end
end
