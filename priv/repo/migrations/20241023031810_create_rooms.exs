defmodule Eureka.Repo.Migrations.CreateRooms do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :code, :string, null: false
      add :capacity, :integer, null: false, default: 2
      add :score, :integer, null: false, default: 0
      add :genres, {:array, :string}, null: false, default: []
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :last_played_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:rooms, [:code])
    create index(:rooms, [:user_id])
  end
end
