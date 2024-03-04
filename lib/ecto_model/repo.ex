if Mix.env() == :test do
  defmodule EctoModel.Repo do
    @moduledoc false
    use Ecto.Repo,
      otp_app: :ecto_model,
      adapter: Ecto.Adapters.Postgres
  end
end
