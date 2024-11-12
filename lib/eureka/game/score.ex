defmodule Eureka.Game.Score do
  defstruct [:player, :score]

  @type t :: %__MODULE__{
          player: integer(),
          score: integer()
        }

  def new(player) do
    %Eureka.Game.Score{
      player: player.id,
      score: 0
    }
  end
end
