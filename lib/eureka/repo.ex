defmodule Eureka.Repo do
  use Ecto.Repo,
    otp_app: :eureka,
    adapter: Ecto.Adapters.Postgres
end
