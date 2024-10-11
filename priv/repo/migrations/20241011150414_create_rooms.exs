defmodule Eureka.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :room_code, :string, null: false
      add :capacity, :integer, null: false
      add :score, :integer, null: false
      add :genres, {:array, :string}, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:rooms, [:user_id])
  end
end
