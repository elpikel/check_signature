defmodule CheckSignature.Repo do
  use Ecto.Repo,
    otp_app: :check_signature,
    adapter: Ecto.Adapters.Postgres
end
