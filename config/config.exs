import Config

config :ecto_model, ecto_repos: [EctoModel.Repo], table_schema: "public"

config :ecto_model, EctoModel.Repo,
  database: System.fetch_env!("POSTGRES_DB"),
  username: System.fetch_env!("POSTGRES_USER"),
  password: System.fetch_env!("POSTGRES_PASSWORD"),
  hostname: "localhost"
