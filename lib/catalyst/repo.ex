defmodule Catalyst.Repo do
  use Ecto.Repo,
    otp_app: :catalyst,
    adapter: Ecto.Adapters.Postgres
end
