# coveralls-ignore-start
if Mix.env() == :test do
  defmodule EctoModel.Vaccination do
    use Ecto.Schema
    use EctoModel.Queryable
    use EctoModel.SoftDelete, field: :deleted, type: :boolean

    import Ecto.Changeset

    schema "vaccinations" do
      field(:name, :string)
      field(:date, :date)
      field(:deleted, :boolean)
      belongs_to(:dog, EctoModel.Dog)

      timestamps()
    end

    def changeset(vaccination, attrs) do
      vaccination
      |> cast(attrs, [:name, :date, :dog_id, :deleted])
      |> validate_required([:name, :date, :dog_id])
    end
  end
end
