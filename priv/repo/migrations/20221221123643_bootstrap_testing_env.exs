defmodule EctoModel.Repo.Migrations.BootstrapTables do
  use Ecto.Migration

  def change do
    create table(:dog) do
      add(:breed, :string, null: false)
      add(:name, :map, null: false)

      timestamps()
    end
  end
end
