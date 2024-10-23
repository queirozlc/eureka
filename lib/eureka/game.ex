defmodule Eureka.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias Eureka.Repo

  alias Eureka.Game.Room

  @doc """
  Returns the list of rooms.

  ## Examples

      iex> list_rooms()
      [%Room{}, ...]

  """
  def list_rooms do
    Repo.all(Room)
  end

  @doc """
  Gets a single room.

  Raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples

      iex> get_room!(123)
      %Room{}

      iex> get_room!(456)
      ** (Ecto.NoResultsError)

  """
  def get_room!(id), do: Repo.get!(Room, id)

  @doc """
  Similar to `get_room!/1`, but fetches a room by its code.
  Also raises `Ecto.NoResultsError` if the Room does not exist.

  ## Examples
    iex> get_room_by_code!("123")
    %Room{}

    iex> get_room_by_code!("456")
    ** (Ecto.NoResultsError)
  """
  def get_room_by_code(code) do
    from(r in Room, where: r.code == ^code)
    |> Repo.one!()
  end

  @doc """
  Creates a room.

  ## Examples

      iex> create_room(%{field: value})
      {:ok, %Room{}}

      iex> create_room(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_room(attrs \\ %{}) do
    room_code = Room.generate_code()
    attrs = Map.put(attrs, :code, room_code)

    %Room{}
    |> Room.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a room.

  ## Examples

      iex> update_room(room, %{field: new_value})
      {:ok, %Room{}}

      iex> update_room(room, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_room(%Room{} = room, attrs) do
    room
    |> Room.settings_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a room.

  ## Examples

      iex> delete_room(room)
      {:ok, %Room{}}

      iex> delete_room(room)
      {:error, %Ecto.Changeset{}}

  """
  def delete_room(%Room{} = room) do
    Repo.delete(room)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking room changes.

  ## Examples

      iex> change_room(room)
      %Ecto.Changeset{data: %Room{}}

  """
  def change_room(%Room{} = room, attrs \\ %{}) do
    Room.settings_changeset(room, attrs)
  end

  @doc """
  Similar to `change_room/2`, but for updating the room settings
  """
  def change_room_settings(%Room{} = room, attrs \\ %{}) do
    Room.settings_changeset(room, attrs)
  end
end
