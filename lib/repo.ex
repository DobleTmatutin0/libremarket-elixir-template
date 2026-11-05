
defmodule Libremarket.Repo do
  use Ecto.Repo,
    otp_app: :libremarket,
    adapter: Ecto.Adapters.Postgres
end
