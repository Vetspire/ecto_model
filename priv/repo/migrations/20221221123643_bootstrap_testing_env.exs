defmodule EctoModel.Repo.Migrations.BootstrapTables do
  use Ecto.Migration

  def change do
    create table(:owners) do
      add(:name, :string, null: false)
      add(:email, :string, null: false)
      add(:phone, :string, null: false)
    end

    create table(:dogs) do
      add(:breed, :string, null: false)
      add(:name, :map, null: false)
      add(:date_of_birth, :date, null: false)
      add(:notes, :text)
      add(:owner_id, references(:owners, on_delete: :delete_all), null: false)
      add(:deleted_at, :utc_datetime)

      timestamps()
    end

    create table(:vaccinations) do
      add(:name, :string, null: false)
      add(:date, :date, null: false)
      add(:dog_id, references(:dogs, on_delete: :delete_all), null: false)
      add(:deleted, :boolean)

      timestamps()
    end
  end
end
