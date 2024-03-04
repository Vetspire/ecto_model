defmodule EctoModel.Application do
  @moduledoc false

  use Application

  # coveralls-ignore-start
  @impl Application
  def start(_type, _args) do
    Supervisor.start_link(test_deps(), strategy: :one_for_one, name: __MODULE__)
  end

  defp test_deps do
    if match?({:module, _}, Code.ensure_compiled(EctoModel.Repo)) do
      [EctoModel.Repo]
    else
      []
    end
  end
end
