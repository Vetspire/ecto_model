# coveralls-ignore-start
if Mix.env() == :test do
  defmodule EctoModel.Dog do
    use Ecto.Schema
    use EctoModel.Queryable
    use EctoModel.SoftDelete, field: :deleted_at, type: :utc_datetime
    import Ecto.Changeset

    schema "dogs" do
      field(:breed, :string)
      field(:name, :string)
      field(:date_of_birth, :date)
      field(:notes, :string)
      field(:deleted_at, :utc_datetime)

      belongs_to(:owner, EctoModel.Owner)

      timestamps()
    end

    def changeset(owner, attrs) do
      owner
      |> cast(attrs, [:breed, :name, :date_of_birth, :notes, :owner_id, :deleted_at])
      |> validate_required([:breed, :name, :date_of_birth, :owner_id])
    end
  end
end
