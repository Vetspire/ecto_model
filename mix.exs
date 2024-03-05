defmodule EctoModel.MixProject do
  use Mix.Project

  def project do
    [
      app: :ecto_model,
      version: "0.0.1",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_apps: [:iex, :mix, :ex_unit],
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        flags: [:error_handling]
      ],
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        lint: :test,
        dialyzer: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "test.watch": :test
      ],
      name: "EctoModel",
      package: package(),
      description: description(),
      source_url: "https://github.com/vetspire/ecto_model",
      homepage_url: "https://github.com/vetspire/ecto_model",
      docs: [
        main: "EctoModel"
      ]
    ]
  end

  def application do
    [
      mod: {EctoModel.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp description() do
    """
    EctoModel is a library that overhauls your EctoSchemas with additional functionality.
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/vetspire/ecto_model"}
    ]
  end

  defp deps do
    [
      # Ecto Model's actual dependencies
      {:jason, "~> 1.1"},
      {:ecto, "~> 3.6"},
      {:ecto_middleware, "~> 1.0"},
      {:ecto_hooks, "~> 1.2"},

      # Adapter Dependencies, should be supplied by host app but these
      # are nice to have for tests.
      {:postgrex, "~> 0.15", only: :test},
      {:ecto_sql, "~> 3.6", only: :test},

      # Runtime dependencies for tests / linting
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.28", only: :dev},
      {:excoveralls, "~> 0.10", only: :test},
      {:mix_test_watch, "~> 1.0", only: [:test], runtime: false}
    ]
  end

  defp aliases do
    [
      test: ["coveralls.html --trace --slowest 10"],
      lint: [
        "format --check-formatted --dry-run",
        "credo --strict",
        "compile --warnings-as-errors",
        "dialyzer"
      ]
    ]
  end
end
