defmodule Eureka.Players.Room do
  use Ecto.Schema
  alias Eureka.Accounts.User
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          code: String.t(),
          capacity: non_neg_integer(),
          score: non_neg_integer(),
          genres: [String.t()],
          last_played_at: DateTime.t(),
          user_id: non_neg_integer(),
          user: User.t(),
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  schema "rooms" do
    field :code, :string
    field :capacity, :integer, default: 2
    field :score, :integer, default: 50
    field :genres, {:array, :string}, default: []
    field :last_played_at, :utc_datetime
    belongs_to :user, User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(room, attrs) do
    room
    |> cast(attrs, [:code, :user_id])
    |> validate_required([:code, :user_id])
    |> unique_constraint(:code)
    |> validate_length(:code, is: 4)
    |> validate_format(:code, ~r/^[A-Z0-9]{4}$/,
      message: "must be 4 uppercase alphanumeric characters"
    )
    |> foreign_key_constraint(:user_id)
  end

  @doc """
  The changeset/2 function only setup's the changeset for the room creation.
  After that the owner will customize the room settings, that's why we have
  this function below.
  """
  def settings_changeset(room, attrs) do
    room
    |> cast(attrs, [:capacity, :score, :genres, :last_played_at])
    |> validate_required([:capacity, :score, :genres])
    |> validate_number(:capacity, greater_than: 0)
    |> validate_number(:score, greater_than: 0)
    |> validate_length(:genres, min: 1)
  end

  def generate_code do
    :crypto.strong_rand_bytes(2) |> Base.encode16()
  end
end
