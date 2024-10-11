defmodule Eureka.Players.Room do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rooms" do
    field :room_code, :string
    field :capacity, :integer
    field :score, :integer
    field :genres, {:array, :string}
    belongs_to :user, Eureka.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:room_code, :user_id])
    |> validate_required([:room_code, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  First set the room creator and generates a random room_code
  then cast the room attributes
  """
  def settings_changeset(room, attrs) do
    room
    |> cast(attrs, [:capacity, :score, :genres])
    |> validate_required([:capacity, :score, :genres])
  end
end
