if Mix.env() == :test do
  defmodule EctoModel.Repo do
    @moduledoc false
    use Ecto.Repo,
      otp_app: :ecto_model,
      adapter: Ecto.Adapters.Postgres

    use EctoMiddleware

    @dialyzer {:nowarn_function, middleware: 2}
    def middleware(_resource, _action) do
      [EctoModel.SoftDelete, EctoMiddleware.Super]
    end

    def soft_delete!(resource, opts \\ []) do
      EctoModel.SoftDelete.soft_delete!(resource, Keyword.put(opts, :repo, __MODULE__))
    end

    def soft_delete(resource, opts \\ []) do
      EctoModel.SoftDelete.soft_delete(resource, Keyword.put(opts, :repo, __MODULE__))
    end
  end
end
