defmodule TheDotfather.Repo do
  use Ecto.Repo,
    otp_app: :the_dotfather,
    adapter: Ecto.Adapters.Postgres
end
